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

    function invokeAction(notifId, actionIndex) {
        try {
            let notif = root.notificationStore[notifId];
            if (!notif || actionIndex >= notif.actions.length) return;
            notif.actions[actionIndex].invoke();
            if (!notif.resident) {
                root.removeFromModel(notificationPopups, notifId);
                root.scheduleTrim();
            }
        } catch (e) { console.warn("hypr-shell: notification action invoke failed:", e); }
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

            let labels = [];
            for (let i = 0; i < notification.actions.length; i++)
                labels.push(notification.actions[i].text);

            let entry = {
                notifId: id,
                appName: (notification.appName || "").trim() || "System",
                summary: (notification.summary || "").trim() || "Notification",
                body: notification.body || "",
                timestamp: Date.now(),
                hasActions: notification.actions.length > 0,
                actionLabels: JSON.stringify(labels),
                urgency: notification.urgency || 0
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
