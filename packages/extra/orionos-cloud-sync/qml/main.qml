import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

ApplicationWindow {
    id: root
    visible: true
    width: 800
    height: 600
    title: "OrionOS Cloud Sync"
    Material.theme: Material.Dark
    Material.accent: "#6366f1"

    header: ToolBar {
        Material.background: "#1e1e2e"
        RowLayout {
            anchors.fill: parent
            Label {
                text: "Cloud Sync"
                font.pixelSize: 18
                font.bold: true
                color: "#cdd6f4"
                Layout.fillWidth: true
            }
            ToolButton {
                icon.name: "settings-configure"
                onClicked: stackView.push(settingsPage)
                ToolTip.text: "Settings"
                ToolTip.visible: hovered
            }
        }
    }

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: accountPage
    }

    Component {
        id: accountPage
        AccountPage {
            onNavigateToSync: stackView.push(syncPage)
        }
    }

    Component {
        id: syncPage
        SyncPage {}
    }

    Component {
        id: settingsPage
        SettingsPage {}
    }
}
