pragma ComponentBehavior: Bound

import QtQuick

// Renders the action buttons attached to a notification.
//
// Quickshell gives notification actions as live objects, but ListModel entries
// can only store simple values. NotificationService stores the visible labels
// as JSON; this component turns those labels back into buttons and reports which
// index was clicked so NotificationService can invoke the real action object.
Flow {
    id: root

    property bool hasActions: false
    property string actionLabels: "[]"
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
            required property string modelData
            required property int index

            label: modelData
            accentColor: root.accentColor
            textColor: root.accentTextColor
            hoverTextColor: root.accentTextColor
            width: implicitWidth
            height: implicitHeight
            onClicked: root.actionInvoked(index)
        }
    }

    Repeater {
        model: root.hasActions ? JSON.parse(root.actionLabels) : []
        delegate: actionButtonDelegate
    }
}
