pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Scope {
    id: root

    property bool doNotDisturb: false
    property bool popupsHovered: false
    property var notificationStore: ({})
    property int nextNotifId: 0

    readonly property int maxHistory: 20
    readonly property int popupDuration: 5500
    property alias historyModel: notificationHistory
    property alias popupModel: notificationPopups

    ListModel { id: notificationHistory }
    ListModel { id: notificationPopups }

    function toggleDoNotDisturb() {
        root.doNotDisturb = !root.doNotDisturb;
    }

    // Dismiss the server-side notification and drop our reference. Every
    // notification is tracked=true, so once it ages out of history we must
    // dismiss() it — otherwise the server keeps it alive forever after we drop
    // our last handle, leaking tracked objects for the whole session.
    function releaseNotification(notifId) {
        try {
            let notif = root.notificationStore[notifId];
            if (notif) notif.dismiss();
        } catch (e) { console.warn("hypr-shell: notification dismiss failed:", e); }
        delete root.notificationStore[notifId];
    }

    function addEntry(entry) {
        notificationHistory.insert(0, entry);
        while (notificationHistory.count > root.maxHistory) {
            let old = notificationHistory.get(notificationHistory.count - 1);
            // Remove from the model before releasing: dismiss() may emit `closed`
            // synchronously, and handleClosed must not race this index removal.
            notificationHistory.remove(notificationHistory.count - 1);
            root.releaseNotification(old.notifId);
        }
    }

    // The source app closed or replaced its own notification. Drop any live
    // popup so it doesn't linger for the full 5.5s pointing at a destroyed
    // object; the history row stays as a log and is released when it ages out.
    function handleClosed(notifId) {
        root.removeFromModel(notificationPopups, notifId);
        root.scheduleTrim();
    }

    // Each popup carries its own expiresAt timestamp, so the trim timer always
    // fires for the soonest-expiring toast rather than a single shared window.
    function scheduleTrim() {
        if (notificationPopups.count === 0) {
            popupTrimTimer.stop();
            return;
        }
        let soonest = Infinity;
        for (let i = 0; i < notificationPopups.count; i++)
            soonest = Math.min(soonest, notificationPopups.get(i).expiresAt);
        popupTrimTimer.interval = Math.max(50, soonest - Date.now());
        popupTrimTimer.restart();
    }

    function removeFromModel(model, notifId) {
        for (let i = model.count - 1; i >= 0; i--) {
            if (model.get(i).notifId === notifId) {
                model.remove(i);
                break;
            }
        }
    }

    // Feedback toast when a click lands on a notification whose sender is
    // gone (e.g. a history card after the app closed the notification). The
    // shell is the server, so this is synthesized straight into the popup
    // model: no notificationStore object exists for it, which is safe —
    // releaseNotification and invokeAction both tolerate a missing entry.
    // Deliberately popup-only and shown even in Do Not Disturb: it answers a
    // click the user just made, and it would only crowd history as a log row.
    function showInternalNotice(summary, body) {
        notificationPopups.insert(0, {
            notifId: root.nextNotifId++,
            appName: "Shell",
            summary: summary,
            body: body,
            timestamp: Date.now(),
            hasActions: false,
            actionsJson: "[]",
            defaultActionIndex: -1,
            urgency: 0,
            expiresAt: Date.now() + root.popupDuration
        });
        root.scheduleTrim();
    }

    function invokeAction(notifId, actionIndex) {
        try {
            let notif = root.notificationStore[notifId];
            if (!notif || actionIndex >= notif.actions.length) {
                root.showInternalNotice("Action unavailable",
                    "The app closed this notification, so its actions can no longer be invoked.");
                return;
            }
            notif.actions[actionIndex].invoke();
            if (!notif.resident) {
                root.removeFromModel(notificationPopups, notifId);
                root.scheduleTrim();
            }
        } catch (e) {
            console.warn("hypr-shell: notification action invoke failed:", e);
            root.showInternalNotice("Action failed",
                "This notification's actions are no longer available.");
        }
    }

    function dismissPopup(notifId) {
        root.removeFromModel(notificationPopups, notifId);
        root.scheduleTrim();
    }

    function dismissHistory(notifId) {
        root.removeFromModel(notificationHistory, notifId);
        root.removeFromModel(notificationPopups, notifId);
        root.releaseNotification(notifId);
        root.scheduleTrim();
    }

    function clearAll() {
        // Snapshot ids and clear the models first, so the dismiss() calls below
        // (which can emit `closed` synchronously) can't mutate a model we're
        // still iterating.
        let ids = [];
        for (let i = 0; i < notificationHistory.count; i++)
            ids.push(notificationHistory.get(i).notifId);
        notificationHistory.clear();
        notificationPopups.clear();
        popupTrimTimer.stop();
        for (let k = 0; k < ids.length; k++)
            root.releaseNotification(ids[k]);
    }

    NotificationServer {
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: function(notification) {
            notification.tracked = true;
            let id = root.nextNotifId++;
            root.notificationStore[id] = notification;
            // Clean up our popup if the app closes/replaces this notification.
            notification.closed.connect(function(reason) { root.handleClosed(id); });

            // Only actions with a visible label become buttons. The freedesktop
            // "default" action is the click-on-the-notification action, not a
            // button: GLib apps (Deja Dup et al) send it with an empty label,
            // so rendering it produced blank buttons. Each button keeps its
            // original index into notification.actions so invokeAction targets
            // the right live action object after filtering.
            let buttons = [];
            let defaultActionIndex = -1;
            for (let i = 0; i < notification.actions.length; i++) {
                let action = notification.actions[i];
                if (action.identifier === "default") {
                    if (defaultActionIndex === -1) defaultActionIndex = i;
                    continue;
                }
                if ((action.text || "").trim().length === 0) continue;
                buttons.push({ label: action.text, index: i });
            }

            let entry = {
                notifId: id,
                appName: (notification.appName || "").trim() || "System",
                summary: (notification.summary || "").trim() || "Notification",
                body: notification.body || "",
                timestamp: Date.now(),
                hasActions: buttons.length > 0,
                actionsJson: JSON.stringify(buttons),
                defaultActionIndex: defaultActionIndex,
                // ?? not ||: 0 is Low, a valid urgency that || would clobber.
                // Only a missing value falls back, and the freedesktop default
                // for an unspecified urgency is Normal (1), not Low.
                urgency: notification.urgency ?? 1
            };
            root.addEntry(entry);
            if (!root.doNotDisturb) {
                notificationPopups.insert(0, Object.assign({}, entry, {
                    expiresAt: Date.now() + root.popupDuration
                }));
                root.scheduleTrim();
            }
        }
    }

    Timer {
        id: popupTrimTimer
        interval: root.popupDuration
        onTriggered: {
            // While hovered, keep every toast alive and re-check after one
            // full duration once the pointer leaves.
            if (root.popupsHovered) {
                let until = Date.now() + root.popupDuration;
                for (let i = 0; i < notificationPopups.count; i++)
                    notificationPopups.setProperty(i, "expiresAt", until);
                root.scheduleTrim();
                return;
            }
            let now = Date.now();
            for (let i = notificationPopups.count - 1; i >= 0; i--) {
                if (notificationPopups.get(i).expiresAt <= now)
                    notificationPopups.remove(i);
            }
            root.scheduleTrim();
        }
    }
}
