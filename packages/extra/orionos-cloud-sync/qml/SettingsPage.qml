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
            text: "Cloud Sync Settings"
            font.pixelSize: 24
            font.bold: true
            color: "#cdd6f4"
        }

        GroupBox {
            Layout.fillWidth: true
            title: "General"
            Material.background: "#313244"

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Label { text: "Auto-sync on startup"; color: "#cdd6f4"; Layout.fillWidth: true }
                    Switch { checked: true }
                }
                RowLayout {
                    Label { text: "Sync interval (minutes)"; color: "#cdd6f4"; Layout.fillWidth: true }
                    SpinBox { from: 1; to: 1440; value: 15 }
                }
                RowLayout {
                    Label { text: "Sync on file change"; color: "#cdd6f4"; Layout.fillWidth: true }
                    Switch { checked: true }
                }
                RowLayout {
                    Label { text: "Bandwidth limit (MB/s)"; color: "#cdd6f4"; Layout.fillWidth: true }
                    SpinBox { from: 0; to: 1000; value: 0 }
                }
            }
        }

        GroupBox {
            Layout.fillWidth: true
            title: "Conflict Resolution"
            Material.background: "#313244"

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Label { text: "Auto-resolve conflicts"; color: "#cdd6f4"; Layout.fillWidth: true }
                    ComboBox {
                        model: ["Keep newer", "Keep local", "Keep remote", "Ask each time"]
                        currentIndex: 3
                    }
                }
                RowLayout {
                    Label { text: "Keep conflict copies"; color: "#cdd6f4"; Layout.fillWidth: true }
                    Switch { checked: true }
                }
            }
        }

        GroupBox {
            Layout.fillWidth: true
            title: "Encryption"
            Material.background: "#313244"

            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                RowLayout {
                    Label { text: "Encrypt synced files"; color: "#cdd6f4"; Layout.fillWidth: true }
                    Switch { checked: false }
                }
                RowLayout {
                    Label { text: "Encryption method"; color: "#cdd6f4"; Layout.fillWidth: true }
                    ComboBox {
                        model: ["AES-256-GCM", "ChaCha20-Poly1305"]
                        enabled: false
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            Button { text: "Reset Defaults"; flat: true }
            Item { Layout.fillWidth: true }
            Button { text: "Apply"; Material.background: "#6366f1" }
        }
    }
}
