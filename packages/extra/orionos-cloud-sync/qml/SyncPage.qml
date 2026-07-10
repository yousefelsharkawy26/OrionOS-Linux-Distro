import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls.Material 2.15

Page {
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 16

        Label {
            text: "Sync Folders"
            font.pixelSize: 24
            font.bold: true
            color: "#cdd6f4"
        }

        Label {
            text: "Configure which folders to synchronize"
            font.pixelSize: 14
            color: "#a6adc8"
        }

        Repeater {
            model: [
                { folder: "Documents", remote: "/Documents", direction: "bidirectional", size: "2.3 GB" },
                { folder: "Pictures", remote: "/Pictures", direction: "download", size: "8.1 GB" },
                { folder: "Desktop", remote: "/Desktop", direction: "bidirectional", size: "156 MB" }
            ]

            delegate: Card {
                Layout.fillWidth: true
                Material.background: "#313244"
                Material.roundedScale: Material.MediumScale

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 8
                        color: "#6366f1"
                        Label {
                            anchors.centerIn: parent
                            text: modelData.folder[0]
                            font.pixelSize: 18
                            font.bold: true
                            color: "white"
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Label {
                            text: modelData.folder
                            font.pixelSize: 16
                            font.bold: true
                            color: "#cdd6f4"
                        }
                        Label {
                            text: modelData.remote + "  |  " + modelData.direction + "  |  " + modelData.size
                            font.pixelSize: 12
                            color: "#a6adc8"
                        }
                    }

                    Switch {
                        checked: true
                    }

                    Button {
                        icon.name: "document-properties"
                        flat: true
                    }
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignRight
            text: "+ Add Folder"
            Material.background: "#6366f1"
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true

            Label {
                text: "Last sync: 5 minutes ago"
                font.pixelSize: 12
                color: "#a6adc8"
                Layout.fillWidth: true
            }

            Button {
                text: "Sync Now"
                Material.background: "#a6e3a1"
                Material.foreground: "#1e1e2e"
            }
        }
    }
}
