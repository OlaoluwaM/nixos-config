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

    function addEntry(entry) {
        notificationHistory.insert(0, entry);
        while (notificationHistory.count > root.maxHistory) {
            let old = notificationHistory.get(notificationHistory.count - 1);
            delete root.notificationStore[old.notifId];
            notificationHistory.remove(notificationHistory.count - 1);
        }
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
            if (!notif.resident) root.removeFromModel(notificationPopups, notifId);
        } catch (e) { console.warn("hypr-shell: notification action invoke failed:", e); }
    }

    function dismissPopup(notifId) {
        root.removeFromModel(notificationPopups, notifId);
    }

    function dismissHistory(notifId) {
        try {
            let notif = root.notificationStore[notifId];
            if (notif) notif.dismiss();
        } catch (e) { console.warn("hypr-shell: notification dismiss failed:", e); }
        delete root.notificationStore[notifId];
        root.removeFromModel(notificationHistory, notifId);
    }

    function clearAll() {
        for (let i = 0; i < notificationHistory.count; i++) {
            let item = notificationHistory.get(i);
            try {
                let notif = root.notificationStore[item.notifId];
                if (notif) notif.dismiss();
            } catch (e) { console.warn("hypr-shell: notification dismiss failed:", e); }
            delete root.notificationStore[item.notifId];
        }
        notificationHistory.clear();
    }

    NotificationServer {
        bodySupported: true
        imageSupported: true
        actionsSupported: true

        onNotification: function(notification) {
            notification.tracked = true;
            let id = root.nextNotifId++;
            root.notificationStore[id] = notification;

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
