pragma ComponentBehavior: Bound

import QtQuick

// Renders the action buttons attached to a notification.
//
// Quickshell gives notification actions as live objects, but ListModel entries
// can only store simple values. NotificationService stores the button actions
// as JSON entries of { label, index }, where index points into the live
// notification.actions array (buttons are a filtered subset — the unlabeled
// "default" action is excluded). This component turns those entries back into
// buttons and reports the original index so NotificationService can invoke the
// real action object.
Flow {
    id: root

    property bool hasActions: false
    property string actionsJson: "[]"
    property int urgency: 1
    readonly property color accentColor: root.urgency === 2 ? Theme.error
        : root.urgency === 0 ? Theme.secondary
        : Theme.primary
    readonly property color accentTextColor: root.urgency === 2 ? Theme.errorForeground
        : root.urgency === 0 ? Theme.secondaryForeground
        : Theme.primaryForeground

    signal actionInvoked(int index)

    spacing: 8
    visible: root.hasActions

    Component {
        id: actionButtonDelegate

        ActionButton {
            required property var modelData

            label: modelData.label
            accentColor: root.accentColor
            textColor: root.accentTextColor
            hoverTextColor: root.accentTextColor
            width: implicitWidth
            height: implicitHeight
            onClicked: root.actionInvoked(modelData.index)
        }
    }

    Repeater {
        model: root.hasActions ? JSON.parse(root.actionsJson) : []
        delegate: actionButtonDelegate
    }
}
