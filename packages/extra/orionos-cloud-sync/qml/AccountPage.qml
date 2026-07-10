import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Page {
    id: page
    signal navigateToSync()

    property var accounts: [
        { name: "Nextcloud", icon: "cloud-download", connected: false, url: "" },
        { name: "WebDAV", icon: "folder-remote", connected: false, url: "" },
        { name: "SFTP", icon: "network-server", connected: false, url: "" }
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Label {
            text: "Cloud Accounts"
            font.pixelSize: 24
            font.bold: true
            color: "#cdd6f4"
        }

        Label {
            text: "Connect your cloud storage providers"
            font.pixelSize: 14
            color: "#a6adc8"
        }

        Repeater {
            model: page.accounts

            delegate: Card {
                Layout.fillWidth: true
                Material.background: "#313244"
                Material.roundedScale: Material.MediumScale

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    Rectangle {
                        width: 48
                        height: 48
                        radius: 24
                        color: modelData.connected ? "#a6e3a1" : "#585b70"

                        Label {
                            anchors.centerIn: parent
                            text: modelData.name[0]
                            font.pixelSize: 20
                            font.bold: true
                            color: modelData.connected ? "#1e1e2e" : "#cdd6f4"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Label {
                            text: modelData.name
                            font.pixelSize: 16
                            font.bold: true
                            color: "#cdd6f4"
                        }
                        Label {
                            text: modelData.connected ? "Connected" : "Not connected"
                            font.pixelSize: 12
                            color: modelData.connected ? "#a6e3a1" : "#a6adc8"
                        }
                    }

                    Button {
                        text: modelData.connected ? "Manage" : "Connect"
                        Material.background: modelData.connected ? "#45475a" : "#6366f1"
                        onClicked: {
                            if (!modelData.connected) {
                                connectDialog.open()
                            } else {
                                page.navigateToSync()
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }

    Dialog {
        id: connectDialog
        anchors.centerIn: parent
        title: "Connect Account"
        modal: true
        width: 400

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            ComboBox {
                Layout.fillWidth: true
                model: ["Nextcloud", "WebDAV", "SFTP"]
                label: "Provider"
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: "https://cloud.example.com"
                label: "Server URL"
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: "username"
                label: "Username"
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: "password"
                echoMode: TextInput.Password
                label: "Password"
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Cancel"
                    onClicked: connectDialog.close()
                }
                Button {
                    text: "Connect"
                    Material.background: "#6366f1"
                    onClicked: connectDialog.close()
                }
            }
        }
    }
}
