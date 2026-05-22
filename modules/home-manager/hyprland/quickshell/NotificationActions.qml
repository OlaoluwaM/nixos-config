import QtQuick

// Renders the action buttons attached to a notification.
//
// Quickshell gives notification actions as live objects, but ListModel entries
// can only store simple values. shell.qml stores the visible labels as JSON;
// this component turns those labels back into buttons and reports which index
// was clicked so shell.qml can invoke the real action object.
Flow {
    id: root

    property bool hasActions: false
    property string actionLabels: "[]"
    property int urgency: 1
    readonly property color accentColor: root.urgency === 2 ? Theme.error
        : root.urgency === 0 ? Theme.secondary
        : Theme.primary

    signal actionInvoked(int index)

    spacing: 8
    visible: root.hasActions

    Repeater {
        model: root.hasActions ? JSON.parse(root.actionLabels) : []

        delegate: ActionButton {
            required property string modelData
            required property int index

            label: modelData
            accentColor: root.accentColor
            width: implicitWidth
            height: implicitHeight
            onClicked: root.actionInvoked(index)
        }
    }
}
