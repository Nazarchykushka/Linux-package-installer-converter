import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import Qt.labs.platform as Platform
import org.kde.kirigami as Kirigami
import Qt5Compat.GraphicalEffects

Kirigami.ApplicationWindow {
    id: mainWindow

    property bool consoleVisible: (backend.showConsole || mainWindow.consoleOverlay) && consoleLines.count > 0
    property bool installFailed: false
    property bool installCancelled: false
    property bool installSuccess: false
    property bool isInstalling: mainWindow.confirmOnClose && !mainWindow.installFinished
    property bool consoleManuallyHidden: false
    property bool consoleHidden: true
    property bool consoleFullWidth: backend.loadConsoleWidthEnabled()
    property string consoleFontFamily: "monospace"
    property bool consoleFontBold: false
    property int consoleFontSize: 12

    Binding {
        target: mainWindow
        property: "width"
        value: {
            if ((backend.packageType === "extracting" && !backend.showConsole) || backend.waitingForInstance) return 380;

            if (backend.showConsole && consoleLines.count > 0) return 500;
            if (mainWindow.consoleOverlay && consoleLines.count > 0) return 480;
            return 380;
        }
    }

    Binding {
        target: mainWindow
        property: "height"
        value: {
            if ((backend.packageType === "extracting" && !backend.showConsole) || backend.waitingForInstance) return 180;

            return (backend.showConsole && consoleLines.count > 0)
                   ? 350
                   : (mainWindow.consoleOverlay && consoleLines.count > 0 ? 310 : 180)
        }
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: mainWindow
        property: "minimumHeight"
        value: {
            if ((backend.packageType === "extracting" && !backend.showConsole) || backend.waitingForInstance) return 180;

            return (backend.showConsole && consoleLines.count > 0)
                   ? 350
                   : (mainWindow.consoleOverlay && consoleLines.count > 0 ? 310 : 180)
        }
        restoreMode: Binding.RestoreBindingOrValue
    }

    Binding {
        target: mainWindow
        property: "minimumWidth"
        value: {
            if ((backend.packageType === "extracting" && !backend.showConsole) || backend.waitingForInstance) return 380;

            if (backend.showConsole && consoleLines.count > 0) return 500;
            if (mainWindow.consoleOverlay && consoleLines.count > 0) return 480;
            return 380;
        }
    }

    maximumHeight:  mainWindow.minimumHeight
    maximumWidth: mainWindow.minimumWidth


    visible: true
    title: qsTr("Linux App Installer")
    color: mainWindow.clrBg

    property bool confirmOnClose: false
    property bool forceClose: false
    property string pendingDebLocation: ""
    property bool consoleOverlay: false

    Connections {
        target: backend
        function onAlwaysShowConsoleChanged() {
            if (backend.alwaysShowConsole) {
                mainWindow.consoleOverlay = true
            } else {
                mainWindow.consoleOverlay = false
            }
        }
    }


    property bool lightMode: backend.loadLightMode()

    property bool installDragOverlay: false
    property bool installFinished: false
    property bool aiExpanded: backend.aiEnabled && aiSwitchSettings.hasToken

    property bool notificationsEnabled: false
    property bool isDependenciesSwitch: false
    property bool anyWindowFocused: mainWindow.active || settingsWindow.active ||
                                     modalWindow.active || modalWindow2.active
    property real lastNotifTime: 0

    function fixedLightness(systemColor, brightness) {
        return Qt.hsla(
            systemColor.hslHue,
            systemColor.hslSaturation,
            brightness,
            systemColor.a
        )
    }

    // Global dynamic color variables
    readonly property bool useSystemAccent: backend.systemColors
    readonly property color clrLink:          backend.systemColors ? fixedLightness(Kirigami.Theme.linkColor, 0.35) : (lightMode ? "#4a5a8a" : "#6272a4")
    readonly property color clrBg:            backend.systemColors && !backend.accentOnlyColors ? Kirigami.Theme.backgroundColor       : (lightMode ? "#f0f0f5" : "#23242D")
    readonly property color clrBgAlt:         backend.systemColors && !backend.accentOnlyColors ? Kirigami.Theme.alternateBackgroundColor : (lightMode ? "#e8e8f0" : "#1E1F29")
    readonly property color clrBgMid:         backend.systemColors && !backend.accentOnlyColors ? Qt.darker(Kirigami.Theme.backgroundColor, 1.05) : (lightMode ? "#dcdce8" : "#2a2b38")
    readonly property color clrBorder:        backend.systemColors && !backend.accentOnlyColors ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.2) : (lightMode ? "#c0c0d0" : "#3a3b4a")
    readonly property color clrBorderAlt:     backend.systemColors && !backend.accentOnlyColors ? Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.35) : (lightMode ? "#a8a8c0" : "#44475a")
    readonly property color clrText:          backend.systemColors && !backend.accentOnlyColors ? Kirigami.Theme.textColor               : (lightMode ? "#1a1a2e" : "white")
    readonly property color clrMuted:         backend.systemColors && !backend.accentOnlyColors ? Kirigami.Theme.disabledTextColor       : (lightMode ? "#6a6a80" : "#888")
    readonly property color clrSubtle:        backend.systemColors && !backend.accentOnlyColors ? Kirigami.Theme.disabledTextColor       : (lightMode ? "#9090a8" : "#555")
    readonly property color clrAccent:        useSystemAccent ? fixedLightness(Kirigami.Theme.highlightColor, 0.35)   : (lightMode ? "#7c6be0" : "#9476ff")
    readonly property color clrAccentAlt:     useSystemAccent ? fixedLightness(Kirigami.Theme.linkColor,      0.25)   : (lightMode ? "#a07ee0" : "#bd93f9")
    readonly property color clrAccentBorder:  useSystemAccent ? fixedLightness(Kirigami.Theme.highlightColor, lightMode ? 0.35 : 0.25)   : (lightMode ? "#7c6be0" : "#6F56AB")
    readonly property color clrAccentFocus:   useSystemAccent ? fixedLightness(Kirigami.Theme.highlightColor, lightMode ? 0.35 : 0.25)   : (lightMode ? "#7c6be0" : "#9476ff")
    readonly property color clrAccentHover:   useSystemAccent ? fixedLightness(Kirigami.Theme.linkColor,      lightMode ? 0.35 : 0.25)   : (lightMode ? "#9070d8" : "#bd93f9")
    readonly property color clrBgHover:       backend.systemColors && !backend.accentOnlyColors ? fixedLightness(Kirigami.Theme.alternateBackgroundColor, 0.35) : (lightMode ? "#717699" : "#44475a")
    readonly property color clrBgButton:      backend.systemColors && !backend.accentOnlyColors ? fixedLightness(Kirigami.Theme.alternateBackgroundColor, 0.35) : (lightMode ? "#717699" : "#44475a")
    readonly property color clrBgButtonHover: backend.systemColors && !backend.accentOnlyColors ? fixedLightness(Kirigami.Theme.highlightColor,           0.35) : (lightMode ? "#8e94bf" : "#595d78")

    onAnyWindowFocusedChanged: {
        if (!anyWindowFocused && mainWindow.installSuccess && notificationsEnabled) {
            var now = Date.now()
            if (now - lastNotifTime > 30000) {
                lastNotifTime = now
                backend.sendDesktopNotification("success")
            }
        }
    }
    Component.onCompleted: {
        notificationsEnabled = backend.loadNotificationsEnabled()
        isDependenciesSwitch = backend.loadDependenciesSwitch()
        consoleFontFamily = backend.loadConsoleFontFamily()
        consoleFontBold = backend.loadConsoleFontBold()
        consoleFontSize = backend.loadConsoleFontSize()
    }

    onVisibleChanged: {
        if (visible) {
            backend.initAiAccess()
        }
    }

    onClosing: function(closeEvent) {
        if (confirmOnClose && !forceClose) {
            closeEvent.accepted = false
            Qt.callLater(function() { killDialog.open() })
        }
    }

    // Drag&drop area + console
    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        // donatebtn
        Rectangle {
            id: donateHeart
            width: 28
            height: 28
            radius: 6
            visible: !progressBar.visible && !backend.loadDonateHidden()
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 4
            anchors.leftMargin: 4

            color: heartArea.containsMouse && !mainWindow.confirmOnClose ? mainWindow.clrBorder : "transparent"
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 0
                anchors.horizontalCenterOffset: -0.5
                text: "♥"
                font.pixelSize: 23
                color: heartArea.containsMouse && !mainWindow.confirmOnClose ? "#a33434" : "#888"
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            MouseArea {
                id: heartArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: mainWindow.confirmOnClose ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                onClicked: {
                    Qt.openUrlExternally("https://example.com")
                }
            }

            ToolTip.text: qsTr("Donate")
            ToolTip.visible: heartArea.containsMouse
            ToolTip.delay: 500
        }

        Row {
            id: topRightRow
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 4
            anchors.rightMargin: 4
            spacing: 6
            z: 10

            // Small green dot when AI is active
            Rectangle {
                width: 8; height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: backend.hasAiAccess && !progressBar.visible
                color: mainWindow.lightMode ? "#17782f" : "#33b554";
            }

            // Gear button
            Rectangle {
                width: 28; height: 28
                radius: 6
                color: gearArea.containsMouse && !mainWindow.confirmOnClose ? mainWindow.clrBorder : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                opacity: mainWindow.confirmOnClose ? 0.35 : 1.0 // ← add
                visible: !progressBar.visible
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 150 } } // ← add


                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.8
                    anchors.horizontalCenterOffset: -0.5
                    text: "⚙"
                    font.pixelSize: 23
                    color: gearArea.containsMouse && !mainWindow.confirmOnClose ? mainWindow.clrAccentHover : "#888"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: gearArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: mainWindow.confirmOnClose ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!mainWindow.confirmOnClose) {
                            settingsWindow.refreshLangModel()  // ← add this line
                            settingsWindow.show()
                        }
                    }
                }

                ToolTip.text: mainWindow.confirmOnClose ? qsTr("Installing in progress…") : qsTr("Settings") // ← changed
                ToolTip.visible: gearArea.containsMouse
                ToolTip.delay: 500
            }
        }

        Row {
            id: topRightRow1
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: -4
            anchors.rightMargin: -4
            spacing: 6
            z: 10

            // Close console button
            Rectangle {
                id: closeConsoleBut
                width: 28; height: 28
                radius: 6
                color: crossArea.containsMouse && !mainWindow.confirmOnClose ? mainWindow.clrBorder : "transparent"
                anchors.verticalCenter: parent.verticalCenter
                opacity: mainWindow.confirmOnClose ? 0.35 : 1.0
                visible: progressBar.visible && !consoleArea.visible && mainWindow.installFinished
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -0.8
                    anchors.horizontalCenterOffset: -0.4
                    text: "⨯"
                    font.pixelSize: 20
                    color: crossArea.containsMouse && !mainWindow.confirmOnClose ? mainWindow.clrAccentHover : "#888"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                MouseArea {
                    id: crossArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: mainWindow.confirmOnClose ? Qt.ForbiddenCursor : Qt.PointingHandCursor
                    onClicked: {
                        if (!mainWindow.confirmOnClose) {
                            mainWindow.consoleHidden = true
                            mainWindow.installFinished = false
                            consoleLines.clear()
                            mainWindow.consoleOverlay = backend.alwaysShowConsole
                            mainWindow.consoleManuallyHidden = true
                        }
                    }
                }

                ToolTip.text: qsTr("Return to main layout")
                ToolTip.visible: crossArea.containsMouse
                ToolTip.delay: 500
            }
        }

        // Show/hide console
        Rectangle {
            width: 28; height: 28
            radius: 6
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.bottomMargin: -8
            anchors.rightMargin: -4
            z: 10
            visible: (mainWindow.confirmOnClose || mainWindow.installFinished) && !backend.showConsole &&
                     backend.packageType !== "extracting" && !mainWindow.consoleOverlay
            color: consoleToggleArea.containsMouse ? (backend.systemColors ? mainWindow.clrBorder : "#3a3b4a") :
                   "transparent"

            Behavior on color { ColorAnimation { duration: 120 } }

            Item {
                width: 14; height: 8
                anchors.centerIn: parent
                anchors.verticalCenterOffset: 3

                Rectangle {
                    width: 8; height: 2
                    radius: 1
                    color: consoleToggleArea.containsMouse ? mainWindow.clrAccentHover : "#888"
                    x: 0; y: 3
                    transformOrigin: Item.Right
                    rotation: 40
                }

                Rectangle {
                    width: 8; height: 2
                    radius: 1
                    color: consoleToggleArea.containsMouse ? mainWindow.clrAccentHover : "#888"
                    x: 6; y: 3
                    transformOrigin: Item.Left
                    rotation: -40
                }
            }

            MouseArea {
                id: consoleToggleArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mainWindow.consoleOverlay = true
            }

            ToolTip.text: qsTr("Show console")
            ToolTip.visible: consoleToggleArea.containsMouse
            ToolTip.delay: 500
        }



        Column {
            anchors.fill: parent
            spacing: 0

            Item {
                width: parent.width

                height: (!backend.showConsole || consoleLines.count === 0)
                        ? parent.height
                        : 150

                // Drag&drop area
                Item {
                    anchors.fill: parent
                    opacity: (!backend.showConsole && (mainWindow.confirmOnClose || mainWindow.installFinished || backend.waitingForInstance)) ? 0 : 1
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    Shape {
                        id: dropFrame
                        width: parent.width
                        height: parent.height

                        ShapePath {
                            strokeStyle: ShapePath.DashLine
                            strokeColor: "grey"
                            strokeWidth: 3
                            dashPattern: [4, 4]
                            fillColor: "transparent"
                            PathRectangle { width: dropFrame.width; height: dropFrame.height }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        enabled: !(!backend.showConsole && (mainWindow.confirmOnClose || mainWindow.installFinished))
                        onDropped: function(drop) {
                            mainWindow.consoleHidden = false
                            if (drop.urls.length > 0) {
                                consoleListView.stickToBottom = true
                                var localPath = Qt.resolvedUrl(drop.urls[0]).toString()
                                localPath = localPath.replace(/^file:\/\//, "")
                                // Remove trailing slash
                                while (localPath.endsWith("/") && localPath.length > 1)
                                    localPath = localPath.slice(0, -1)
                                if (!isInstalling) {
                                    handleDrop(localPath)
                                } else {
                                    backend.launchNewInstance(localPath)
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Drag app package here")
                        color: mainWindow.clrMuted
                    }
                }

                Item {
                    id: progressBar
                    anchors.fill: parent
                    opacity: (!backend.showConsole && (mainWindow.confirmOnClose || mainWindow.installFinished || backend.waitingForInstance || backend.packageType === "extracting")) ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
                    }

                    // Waiting for instance UI
                    Item {
                        anchors.fill: parent
                        opacity: (backend.waitingForInstance && !backend.showConsole) ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 12

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Waiting for another instance to finish")
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                font.pixelSize: 12
                            }

                            Rectangle {
                                id: waitingTrack
                                width: 260
                                height: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: 2
                                color: mainWindow.clrBgMid

                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: waitingTrack.width
                                        height: waitingTrack.height
                                        radius: waitingTrack.radius
                                    }
                                }

                                Rectangle {
                                    id: waitingBar
                                    height: parent.height
                                    radius: 2
                                    width: parent.width * 0.35
                                    color: mainWindow.clrAccent
                                    x: -width

                                    SequentialAnimation on x {
                                        running: backend.waitingForInstance
                                        loops: Animation.Infinite

                                        onRunningChanged: {
                                            if (!running) waitingBar.x = -waitingBar.width
                                        }

                                        NumberAnimation {
                                            from: -waitingBar.width
                                            to: waitingBar.parent.width
                                            duration: 1400
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            to: -waitingBar.width
                                            duration: 0
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Extracting UI
                    Item {
                        anchors.fill: parent
                        visible: (backend.packageType === "extracting" && !backend.waitingForInstance) ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 12

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Extracting archive...")
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                font.pixelSize: 12
                            }

                            Rectangle {
                                id: extractingTrack
                                width: 260
                                height: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                radius: 2
                                color: mainWindow.clrBgMid

                                layer.enabled: true
                                layer.effect: OpacityMask {
                                    maskSource: Rectangle {
                                        width: extractingTrack.width
                                        height: extractingTrack.height
                                        radius: extractingTrack.radius
                                    }
                                }

                                Rectangle {
                                    id: extractingBar
                                    height: parent.height
                                    radius: 2
                                    width: parent.width * 0.35
                                    color: mainWindow.clrAccent
                                    x: -width

                                    SequentialAnimation on x {
                                        running: backend.packageType === "extracting"
                                        loops: Animation.Infinite
                                        onRunningChanged: {
                                            if (!running) extractingBar.x = -extractingBar.width
                                        }
                                        NumberAnimation {
                                            from: -extractingBar.width
                                            to: extractingBar.parent.width
                                            duration: 1400
                                            easing.type: Easing.InOutSine
                                        }
                                        NumberAnimation {
                                            to: -extractingBar.width
                                            duration: 0
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Progress Bar
                    Column {
                        anchors.top: parent.top
                        anchors.topMargin: 16
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 16
                        width: 360
                        opacity: !backend.waitingForInstance && backend.packageType !== "extracting" ? 1 : 0
                        visible: opacity > 0 && backend.packageType !== "extracting"
                        Behavior on opacity {
                            NumberAnimation { duration: 300; easing.type: Easing.InOutQuad }
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Installing a .") + backend.packageType + qsTr(" package")
                            color: mainWindow.clrText
                            font.pixelSize: 13
                            font.bold: true
                        }

                        Item {
                            id: stepsContainer
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            height: 72

                            property var steps: {
                                var t = backend.packageType
                                if (t === "deb") return [
                                    { pct: 8,   label: qsTr("Extracting")     },
                                    { pct: 31,  label: qsTr("Converting (AI)")},
                                    { pct: 54,  label: qsTr("Building pkg")   },
                                    { pct: 77,  label: qsTr("Installing")     },
                                    { pct: 100, label: qsTr("Done")           }
                                ]
                                if (t === "rpm") return [
                                    { pct: 8,   label: qsTr("Extracting")     },
                                    { pct: 31,  label: qsTr("Converting (AI)")},
                                    { pct: 54,  label: qsTr("Building pkg")   },
                                    { pct: 77,  label: qsTr("Installing")     },
                                    { pct: 100, label: qsTr("Done")           }
                                ]
                                if (t === "appimage") return [
                                    { pct: 8,   label: qsTr("Collecting data")},
                                    { pct: 36,  label: qsTr("Building")       },
                                    { pct: 68,  label: qsTr("Installing")     },
                                    { pct: 100, label: qsTr("Done")           }
                                ]
                                if (t === "flatpak") return [
                                    { pct: 8,   label: qsTr("Downloading")    },
                                    { pct: 54,  label: qsTr("Installing")     },
                                    { pct: 100, label: qsTr("Done")           }
                                ]
                                if (t === "arch") return [
                                    { pct: 8,   label: qsTr("Installing")     },
                                    { pct: 100, label: qsTr("Done")           }
                                ]
                                if (t === "tarboll") return [
                                     { pct: 8,   label: qsTr("Extracting") },
                                     { pct: 31,  label: qsTr("Collecting data")},
                                     { pct: 54,  label: qsTr("Building pkg")   },
                                     { pct: 77,  label: qsTr("Installing")     },
                                     { pct: 100, label: qsTr("Done")           }
                                ]
                                if (t === "dir") return [
                                    { pct: 8,   label: qsTr("Copying folder") },
                                    { pct: 31,  label: qsTr("Collecting data") },
                                    { pct: 54,  label: qsTr("Building pkg")   },
                                    { pct: 77,  label: qsTr("Installing")     },
                                    { pct: 100, label: qsTr("Done")           }
                                ]
                                return [
                                    { pct: 8,   label: qsTr("Preparing")      },
                                    { pct: 54,  label: qsTr("Installing")     },
                                    { pct: 100, label: qsTr("Done")           }
                                ]
                            }

                            property int currentStepIndex: {
                                var s = steps
                                var idx = -1
                                for (var i = 0; i < s.length; i++)
                                    if (backend.installProgress >= s[i].pct) idx = i
                                return idx
                            }

                            // Background line
                            Rectangle {
                                x: 0; y: 14
                                width: parent.width
                                height: 4; radius: 2
                                color: mainWindow.clrBgMid
                            }

                            // Accent line
                            Rectangle {
                                x: 0; y: 14
                                height: 4; radius: 2
                                color: mainWindow.clrAccent
                                width: {
                                    var idx = parent.currentStepIndex
                                    if (idx < 0) return 0
                                    return (parent.steps[idx].pct / 100) * parent.width
                                }
                                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                                Behavior on color { ColorAnimation { duration: 400 } }
                            }


                            // Animated line
                            Item {
                                id: animSegmentItem
                                x: fromPct * parent.width
                                y: 14
                                width: segWidth
                                height: 4
                                visible: segWidth > 4 && backend.installProgress < 100

                                property var pbSteps: parent.steps
                                property int pbCurrentIdx: parent.currentStepIndex
                                property real fromPct: pbCurrentIdx >= 0 ? pbSteps[pbCurrentIdx].pct / 100 : 0
                                property real toPct:   (pbCurrentIdx + 1) < pbSteps.length ? pbSteps[pbCurrentIdx + 1].pct / 100 : fromPct
                                property real segWidth: (toPct - fromPct) * parent.width
                                property real barWidth: segWidth * 0.6

                                // Is the current step "Downloading" for flatpak
                                property bool isDownloadStep: backend.packageType === "flatpak" && pbCurrentIdx >= 0 &&pbSteps[pbCurrentIdx].label === qsTr("Downloading")

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 2
                                    color: (mainWindow.installFailed || mainWindow.installCancelled) ? "#ff5555" : mainWindow.installSuccess ? "#39a354" : "transparent"
                                    clip: true

                                    Rectangle {
                                        id: realProgressArrow
                                        visible: animSegmentItem.isDownloadStep
                                        height: parent.height

                                        // Set the radius equal to half the height for full rounding (Capsule shape)
                                        // Or leave a specific number, for example 4, if light rounding is needed
                                        radius: height / 2

                                        color: mainWindow.clrAccent
                                        x: 0

                                        // Width calculation (I removed -9 so that the progress fills the entire space,
                                        // as the arrow is no longer there)
                                        width: animSegmentItem.segWidth * (((backend.installProgress - 8) * 2.174) / 100)

                                        Behavior on width {
                                            NumberAnimation {
                                                duration: 300
                                                easing.type: Easing.OutQuad
                                            }
                                        }

                                        // Canvas block (arrowTip) deleted
                                    }

                                    // Regular animation for all other steps
                                    Rectangle {
                                        id: loaderBar2
                                        visible: !animSegmentItem.isDownloadStep
                                        height: parent.height
                                        radius: 2
                                        color: mainWindow.clrAccent
                                        width: animSegmentItem.barWidth
                                        x: -animSegmentItem.barWidth

                                        property real animProgress: 0
                                        property real lastTime: 0

                                        Timer {
                                            id: loaderTimer
                                            interval: 16
                                            repeat: true
                                            running: !animSegmentItem.isDownloadStep && mainWindow.confirmOnClose && !backend.showConsole && animSegmentItem.segWidth > 4 && backend.installProgress < 100

                                            onTriggered: {
                                                var now = Date.now()
                                                if (loaderBar2.lastTime === 0) loaderBar2.lastTime = now
                                                var delta = now - loaderBar2.lastTime
                                                loaderBar2.lastTime = now
                                                loaderBar2.animProgress += delta / 1800.0
                                                if (loaderBar2.animProgress >= 1.0) loaderBar2.animProgress -= 1.0
                                                var t = loaderBar2.animProgress
                                                var eased = -(Math.cos(Math.PI * t) - 1) / 2
                                                var totalTravel = animSegmentItem.segWidth + animSegmentItem.barWidth * 2
                                                loaderBar2.x = -animSegmentItem.barWidth + eased * totalTravel
                                            }

                                            onRunningChanged: {
                                                if (!running) {
                                                    loaderBar2.lastTime = 0
                                                    loaderBar2.animProgress = 0
                                                    loaderBar2.x = -animSegmentItem.barWidth
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // Dots
                            Repeater {
                                id: stepRepeater
                                model: parent.steps

                                Item {
                                    property real dotX: (modelData.pct / 100) * stepsContainer.width
                                    property bool done: backend.installProgress >= modelData.pct
                                    width: stepsContainer.width; height: stepsContainer.height

                                    property bool isLast: index === stepsContainer.steps.length - 1
                                    property bool isCurrent: index === stepsContainer.currentStepIndex

                                    Rectangle {
                                        id: mainDot
                                        x: dotX - 10
                                        y: 6
                                        width: 20; height: 20
                                        radius: 10
                                        color: {
                                            if (!done) return Qt.rgba(mainWindow.clrBg.r, mainWindow.clrBg.g, mainWindow.clrBg.b, 1)
                                            if (mainWindow.installSuccess && isLast) return "#39a354"
                                            if ((mainWindow.installFailed || mainWindow.installCancelled) && isCurrent) return "#ff5555"
                                            return mainWindow.clrAccent
                                        }
                                        border.color: {
                                            if (!done) return backend.systemColors ? mainWindow.clrBorder : "#444"
                                            if (mainWindow.installSuccess && isLast) return "#39a354"
                                            if ((mainWindow.installFailed || mainWindow.installCancelled) && isCurrent) return "#ff5555"
                                            return mainWindow.clrAccent
                                        }
                                        border.width: 2

                                        Behavior on color { ColorAnimation { duration: 400 } }
                                        Behavior on border.color { ColorAnimation { duration: 400 } }

                                        Rectangle {
                                            anchors.centerIn: parent
                                            width: 8; height: 8; radius: 4
                                            color: "white"
                                            opacity: done ? 1 : 0
                                            Behavior on opacity { NumberAnimation { duration: 400; easing.type: Easing.OutQuad } }
                                        }
                                    }

                                    Text {
                                        x: dotX - width/2
                                        y: 36
                                        text: modelData.label
                                        font.pixelSize: 10
                                        color: {
                                            if (!done) return mainWindow.lightMode ? "#8888aa" : "#888"
                                            if (mainWindow.installSuccess && isLast) return "#39a354"
                                            if ((mainWindow.installFailed || mainWindow.installCancelled) && isCurrent) return "#ff5555"
                                            return mainWindow.clrAccentHover
                                        }
                                        Behavior on color { ColorAnimation { duration: 400 } }
                                    }
                                }
                            }

                            // Active circle
                            Rectangle {
                                id: activeCircle
                                width: 28; height: 28; radius: 14
                                color: "transparent"
                                border.color: {
                                    if (mainWindow.installSuccess) return "#39a354"
                                    if (mainWindow.installFailed || mainWindow.installCancelled) return "#ff5555"
                                    return mainWindow.clrAccent
                                }
                                Behavior on border.color { ColorAnimation { duration: 400 } }
                                border.width: 1.5
                                visible: parent.currentStepIndex >= 0

                                property bool firstMove: true

                                Behavior on x {
                                    enabled: !activeCircle.firstMove
                                    NumberAnimation { duration: 400; easing.type: Easing.OutQuad }
                                }

                                x: {
                                    var idx = parent.currentStepIndex
                                    if (idx < 0) return activeCircle.x
                                    var dotX = (parent.steps[idx].pct / 100) * parent.width
                                    return dotX - width/2
                                }

                                onXChanged: {
                                    if (firstMove && parent.currentStepIndex >= 0) {
                                        firstMove = false
                                    }
                                }

                                y: 2
                            }
                        }
                    }

                    // Overlay drop zone when installing
                    property bool dragOverlay: false

                    DropArea {
                        anchors.fill: parent
                        onEntered: function(drag) {
                            if (drag.hasUrls)
                                progressBar.dragOverlay = true
                        }
                        onExited:  progressBar.dragOverlay = false
                        onDropped: function(drop) {
                            shUnsapported.close()
                            unknownErrorDialog.close()

                            progressBar.dragOverlay = false
                            if (drop.urls.length > 0) {
                                var localPath = Qt.resolvedUrl(drop.urls[0]).toString().replace("file://", "")
                                backend.launchNewInstance(localPath)
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 8
                        color: Qt.rgba(mainWindow.clrBg.r, mainWindow.clrBg.g, mainWindow.clrBg.b, 0.88)
                        opacity: progressBar.dragOverlay ? 1 : 0
                        visible: opacity > 0
                        Behavior on opacity {
                            NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                        }


                        Column {
                            anchors.centerIn: parent
                            spacing: 10

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "⊕"
                                font.pixelSize: 32
                                color: mainWindow.clrAccent
                                opacity: 0.85
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: qsTr("Drop to open in new window")
                                font.pixelSize: 12
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                            }
                        }
                    }
                }
            }

            ListModel {
                id: consoleLines
            }

            Item {
                id: consoleArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: mainWindow.consoleFullWidth && mainWindow.consoleVisible ? -12 : 0
                anchors.rightMargin: mainWindow.consoleFullWidth && mainWindow.consoleVisible ? -12 : 0
                anchors.bottomMargin: mainWindow.consoleFullWidth && mainWindow.consoleVisible ? -12 : 0
                width: parent.width + (mainWindow.consoleFullWidth && mainWindow.consoleVisible ? 24 : 0)
                height: backend.showConsole
                        ? parent.height - (mainWindow.consoleFullWidth ? 148 : 167)
                        : parent.height - (mainWindow.consoleFullWidth ? 105 : 112)

                visible: {
                    if (mainWindow.consoleManuallyHidden) return false
                    if (backend.packageType === "extracting" && !backend.showConsole) return false
                    if (backend.showConsole && consoleLines.count > 0) return true
                    if (mainWindow.consoleOverlay && consoleLines.count > 0 &&
                        (mainWindow.confirmOnClose || mainWindow.installFinished)) return true
                    return false
                }

                // Main Container
                Rectangle {
                    anchors.fill: parent
                    radius: mainWindow.consoleFullWidth && mainWindow.consoleVisible ? 0 : 10
                    color: mainWindow.clrBgAlt
                    clip: true

                     Behavior on radius { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }

                    Row {
                        anchors.fill: parent

                        // Console text
                        Rectangle {
                            id: consoleWrapper
                            width: parent.width - (typeof sideBar !== 'undefined' ? sideBar.width : 0)
                            height: parent.height
                            color: "transparent"
                            clip: true

                            property bool userInputMode: false
                            property string currentInput: ""

                            focus: userInputMode
                            Keys.enabled: userInputMode

                            Keys.onPressed: function(event) {
                                if (!userInputMode) return

                                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (currentInput.trim().length > 0) {
                                        backend.shAnswerText(currentInput)
                                        consoleLines.append({ "line": "<span style='color:" + mainWindow.clrAccentHover + "'>› " + currentInput + "</span>" })
                                        currentInput = ""

                                        // Forcing autoscroll when sending a command
                                        consoleListView.stickToBottom = true
                                        Qt.callLater(consoleListView.positionViewAtEnd)
                                    }
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Backspace) {
                                    if (currentInput.length > 0)
                                        currentInput = currentInput.slice(0, -1)
                                    event.accepted = true
                                } else if (event.key === Qt.Key_Escape) {
                                    userInputMode = false
                                    backend.setShUserMode(false)
                                    event.accepted = true
                                } else if (event.text.length > 0) {
                                    currentInput += event.text
                                    event.accepted = true
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 1
                                spacing: 0

                                ListView {
                                    id: consoleListView
                                    width: parent.width
                                    height: consoleWrapper.userInputMode ? parent.height - 24 : parent.height
                                    anchors.leftMargin: 8
                                    clip: true
                                    model: consoleLines
                                    boundsBehavior: Flickable.StopAtBounds
                                    property bool stickToBottom: true

                                    function replaceLastLogEntry(prefix, newFullText) {
                                        var foundDownloading = false;
                                        var replaceIndex = -1;

                                        // 1. Search and replace Downloading
                                        for (var i = consoleLines.count - 1; i >= 0; i--) {
                                            var raw = consoleLines.get(i).line;
                                            var stripped = raw.replace(/<[^>]*>/g, "");

                                            if (stripped.indexOf(prefix) !== -1) {
                                                var totalMatch = stripped.match(/([\d.]+)\s*\/\s*([\d.]+)\s*MB/);
                                                var opMatch    = stripped.match(/\((\d+)\/(\d+)\)/);
                                                var finalText;

                                                if (totalMatch && opMatch) {
                                                    var total = totalMatch[2];
                                                    var opTot = opMatch[2];
                                                    finalText = "Downloading (" + opTot + "/" + opTot + "): "
                                                              + total + " / " + total + " MB (100%)";
                                                } else {
                                                    continue; // If no digits found, keep searching
                                                }

                                                var colorMatch = raw.match(/color:([^'">]+)/);
                                                var color = colorMatch ? colorMatch[1].trim() : backend.greycolor();
                                                var styled = "<span style='color:" + color + "'>" + finalText + "</span>";

                                                consoleLines.setProperty(i, "line", styled);
                                                replaceIndex = i;
                                                foundDownloading = true;
                                                break;
                                            }
                                        }

                                        if (foundDownloading) {
                                            // 2. Check if "Installing package..." is already in the list
                                            var hasInstalling = false;
                                            for (var j = 0; j < consoleLines.count; j++) {
                                                if (consoleLines.get(j).line.indexOf("Installing package...") !== -1) {
                                                    hasInstalling = true;
                                                    break;
                                                }
                                            }

                                            // 3. If not — add a new white line after the replaced one
                                            if (!hasInstalling) {
                                                var installEntry = mainWindow.lightMode ?   "<span style='color:#000000'>Installing package...</span>" : "<span style='color:#ffffff'>Installing package...</span>";
                                                // Insert immediately after Downloading (replaceIndex + 1)
                                                // If Downloading was the last one, append will just add to the end
                                                if (replaceIndex === consoleLines.count - 1) {
                                                    consoleLines.append({"line": installEntry});
                                                } else {
                                                    consoleLines.insert(replaceIndex + 1, {"line": installEntry});
                                                }
                                            }
                                        }

                                        return foundDownloading;
                                    }

                                    onContentHeightChanged: {
                                        if (stickToBottom && !scrollerV.pressed && !moving && !flicking && (mainWindow.confirmOnClose)) {
                                            Qt.callLater(consoleListView.positionViewAtEnd)
                                        }
                                    }
                                    onContentYChanged: {
                                        if (flicking || moving) {
                                            var atBottom = (contentHeight - contentY) <= (height + 5)
                                            stickToBottom = atBottom
                                        }
                                    }

                                    onMovementStarted: {
                                        var atBottom = (contentHeight - contentY) <= (height + 5)
                                        if (!atBottom) stickToBottom = false
                                    }

                                    //Scroll logic

                                    MouseArea {
                                        id: topConsoleArea
                                        anchors.fill: parent
                                        propagateComposedEvents: true
                                        hoverEnabled: true

                                        cursorShape: {
                                            var item = consoleListView.itemAt(mouseX, mouseY + consoleListView.contentY)
                                            if (item) {
                                                var localX = mouseX - item.x
                                                if (localX >= item.leftPadding && localX <= (item.leftPadding + item.contentWidth)) {
                                                    return Qt.IBeamCursor
                                                }
                                            }
                                            return Qt.ArrowCursor
                                        }

                                        onPressed: (mouse) => {
                                            mouse.accepted = false
                                        }

                                        onClicked: consoleWrapper.forceActiveFocus()
                                        onWheel: function(wheel) {
                                            if (wheel.angleDelta.y > 0) {
                                                consoleListView.stickToBottom = false
                                            } else {
                                                var atBottom = (consoleListView.contentHeight - consoleListView.contentY) <= (consoleListView.height + 5)
                                                if (atBottom) consoleListView.stickToBottom = true
                                            }
                                            wheel.accepted = false
                                        }
                                    }

                                    delegate: TextEdit {
                                        id: textItem
                                        width: consoleListView.width - 20
                                        readOnly: true
                                        selectByMouse: true
                                        textFormat: TextEdit.RichText
                                        text: model.line
                                        color: mainWindow.clrText
                                        wrapMode: TextEdit.WrapAnywhere
                                        font.pixelSize: mainWindow.consoleFontSize
                                        font.family: mainWindow.consoleFontFamily
                                        font.bold: mainWindow.consoleFontBold
                                        topPadding: index === 0 ? 6 : 0
                                        bottomPadding: 2
                                        leftPadding: mainWindow.consoleFullWidth && mainWindow.consoleVisible ? 12 : 4
                                        selectedTextColor: color
                                        selectionColor: Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.4)

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.IBeamCursor
                                            acceptedButtons: Qt.NoButton
                                            hoverEnabled: true
                                            propagateComposedEvents: true
                                        }
                                    }


                                    ScrollBar.vertical: ScrollBar {
                                        id: scrollerV
                                        width: 4
                                        policy: ScrollBar.AsNeeded
                                        hoverEnabled: true
                                        minimumSize: parent.height > 0 ? 30 / parent.height : 0.05
                                        anchors.right: parent.right
                                        anchors.rightMargin: 1
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom

                                        onPressedChanged: {
                                            if (pressed) {
                                                consoleListView.stickToBottom = false
                                            } else if (consoleListView.atYEnd) {
                                                consoleListView.stickToBottom = true
                                            }
                                        }

                                        property bool keepVisible: false

                                        Timer {
                                            id: hideDelayTimer
                                            interval: 1500
                                            onTriggered: scrollerV.keepVisible = false
                                        }

                                        Connections {
                                            target: consoleListView
                                            function onMovingChanged() {
                                                if (consoleListView.moving) {
                                                    scrollerV.keepVisible = true
                                                    hideDelayTimer.stop()
                                                } else {
                                                    hideDelayTimer.restart()
                                                }
                                            }
                                        }

                                        opacity: (consoleListView.moving || consoleListView.flicking || active || hovered || keepVisible) ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 250 } }

                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                                            opacity: scrollerV.pressed ? 0.7 : 0.4
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                        }
                                        background: Item {}
                                    }
                                }
                            }
                        }

                        // Right bar
                        Rectangle {
                            id: sideBar
                            width: 30
                            height: parent.height
                            color: Qt.rgba(mainWindow.clrBg.r, mainWindow.clrBg.g, mainWindow.clrBg.b, 0.5)

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1
                                color: Qt.rgba(mainWindow.clrBorder.r, mainWindow.clrBorder.g, mainWindow.clrBorder.b, 0.4)
                            }

                            Column {
                                anchors.top: parent.top
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: 4
                                spacing: 2

                                // Copy all
                                Rectangle {
                                    id: copyAllBtn
                                    width: 22; height: 22
                                    radius: 5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: copyAllMa.containsMouse
                                           ? Qt.rgba(mainWindow.clrAccentBorder.r, mainWindow.clrAccentBorder.g, mainWindow.clrAccentBorder.b, 0.35)
                                           : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    property bool copied: false

                                    Timer {
                                        id: copyResetTimer
                                        interval: 1000
                                        onTriggered: copyAllBtn.copied = false
                                    }

                                    Canvas {
                                        id: clippyCanvas
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        opacity: copyAllBtn.copied ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            ctx.strokeStyle = copyAllMa.containsMouse ? mainWindow.clrAccentHover : "#888"
                                            ctx.lineWidth = 1.5
                                            ctx.lineCap = "round"
                                            ctx.lineJoin = "round"
                                            var s = width / 16
                                            ctx.beginPath()
                                            ctx.moveTo(3.25*s, 2.88*s)
                                            ctx.bezierCurveTo(2.95*s, 3.06*s, 2.75*s, 3.38*s, 2.75*s, 3.75*s)
                                            ctx.lineTo(2.75*s, 13.25*s)
                                            ctx.bezierCurveTo(2.75*s, 13.8*s, 3.2*s, 14.25*s, 3.75*s, 14.25*s)
                                            ctx.lineTo(12.25*s, 14.25*s)
                                            ctx.bezierCurveTo(12.8*s, 14.25*s, 13.25*s, 13.8*s, 13.25*s, 13.25*s)
                                            ctx.lineTo(13.25*s, 3.75*s)
                                            ctx.bezierCurveTo(13.25*s, 3.38*s, 13.05*s, 3.06*s, 12.75*s, 2.88*s)
                                            ctx.stroke()
                                            ctx.beginPath()
                                            ctx.moveTo(5.75*s, 4.75*s)
                                            ctx.lineTo(5.75*s, 1.75*s)
                                            ctx.lineTo(10.25*s, 1.75*s)
                                            ctx.lineTo(10.25*s, 4.75*s)
                                            ctx.lineTo(5.75*s, 4.75*s)
                                            ctx.stroke()
                                        }
                                    }

                                    Canvas {
                                        id: checkCanvas
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        opacity: copyAllBtn.copied ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            ctx.strokeStyle = mainWindow.lightMode ? "#08631f" : "#50fa7b"
                                            ctx.lineWidth = 1.5
                                            ctx.lineCap = "round"
                                            ctx.lineJoin = "round"
                                            var s = width / 16
                                            ctx.beginPath()
                                            ctx.moveTo(13.25*s, 4.75*s)
                                            ctx.lineTo(6*s, 12*s)
                                            ctx.lineTo(2.75*s, 8.75*s)
                                            ctx.stroke()
                                        }
                                    }

                                    MouseArea {
                                        id: copyAllMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var all = ""
                                            for (var i = 0; i < consoleLines.count; i++)
                                                all += consoleLines.get(i).line.replace(/<[^>]*>/g, "") + "\n"
                                            backend.copyToClipboard(all)
                                            copyAllBtn.copied = true
                                            clippyCanvas.requestPaint()
                                            checkCanvas.requestPaint()
                                            copyResetTimer.restart()
                                        }
                                        onEntered: clippyCanvas.requestPaint()
                                        onExited: clippyCanvas.requestPaint()
                                    }
                                    ToolTip.text: copyAllBtn.copied ? qsTr("Copied!") : qsTr("Copy all")
                                    ToolTip.visible: copyAllMa.containsMouse
                                    ToolTip.delay: 500
                                }
                            }

                            Column {
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottomMargin: 4
                                spacing: 2

                                // Spinner
                                Rectangle {
                                    id: consoleControlBtn
                                    width: 22; height: 22
                                    radius: 5
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: mainWindow.confirmOnClose || mainWindow.installFinished

                                    color: (mainControlMouseArea.containsMouse && (mainWindow.installFinished || !backend.showConsole)) ? mainWindow.clrBorder : "transparent"
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    // Single mouse area for all buttons
                                    MouseArea {
                                        id: mainControlMouseArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            if (mainWindow.installFinished) {
                                                mainWindow.consoleHidden = true
                                                mainWindow.installFinished = false
                                                consoleLines.clear()
                                                mainWindow.consoleOverlay = backend.alwaysShowConsole
                                                mainWindow.consoleManuallyHidden = true
                                            } else {
                                                mainWindow.consoleOverlay = !mainWindow.consoleOverlay
                                            }
                                        }
                                    }

                                    ToolTip.text: mainWindow.installFinished ? qsTr("Close console") : (mainWindow.consoleOverlay ? qsTr("Hide console") : qsTr("Show console"))
                                    ToolTip.visible: (mainWindow.installFinished || !backend.showConsole) && mainControlMouseArea.containsMouse
                                    ToolTip.delay: 500

                                    // Spinner
                                    Canvas {
                                        id: spinnerCanvas
                                        anchors.fill: parent
                                        anchors.margins: 3
                                        visible: !mainWindow.installFinished && backend.showConsole
                                        property real angle: 0
                                        property real arcLen: 30

                                        NumberAnimation on angle {
                                            from: 0; to: 360; duration: 1100
                                            loops: Animation.Infinite; running: spinnerCanvas.visible
                                        }
                                        SequentialAnimation {
                                            running: spinnerCanvas.visible
                                            loops: Animation.Infinite
                                            NumberAnimation { target: spinnerCanvas; property: "arcLen"; from: 10; to: 300; duration: 550; easing.type: Easing.InOutSine }
                                            NumberAnimation { target: spinnerCanvas; property: "arcLen"; from: 300; to: 10; duration: 550; easing.type: Easing.InOutSine }
                                        }
                                        onAngleChanged: requestPaint()
                                        onArcLenChanged: requestPaint()
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.clearRect(0, 0, width, height)
                                            ctx.strokeStyle = mainWindow.lightMode ? "#666565" : "rgba(255,255,255,0.85)"
                                            ctx.lineWidth = 2.5
                                            ctx.lineCap = "round"
                                            var cx = width/2, cy = height/2, r = width/2 - 1.5
                                            var s = (angle - 90) * Math.PI / 180
                                            var e = s + arcLen * Math.PI / 180
                                            ctx.beginPath(); ctx.arc(cx, cy, r, s, e); ctx.stroke()
                                        }
                                    }

                                    // Arrow icon
                                    Item {
                                        id: arrowIcon
                                        width: 14; height: 8
                                        anchors.centerIn: parent
                                        anchors.verticalCenterOffset: mainWindow.consoleOverlay ? -3 : 3
                                        visible: !mainWindow.installFinished && !backend.showConsole

                                        Rectangle {
                                            width: 8; height: 2
                                            radius: 1
                                            color: mainControlMouseArea.containsMouse ? mainWindow.clrAccentHover : "#888"
                                            x: 0; y: 3
                                            transformOrigin: Item.Right
                                            rotation: mainWindow.consoleOverlay ? -40 : 40
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                        Rectangle {
                                            width: 8; height: 2
                                            radius: 1
                                            color: mainControlMouseArea.containsMouse ? mainWindow.clrAccentHover : "#888"
                                            x: 6; y: 3
                                            transformOrigin: Item.Left
                                            rotation: mainWindow.consoleOverlay ? 40 : -40
                                            Behavior on color { ColorAnimation { duration: 120 } }
                                        }
                                    }

                                    // Cross icon
                                    Text {
                                        id: closeIcon
                                        anchors.centerIn: parent
                                        visible: mainWindow.installFinished
                                        text: "✕"
                                        font.pixelSize: 13
                                        color: mainControlMouseArea.containsMouse ? "#ff5555" : "#888"
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        // Overlay drag&drop zone when installing in progress
        Rectangle {
            anchors.fill: parent
            radius: 8
            z: 20
            color: Qt.rgba(mainWindow.clrBg.r, mainWindow.clrBg.g, mainWindow.clrBg.b, 0.88)
            opacity: progressBar.dragOverlay ? 1 : 0
            visible: opacity > 0
            Behavior on opacity {
                NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
            }

            Column {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "⊕"
                    font.pixelSize: 32
                    color: mainWindow.clrAccent
                    opacity: 0.85
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: qsTr("Drop to open in new window")
                    font.pixelSize: 12
                    color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                }
            }
        }
    }

    // Drop handler
    function handleDrop(localPath) {
        mainWindow.installFailed = false
        mainWindow.installCancelled = false
        mainWindow.installSuccess = false
        mainWindow.consoleManuallyHidden = false  // ← add
        backend.generateArchPackageList()
        backend.installAPP(localPath)
    }

    // ════════════════════════════════════════════════════════════════════
    //  SETTINGS WINDOW
    // ════════════════════════════════════════════════════════════════════
    Window {
        id: settingsWindow
        title: qsTr("Settings — Linux App Installer")
        width: 425
        height: 510
        minimumWidth: 425
        minimumHeight: 500
        maximumHeight:  settingsWindow.minimumHeight
        maximumWidth: settingsWindow.minimumWidth
        color: mainWindow.clrBg
        modality: Qt.ApplicationModal

        property bool aiSectionExpanded: true
        property string savedToken: ""

        onVisibleChanged: {
            if (!visible) { eyeBtn.showing = false; return }
            var p = backend.aiProvider
            if      (p === "gemini")      tokenField.text = backend.loadGeminiToken()
            else if (p === "openai")      tokenField.text = backend.loadOpenAiToken()
            else if (p === "huggingface") tokenField.text = backend.loadHuggingFaceToken()
            else if (p === "mistral")     tokenField.text = backend.loadMistralToken()  // ← add
            else                          tokenField.text = backend.loadToken()
            savedToken = tokenField.text  // ← remember the saved token
            var savedModel = backend.loadProviderModel(backend.aiProvider)
            aiModelInput.text = savedModel
            backend.aiModel = savedModel
            langRestartNote.visible = false
            refreshLangModel()
        }

        onClosing: function(closeEvent) {
            if (tokenField.text !== savedToken) {
                closeEvent.accepted = false
                Qt.callLater(function() { unsavedTokenDialog.open() })
            }
        }

        Kirigami.PromptDialog {
            id: unsavedTokenDialog
            parent: settingsWindow.contentItem
            title: qsTr("Warning")
            subtitle: qsTr("You didn't save your token. Do you want to exit anyway?")
            standardButtons: Kirigami.Dialog.NoButton
            customFooterActions: [
                Kirigami.Action {
                    text: qsTr("Exit")
                    icon.name: "dialog-ok"
                    onTriggered: {
                        unsavedTokenDialog.close()
                        settingsWindow.savedToken = tokenField.text  // ← reset so it doesn't trigger again
                        settingsWindow.close()
                    }
                },
                Kirigami.Action {
                    text: qsTr("Cancel")
                    icon.name: "dialog-cancel"
                    onTriggered: unsavedTokenDialog.close()
                }
            ]
            palette.highlight: mainWindow.clrAccent
            palette.button: mainWindow.clrBgButton
            palette.buttonText:  mainWindow.clrText
            palette.window: mainWindow.clrBg
            palette.windowText:  mainWindow.clrText
        }

        Connections {
            target: backend
            function onArchPackageListDateChanged() {
                pkgListDateText.text = backend.archPackageListDate()
            }
            function onAiProviderChanged() {
                var p = backend.aiProvider
                if      (p === "gemini")      tokenField.text = backend.loadGeminiToken()
                else if (p === "openai")      tokenField.text = backend.loadOpenAiToken()
                else if (p === "huggingface") tokenField.text = backend.loadHuggingFaceToken()
                else if (p === "mistral")     tokenField.text = backend.loadMistralToken()
                else                          tokenField.text = backend.loadToken()
                settingsWindow.savedToken = tokenField.text
                eyeBtn.showing = false
                var savedModel = backend.loadProviderModel(backend.aiProvider)
                aiModelInput.text = savedModel
                backend.aiModel = savedModel
            }

            function onAiModelChanged() {
                aiModelInput.text = backend.aiModel
            }

            onAiStatusResult: function(ok, message) {
                checkApiBtn.state = ok ? 2 : 3
                statusai.aistatusOk = ok
                statusai.aistatus = message
                statusai.visible = true
                checkResetTimer.restart()
            }
        }

        function refreshLangModel() {
            languageModel.clear()
            languageModel.append({ "display": "English", "code": "" })
            var langs = backend.availableLanguages()
            for (var i = 0; i < langs.length; i++)
                languageModel.append({ "display": langs[i].display, "code": langs[i].code })
            var cur = backend.currentLanguage()
            for (var j = 0; j < languageModel.count; j++) {
                if (languageModel.get(j).code === cur) { langComboBox.currentIndex = j; break }
            }
        }

        ListModel { id: languageModel }

        Kirigami.PromptDialog {
            id: reloadDialog; parent: settingsWindow.contentItem
            title: qsTr("Restart required")
            subtitle: qsTr("Application needs to be restarted to apply language changes")
            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
            onAccepted: backend.confirmReload()
        }

        Rectangle {
            anchors.fill: parent
            color: mainWindow.clrBg

            property real scrollY: 0  // Refreshing with Flickable

            Rectangle {
                layer.enabled: true
                id: settingsHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                z: 10
                height: 35
                color: mainWindow.clrBg


                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(mainWindow.clrBorder.r, mainWindow.clrBorder.g, mainWindow.clrBorder.b, 0.8)
                }


                Rectangle {
                    anchors.fill: parent
                    color: mainWindow.clrBg
                }



                Text {
                    anchors.centerIn: parent
                    text: qsTr("Settings")
                    color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                    font.pixelSize: 15
                    font.bold: true
                }

                Rectangle {
                    anchors.bottom: settingsHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: mainWindow.clrBorder
                    opacity: settingsScroll.parent.scrollY > 5 ? 0.8 : 0.0
                    Behavior on opacity {
                        NumberAnimation { duration: 200; easing.type: Easing.InOutQuad }
                    }
                }
            }

            Flickable {
                id: settingsScroll
                anchors.top: settingsHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 18
                anchors.rightMargin: 0
                anchors.bottomMargin: 8
                anchors.topMargin: 0
                clip: true
                contentWidth: width
                contentHeight: settingsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                onContentYChanged: {
                    langDropdown.close()
                    aiProviderDropdown.close()
                    fontFamilyDropdown.close()
                    settingsScrollerV.keepVisible = true
                    settingsHideDelayTimer.restart()
                }

                WheelHandler {
                    id: settingsWheelHandler
                    onWheel: function(event) {
                        var delta = event.angleDelta.y / 120
                        var step = 120
                        var targetY = settingsScroll.contentY - delta * step
                        targetY = Math.max(0, Math.min(targetY, settingsScroll.contentHeight - settingsScroll.height))
                        settingsScrollAnim.to = targetY
                        settingsScrollAnim.restart()
                        event.accepted = true
                    }
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    target: null
                }

                NumberAnimation {
                    id: settingsScrollAnim
                    target: settingsScroll
                    property: "contentY"
                    duration: 120
                    easing.type: Easing.OutQuad
                }
                ScrollBar.vertical: ScrollBar {
                    id: settingsScrollerV
                    width: 4
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true
                    minimumSize: settingsScroll.height > 0 ? 30 / settingsScroll.height : 0.05
                    anchors.right: parent.right
                    anchors.rightMargin: 1
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    property bool keepVisible: false

                    Timer {
                        id: settingsHideDelayTimer
                        interval: 1500
                        onTriggered: settingsScrollerV.keepVisible = false
                    }

                    opacity: (settingsScroll.moving || settingsScroll.flicking ||
                              active || hovered || keepVisible) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                        opacity: settingsScrollerV.pressed ? 0.7 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    background: Item {}
                }

                Column {
                    id: settingsColumn
                    width: settingsWindow.width - 36
                    spacing: 0

                    Text {
                        text: qsTr("AI")
                        color: backend.systemColors ? mainWindow.clrAccent : "#9070cc"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        bottomPadding: 12
                    }

                    Row {
                        width: parent.width
                        height: 44

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - aiSwitchSettings.width - 8
                            spacing: 2
                            Text { text: qsTr("Auto-fill app metadata using AI"); color: mainWindow.clrText; font.pixelSize: 13 }
                        }

                        Item {
                            id: aiSwitchSettings
                            width: 50; height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            property bool hasToken: {
                                var ht  = backend.hasToken
                                var hg  = backend.hasGeminiToken
                                var ho  = backend.hasOpenAiToken
                                var hhf = backend.hasHuggingFaceToken
                                var hm  = backend.hasMistralToken

                                var p = backend.aiProvider
                                if (p === "gemini")      return hg
                                if (p === "openai")      return ho
                                if (p === "huggingface") return hhf
                                if (p === "mistral")     return hm
                                return ht
                            }
                            property bool isInstalling: mainWindow.confirmOnClose
                            property bool isOn: backend.aiEnabled && hasToken

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: {
                                    if (!aiSwitchSettings.hasToken) return backend.systemColors ? Qt.darker(mainWindow.clrBg, 1.2) : "#383838"
                                    return aiSwitchSettings.isOn ? mainWindow.clrAccentFocus : backend.systemColors ? mainWindow.clrBorder : "#525252"
                                }
                                opacity: aiSwitchSettings.isInstalling ? 0.6 : 1.0
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: aiSwitchSettings.isOn ? parent.width - width - 5 : 5
                                color: aiSwitchSettings.isOn ? "white" : "transparent"
                                border.color: "white"
                                border.width: 5
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: (aiSwitchSettings.hasToken && !aiSwitchSettings.isInstalling)
                                             ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: {
                                    if (!aiSwitchSettings.hasToken) {
                                        tokenHintAnim.start()
                                        tokenField.forceActiveFocus()
                                        return
                                    }
                                    if (aiSwitchSettings.isInstalling) return
                                    backend.aiEnabled = !aiSwitchSettings.isOn
                                    backend.initAiAccess()
                                }
                            }
                            ToolTip.text: {
                                if (!aiSwitchSettings.hasToken) return qsTr("Enter an API token first")
                                if (aiSwitchSettings.isInstalling) return qsTr("Cannot change while installing")
                                return aiSwitchSettings.isOn ? qsTr("AI mode on") : qsTr("AI mode off")
                            }
                            ToolTip.visible: aiSwitchMouseArea.containsMouse
                            ToolTip.delay: 500
                        }
                    }

                    Item { width: 1; height: 14 }

                    Item {
                        width: parent.width
                        property bool expanded: backend.aiEnabled || !aiSwitchSettings.hasToken
                        height: expanded ? contentCol.implicitHeight : 0
                        clip: true
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                        Column {
                            id: contentCol
                            width: parent.width
                            spacing: 0

                            Text {
                                text: backend.aiProvider === "gemini"      ? qsTr("Gemini API key:")
                                    : backend.aiProvider === "openai"      ? qsTr("OpenAI API key:")
                                    : backend.aiProvider === "huggingface" ? qsTr("Hugging Face API key:")
                                    : backend.aiProvider === "mistral"     ? qsTr("Mistral API key:")
                                    : backend.aiProvider === "openrouter"  ? qsTr("OpenRouter API key:")
                                    : qsTr("Token:")
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                font.pixelSize: 13
                                bottomPadding: 8
                            }

                            Row {
                                width: parent.width
                                spacing: 6

                                Rectangle {
                                    id: tokenFieldBg
                                    width: parent.width - eyeBtn.width - saveTokenBtn.width - 12
                                    height: 36
                                    radius: 8
                                    color: mainWindow.clrBgAlt
                                    border.width: 1.5
                                    border.color: tokenField.activeFocus ? mainWindow.clrAccentBorder
                                                  : tokenArea.containsMouse ? mainWindow.clrAccentBorder
                                                  : mainWindow.clrBorder

                                    Behavior on border.color { ColorAnimation { duration: 100 } }

                                    SequentialAnimation {
                                        id: tokenHintAnim; loops: 3
                                        ColorAnimation {
                                            target: tokenFieldBg
                                            property: "border.color"
                                            to: mainWindow.clrAccentHover
                                            duration: 200
                                        }
                                        ColorAnimation {
                                            target: tokenFieldBg
                                            property: "border.color"
                                            to: backend.systemColors ? mainWindow.clrBorder : "#3a3b4a"
                                            duration: 200
                                        }
                                    }

                                    TextField {
                                        id: tokenField
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                        placeholderText: {
                                            var p = backend.aiProvider
                                            if (p === "gemini")      return "AIza..."
                                            if (p === "openai")      return "sk-..."
                                            if (p === "huggingface") return "hf_..."
                                            if (p === "mistral")      return "..."
                                            return "sk-or-v1-..."
                                        }
                                        echoMode: eyeBtn.showing ? TextInput.Normal : TextInput.Password
                                        background: Item {}
                                        font.pixelSize: 12
                                        font.family: "monospace"
                                    }

                                    MouseArea {
                                        id: tokenArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        cursorShape: Qt.IBeamCursor
                                        z: 10
                                    }
                                }

                                // Secure button for token
                                Rectangle {
                                    id: eyeBtn
                                    width: 36
                                    height: 36
                                    radius: 8
                                    color: mainWindow.clrBgAlt
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    property bool showing: false

                                    Text {
                                        id: monkeyFace
                                        anchors.centerIn: parent
                                        text: "🙈"
                                        font.pixelSize: 26
                                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                        opacity: eyeBtn.showing ? 0 : 1
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }

                                    Text {
                                        id: eyeIcon
                                        anchors.centerIn: parent
                                        text: "🐵"
                                        font.pixelSize: 24
                                        anchors.verticalCenterOffset: -0.5
                                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                        opacity: eyeBtn.showing ? 1 : 0
                                        Behavior on opacity { NumberAnimation { duration: 200 } }
                                    }

                                    MouseArea {
                                        id: eyeArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: eyeBtn.showing = !eyeBtn.showing
                                    }


                                    Rectangle {
                                        anchors.fill: parent
                                        radius: parent.radius
                                        color: "transparent"
                                        border.width: 1.5
                                        border.color: eyeArea.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                                        Behavior on border.color { ColorAnimation { duration: 100 } }
                                    }
                                }


                                Rectangle {
                                    id: saveTokenBtn
                                    width: Math.max(63, saveTokenText.implicitWidth + 24)
                                    height: 36
                                    radius: 8
                                    color: saveArea.containsMouse ? mainWindow.clrBgButtonHover : mainWindow.clrBgHover
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        id: saveTokenText
                                        font.bold: true
                                        anchors.centerIn: parent
                                        text: qsTr("Save")
                                        color: "white"
                                        font.pixelSize: 12 }
                                    MouseArea {
                                        id: saveArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {                                            var p = backend.aiProvider
                                            var ok = false
                                            var t = tokenField.text.trim()
                                            if      (p === "gemini")      ok = backend.saveGeminiToken(t)
                                            else if (p === "openai")      ok = backend.saveOpenAiToken(t)
                                            else if (p === "huggingface") ok = backend.saveHuggingFaceToken(t)
                                            else if (p === "mistral")     ok = backend.saveMistralToken(t)
                                            else                          ok = backend.saveToken(t)
                                            if (ok) settingsWindow.savedToken = t
                                            tokenSaveStatus.success = ok
                                            fadeOutAnimation.stop()
                                            fadeInAnimation.stop()
                                            tokenSaveTimer.stop()
                                            tokenSaveStatus.opacity = 0
                                            tokenSaveStatus.visible = true
                                            fadeInAnimation.start()
                                            backend.initAiAccess()
                                        }
                                    }
                                }
                            }

                            Item { width: 1; height: 5 }

                            Row {
                                width: parent.width
                                spacing: 0
                                height: 24

                                Rectangle {
                                    id: checkApiBtn
                                    width: checkSpinner.visible ? 85 : 70
                                    height: 24
                                    radius: 6
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: 120
                                            easing.type: Easing.InOutQuad
                                        }
                                    }
                                    anchors.verticalCenter: parent.verticalCenter

                                    property int state: 0  // 0=idle, 1=checking, 2=ok, 3=error
                                    property string statusText: qsTr("Test")

                                    color: mainWindow.clrBgAlt

                                    border.width: 1.5
                                    border.color: {
                                        if (state === 2) return "#50fa7b"
                                        if (state === 3) return "#ff5555"
                                        return checkApiMa.containsMouse && state === 0
                                            ? mainWindow.clrAccentBorder
                                            : mainWindow.clrBorder
                                    }
                                    Behavior on border.color { ColorAnimation { duration: 120 } }
                                    Behavior on color        { ColorAnimation { duration: 120 } }

                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Canvas {
                                            id: checkSpinner
                                            width: 10
                                            height: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: checkApiBtn.state === 1
                                            property real angle: 0
                                            NumberAnimation on angle {
                                                from: 0
                                                to: 360
                                                duration: 900
                                                loops: Animation.Infinite
                                                running: checkSpinner.visible
                                            }
                                            onAngleChanged: requestPaint()
                                            onPaint: {
                                                var ctx = getContext("2d")
                                                ctx.clearRect(0, 0, width, height)
                                                ctx.strokeStyle = mainWindow.clrAccentHover
                                                ctx.lineWidth = 1.8
                                                ctx.lineCap = "round"
                                                var cx = width/2, cy = height/2, r = width/2 - 1.2
                                                var s = (angle - 90) * Math.PI / 180
                                                var e = s + 240 * Math.PI / 180
                                                ctx.beginPath()
                                                ctx.arc(cx, cy, r, s, e)
                                                ctx.stroke()
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                if (checkApiBtn.state === 1) return qsTr("Checking…")
                                                if (checkApiBtn.state === 2) return qsTr("✔ OK")
                                                if (checkApiBtn.state === 3) return "✕" + qsTr("Failed")
                                                return qsTr("Test")
                                            }
                                            font.pixelSize: 11
                                            color: {
                                                if (checkApiBtn.state === 2) return "#50fa7b"
                                                if (checkApiBtn.state === 3) return "#ff5555"
                                                return checkApiMa.containsMouse && checkApiBtn.state === 0
                                                    ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                            }
                                            Behavior on color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    Timer {
                                        id: checkResetTimer
                                        interval: 3000
                                        onTriggered: {
                                            checkApiBtn.state = 0
                                            statusai.visible = false
                                        }
                                    }

                                    MouseArea {
                                        id: checkApiMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: checkApiBtn.state === 1 ? Qt.WaitCursor
                                                   : aiSwitchSettings.hasToken ? Qt.PointingHandCursor
                                                   : Qt.ForbiddenCursor
                                        onClicked: {
                                            if (checkApiBtn.state === 1) return
                                            if (!aiSwitchSettings.hasToken) {
                                                tokenHintAnim.start()
                                                tokenField.forceActiveFocus()
                                                return
                                            }
                                            statusai.visible = false
                                            statusai.aistatus = ""
                                            checkApiBtn.state = 1
                                            backend.checkAiStatus(backend.aiProvider)
                                        }
                                    }

                                    ToolTip.text: !aiSwitchSettings.hasToken
                                                  ? qsTr("Enter a token first")
                                                  : checkApiBtn.state === 1 ? qsTr("Checking connection…")
                                                  : qsTr("Test connection to the AI provider")
                                    ToolTip.visible: checkApiMa.containsMouse
                                    ToolTip.delay: 500
                                }

                                Text {
                                    id: statusai
                                    property string aistatus: ""
                                    property bool aistatusOk: true
                                    visible: false
                                    text: aistatus
                                    color: aistatusOk ? "#50fa7b" : "#ff5555"
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    leftPadding: 8
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideRight
                                    height: 24
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    id: tokenSaveStatus
                                    property bool success: true
                                    property bool showAnimation: false
                                    anchors.right: parent.right
                                    visible: false
                                    text: success ? qsTr("✔ Token saved") : qsTr("✕ Could not save token")
                                    color: success ? "#50fa7b" : "#ff5555"
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    opacity: 0

                                    Timer {
                                        id: tokenSaveTimer
                                        interval: 3000
                                        onTriggered: {
                                            fadeOutAnimation.start()
                                        }
                                    }

                                    PropertyAnimation {
                                        id: fadeInAnimation
                                        target: tokenSaveStatus
                                        property: "opacity"
                                        from: 0
                                        to: 1
                                        duration: 150
                                        onRunningChanged: {
                                            if (!running) {
                                                tokenSaveTimer.start()
                                            }
                                        }
                                    }

                                    PropertyAnimation {
                                        id: fadeOutAnimation
                                        target: tokenSaveStatus
                                        property: "opacity"
                                        from: 1
                                        to: 0
                                        duration: 150
                                        onRunningChanged: {
                                            if (!running) {
                                                tokenSaveStatus.visible = false
                                                tokenSaveStatus.opacity = 0
                                            }
                                        }
                                    }

                                    onShowAnimationChanged: {
                                        if (showAnimation) {
                                            tokenSaveStatus.visible = true
                                            tokenSaveStatus.opacity = 0
                                            fadeInAnimation.start()
                                        }
                                    }
                                }
                            }

                            Item { width: 1; height: 5 }

                            Item {
                                width: parent.width
                                height: linkText.implicitHeight

                                Text {
                                    id: linkText
                                    text: {
                                        var p = backend.aiProvider
                                        if (p === "gemini")      return qsTr("Get a token at aistudio.google.com ↗")
                                        if (p === "openai")      return qsTr("Get a token at platform.openai.com ↗")
                                        if (p === "huggingface") return qsTr("Get a token at huggingface.co/settings/tokens ↗")
                                        if (p === "mistral")     return qsTr("Get a token at console.mistral.ai ↗")
                                        return qsTr("Get a free token at openrouter.ai ↗")
                                    }
                                    color: mainWindow.clrLink
                                    Behavior on color { ColorAnimation { duration: 120 }}
                                    font.pixelSize: 10
                                }

                                MouseArea {
                                    anchors.fill: linkText
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: linkText.color = backend.systemColors ? Qt.lighter(mainWindow.clrLink, 1.2) : Qt.lighter(mainWindow.clrLink, 1.5)
                                    onExited:  linkText.color = mainWindow.clrLink

                                    onClicked: {
                                        var p = backend.aiProvider
                                        var urls = {
                                            "gemini":      "https://aistudio.google.com/apikey",
                                            "openai":      "https://platform.openai.com/api-keys",
                                            "huggingface": "https://huggingface.co/settings/tokens",
                                            "mistral":     "https://admin.mistral.ai/organization/api-keys",
                                            "openrouter":  "https://openrouter.ai/collections/free-models"
                                        }
                                        Qt.openUrlExternally(urls[p] || urls["openrouter"])
                                    }
                                }
                            }



                            Item { width: 1; height: 5 }

                            // AI Provider row
                            Row {
                                width: parent.width
                                height: 36
                                spacing: 10

                                Text {
                                    text: qsTr("AI provider")
                                    color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText; font.pixelSize: 13
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - aiProviderCombo.width - 10
                                }

                                Rectangle {
                                    id: aiProviderCombo
                                    width: 170
                                    height: 36
                                    radius: 8
                                    color: mainWindow.clrBgAlt
                                    border.color: (aiProviderMa.containsMouse || aiProviderDropdown.visible) ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                                    Behavior on border.color { ColorAnimation { duration: 100 } }
                                    border.width: 1.5
                                    anchors.verticalCenter: parent.verticalCenter

                                    readonly property var providers: [
                                        { label: "OpenRouter",     value: "openrouter"  },
                                        { label: "Google Gemini",  value: "gemini"      },
                                        { label: "OpenAI",         value: "openai"      },
                                        { label: "Mistral",        value: "mistral"     },
                                        { label: "Hugging Face",   value: "huggingface" },
                                    ]
                                    property int currentIndex: {
                                        for (var i = 0; i < providers.length; i++)
                                            if (providers[i].value === backend.aiProvider) return i
                                        return 0
                                    }

                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 4

                                        Text {
                                            text: aiProviderCombo.providers[aiProviderCombo.currentIndex].label
                                            color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText; font.pixelSize: 12
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 20
                                            elide: Text.ElideRight
                                        }

                                        Item {
                                            width: 14; height: 10
                                            anchors.verticalCenter: parent.verticalCenter

                                            Item {
                                                width: parent.width; height: parent.height
                                                y: aiProviderDropdown.visible ? 0 : -2
                                                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

                                                Rectangle {
                                                    width: 2
                                                    height: 8
                                                    radius: 1
                                                    color: aiProviderMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                                    x: 3
                                                    y: aiProviderDropdown.visible ? 1 : 3
                                                    transformOrigin: Item.Center
                                                    rotation: aiProviderDropdown.visible ? -45 : -135
                                                    Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                                    Behavior on y        { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                                    Behavior on color    { ColorAnimation  { duration: 100 } }
                                                }
                                                Rectangle {
                                                    width: 2
                                                    height: 8
                                                    radius: 1
                                                    color: aiProviderMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                                    x: 9
                                                    y: aiProviderDropdown.visible ? 1 : 3
                                                    transformOrigin: Item.Center
                                                    rotation: aiProviderDropdown.visible ? 45 : 135
                                                    Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                                    Behavior on y        { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                                    Behavior on color    { ColorAnimation  { duration: 100 } }
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: aiProviderMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: aiProviderDropdown.visible ? aiProviderDropdown.close() : aiProviderDropdown.open()
                                    }

                                    Popup {
                                        id: aiProviderDropdown
                                        y: implicitHeight - implicitHeight * 2 - 3
                                        width: parent.width
                                        padding: 4

                                        background: Rectangle {
                                            color: mainWindow.clrBgMid
                                            radius: 8
                                            border.color: mainWindow.clrBorderAlt
                                            border.width: 1
                                        }
                                        contentItem: Column {
                                            spacing: 0
                                            Repeater {
                                                model: aiProviderCombo.providers
                                                delegate: Rectangle {
                                                    width: aiProviderDropdown.width - 8
                                                    height: 32
                                                    radius: 6
                                                    color: aiProviderItemMa.containsMouse ? mainWindow.clrBgHover : "transparent"
                                                    Row {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        spacing: 6
                                                        Text {
                                                            text: aiProviderCombo.currentIndex === index ? "✔" : " "
                                                            color: mainWindow.clrAccentAlt
                                                            font.pixelSize: 11
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            width: 14
                                                        }
                                                        Text {
                                                            text: modelData.label
                                                            color: aiProviderCombo.currentIndex === index ? mainWindow.clrAccentHover :  mainWindow.clrText
                                                            font.pixelSize: 12
                                                            anchors.verticalCenter: parent.verticalCenter
                                                        }
                                                    }
                                                    MouseArea {
                                                        id: aiProviderItemMa
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        cursorShape: Qt.PointingHandCursor
                                                        onClicked: {
                                                            var p = modelData.value
                                                            if      (p === "gemini")      tokenField.text = backend.loadGeminiToken()
                                                            else if (p === "openai")      tokenField.text = backend.loadOpenAiToken()
                                                            else if (p === "huggingface") tokenField.text = backend.loadHuggingFaceToken()
                                                            else if (p === "mistral")     tokenField.text = backend.loadMistralToken()
                                                            else                          tokenField.text = backend.loadToken()
                                                            settingsWindow.savedToken = tokenField.text
                                                            eyeBtn.showing = false
                                                            var savedModel = backend.loadProviderModel(p)
                                                            aiModelInput.text = savedModel
                                                            backend.aiProvider = p
                                                            backend.initAiAccess()
                                                            aiProviderDropdown.close()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Item { width: 1; height: 10 }

                            // AI Model row
                            Row {
                                width: parent.width
                                height: 36
                                spacing: 10

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - aiModelField.width - 10
                                    spacing: 2

                                    property string defaultModel: {
                                        var p = backend.aiProvider
                                        if (p === "gemini")      return "gemini-2.5-flash"
                                        if (p === "openai")      return "gpt-4o-mini"
                                        if (p === "huggingface") return "meta-llama/Llama-3.2-3B-Instruct"
                                        if (p === "mistral")     return "mistral-small-latest"
                                        return "google/gemma-4-31b-it:free"
                                    }

                                    Text {
                                        text: qsTr("Model")
                                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        text: qsTr("Default: ") + parent.defaultModel
                                        color: mainWindow.clrSubtle
                                        font.pixelSize: 10
                                    }
                                }

                                Rectangle {
                                    id: aiModelField
                                    width: 170
                                    height: 36
                                    radius: 8
                                    color: mainWindow.clrBgAlt
                                    border.width: 1.5
                                    border.color: aiModelInput.activeFocus ? mainWindow.clrAccentBorder : aiModelHover.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                                    Behavior on border.color { ColorAnimation { duration: 100 } }
                                    anchors.verticalCenter: parent.verticalCenter

                                    TextField {
                                        id: aiModelInput
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                        placeholderText: {
                                            var p = backend.aiProvider
                                            if (p === "gemini")      return "gemini-2.5-flash"
                                            if (p === "openai")      return "gpt-4o-mini"
                                            if (p === "huggingface") return "meta-llama/Llama-3.2-3B-Instruct"
                                            if (p === "mistral")     return "mistral-small-latest"
                                            return "google/gemma-4-31b-it:free"
                                        }
                                        background: Item {}
                                        font.pixelSize: 11
                                        font.family: "monospace"
                                        text: backend.aiModel
                                        Binding on text {
                                            value: backend.aiModel
                                            when: !aiModelInput.activeFocus
                                        }
                                        onTextEdited: {
                                            backend.aiModel = text
                                            backend.saveProviderModel(backend.aiProvider, text)
                                        }
                                        placeholderTextColor: mainWindow.clrMuted
                                    }

                                    MouseArea {
                                        id: aiModelHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        cursorShape: Qt.IBeamCursor; z: 10
                                    }
                                }
                            }

                            Item { width: 1; height: 8 }
                        }
                    }

                    // Behavior Section
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: mainWindow.clrBorder
                    }

                    Item { width: 1; height: 12 }

                    Text {
                        text: qsTr("BEHAVIOR")
                        color: backend.systemColors ? mainWindow.clrAccent : "#9070cc"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        bottomPadding: 12
                    }

                    Row {
                        width: parent.width
                        height: 44

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - consoleSwitch.width - 8
                            spacing: 2
                            Text { text: qsTr("Show progress bar")
                                color: mainWindow.clrText
                                font.pixelSize: 13 }
                            Text {
                                text: qsTr("Display informative progress bar in the main window")
                                color: mainWindow.clrSubtle
                                font.pixelSize: 10
                            }
                        }

                        Item {
                            id: consoleSwitch
                            width: 50
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            property bool isOn: !backend.showConsole

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: consoleSwitch.isOn ? mainWindow.clrAccentFocus : backend.systemColors ? mainWindow.clrBorder : "#525252"
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: consoleSwitch.isOn ? parent.width - width - 5 : 5
                                color: consoleSwitch.isOn ? "white" : "transparent"
                                border.color: "white"
                                border.width: 5
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.showConsole = consoleSwitch.isOn
                            }
                            ToolTip.text: consoleSwitch.isOn ? qsTr("Progress bar visible") : qsTr("Progress bar hidden")
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                        }
                    }

                    Item {
                        width: 1
                        height: consoleSwitch.isOn ? 2 : 0
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                    }

                    Item {
                        width: parent.width
                        property bool expanded: consoleSwitch.isOn
                        height: expanded ? 20 : 0
                        clip: true
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }

                        Row {
                            spacing: 12
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter


                            // REPLACE CheckBox id: alwaysConsoleCheckbox with:
                            Row {
                                spacing: 12
                                clip: true
                                anchors.verticalCenter: parent.verticalCenter

                                Rectangle {
                                    id: alwaysConsoleIndicator
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 4
                                    anchors.verticalCenter: parent.verticalCenter

                                    color: !alwaysConsoleEnabled
                                        ? (backend.systemColors ? Qt.rgba(mainWindow.clrBorder.r, mainWindow.clrBorder.g, mainWindow.clrBorder.b, 0.3) : "#3d3d3d")
                                        : (backend.alwaysShowConsole ? mainWindow.clrAccentFocus : mainWindow.clrBgAlt)

                                    border.color: !alwaysConsoleEnabled
                                        ? (backend.systemColors ? mainWindow.clrBorder : "#555555")
                                        : (alwaysConsoleHover.containsMouse || backend.alwaysShowConsole ? mainWindow.clrAccentFocus : mainWindow.clrBgHover)
                                    border.width: 1.5

                                    property bool alwaysConsoleEnabled: !backend.showConsole

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 130 } }

                                    Text {
                                        text: "✔"
                                        color: alwaysConsoleIndicator.alwaysConsoleEnabled ? "white" : mainWindow.clrSubtle
                                        font.pixelSize: 16
                                        font.bold: true
                                        anchors.centerIn: parent
                                        visible: backend.alwaysShowConsole
                                        opacity: backend.alwaysShowConsole ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 100 } }
                                    }

                                    MouseArea {
                                        id: alwaysConsoleHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: alwaysConsoleIndicator.alwaysConsoleEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                        onClicked: {
                                            if (alwaysConsoleIndicator.alwaysConsoleEnabled)
                                                backend.alwaysShowConsole = !backend.alwaysShowConsole
                                        }
                                    }
                                }

                                Text {
                                    text: qsTr("Always show console")
                                    color: !backend.showConsole ? mainWindow.clrText : mainWindow.clrSubtle
                                    font.pixelSize: 11
                                    verticalAlignment: Text.AlignVCenter
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Item { width: 1; height: 9 }
                        }
                    }



                    Row {
                        width: parent.width
                        height: 44

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - systemColorsSwitch.width - 8
                            spacing: 2
                            Text {
                                text: qsTr("Use system color theme")
                                color: mainWindow.clrText
                                font.pixelSize: 13 }
                            Text {
                                text: qsTr("Follow system color scheme instead of build-in purple")
                                color: mainWindow.clrSubtle
                                font.pixelSize: 10
                            }
                        }

                        Item {
                            id: systemColorsSwitch
                            width: 50
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            property bool isOn: backend.systemColors

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: systemColorsSwitch.isOn ? mainWindow.clrAccentFocus : backend.systemColors ? mainWindow.clrBorder : "#525252"
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: systemColorsSwitch.isOn ? parent.width - width - 5 : 5
                                color: systemColorsSwitch.isOn ? "white" : "transparent"
                                border.color: "white"
                                border.width: 5
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.systemColors = !systemColorsSwitch.isOn
                            }
                            ToolTip.text: systemColorsSwitch.isOn ? qsTr("System theme active") : qsTr("Dark theme active")
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                        }
                    }

                    Item {
                        width: 1
                        height: systemColorsSwitch.isOn ? 2 : 0
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                    }

                    Item {
                        width: parent.width
                        property bool expanded: systemColorsSwitch.isOn
                        height: expanded ? 20 : 0
                        clip: true
                        Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
                        Row {
                            spacing: 12
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                id: accentOnlyIndicator
                                implicitWidth: 18
                                implicitHeight: 18
                                radius: 4
                                anchors.verticalCenter: parent.verticalCenter

                                property bool isEnabled: systemColorsSwitch.isOn

                                color: !isEnabled
                                    ? (backend.systemColors ? Qt.rgba(mainWindow.clrBorder.r, mainWindow.clrBorder.g, mainWindow.clrBorder.b, 0.3) : "#3d3d3d")
                                    : (backend.accentOnlyColors ? mainWindow.clrAccentFocus : mainWindow.clrBgAlt)

                                border.color: !isEnabled
                                    ? (backend.systemColors ? mainWindow.clrBorder : "#555555")
                                    : (accentOnlyHover.containsMouse || backend.accentOnlyColors ? mainWindow.clrAccentFocus : mainWindow.clrBgHover)
                                border.width: 1.5

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 130 } }

                                Text {
                                    text: "✔"
                                    color: accentOnlyIndicator.isEnabled ? "white" : mainWindow.clrSubtle
                                    font.pixelSize: 16
                                    font.bold: true
                                    anchors.centerIn: parent
                                    visible: backend.accentOnlyColors
                                    opacity: backend.accentOnlyColors ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 100 } }
                                }

                                MouseArea {
                                    id: accentOnlyHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: accentOnlyIndicator.isEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                    onClicked: {
                                        if (accentOnlyIndicator.isEnabled)
                                            backend.accentOnlyColors = !backend.accentOnlyColors
                                    }
                                }
                            }

                            Text {
                                text: qsTr("Use only accent color")
                                color: systemColorsSwitch.isOn ? mainWindow.clrText : mainWindow.clrSubtle
                                font.pixelSize: 11
                                verticalAlignment: Text.AlignVCenter
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 44

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - lightModeSwitch.width - 8
                            spacing: 2
                            Text {
                                text: qsTr("Light mode")
                                color: mainWindow.clrText
                                font.pixelSize: 13
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                        }

                        Item {
                            id: lightModeSwitch
                            width: 50
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            property bool isOn: mainWindow.lightMode && lightModeSwitch.isEnabled
                            property bool isEnabled: (backend.accentOnlyColors && systemColorsSwitch.isOn) || !systemColorsSwitch.isOn

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: {
                                    if (!lightModeSwitch.isEnabled) return backend.systemColors
                                        ? Qt.rgba(mainWindow.clrBorder.r, mainWindow.clrBorder.g, mainWindow.clrBorder.b, 0.15)
                                        : "#2e2e2e"
                                    return lightModeSwitch.isOn ? mainWindow.clrAccentFocus
                                        : backend.systemColors
                                            ? mainWindow.clrBorder
                                            : "#525252"
                                }
                                opacity: lightModeSwitch.isEnabled ? 1.0 : 0.5
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: lightModeSwitch.isOn ? parent.width - width - 5 : 5
                                color: lightModeSwitch.isOn && lightModeSwitch.isEnabled ? "white" : "transparent"
                                border.color: "white"
                                border.width: 5
                                opacity: lightModeSwitch.isEnabled ? 1.0 : 0.4
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: lightModeSwitch.isEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                                onClicked: {
                                    if (!lightModeSwitch.isEnabled) return
                                    mainWindow.lightMode = !lightModeSwitch.isOn
                                    backend.saveLightMode(mainWindow.lightMode)
                                }
                            }
                            ToolTip.text: !lightModeSwitch.isEnabled
                                          ? qsTr("System theme is using")
                                          : lightModeSwitch.isOn ? qsTr("Light mode on") : qsTr("Light mode off")
                            ToolTip.visible: lightModeSwitchMa.containsMouse
                            ToolTip.delay: 500
                            MouseArea {
                                id: lightModeSwitchMa
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: lightModeSwitch.isEnabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        height: 44

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - notifSwitch.width - 8
                            spacing: 2
                            Text {
                                text: qsTr("Desktop notifications when minimized")
                                color: mainWindow.clrText
                                font.pixelSize: 13
                            }
                            Text {
                                text: qsTr("Send install status notification when minimized")
                                color: mainWindow.clrSubtle
                                font.pixelSize: 10
                            }
                        }

                        Item {
                            id: notifSwitch
                            width: 50
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            property bool isOn: mainWindow.notificationsEnabled

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: notifSwitch.isOn ? mainWindow.clrAccentFocus : backend.systemColors ? mainWindow.clrBorder : "#525252"
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: notifSwitch.isOn ? parent.width - width - 5 : 5
                                color: notifSwitch.isOn ? "white" : "transparent"
                                border.color: "white"; border.width: 5
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mainWindow.notificationsEnabled = !notifSwitch.isOn
                                    backend.saveNotificationsEnabled(mainWindow.notificationsEnabled)
                                }
                            }
                            ToolTip.text: notifSwitch.isOn ? qsTr("Notifications on") : qsTr("Notifications off")
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                        }
                    }

                    Row {
                        width: parent.width
                        height: 44

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - dependenciesSwitch.width - 8
                            spacing: 2
                            Text { text: qsTr("Show dependencies edit window")
                                color: mainWindow.clrText
                                font.pixelSize: 13 }
                            Text {
                                text: qsTr("Show window when installing .deb or .rpm")
                                color: mainWindow.clrSubtle
                                font.pixelSize: 10
                            }
                        }

                        Item {
                            id: dependenciesSwitch
                            width: 50
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            property bool isOn: mainWindow.isDependenciesSwitch

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: dependenciesSwitch.isOn ? mainWindow.clrAccentFocus : backend.systemColors ? mainWindow.clrBorder : "#525252"
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: dependenciesSwitch.isOn ? parent.width - width - 5 : 5
                                color: dependenciesSwitch.isOn ? "white" : "transparent"
                                border.color: "white"
                                border.width: 5
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mainWindow.isDependenciesSwitch = !dependenciesSwitch.isOn
                                    backend.saveDependenciesSwitch(mainWindow.isDependenciesSwitch)
                                }
                            }
                            ToolTip.text: dependenciesSwitch.isOn ? qsTr("Window will show") : qsTr("Window would not be showing")
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 500
                        }
                    }

                    Row {
                        width: parent.width
                        height: 44

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - notifSwitch.width - 8
                            spacing: 2
                            Text {
                                text: qsTr("Display console in full window width")
                                color: mainWindow.clrText
                                font.pixelSize: 13
                            }
                        }

                        Item {
                            id: fullWidthSwitch
                            width: 50
                            height: 30
                            anchors.verticalCenter: parent.verticalCenter

                            property bool isOn: mainWindow.consoleFullWidth

                            Rectangle {
                                anchors.fill: parent
                                radius: 15
                                color: fullWidthSwitch.isOn ? mainWindow.clrAccentFocus : backend.systemColors ? mainWindow.clrBorder : "#525252"
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            Rectangle {
                                width: 20
                                height: 20
                                radius: 10
                                anchors.verticalCenter: parent.verticalCenter
                                x: fullWidthSwitch.isOn ? parent.width - width - 5 : 5
                                color: fullWidthSwitch.isOn ? "white" : "transparent"
                                border.color: "white"
                                border.width: 5
                                Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                id: fullWidthSwitchMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mainWindow.consoleFullWidth = !fullWidthSwitch.isOn
                                    backend.saveConsoleWidthEnabled(mainWindow.consoleFullWidth)
                                }
                            }
                            ToolTip.text: fullWidthSwitch.isOn ? qsTr("Full width console on") : qsTr("Full width console off")
                            ToolTip.visible: fullWidthSwitchMa.containsMouse
                            ToolTip.delay: 500
                        }
                    }

                    Row {
                        width: parent.width
                        height: 36
                        spacing: 10

                        Text {
                            text: qsTr("Console font style")
                            color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - langComboBox.width - 10
                        }

                        Row {
                            anchors.right: parent.right
                            height: 36
                            spacing: 6


                            Rectangle {
                                id: fontFamilyCombo
                                width: 120
                                height: 36
                                radius: 8
                                color: mainWindow.clrBgAlt
                                border.width: 1.5
                                border.color: fontFamilyMa.containsMouse || fontFamilyDropdown.visible ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                                Behavior on border.color { ColorAnimation { duration: 100 } }
                                anchors.verticalCenter: parent.verticalCenter

                                readonly property var builtinFonts: ["Monospace", "Courier New", "Hack", "Fira Code"]
                                property int currentIndex: 0

                                ListModel {
                                    id: fontFamilyModel
                                }

                                function reloadCustomFonts() {
                                    fontFamilyModel.clear()

                                    for (var k = 0; k < builtinFonts.length; k++) {
                                        fontFamilyModel.append({ name: builtinFonts[k], path: "", builtin: true })
                                    }

                                    var loaded = backend.loadCustomFonts()
                                    for (var m = 0; m < loaded.length; m++) {
                                        fontFamilyModel.append({ name: loaded[m].name, path: loaded[m].path, builtin: false })
                                    }

                                    syncCurrentIndex()
                                }

                                function syncCurrentIndex() {
                                    for (var i = 0; i < fontFamilyModel.count; i++) {
                                        if (fontFamilyModel.get(i).name.toLowerCase() ===
                                            mainWindow.consoleFontFamily.toLowerCase()) {
                                            currentIndex = i
                                            return
                                        }
                                    }
                                    currentIndex = 0
                                }

                                Component.onCompleted: reloadCustomFonts()

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 6
                                    spacing: 4
                                    Text {
                                        text: fontFamilyModel.count > 0 ? fontFamilyModel.get(fontFamilyCombo.currentIndex).name : "Monospace"
                                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText; font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 16
                                        elide: Text.ElideRight
                                    }
                                    Item {
                                        width: 14
                                        height: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        Item {
                                            width: parent.width
                                            height: parent.height
                                            y: fontFamilyDropdown.visible ? 0 : -2
                                            Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                            Rectangle {
                                                width: 2
                                                height: 8
                                                radius: 1
                                                color: fontFamilyMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                                x: -1
                                                y: fontFamilyDropdown.visible ? 1 : 3
                                                transformOrigin: Item.Center
                                                rotation: fontFamilyDropdown.visible ? -45 : -135
                                                Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }
                                            Rectangle {
                                                width: 2
                                                height: 8
                                                radius: 1
                                                color: fontFamilyMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                                x: 5
                                                y: fontFamilyDropdown.visible ? 1 : 3
                                                transformOrigin: Item.Center
                                                rotation: fontFamilyDropdown.visible ? 45 : 135
                                                Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                                Behavior on color { ColorAnimation { duration: 100 } }
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: fontFamilyMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: fontFamilyDropdown.visible ? fontFamilyDropdown.close() : fontFamilyDropdown.open()
                                }

                                Popup {
                                    id: fontFamilyDropdown
                                    y: -implicitHeight - 3
                                    width: parent.width + 42
                                    padding: 4
                                    background: Rectangle {
                                        color: mainWindow.clrBgMid
                                        radius: 8
                                        border.color: mainWindow.clrBorderAlt
                                        border.width: 1
                                    }
                                    contentItem: Column {
                                        spacing: 0
                                        Repeater {
                                            model: fontFamilyModel
                                            delegate: Rectangle {
                                                width: fontFamilyDropdown.width - 8
                                                height: 32
                                                radius: 6
                                                color: fontItemMa.containsMouse ? mainWindow.clrBgHover : "transparent"

                                                Row {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 10
                                                    spacing: 6

                                                    Text {
                                                        text: fontFamilyCombo.currentIndex === index ? "✔" : " "
                                                        color: mainWindow.clrAccentAlt
                                                        font.pixelSize: 11
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: 14
                                                    }
                                                    Text {
                                                        text: model.name
                                                        color: fontFamilyCombo.currentIndex === index ? mainWindow.clrAccentHover :  mainWindow.clrText
                                                        font.pixelSize: 11
                                                        font.family: model.name
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        width: parent.width - 14 - (model.builtin ? 0 : 28) - 12
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                MouseArea {
                                                    id: fontItemMa
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var localX = mouseX
                                                        if (!model.builtin && localX > width - 34) return
                                                        fontFamilyCombo.currentIndex = index
                                                        mainWindow.consoleFontFamily = model.name
                                                        backend.saveConsoleFontFamily(model.name)
                                                        fontFamilyDropdown.close()
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }


                            Rectangle {
                                id: fontBoldBtn
                                width: 36
                                height: 36
                                radius: 8
                                color: mainWindow.consoleFontBold ? Qt.rgba(mainWindow.clrAccentBorder.r, mainWindow.clrAccentBorder.g, mainWindow.clrAccentBorder.b, 0.25) : mainWindow.clrBgAlt
                                border.width: 1.5
                                border.color: mainWindow.consoleFontBold
                                              ? mainWindow.clrAccentBorder
                                              : mainWindow.clrBorder
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: "B"
                                    font.pixelSize: 14
                                    font.bold: true
                                    color: mainWindow.consoleFontBold ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        mainWindow.consoleFontBold = !mainWindow.consoleFontBold
                                        backend.saveConsoleFontBold(mainWindow.consoleFontBold)
                                    }
                                }
                                ToolTip.text: mainWindow.consoleFontBold ? qsTr("Bold on") : qsTr("Bold off")
                                ToolTip.visible: fontBoldMaToolTip.containsMouse
                                ToolTip.delay: 500
                                MouseArea {
                                    id: fontBoldMaToolTip
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                    cursorShape: Qt.PointingHandCursor
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 5 }

                    Row {
                        width: parent.width
                        height: 80
                        spacing: 8

                        Text {
                            id: customFontNameLabel
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.margins: 6
                            text: mainWindow.consoleFontFamily !== "monospace" &&
                                  mainWindow.consoleFontFamily !== "Monospace" &&
                                  mainWindow.consoleFontFamily !== "Courier New" &&
                                  mainWindow.consoleFontFamily !== "Hack" &&
                                  mainWindow.consoleFontFamily !== "Fira Code"
                                  ? mainWindow.consoleFontFamily : ""
                            font.pixelSize: 9
                            color: mainWindow.clrMuted
                            visible: text !== ""
                        }

                        Rectangle {
                            width: parent.width - 140 - 8
                            height: 80
                            radius: 8
                            color: mainWindow.clrBgAlt
                            anchors.right: parent.right
                            border.width: 1.5
                            border.color: mainWindow.clrBorder
                            clip: true
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                anchors.fill: parent
                                anchors.margins: 10
                                text: "Debian package detected\n==> Extracting package data...\n*** Translating dependencies"
                                font.pixelSize: mainWindow.consoleFontSize
                                font.family: mainWindow.consoleFontFamily
                                font.bold: mainWindow.consoleFontBold
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                wrapMode: Text.WrapAnywhere
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Item { width: 1; height: 6 }

                    //  Package DB Section
                    Rectangle { width: parent.width; height: 1; color: mainWindow.clrBorder }
                    Item { width: 1; height: 12 }

                    Text {
                        text: qsTr("PACKAGE DATABASE")
                        color: backend.systemColors ? mainWindow.clrAccent : "#9070cc"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        bottomPadding: 12
                    }

                    Row {
                        width: parent.width
                        height: 56
                        spacing: 10

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - updateDbBtn.width - 10
                            spacing: 2
                            Text {
                                text: qsTr("Arch package list")
                                color: mainWindow.clrText
                                font.pixelSize: 13
                            }
                            Text {
                                text: qsTr("Used for .deb/.rpm dependency translation")
                                color: mainWindow.clrSubtle
                                font.pixelSize: 10
                            }
                            Text {
                                id: pkgListDateText
                                text: backend.archPackageListDate()
                                color: backend.systemColors ? mainWindow.clrSubtle : "#444"
                                font.pixelSize: 10
                            }
                        }

                        Rectangle {
                            id: updateDbBtn
                            width: Math.max(76, updateDbMeasureText.implicitWidth + 20)
                            height: 34
                            radius: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: mainWindow.clrBgAlt
                            opacity: backend.updatingPackageList ? 0.6 : 1.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            // Hidden text for width measurement to prevent shrinking
                            Text {
                                id: updateDbMeasureText
                                text: qsTr("Update")
                                font.pixelSize: 11
                                font.bold: true
                                visible: false
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1.5
                                border.color: updateDbArea.containsMouse && !backend.updatingPackageList ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 5
                                Canvas {
                                    id: checkSpinner3
                                    width: 10
                                    height: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: backend.updatingPackageList
                                    property real angle: 0
                                    NumberAnimation on angle {
                                        from: 0
                                        to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                        running: checkSpinner3.visible
                                    }
                                    onAngleChanged: requestPaint()
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.strokeStyle = mainWindow.clrAccentHover
                                        ctx.lineWidth = 1.8
                                        ctx.lineCap = "round"
                                        var cx = width/2, cy = height/2, r = width/2 - 1.2
                                        var s = (angle - 90) * Math.PI / 180
                                        var e = s + 240 * Math.PI / 180
                                        ctx.beginPath()
                                        ctx.arc(cx, cy, r, s, e)
                                        ctx.stroke()
                                    }
                                }
                                Text {
                                    id: updateDbText
                                    font.bold: true
                                    text: backend.updatingPackageList ? "" : qsTr("Update")
                                    color: updateDbArea.containsMouse && !backend.updatingPackageList ? mainWindow.clrAccentHover : mainWindow.clrText
                                    font.pixelSize: 11
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                }
                            }

                            MouseArea {
                                id: updateDbArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: backend.updatingPackageList ? Qt.WaitCursor : Qt.PointingHandCursor
                                enabled: !backend.updatingPackageList
                                onClicked: backend.forceUpdateArchPackageList()
                            }
                        }

                        Text {
                            id: updateStatus
                            visible: opacity > 0
                            opacity: 0
                            text: backend.archsuccess ? ("✔ " + qsTr("Successful")) : backend.archerror ? ("✕ " + qsTr("Failed")) : ""
                            color: backend.archsuccess ? "#50fa7b" : "#ff5555"
                            font.pixelSize: 10
                            anchors.right: parent.right
                            y: 50

                            function showResult() {
                                fadeOutAnimationUpdate.stop()
                                updateTimer.stop()
                                updateStatus.opacity = 0
                                fadeInAnimationUpdate.start()
                            }

                            Connections {
                                target: backend
                                function onArchsuccessChanged() {
                                    if (backend.archsuccess) updateStatus.showResult()
                                }
                                function onArcherrorChanged() {
                                    if (backend.archerror) updateStatus.showResult()
                                }
                            }

                            Timer {
                                id: updateTimer
                                interval: 3000
                                onTriggered: fadeOutAnimationUpdate.start()
                            }

                            PropertyAnimation {
                                id: fadeInAnimationUpdate
                                target: updateStatus
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 150
                                onRunningChanged: {
                                    if (!running) updateTimer.start()
                                }
                            }

                            PropertyAnimation {
                                id: fadeOutAnimationUpdate
                                target: updateStatus
                                property: "opacity"
                                from: 1
                                to: 0
                                duration: 150
                                onRunningChanged: {
                                    if (!running) backend.resetArchStatus()
                                }
                            }
                        }
                    }

                    Item { width: 1; height: 16 }

                    //  Language Section
                    Rectangle { width: parent.width; height: 1; color: mainWindow.clrBorder }
                    Item { width: 1; height: 12 }

                    Text {
                        text: qsTr("LANGUAGE")
                        color: backend.systemColors ? mainWindow.clrAccent : "#9070cc"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.5
                        bottomPadding: 12
                    }

                    Row {
                        width: parent.width
                        height: 36
                        spacing: 10

                        Text {
                            text: qsTr("Interface language")
                            color: mainWindow.clrText
                            font.pixelSize: 13
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - langComboBox.width - 10
                        }

                        Rectangle {
                            id: langComboBox
                            width: 170
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            border.color: (langDropdownMa.containsMouse || langDropdown.visible) ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 100 } }
                            border.width: 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            property int currentIndex: 0

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 8
                                spacing: 4

                                Text {
                                    text: languageModel.count > 0
                                          ? languageModel.get(langComboBox.currentIndex).display
                                          : "English"
                                    color: mainWindow.clrText
                                    font.pixelSize: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 20
                                    elide: Text.ElideRight
                                }

                                Item {
                                    width: 14
                                    height: 10
                                    anchors.verticalCenter: parent.verticalCenter

                                    Item {
                                        width: parent.width
                                        height: parent.height
                                        y: langDropdown.visible ? 0 : -2
                                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

                                        Rectangle {
                                            width: 2
                                            height: 8
                                            radius: 1
                                            color: langDropdownMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                            x: 3
                                            y: langDropdown.visible ? 1 : 3
                                            transformOrigin: Item.Center
                                            rotation: langDropdown.visible ? -45 : -135
                                            Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                            Behavior on y      { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                            Behavior on color  { ColorAnimation  { duration: 100 } }
                                        }

                                        Rectangle {
                                            width: 2
                                            height: 8
                                            radius: 1
                                            color: langDropdownMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                            x: 9
                                            y: langDropdown.visible ? 1 : 3
                                            transformOrigin: Item.Center
                                            rotation: langDropdown.visible ? 45 : 135
                                            Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                            Behavior on y      { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                            Behavior on color  { ColorAnimation  { duration: 100 } }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: langDropdownMa
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: langDropdown.visible ? langDropdown.close() : langDropdown.open()
                            }

                            Popup {
                                id: langDropdown
                                y: -implicitHeight - 3
                                width: parent.width
                                padding: 4
                                background: Rectangle {
                                    color: mainWindow.clrBgMid
                                    radius: 8
                                    border.color: mainWindow.clrBorderAlt
                                    border.width: 1
                                }

                                onOpened: {
                                    langScrollTimer.start()
                                }

                                Timer {
                                    id: langScrollTimer
                                    interval: 25
                                    onTriggered: {
                                        langListView.currentIndex = langComboBox.currentIndex
                                    }
                                }

                                contentItem: ListView {
                                    id: langListView
                                    clip: true
                                    implicitHeight: Math.min(200, contentHeight)
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: languageModel
                                    highlightMoveDuration: 400
                                    highlightRangeMode: ListView.ApplyRange
                                    preferredHighlightBegin: implicitHeight / 2 - 16
                                    preferredHighlightEnd: implicitHeight / 2 + 16

                                    highlight: Item {}

                                    ScrollBar.vertical: ScrollBar {
                                        id: langScroller
                                        width: 4
                                        policy: ScrollBar.AsNeeded
                                        hoverEnabled: true
                                        minimumSize: langListView.height > 0 ? 30 / langListView.height : 0.05

                                        anchors.right: parent.right
                                        anchors.rightMargin: 1
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom

                                        onPressedChanged: {
                                            if (pressed) {
                                                langListView.stickToBottom = false
                                            } else if (langListView.atYEnd) {
                                                langListView.stickToBottom = true
                                            }
                                        }

                                        property bool keepVisible: false

                                        Timer {
                                            id: langHideDelayTimer
                                            interval: 1500
                                            onTriggered: langScroller.keepVisible = false
                                        }

                                        Connections {
                                            target: langListView
                                            function onMovingChanged() {
                                                if (langListView.moving) {
                                                    langScroller.keepVisible = true
                                                    langHideDelayTimer.stop()
                                                } else {
                                                    langHideDelayTimer.restart()
                                                }
                                            }
                                        }

                                        opacity: (langListView.moving || langListView.flicking || active || hovered || keepVisible) ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 250 } }

                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                                            opacity: langScroller.pressed ? 0.7 : 0.4
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                        }
                                        background: Item {}
                                    }

                                    delegate: Rectangle {
                                        width: langDropdown.width - 8
                                        height: 32
                                        radius: 6
                                        color: langItemMa.containsMouse ? mainWindow.clrBgHover : "transparent"

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            spacing: 6
                                            Text {
                                                text: langComboBox.currentIndex === index ? "✔" : " "
                                                color: mainWindow.clrAccentAlt
                                                font.pixelSize: 11
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 14
                                            }
                                            Text {
                                                text: model.display
                                                color: langComboBox.currentIndex === index ? mainWindow.clrAccentHover : mainWindow.clrText
                                                font.pixelSize: 12
                                                anchors.verticalCenter: parent.verticalCenter
                                            }
                                        }

                                        MouseArea {
                                            id: langItemMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                langComboBox.currentIndex = index
                                                langDropdown.close()
                                                backend.setLanguage(model.code)
                                                langRestartNote.visible = false
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Item { width: 1; height: backend.loadDonateHidden() ? 12 : 20 }

                    Column {
                        width: parent.width
                        spacing: 0
                        visible: !backend.loadDonateHidden()

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Developing") + " \"Linux Package Installer\" " + qsTr("is not the easiest work, author spent a lot of evenings to develop and test it. Without your support this project will become abandoned.")
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            color: mainWindow.clrMuted
                            width: parent.width * 1
                            wrapMode: Text.Wrap
                        }

                        Item { width: 1; height: 5 }

                        Text {
                            id: support
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: qsTr("Support")
                            font.pixelSize: 11
                            horizontalAlignment: Text.AlignHCenter
                            color: mainWindow.clrLink
                            width: parent.width * 0.9
                            wrapMode: Text.Wrap

                            Behavior on color { ColorAnimation { duration: 120 } }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: support.color = backend.systemColors ? Qt.lighter(mainWindow.clrLink, 1.25) : Qt.lighter(mainWindow.clrLink, 1.5)
                                onExited:  support.color = mainWindow.clrLink
                                onClicked: {
                                    Qt.openUrlExternally("https://example.com")
                                }
                            }
                        }
                    }


                    Item { width: 1; height: 9; visible: !backend.loadDonateHidden() }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Version: pre-release")
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        color: mainWindow.clrMuted
                    }

                    Item { width: 1; height: backend.loadDonateHidden() ? 8 : 12 }

                }
            }
        }
    }

    // Installation properties (archive / folder)
    Window {
        id: modalWindow
        title: qsTr("Installation properties")
        width: 460
        height: 585
        minimumWidth: 460
        minimumHeight: 585
        maximumHeight:  modalWindow.minimumHeight
        maximumWidth: modalWindow.minimumWidth
        modality: Qt.ApplicationModal
        visible: false
        color: mainWindow.clrBg

        property bool forceClose: false
        property string packageRoot: ""



        onClosing: function(closeEvent) {
            if (!forceClose) {
                closeEvent.accepted = false
                Qt.callLater(function() { killDialog2.open() })
            }
        }

        onVisibleChanged: {
            if (!visible) return
            var dir         = backend.getExtractedDir()
            var archivePath = backend.archiveLocation
            modalWindow.packageRoot = backend.packageRootDir()
            executableModel.clear()
            iconModel.clear()
            backend.findIconsAsync(dir)
            backend.findExecutablesAsync(dir, archivePath)
            iconModel.append({ "name": "Default (system)", "path": "__system__" })
            iconGrid.currentIndex = 0
            backend.iconPath = ""
            appNameField.updatingFromBackend = true
            appNameField.text = backend.appName
            appNameField.updatingFromBackend = false
            execCommandField.text = backend.execCommand
            descField.updatingFromBackend = true
            descField.text = backend.appDescription
            descField.updatingFromBackend = false
            categoryField.updatingFromBackend = true
            categoryField.text = backend.appCategory
            categoryField.updatingFromBackend = false
        }

        Kirigami.PromptDialog {
            id: aiCustomErrorDialog2
            parent: modalWindow.contentItem
            title: qsTr("")
            subtitle: qsTr("")
            standardButtons: Kirigami.Dialog.NoButton

            property string currentUrl: ""
            property bool settingbut: false

            customFooterActions: [
                Kirigami.Action {
                    text: qsTr("Open AI page")
                    icon.name: "internet-web-browser"
                    visible: aiCustomErrorDialog2.currentUrl === "" ? false : true
                    onTriggered: {
                        Qt.openUrlExternally(aiCustomErrorDialog2.currentUrl)
                        aiCustomErrorDialog2.close()
                    }
                },
                Kirigami.Action {
                    text: qsTr("Open settings")
                    icon.name: "settings"
                    visible: aiCustomErrorDialog2.settingbut
                    onTriggered: {
                        aiCustomErrorDialog2.close()
                        modalWindow.forceClose = true
                        modalWindow.close()
                        backend.cancel()
                        settingsWindow.show()
                    }
                },
                Kirigami.Action {
                    text: qsTr("Continue")
                    icon.name: "dialog-ok"
                    onTriggered: aiCustomErrorDialog2.close()
                }
            ]
        }

        Kirigami.PromptDialog {
            id: aiErrorDialog2
            parent: modalWindow.contentItem
            title: qsTr("AI Error")
            subtitle: ""
            standardButtons: Kirigami.Dialog.Ok
        }


        Kirigami.PromptDialog {
            id: killDialog2
            parent: modalWindow.contentItem
            title: qsTr("Cancel")
            subtitle: qsTr("Do you want to cancel the installation process?")
            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
            onAccepted: { modalWindow.forceClose = true
                modalWindow.close()
                backend.cancel() }
        }

        Platform.FileDialog {
            id: customExecDialog
            folder: "file://" + backend.packageRootDir()
            title: qsTr("Select executable file")
            nameFilters: ["All files (*)"]
            onAccepted: {
                var path = file.toString().replace("file://", "")
                if (!path.startsWith(modalWindow.packageRoot)) { execWarningDialog.open(); return }
                backend.executable = path
                backend.onExecutableChanged(path)
                var found = false
                for (var i = 0; i < executableModel.count; i++) {
                    if (executableModel.get(i).path === path) {
                        executableList.currentIndex = i
                        found = true
                        break }
                }
                if (!found) {
                    executableModel.insert(0, { "name": path.substring(path.lastIndexOf('/') + 1) + " (custom)", "path": path })
                    executableList.currentIndex = 0
                }
            }
        }

        Kirigami.PromptDialog {
            id: ai402ErrorDialog
            title: qsTr("AI limit reached")
            parent: modalWindow.contentItem
            subtitle: ""
            standardButtons: Kirigami.Dialog.NoButton

            property string currentUrl: ""
            property string currentName: ""
            customFooterActions: [
                Kirigami.Action {
                    text: qsTr("Open ") + ai402ErrorDialog.currentName
                    icon.name: "internet-web-browser"
                    onTriggered: {
                        Qt.openUrlExternally(ai402ErrorDialog.currentUrl)
                        ai402ErrorDialog.close()
                    }
                },
                Kirigami.Action {
                    text: qsTr("Continue without AI")
                    icon.name: "dialog-ok"
                    onTriggered: ai402ErrorDialog.close()
                }
            ]
        }

        Platform.FileDialog {
            id: customIconDialog
            folder: "file://" + modalWindow.packageRoot
            title: qsTr("Select icon file")
            nameFilters: ["Image files (*.png *.jpg *.jpeg *.svg *.ico)", "All files (*)"]
            onAccepted: {
                var path = file.toString().replace("file://", "")
                backend.iconPath = path
                var found = false
                for (var i = 0; i < iconModel.count; i++) {
                    if (iconModel.get(i).path === path) {
                        iconGrid.currentIndex = i
                        found = true
                        break
                    }
                }
                if (!found) {
                    iconModel.insert(0, { "name": path.substring(path.lastIndexOf('/') + 1) + " (external)", "path": path })
                    iconGrid.currentIndex = 0
                }
            }
        }

        Kirigami.PromptDialog {
            id: execWarningDialog
            parent: modalWindow.contentItem
            title: qsTr("File outside package")
            subtitle: qsTr("The executable must be selected from inside the package directory.")
            standardButtons: Kirigami.Dialog.Ok
        }

        ListModel { id: executableModel }
        ListModel { id: iconModel }

        Rectangle {
            anchors.fill: parent
            color: mainWindow.clrBg

            MouseArea {
                anchors.fill: parent
                onClicked: parent.forceActiveFocus()
            }

            Flickable {
                id: modalFlickable
                anchors.fill: parent
                anchors.bottomMargin: 47
                anchors.margins: 12
                clip: true
                contentWidth: width
                contentHeight: modalColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                MouseArea {
                    width: modalFlickable.width
                    height: modalFlickable.contentHeight
                    onClicked: modalFlickable.forceActiveFocus()
                }

                Column {
                    id: modalColumn
                    width: modalFlickable.width

                    spacing: 10

                    Rectangle {
                        width: parent.width
                        height: aiStatusRow1.implicitHeight + 10
                        color: mainWindow.clrBgMid
                        radius: 6
                        visible: backend.aiAnalyzing || backend.appDescription !== ""
                        Row {
                            id: aiStatusRow1
                            anchors.centerIn: parent
                            spacing: 8
                            Canvas {
                                id: modalSpinner
                                width: 10
                                height: 10
                                anchors.verticalCenter: parent.verticalCenter
                                visible: backend.aiAnalyzing
                                property real angle: 0
                                NumberAnimation on angle {
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: modalSpinner.visible
                                }
                                onAngleChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = mainWindow.lightMode ? "#666565" : "#aaaaaa"
                                    ctx.lineWidth = 1.8
                                    ctx.lineCap = "round"
                                    var cx = width/2, cy = height/2, r = width/2 - 1.2
                                    var s = (angle - 90) * Math.PI / 180
                                    var e = s + 240 * Math.PI / 180
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, s, e)
                                    ctx.stroke()
                                }
                            }
                            Text {
                                color: backend.aiAnalyzing ? (mainWindow.lightMode ? "#666565" : "#aaaaaa") : (mainWindow.lightMode ? "#08631f" : "#50fa7b")
                                font.pixelSize: 12
                                text: backend.aiAnalyzing ? qsTr("AI is analyzing the application...") : "✔ " + qsTr("AI metadata applied")
                                verticalAlignment: Text.AlignVCenter
                                height: 24
                            }
                        }
                    }


                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            color: mainWindow.clrText
                            text: qsTr("Select main executable:")
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            width: parent.width - parent.children[0].width - browseIconBtn.width - 16
                            height: 1
                        }
                        Rectangle {
                            id: browseExecBtn
                            width: Math.max(70, browseExecText.implicitWidth + 24)
                            height: 36
                            radius: 8
                            color: browseExecMa.containsMouse ? mainWindow.clrBgButtonHover : mainWindow.clrBgHover
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                id: browseExecText
                                anchors.centerIn: parent
                                text: qsTr("Browse…")
                                font.pixelSize: 11
                                font.bold: true
                                color: "white"
                            }
                            MouseArea {
                                id: browseExecMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: customExecDialog.open()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 110
                        color: mainWindow.clrBgAlt
                        radius: 6
                        ListView {
                            id: executableList
                            anchors.fill: parent
                            model: executableModel
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                id: scroller
                                width: 4
                                policy: ScrollBar.AsNeeded
                                hoverEnabled: true
                                minimumSize: executableList.height > 0 ? 30 / executableList.height : 0.05

                                anchors.right: parent.right
                                anchors.rightMargin: 1
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                onPressedChanged: {
                                    if (pressed) {
                                        executableList.stickToBottom = false
                                    } else if (executableList.atYEnd) {
                                        executableList.stickToBottom = true
                                    }
                                }

                                property bool keepVisible: false

                                Timer {
                                    id: hideDelayTimer1
                                    interval: 1500
                                    onTriggered: scroller.keepVisible = false
                                }

                                Connections {
                                    target: executableList
                                    function onMovingChanged() {
                                        if (executableList.moving) {
                                            scroller.keepVisible = true
                                            hideDelayTimer1.stop()
                                        } else {
                                            hideDelayTimer1.restart()
                                        }
                                    }
                                }

                                opacity: (executableList.moving || executableList.flicking || active || hovered || keepVisible) ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 250 } }

                                contentItem: Rectangle {
                                    implicitWidth: 4
                                    radius: 2
                                    color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                                    opacity: scroller.pressed ? 0.7 : 0.4
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                background: Item {}
                            }


                            delegate: Rectangle {
                                width: executableList.width
                                height: 40
                                color: executableList.currentIndex === index ? mainWindow.clrBorder : "transparent"

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        executableList.currentIndex = index
                                        backend.executable = model.path
                                        backend.onExecutableChanged(model.path)
                                    }
                                    onDoubleClicked: backend.runFile(model.path)
                                }

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 8
                                    Kirigami.Icon { source: "application-x-executable"
                                        width: 20
                                        height: 20 }
                                    Column {
                                        Text {
                                            text: model.name
                                            color: mainWindow.clrText
                                            font.pixelSize: 13
                                        }

                                        Text {
                                            text: model.path
                                            color: mainWindow.clrMuted
                                            font.pixelSize: 10
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        color: mainWindow.clrMuted
                        font.pixelSize: 10
                        text: qsTr("Double-click to run")
                        width: parent.width
                    }

                    Text {
                        color: mainWindow.clrText
                        text: qsTr("Launch command (Exec=):")
                        font.bold: true
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - resetExecBtn.width - 8
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            border.width: 1.5
                            border.color: execCommandField.activeFocus ? mainWindow.clrAccentBorder : execCmdHover.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 95 } }

                            TextField {
                                id: execCommandField
                                anchors.fill: parent
                                anchors.margins: 2
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                placeholderText: "/usr/lib/appname/exe %u"
                                background: Item {}
                                onTextEdited: backend.execCommand = text
                            }

                            MouseArea {
                                id: execCmdHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                                z: 10
                            }
                        }

                        Rectangle {
                            id: resetExecBtn
                            width: 36
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1.5
                                border.color: resetExecMa.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                                Behavior on border.color { ColorAnimation { duration: 95 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "↺"
                                font.pixelSize: 15
                                color: resetExecMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            MouseArea {
                                id: resetExecMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: backend.resetExecCommand()
                            }
                            ToolTip.text: qsTr("Reset to default")
                            ToolTip.visible: resetExecMa.containsMouse
                            ToolTip.delay: 500
                        }
                    }
                    Text {
                        color: mainWindow.clrSubtle
                        font.pixelSize: 10
                        text: qsTr("This goes into Exec= in the .desktop file. You can add arguments, e.g. --no-sandbox")
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        width: parent.width
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        Text {
                            color: mainWindow.clrText
                            text: qsTr("Select icon:")
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Item {
                            width: parent.width - parent.children[0].width - browseIconBtn.width - 16
                            height: 1
                        }
                        Rectangle {
                            id: browseIconBtn
                            width: Math.max(70, browseIconText.implicitWidth + 24)
                            height: 36
                            radius: 8
                            color: browseIconMa.containsMouse ? mainWindow.clrBgButtonHover : mainWindow.clrBgHover
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                id: browseIconText
                                anchors.centerIn: parent
                                text: qsTr("Browse…")
                                font.pixelSize: 11
                                font.bold: true
                                color: "white"
                            }
                            MouseArea {
                                id: browseIconMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: customIconDialog.open()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 100
                        color: mainWindow.clrBgAlt
                        radius: 6
                        GridView {
                            id: iconGrid
                            anchors.fill: parent
                            model: iconModel
                            clip: true
                            cellWidth: 107
                            cellHeight: 100
                            flow: GridView.FlowLeftToRight
                            boundsBehavior: Flickable.StopAtBounds

                            ScrollBar.vertical: ScrollBar {
                                id: scroller1
                                width: 4
                                policy: ScrollBar.AsNeeded
                                hoverEnabled: true
                                minimumSize: iconGrid.height > 0 ? 30 / iconGrid.height : 0.05

                                anchors.right: parent.right
                                anchors.rightMargin: 1
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom

                                onPressedChanged: {
                                    if (pressed) {
                                        iconGrid.stickToBottom = false
                                    } else if (iconGrid.atYEnd) {
                                        iconGrid.stickToBottom = true
                                    }
                                }

                                property bool keepVisible: false

                                Timer {
                                    id: hideDelayTimer2
                                    interval: 1500
                                    onTriggered: scroller1.keepVisible = false
                                }

                                Connections {
                                    target: iconGrid
                                    function onMovingChanged() {
                                        if (iconGrid.moving) {
                                            scroller1.keepVisible = true
                                            hideDelayTimer2.stop()
                                        } else {
                                            hideDelayTimer2.restart()
                                        }
                                    }
                                }

                                opacity: (iconGrid.moving || iconGrid.flicking || active || hovered || keepVisible) ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 250 } }

                                contentItem: Rectangle {
                                    implicitWidth: 4
                                    radius: 2
                                    color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                                    opacity: scroller1.pressed ? 0.7 : 0.4
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }

                                background: Item {}
                            }



                            delegate: Rectangle {
                                width: iconGrid.cellWidth
                                height: iconGrid.cellHeight
                                color: iconGrid.currentIndex === index ? mainWindow.clrBorder : "transparent"
                                radius: 6
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        iconGrid.currentIndex = index
                                        backend.iconPath = model.path === "__system__" ? "" : model.path
                                    }
                                    onDoubleClicked: {
                                        if (model.path !== "__system__") Qt.openUrlExternally("file://" + model.path)
                                    }
                                }
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Kirigami.Icon {
                                        source: "application-x-executable"
                                        width: 64
                                        height: 64
                                        visible: model.path === "__system__"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Image {
                                        source: model.path !== "__system__" ? "file://" + model.path : ""
                                        width: 64
                                        height: 64
                                        fillMode: Image.PreserveAspectFit
                                        visible: model.path !== "__system__"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                    Text {
                                        text: model.name
                                        color: mainWindow.clrText
                                        font.pixelSize: 12
                                        horizontalAlignment: Text.AlignHCenter
                                        width: parent.width
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                        text: qsTr("Application name:")
                        font.bold: true
                    }
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 8
                        color: mainWindow.clrBgAlt
                        border.width: 1.5
                        border.color: appNameField.activeFocus ? mainWindow.clrAccentBorder : appNameHover.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        TextField {
                            id: appNameField
                            anchors.fill: parent
                            anchors.margins: 2
                            placeholderText: "Enter app name..."
                            color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                            background: Item {}
                            property bool updatingFromBackend: false
                            onTextChanged: { if (!updatingFromBackend) backend.appName = text }
                        }

                        MouseArea {
                            id: appNameHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            cursorShape: Qt.IBeamCursor
                            z: 10
                        }
                    }
                    Text {
                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                        text: qsTr("Description:")
                        font.bold: true
                    }
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: !backend.hasAiAccess ? parent.width : parent.width - regenDescBtn.width - resetDescBtn.width - 16
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            border.width: 1.5
                            border.color: descField.activeFocus ? mainWindow.clrAccentBorder : descHover.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            TextField {
                                id: descField
                                anchors.fill: parent
                                anchors.margins: 2
                                placeholderText: qsTr("Short description...")
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                background: Item {}
                                property bool updatingFromBackend: false
                                onTextChanged: {
                                    if (!updatingFromBackend) backend.appDescription = text
                                    else cursorPosition = 0
                                }
                            }

                            MouseArea {
                                id: descHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                                z: 10
                            }
                        }

                        Rectangle {
                            id: regenDescBtn
                            width: 36
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            visible: backend.hasAiAccess
                            opacity: backend.aiAnalyzing ? 0.4 : 1.0
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1.5
                                border.color: regenDescMa.containsMouse && !backend.aiAnalyzing ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "↺"
                                font.pixelSize: 15
                                color: regenDescMa.containsMouse && !backend.aiAnalyzing ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            MouseArea {
                                id: regenDescMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: backend.aiAnalyzing ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !backend.aiAnalyzing
                                onClicked: backend.regenerateDescription()
                            }
                            ToolTip.text: qsTr("Regenerate description with AI")
                            ToolTip.visible: regenDescMa.containsMouse
                            ToolTip.delay: 500
                        }

                        Rectangle {
                            id: resetDescBtn
                            width: 36
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            visible: backend.hasAiAccess
                            opacity: backend.aiAnalyzing ? 0.4 : 1.0

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1.5
                                border.color: resetDescMa.containsMouse && !backend.aiAnalyzing ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "⟲"
                                font.pixelSize: 15
                                color: resetDescMa.containsMouse && !backend.aiAnalyzing ? mainWindow.clrAccentHover : mainWindow.clrMuted

                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: resetDescMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: backend.aiAnalyzing ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !backend.aiAnalyzing
                                onClicked: backend.resetDescriptionToFirst()
                            }
                            ToolTip.text: qsTr("Reset to first AI description")
                            ToolTip.visible: resetDescMa.containsMouse
                            ToolTip.delay: 500
                        }
                    }

                    Text {
                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                        text: qsTr("Category (freedesktop):")
                        font.bold: true
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - categoryHelpBtn.width - 8
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            border.width: 1.5
                            border.color: categoryField.activeFocus ? mainWindow.clrAccentBorder : categoryHover.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            TextField {
                                id: categoryField
                                anchors.fill: parent
                                anchors.margins: 2
                                placeholderText: "e.g. Network;WebBrowser;"
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                background: Item {}
                                property bool updatingFromBackend: false
                                onTextChanged: { if (!updatingFromBackend) backend.appCategory = text }
                            }

                            MouseArea {
                                id: categoryHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                                z: 10
                            }
                        }

                        Rectangle {
                            id: categoryHelpBtn
                            width: 36
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1.5
                                border.color: categoryMa.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }

                            Item {
                                anchors.centerIn: parent
                                width: 14
                                height: 10

                                Item {
                                    width: parent.width
                                    height: parent.height
                                    y: categoryMenu.visible ? 0 : -2
                                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

                                    Rectangle {
                                        width: 2
                                        height: 8
                                        radius: 1
                                        color: categoryMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                        x: 3
                                        y: categoryMenu.visible ? 1 : 3
                                        transformOrigin: Item.Center
                                        rotation: categoryMenu.visible ? -45 : -135
                                        Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    Rectangle {
                                        width: 2; height: 8; radius: 1
                                        color: categoryMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                        x: 9
                                        y: categoryMenu.visible ? 1 : 3
                                        transformOrigin: Item.Center
                                        rotation: categoryMenu.visible ? 45 : 135
                                        Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                }
                            }

                            MouseArea {
                                id: categoryMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: categoryMenu.visible ? categoryMenu.close() : categoryMenu.open()
                            }

                            Popup {
                                id: categoryMenu
                                y: -253
                                x: -144
                                width: 180
                                height: Math.min(250, categoryListView.contentHeight + 8)
                                padding: 4

                                Connections {
                                    target: modalFlickable

                                    function onContentYChanged() {
                                        if (categoryMenu.opened && (modalFlickable.flicking || modalFlickable.moving)) {
                                            categoryMenu.close()
                                        }
                                    }
                                }

                                background: Rectangle {
                                    color: mainWindow.clrBgMid
                                    radius: 8
                                    border.color: mainWindow.clrBorderAlt
                                    border.width: 1
                                }

                                contentItem: ListView {
                                    id: categoryListView
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: [
                                        "Audio;Video;", "Audio;", "Video;", "Development;",
                                        "Education;", "Game;", "Graphics;", "Network;",
                                        "Network;WebBrowser;", "Office;", "Science;", "Settings;",
                                        "System;", "System;FileManager;", "System;TerminalEmulator;",
                                        "Utility;", "Utility;TextEditor;"
                                    ]

                                    ScrollBar.vertical: ScrollBar {
                                        id: catScroller
                                        width: 4
                                        policy: ScrollBar.AsNeeded
                                        hoverEnabled: true
                                        minimumSize: categoryListView.height > 0 ? 30 / categoryListView.height : 0.05

                                        anchors.right: parent.right
                                        anchors.rightMargin: 1
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom

                                        onPressedChanged: {
                                            if (pressed) {
                                                categoryListView.stickToBottom = false
                                            } else if (categoryListView.atYEnd) {
                                                categoryListView.stickToBottom = true
                                            }
                                        }

                                        property bool keepVisible: false

                                        Timer {
                                            id: hideDelayTimer3
                                            interval: 1500
                                            onTriggered: catScroller.keepVisible = false
                                        }

                                        Connections {
                                            target: categoryListView
                                            function onMovingChanged() {
                                                if (categoryListView.moving) {
                                                    catScroller.keepVisible = true
                                                    hideDelayTimer3.stop()
                                                } else {
                                                    hideDelayTimer3.restart()
                                                }
                                            }
                                        }

                                        opacity: (categoryListView.moving || categoryListView.flicking || active || hovered || keepVisible) ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 250 } }

                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                                            opacity: catScroller.pressed ? 0.7 : 0.4
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                        }

                                        background: Item {}
                                    }

                                    delegate: Rectangle {
                                        width: categoryListView.width
                                        height: 32
                                        radius: 6
                                        color: catItemMa.containsMouse ? mainWindow.clrBgHover : "transparent"
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            text: modelData
                                            color: categoryField.text === modelData ? mainWindow.clrAccentHover : mainWindow.clrText
                                            font.pixelSize: 12
                                        }
                                        MouseArea {
                                            id: catItemMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                categoryField.text = modelData
                                                backend.appCategory = modelData
                                                categoryMenu.close()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text { color: mainWindow.clrSubtle
                        font.pixelSize: 10
                        text: qsTr("Format: PrimaryCategory;ExtraCategory;  (e.g. Network;WebBrowser;)")
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        width: parent.width
                    }
                    Item {
                        width: 1
                        height: 6
                    }
                }
            }

            // Blur footer
            Item {
                id: footer
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 47
                z: 10

                FastBlur {
                    anchors.fill: parent
                    radius: 64
                    source: ShaderEffectSource {
                        sourceItem: modalFlickable
                        sourceRect: Qt.rect(0, modalFlickable.height - footer.height, footer.width, footer.height)
                        live: true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(mainWindow.clrBg.r, mainWindow.clrBg.g, mainWindow.clrBg.b, 0.6)
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: mainWindow.clrBorder
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: Math.max(80, installText.implicitWidth + 24)
                        height: 36
                        radius: 8
                        color: mainWindow.clrBgAlt
                        opacity: (backend.aiAnalyzing || executableModel.count === 0) ? 0.4 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1.5
                            border.color: installMa.containsMouse && !backend.aiAnalyzing && executableModel.count > 0 ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            id: installText
                            anchors.centerIn: parent
                            text: qsTr("Install")
                            font.pixelSize: 13
                            color: installMa.containsMouse && !backend.aiAnalyzing && executableModel.count > 0 ? mainWindow.clrAccentHover : mainWindow.clrText
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea {
                            id: installMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: (backend.aiAnalyzing || executableModel.count === 0) ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !backend.aiAnalyzing && executableModel.count > 0
                            onClicked: {
                                modalWindow.forceClose = true
                                modalWindow.close()
                                modalWindow.forceClose = false
                                backend.installPackage()
                            }
                        }
                    }

                    Rectangle {
                        width: Math.max(80, cancelText.implicitWidth + 24)
                        height: 36
                        radius: 8
                        color: mainWindow.clrBgAlt

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1.5
                            border.color: cancelMa.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 95 } }
                        }
                        Text {
                            id: cancelText
                            anchors.centerIn: parent
                            text: qsTr("Cancel")
                            font.pixelSize: 13
                            color: cancelMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrText
                            Behavior on color { ColorAnimation { duration: 95 } }
                        }
                        MouseArea {
                            id: cancelMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { backend.rmAlltempfiles()
                                modalWindow.forceClose = true
                                modalWindow.close()
                                mainWindow.installCancelled = true
                                modalWindow.forceClose = false
                                backend.cancel()
                            }
                        }
                    }
                }
            }
        }
        ScrollBar {
            id: modalScrollerV
            parent: modalWindow.contentItem

            x: modalWindow.width - width - 2
            y: modalFlickable.y
            height: modalFlickable.height

            position: modalFlickable.visibleArea.yPosition
            size: modalFlickable.visibleArea.heightRatio
            orientation: Qt.Vertical

            width: 4
            policy: ScrollBar.AsNeeded
            hoverEnabled: true
            minimumSize: modalFlickable.height > 0 ? 30 / modalFlickable.height : 0.05

            property bool keepVisible: false

            Timer {
                id: modalHideDelayTimer
                interval: 1500
                onTriggered: modalScrollerV.keepVisible = false
            }

            Connections {
                target: modalFlickable
                ignoreUnknownSignals: true

                function onMovingChanged() {
                    if (modalFlickable.moving) {
                        modalScrollerV.keepVisible = true
                        modalHideDelayTimer.stop()
                    } else {
                        modalHideDelayTimer.restart()
                    }
                }
            }

            readonly property bool isMoving: modalFlickable.moving || modalFlickable.flicking

            opacity: (isMoving || active || hovered || keepVisible) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250 } }

            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                opacity: modalScrollerV.pressed ? 0.7 : 0.4
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            background: Item {}
        }
    }

    // ── AppImage modal ───────────────────────────────────────────────────
    Window {
        id: modalWindow2
        title: qsTr("AppImage — Installation properties")
        width: 440
        height: 490
        minimumWidth: 440
        minimumHeight: 490
        maximumHeight: modalWindow2.minimumHeight
        maximumWidth: modalWindow2.minimumWidth
        modality: Qt.ApplicationModal
        visible: false
        color: mainWindow.clrBg

        property bool forceClose: false
        property string customIconPath: ""

        onClosing: function(closeEvent) {
            if (!forceClose) {
                closeEvent.accepted = false
                Qt.callLater(function() { killDialog3.open() })
            }
        }
        onVisibleChanged: {
            if (!visible) return
            customIconPath = ""
            var fallback = backend.appimageBaseName(backend.appimageLocation)
            aiNameField.text = fallback
            aiDescField.text = ""
            aiCategoryField.text = "Utility;"
            backend.analyzeAppimageWithAI(backend.appimageLocation)
        }

        Kirigami.PromptDialog {
            id: aiCustomErrorDialog3
            parent: modalWindow2.contentItem
            title: qsTr("")
            subtitle: qsTr("")
            standardButtons: Kirigami.Dialog.NoButton

            property string currentUrl: ""

            property bool settingbut: false

            customFooterActions: [
                Kirigami.Action {
                    text: qsTr("Open AI page")
                    icon.name: "internet-web-browser"
                    visible: aiCustomErrorDialog3.currentUrl === "" ? false : true
                    onTriggered: {
                        Qt.openUrlExternally(aiCustomErrorDialog3.currentUrl)
                        aiCustomErrorDialog3.close()
                    }
                },
                Kirigami.Action {
                    text: qsTr("Open settings")
                    icon.name: "settings"
                    visible: aiCustomErrorDialog3.settingbut
                    onTriggered: {
                        aiCustomErrorDialog3.close()
                        modalWindow2.forceClose = true
                        modalWindow2.close()
                        backend.cancel()
                        settingsWindow.show()
                    }
                },
                Kirigami.Action {
                    text: qsTr("Continue")
                    icon.name: "dialog-ok"
                    onTriggered: aiCustomErrorDialog3.close()
                }
            ]
        }

        Kirigami.PromptDialog {
            id: killDialog3
            parent: modalWindow2.contentItem
            title: qsTr("Cancel")
            subtitle: qsTr("Do you want to cancel the installation process?")
            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
            onAccepted: {
                modalWindow2.forceClose = true
                modalWindow2.close()
                modalWindow2.forceClose = false
                backend.cancel()
            }
        }

        Kirigami.PromptDialog {
            id: aiErrorDialog3
            parent: modalWindow2.contentItem
            title: qsTr("AI Error")
            subtitle: ""
            standardButtons: Kirigami.Dialog.Ok
        }


        Kirigami.PromptDialog {
            id: ai402ErrorDialog2
            title: qsTr("AI limit reached")
            parent: modalWindow2.contentItem
            subtitle: ""
            standardButtons: Kirigami.Dialog.NoButton

            property string currentUrl: ""
            property string currentName: ""

            customFooterActions: [
                Kirigami.Action {
                    text: qsTr("Open ") + ai402ErrorDialog2.currentName
                    icon.name: "internet-web-browser"
                    onTriggered: {
                        Qt.openUrlExternally(ai402ErrorDialog2.currentUrl)
                        ai402ErrorDialog2.close()
                    }
                },
                Kirigami.Action {
                    text: qsTr("Continue without AI")
                    icon.name: "dialog-ok"
                    onTriggered: ai402ErrorDialog2.close()
                }
            ]
        }

        Platform.FileDialog {
            id: iconFileDialog
            folder: "file://" + modalWindow.packageRoot
            title: qsTr("Select icon file")
            nameFilters: ["Image files (*.png *.jpg *.jpeg *.svg *.ico)", "All files (*)"]
            onAccepted: { var path = file.toString().replace("file://", "")
                modalWindow2.customIconPath = path
                customIconPreview.source = file }
        }

        Rectangle {
            anchors.fill: parent
            color: mainWindow.clrBg

            MouseArea {
                anchors.fill: parent
                onClicked: parent.forceActiveFocus()
            }

            Flickable {
                id: modal2Flickable
                anchors.fill: parent
                anchors.margins: 12
                anchors.bottomMargin: 47
                clip: true
                contentWidth: width
                contentHeight: modalColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                TapHandler {
                    onTapped: {
                        aiNameField.focus = false
                        aiDescField.focus = false
                        aiCategoryField.focus = false
                    }
                }


                Column {
                    width: parent.parent.width
                    spacing: 12
                    Rectangle {
                        width: parent.width
                        height: aiAppStatusRow.implicitHeight + 10
                        color: mainWindow.clrBgMid
                        radius: 6
                        visible: backend.aiAppimageAnalyzing || backend.aiAppDescription !== ""
                        Row {
                            id: aiAppStatusRow
                            anchors.centerIn: parent
                            spacing: 8
                            Canvas {
                                id: modal2Spinner
                                width: 10
                                height: 10
                                anchors.verticalCenter: parent.verticalCenter
                                visible: backend.aiAppimageAnalyzing
                                property real angle: 0

                                NumberAnimation on angle {
                                    from: 0
                                    to: 360
                                    duration: 900
                                    loops: Animation.Infinite
                                    running: modal2Spinner.visible
                                }

                                onAngleChanged: requestPaint()
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.strokeStyle = mainWindow.lightMode ? "#666565" : "#aaaaaa"
                                    ctx.lineWidth = 1.8
                                    ctx.lineCap = "round"
                                    var cx = width/2, cy = height/2, r = width/2 - 1.2
                                    var s = (angle - 90) * Math.PI / 180
                                    var e = s + 240 * Math.PI / 180
                                    ctx.beginPath()
                                    ctx.arc(cx, cy, r, s, e)
                                    ctx.stroke()
                                }
                            }
                            Text {
                                color: backend.aiAppimageAnalyzing ? (mainWindow.lightMode ? "#666565" : "#aaaaaa") : (mainWindow.lightMode ? "#08631f" : "#50fa7b")
                                font.pixelSize: 12
                                text: backend.aiAppimageAnalyzing ? qsTr("AI is analyzing the AppImage...") : qsTr("✔ AI metadata applied")
                                verticalAlignment: Text.AlignVCenter
                                height: 24
                            }
                        }
                    }
                    Text {
                        color: mainWindow.lightMode ? "#1a1a2e" : mainWindow.clrText
                        text: qsTr("Icon:")
                        font.bold: true
                    }
                    Row {
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            width: 80
                            height: 80
                            color: mainWindow.clrBgAlt
                            radius: 8
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                source: "application-x-executable"
                                width: 56
                                height: 56
                                visible: modalWindow2.customIconPath === ""
                            }
                            Image {
                                id: customIconPreview
                                anchors.centerIn: parent
                                width: 64
                                height: 64
                                fillMode: Image.PreserveAspectFit
                                visible: modalWindow2.customIconPath !== ""
                            }
                        }
                        Column {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Text { color: mainWindow.clrMuted
                                font.pixelSize: 11
                                text: modalWindow2.customIconPath === "" ? qsTr("Default system icon (application-x-executable)") :
                                    modalWindow2.customIconPath.substring(modalWindow2.customIconPath.lastIndexOf('/') + 1)
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                width: 340
                                elide: Text.ElideMiddle
                            }
                            Row { spacing: 8
                                Rectangle {
                                    width: Math.max(100, chooseIconText.implicitWidth + 24)
                                    height: 34
                                    radius: 8
                                    color: chooseIconMa.containsMouse ? mainWindow.clrBgButtonHover : mainWindow.clrBgHover
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        id: chooseIconText
                                        anchors.centerIn: parent
                                        text: qsTr("Choose icon…")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "white"
                                    }
                                    MouseArea {
                                        id: chooseIconMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: iconFileDialog.open()
                                    }
                                }
                                Rectangle {
                                    width: 60
                                    height: 34
                                    radius: 8
                                    visible: modalWindow2.customIconPath !== ""
                                    color: resetIconMa.containsMouse ? mainWindow.clrBgButtonHover : mainWindow.clrBgHover
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: qsTr("Reset")
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "white"
                                    }
                                    MouseArea {
                                        id: resetIconMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            modalWindow2.customIconPath = ""
                                            customIconPreview.source = ""
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                        text: qsTr("Application name:")
                        font.bold: true
                    }
                    Rectangle {
                        width: parent.width
                        height: 36
                        radius: 8
                        color: mainWindow.clrBgAlt
                        border.width: 1.5
                        border.color: aiNameField.activeFocus ? mainWindow.clrAccentBorder : aiNameHover.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        TextField {
                            id: aiNameField
                            anchors.fill: parent
                            anchors.margins: 2
                            placeholderText: qsTr("Enter app name...")
                            color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                            background: Item {}
                        }

                        MouseArea {
                            id: aiNameHover
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                            cursorShape: Qt.IBeamCursor
                            z: 10
                        }
                    }
                    Text {
                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                        text: qsTr("Description:")
                        font.bold: true
                    }
                    Row {
                        width: parent.width
                        spacing: 8
                        Rectangle {
                            width: !backend.hasAiAccess ? parent.width : parent.width - regenAiDescBtn.width - resetAiDescBtn.width - 16
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            border.width: 1.5
                            border.color: aiDescField.activeFocus ? mainWindow.clrAccentBorder : aiDescHover.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            TextField {
                                id: aiDescField
                                anchors.fill: parent
                                anchors.margins: 2
                                placeholderText: qsTr("Short description (one sentence)...")
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                background: Item {}
                            }

                            MouseArea {
                                id: aiDescHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                                z: 10
                            }
                        }
                        Rectangle {
                            id: regenAiDescBtn
                            width: 36
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            visible: backend.hasAiAccess
                            opacity: backend.aiAppimageAnalyzing ? 0.4 : 1.0
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1.5
                                border.color: regenAiDescMa.containsMouse && !backend.aiAppimageAnalyzing ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "↺"
                                font.pixelSize: 15
                                color: regenAiDescMa.containsMouse && !backend.aiAppimageAnalyzing ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: regenAiDescMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: backend.aiAppimageAnalyzing ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !backend.aiAppimageAnalyzing
                                onClicked: backend.regenerateAppimageDescription()
                            }

                            ToolTip.text: qsTr("Regenerate description with AI")
                            ToolTip.visible: regenAiDescMa.containsMouse
                            ToolTip.delay: 500
                        }

                        Rectangle {
                            id: resetAiDescBtn
                            width: 36
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            visible: backend.hasAiAccess
                            opacity: backend.aiAppimageAnalyzing ? 0.4 : 1.0

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1.5
                                border.color: resetAiDescMa.containsMouse && !backend.aiAppimageAnalyzing ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "⟲"
                                font.pixelSize: 15
                                color: resetAiDescMa.containsMouse && !backend.aiAppimageAnalyzing ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: resetAiDescMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: backend.aiAppimageAnalyzing ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: !backend.aiAppimageAnalyzing
                                onClicked: backend.resetAppimageDescriptionToFirst()
                            }

                            ToolTip.text: qsTr("Reset to first AI description")
                            ToolTip.visible: resetAiDescMa.containsMouse
                            ToolTip.delay: 500
                        }
                    }
                    Text {
                        color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                        text: qsTr("Category (freedesktop):")
                        font.bold: true
                    }
                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: parent.width - aiCategoryBtn.width - 8
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt
                            border.width: 1.5
                            border.color: aiCategoryField.activeFocus ? mainWindow.clrAccentBorder : aiCategoryHover.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            TextField {
                                id: aiCategoryField
                                anchors.fill: parent
                                anchors.margins: 2
                                placeholderText: "e.g. Network;WebBrowser;"
                                color: mainWindow.lightMode && !backend.systemColors ? "#1a1a2e" : mainWindow.clrText
                                background: Item {}
                            }

                            MouseArea {
                                id: aiCategoryHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                                z: 10
                            }
                        }

                        Rectangle {
                            id: aiCategoryBtn
                            width: 36
                            height: 36
                            radius: 8
                            color: mainWindow.clrBgAlt

                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: "transparent"
                                border.width: 1.5
                                border.color: aiCategoryMa.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                                Behavior on border.color { ColorAnimation { duration: 100 } }
                            }

                            Item {
                                anchors.centerIn: parent
                                width: 14
                                height: 10

                                Item {
                                    width: parent.width
                                    height: parent.height
                                    y: aiCategoryMenu.visible ? 0 : -2
                                    Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

                                    Rectangle {
                                        width: 2
                                        height: 8
                                        radius: 1
                                        color: aiCategoryMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                        x: 3
                                        y: aiCategoryMenu.visible ? 1 : 3
                                        transformOrigin: Item.Center
                                        rotation: aiCategoryMenu.visible ? -45 : -135
                                        Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }

                                    Rectangle {
                                        width: 2
                                        height: 8
                                        radius: 1
                                        color: aiCategoryMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                        x: 9
                                        y: aiCategoryMenu.visible ? 1 : 3
                                        transformOrigin: Item.Center
                                        rotation: aiCategoryMenu.visible ? 45 : 135
                                        Behavior on rotation { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                    }
                                }
                            }

                            MouseArea {
                                id: aiCategoryMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: aiCategoryMenu.visible ? aiCategoryMenu.close() : aiCategoryMenu.open()
                            }

                            Popup {
                                id: aiCategoryMenu
                                y: -253
                                x: -144
                                width: 180
                                height: Math.min(250, aiCategoryListView.contentHeight + 8)
                                padding: 4

                                background: Rectangle {
                                    color: mainWindow.clrBgMid
                                    radius: 8
                                    border.color: mainWindow.clrBorderAlt
                                    border.width: 1
                                }

                                contentItem: ListView {
                                    id: aiCategoryListView
                                    clip: true
                                    boundsBehavior: Flickable.StopAtBounds
                                    model: [
                                        "Audio;Video;", "Audio;", "Video;", "Development;",
                                        "Education;", "Game;", "Graphics;", "Network;",
                                        "Network;WebBrowser;", "Office;", "Science;", "Settings;",
                                        "System;", "System;FileManager;", "System;TerminalEmulator;",
                                        "Utility;", "Utility;TextEditor;"
                                    ]

                                    ScrollBar.vertical: ScrollBar {
                                        id: aiCatScroller
                                        width: 4
                                        policy: ScrollBar.AsNeeded
                                        hoverEnabled: true
                                        minimumSize: aiCategoryListView.height > 0 ? 30 / aiCategoryListView.height : 0.05

                                        anchors.right: parent.right
                                        anchors.rightMargin: 1
                                        anchors.top: parent.top
                                        anchors.bottom: parent.bottom

                                        property bool keepVisible: false

                                        Timer {
                                            id: hideDelayTimer4
                                            interval: 1500
                                            onTriggered: aiCatScroller.keepVisible = false
                                        }

                                        Connections {
                                            target: aiCategoryListView
                                            function onMovingChanged() {
                                                if (aiCategoryListView.moving) {
                                                    aiCatScroller.keepVisible = true
                                                    hideDelayTimer4.stop()
                                                } else {
                                                    hideDelayTimer4.restart()
                                                }
                                            }
                                        }

                                        opacity: (aiCategoryListView.moving || aiCategoryListView.flicking || active || hovered || keepVisible) ? 1.0 : 0.0
                                        Behavior on opacity { NumberAnimation { duration: 250 } }

                                        contentItem: Rectangle {
                                            implicitWidth: 4
                                            radius: 2
                                            color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                                            opacity: aiCatScroller.pressed ? 0.7 : 0.4
                                            Behavior on opacity { NumberAnimation { duration: 150 } }
                                        }
                                        background: Item {}
                                    }

                                    delegate: Rectangle {
                                        width: aiCategoryListView.width
                                        height: 32
                                        radius: 6
                                        color: aiCatItemMa.containsMouse ? mainWindow.clrBgHover : "transparent"
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            text: modelData
                                            color: aiCategoryField.text === modelData ? mainWindow.clrAccentHover : mainWindow.clrText
                                            font.pixelSize: 12
                                        }
                                        MouseArea {
                                            id: aiCatItemMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                aiCategoryField.text = modelData
                                                aiCategoryMenu.close()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        color: mainWindow.clrSubtle
                        font.pixelSize: 10
                        text: qsTr("Format: PrimaryCategory;ExtraCategory;  (e.g. Network;WebBrowser;)")
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        width: parent.width
                    }
                }
            }
            Item {
                id: footer2
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 47
                z: 10

                FastBlur {
                    anchors.fill: parent
                    radius: 64
                    source: ShaderEffectSource {
                        sourceItem: modal2Flickable
                        sourceRect: Qt.rect(0, modal2Flickable.height - footer2.height, footer2.width, footer2.height)
                        live: true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(mainWindow.clrBg.r, mainWindow.clrBg.g, mainWindow.clrBg.b, 0.6)
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Qt.rgba(mainWindow.clrBorder.r, mainWindow.clrBorder.g, mainWindow.clrBorder.b, 0.8)
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: Math.max(80, installText2.implicitWidth + 24)
                        height: 36
                        radius: 8
                        color: mainWindow.clrBgAlt
                        opacity: backend.aiAnalyzing ? 0.4 : 1.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1.5
                            border.color: installMa2.containsMouse && !backend.aiAnalyzing ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 100 } }
                        }
                        Text {
                            id: installText2
                            anchors.centerIn: parent
                            text: qsTr("Install")
                            font.pixelSize: 13
                            color: installMa2.containsMouse && !backend.aiAnalyzing ? mainWindow.clrAccentHover : mainWindow.clrText
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea {
                            id: installMa2

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: backend.aiAnalyzing ? Qt.ArrowCursor : Qt.PointingHandCursor
                            enabled: !backend.aiAnalyzing
                            onClicked: {
                                modalWindow2.forceClose = true
                                modalWindow2.close()
                                modalWindow2.forceClose = false
                                backend.confirmAppimageInstall(
                                    aiNameField.text.trim(),
                                    aiDescField.text.trim(),
                                    aiCategoryField.text.trim(),
                                    modalWindow2.customIconPath
                                )
                            }
                        }
                    }

                    Rectangle {
                        width: Math.max(80, cancelText2.implicitWidth + 24)
                        height: 36
                        radius: 8
                        color: mainWindow.clrBgAlt

                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: "transparent"
                            border.width: 1.5
                            border.color: cancelMa2.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder

                            Behavior on border.color { ColorAnimation { duration: 95 } }
                        }
                        Text {
                            id: cancelText2
                            anchors.centerIn: parent

                            text: qsTr("Cancel")

                            font.pixelSize: 13
                            color: cancelMa2.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrText
                            Behavior on color { ColorAnimation { duration: 95 } }
                        }
                        MouseArea {
                            id: cancelMa2

                            anchors.fill: parent

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.rmAlltempfiles()
                                modalWindow2.forceClose = true
                                modalWindow2.close()
                                modalWindow2.forceClose = false
                                mainWindow.installCancelled = true
                                backend.cancel()
                            }
                        }
                    }
                }
            }
        }
        ScrollBar {
            id: modal2ScrollerV
            parent: modalWindow2.contentItem
            x: modalWindow2.width - width - 2
            y: modal2Flickable.y
            height: modal2Flickable.height
            position: modal2Flickable.visibleArea.yPosition
            size: modal2Flickable.visibleArea.heightRatio
            orientation: Qt.Vertical
            width: 4
            policy: ScrollBar.AsNeeded
            hoverEnabled: true
            minimumSize: modal2Flickable.height > 0 ? 30 / modal2Flickable.height : 0.05

            property bool keepVisible: false

            Timer {
                id: modal2HideDelayTimer
                interval: 1500
                onTriggered: modal2ScrollerV.keepVisible = false
            }

            Connections {
                target: modal2Flickable
                ignoreUnknownSignals: true
                function onMovingChanged() {
                    if (modal2Flickable.moving) {
                        modal2ScrollerV.keepVisible = true
                        modal2HideDelayTimer.stop()
                    } else {
                        modal2HideDelayTimer.restart()
                    }
                }
            }

            readonly property bool isMoving: modal2Flickable.moving || modal2Flickable.flicking
            opacity: (isMoving || active || hovered || keepVisible) ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 250 } }

            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                opacity: modal2ScrollerV.pressed ? 0.7 : 0.4
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            background: Item {}
        }
    }

    /* Window that appers when installing .deb and .rpm packages
      You can edit dependensies of installed package with it */

    Window {
        id: editDependenciesWindow
        title: qsTr("Edit dependencies")
        width: 420
        height: 450
        minimumWidth: 420
        minimumHeight: 450
        maximumWidth: 420
        maximumHeight: 450
        modality: Qt.ApplicationModal
        visible: false
        color: mainWindow.clrBg

        property bool hasChanges: false
        property bool forceClose: false

        ListModel { id: depsListModel }

        function buildResult() {
            var grouped = {}
            for (var i = 0; i < depsListModel.count; i++) {
                var item = depsListModel.get(i)
                if (!grouped[item.section]) grouped[item.section] = []
                grouped[item.section].push({ o: item.original, t: item.translated })
            }
            var result = []
            for (var key in grouped) {
                result.push({ key: key, value: JSON.stringify(grouped[key]) })
            }
            return result
        }

        // Ctrl+A — selects all text in all fields via clipboard
        Shortcut {
            sequence: "Ctrl+A"
            context: Qt.WindowShortcut
            onActivated: {
                var allText = ""
                for (var i = 0; i < depsListModel.count; i++) {
                    var item = depsListModel.get(i)
                    allText += item.original + " → " + item.translated + "\n"
                }
                backend.copyToClipboard(allText)
                selectAllFlash.visible = true
                selectAllFlashTimer.restart()
            }
        }

        onClosing: function(closeEvent) {
            if (!forceClose && hasChanges) {
                closeEvent.accepted = false
                Qt.callLater(function() { depsUnsavedDialog.open() })
            } else {
                backend.cancel()
            }
        }

        Kirigami.PromptDialog {
            id: depsUnsavedDialog
            parent: editDependenciesWindow.contentItem
            title: qsTr("Unsaved changes")
            subtitle: qsTr("You have edited dependencies. Discard changes and cancel?")
            standardButtons: Kirigami.Dialog.NoButton
            customFooterActions: [
                Kirigami.Action {
                    text: qsTr("Discard & Cancel")
                    icon.name: "dialog-cancel"
                    onTriggered: {
                        depsUnsavedDialog.close()
                        backend.cancel()
                        editDependenciesWindow.forceClose = true
                        editDependenciesWindow.visible = false
                    }
                },
                Kirigami.Action {
                    text: qsTr("Keep editing")
                    icon.name: "dialog-ok"
                    onTriggered: depsUnsavedDialog.close()
                }
            ]
        }

        Rectangle {
            anchors.fill: parent
            color: mainWindow.clrBg

            // Flash overlay on Ctrl+A
            Rectangle {
                id: selectAllFlash
                anchors.fill: depList
                color: Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.12)
                visible: false
                z: 5
                Timer {
                    id: selectAllFlashTimer
                    interval: 350
                    onTriggered: selectAllFlash.visible = false
                }
            }

            // Column header (fixed at the top)
            Rectangle {
                id: colHeader
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 32
                color: mainWindow.clrBg
                z: 10

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 6

                    Text {
                        height: parent.height
                        text: qsTr("Translated")
                        font.pixelSize: 11
                        color: mainWindow.clrSubtle
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        height: parent.height
                        text: qsTr("• %1 dependencies").arg(depsListModel.count)
                        font.pixelSize: 11
                        color: mainWindow.clrSubtle
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    height: parent.height
                    text: qsTr("Ctrl+A to copy all").arg(depsListModel.count)
                    font.pixelSize: 11
                    color: mainWindow.clrSubtle
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: mainWindow.clrBorder
                }
            }

            // Sticky section header
            Rectangle {
                id: stickySectionHeader
                anchors.top: colHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34
                color: mainWindow.clrBg
                z: 9
                visible: depList.currentSection !== "" && depList.contentY > 0

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Text {
                        text: depList.currentSection
                        font.pixelSize: 12
                        font.bold: true
                        color: mainWindow.clrText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 18; height: 18
                        radius: 5
                        anchors.verticalCenter: parent.verticalCenter
                        color: stickyAddMa.containsMouse
                               ? Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.22)
                               : "transparent"
                        border.width: 1
                        border.color: stickyAddMa.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            font.pixelSize: 14
                            color: stickyAddMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: stickyAddMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var targetSection = stickySectionHeader.displaySection
                                if (!targetSection) return
                                var insertAt = -1
                                for (var i = 0; i < depsListModel.count; i++) {
                                    if (depsListModel.get(i).section === targetSection)
                                        insertAt = i
                                }
                                var newIndex
                                if (insertAt === -1) {
                                    depsListModel.append({ section: targetSection, original: "", translated: "" })
                                    newIndex = depsListModel.count - 1
                                } else {
                                    depsListModel.insert(insertAt + 1, { section: targetSection, original: "", translated: "" })
                                    newIndex = insertAt + 1
                                }
                                editDependenciesWindow.hasChanges = true
                                Qt.callLater(function() {
                                    depList.positionViewAtIndex(newIndex, ListView.Contain)
                                    depList.pendingFocusIndex = newIndex
                                })
                            }
                        }

                        ToolTip.text: qsTr("Add to %1").arg(stickySectionHeader.displaySection)
                        ToolTip.visible: stickyAddMa.containsMouse
                        ToolTip.delay: 400
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: mainWindow.clrBorder
                    opacity: 0.5
                }
            }

            ListView {
                id: depList
                anchors.top: colHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: dependenciesFooter.top
                anchors.bottomMargin: 0
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: depsListModel
                property int pendingFocusIndex: -1
                section.property: "section"
                section.criteria: ViewSection.FullString
                section.labelPositioning: ViewSection.InlineLabels

                ScrollBar.vertical: ScrollBar {
                    id: depsScrollerV
                    width: 4
                    policy: ScrollBar.AsNeeded
                    hoverEnabled: true
                    minimumSize: depList.height > 0 ? 30 / depList.height : 0.05
                    topPadding: 36
                    anchors.right: parent.right
                    anchors.rightMargin: 1

                    opacity: (depList.moving || depList.flicking || active || hovered || keepVisible) ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 250 } }

                    property bool keepVisible: false

                    Timer {
                        id: depsHideDelayTimer
                        interval: 1500
                        onTriggered: depsScrollerV.keepVisible = false
                    }

                    Connections {
                        target: depList
                        function onMovingChanged() {
                            if (depList.moving) {
                                depsScrollerV.keepVisible = true
                                depsHideDelayTimer.stop()
                            } else {
                                depsHideDelayTimer.restart()
                            }
                        }
                    }

                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: mainWindow.lightMode ? Qt.darker(mainWindow.clrBorder) : mainWindow.clrScrollbar
                        opacity: depsScrollerV.pressed ? 0.7 : 0.4
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    background: Item {}
                }

                footer: Item {
                    width: depList.width
                    height: 42

                    Rectangle {
                        id: addNewDepBtn
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.max(80, addNewDepRow.implicitWidth + 24)
                        height: 26
                        radius: 7
                        color: addNewDepMa.containsMouse
                               ? Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.18)
                               : mainWindow.clrBgAlt
                        border.width: 1.5
                        border.color: addNewDepMa.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                        Behavior on color        { ColorAnimation { duration: 100 } }
                        Behavior on border.color { ColorAnimation { duration: 100 } }

                        Row {
                            id: addNewDepRow
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                text: "+"
                                font.pixelSize: 14
                                color: addNewDepMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            Text {
                                text: qsTr("Add new")
                                font.pixelSize: 11
                                color: addNewDepMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                        }

                        MouseArea {
                            id: addNewDepMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var btnGlobalY = addNewDepBtn.mapToItem(null, 0, 0).y
                                var popupH = 9 * 32 + 8
                                var screenH = editDependenciesWindow.height
                                var spaceBelow = screenH - btnGlobalY - addNewDepBtn.height
                                addNewDepPopup.openUpward = spaceBelow < popupH
                                addNewDepPopup.open()
                            }
                        }

                        Popup {
                            id: addNewDepPopup
                            property bool openUpward: true
                            width: 180
                            padding: 4
                            x: addNewDepBtn.width - width
                            y: openUpward ? -(implicitHeight + 4) : (addNewDepBtn.height + 4)
                            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

                            Connections {
                                target: depList
                                function onMovementStarted() { addNewDepPopup.close() }
                            }

                            background: Rectangle {
                                color: mainWindow.clrBgMid
                                radius: 8
                                border.color: mainWindow.clrBorderAlt
                                border.width: 1
                            }

                            contentItem: Column {
                                spacing: 0
                                Repeater {
                                    model: [
                                        { section: "Depends",     label: "Depends"     },
                                        { section: "Recommends",  label: "Recommends"  },
                                        { section: "Suggests",    label: "Suggests"    },
                                        { section: "Pre-Depends", label: "Pre-Depends" },
                                        { section: "Replaces",    label: "Replaces"    },
                                        { section: "Conflicts",   label: "Conflicts"   },
                                        { section: "Provides",    label: "Provides"    },
                                        { section: "Breaks",      label: "Breaks"      },
                                        { section: "Enhances",    label: "Enhances"    },
                                    ]
                                    delegate: Rectangle {
                                        width: addNewDepPopup.width - 8
                                        height: 32
                                        radius: 6
                                        color: sectionItemMa.containsMouse
                                               ? Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.12)
                                               : "transparent"
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text {
                                            text: modelData.label
                                            font.pixelSize: 12
                                            color: sectionItemMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrText
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left
                                            anchors.leftMargin: 10
                                            Behavior on color { ColorAnimation { duration: 80 } }
                                        }
                                        MouseArea {
                                            id: sectionItemMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                addNewDepPopup.close()
                                                var sec = modelData.section
                                                var insertAt = -1
                                                for (var i = 0; i < depsListModel.count; i++) {
                                                    if (depsListModel.get(i).section === sec)
                                                        insertAt = i
                                                }
                                                var newIndex
                                                if (insertAt === -1) {
                                                    depsListModel.append({ section: sec, original: "", translated: "" })
                                                    newIndex = depsListModel.count - 1
                                                } else {
                                                    depsListModel.insert(insertAt + 1, { section: sec, original: "", translated: "" })
                                                    newIndex = insertAt + 1
                                                }
                                                editDependenciesWindow.hasChanges = true
                                                Qt.callLater(function() {
                                                    depList.positionViewAtIndex(newIndex, ListView.Contain)
                                                    depList.pendingFocusIndex = newIndex
                                                })
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                

                section.delegate: Rectangle {
                    width: depList.width
                    height: 34
                    color: mainWindow.clrBg
                    z: 2

                    // ← FIX: save in a local variable
                    property string localSection: section

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Text {
                            text: section
                            font.pixelSize: 12
                            font.bold: true
                            color: mainWindow.clrText
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Rectangle {
                            width: 18; height: 18
                            radius: 5
                            anchors.verticalCenter: parent.verticalCenter
                            color: sectionAddMa.containsMouse
                                   ? Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.22)
                                   : "transparent"
                            border.width: 1
                            border.color: sectionAddMa.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                            Behavior on color        { ColorAnimation { duration: 100 } }
                            Behavior on border.color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.centerIn: parent
                                text: "+"
                                font.pixelSize: 14
                                color: sectionAddMa.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrMuted
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }

                            MouseArea {
                                id: sectionAddMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // ← FIX: read localSection instead of parent.parent.parent.sectionName
                                    var targetSection = localSection
                                    var insertAt = -1
                                    for (var i = 0; i < depsListModel.count; i++) {
                                        if (depsListModel.get(i).section === targetSection)
                                            insertAt = i
                                    }
                                    var newIndex
                                    if (insertAt === -1) {
                                        depsListModel.append({ section: targetSection, original: "", translated: "" })
                                        newIndex = depsListModel.count - 1
                                    } else {
                                        depsListModel.insert(insertAt + 1, { section: targetSection, original: "", translated: "" })
                                        newIndex = insertAt + 1
                                    }
                                    editDependenciesWindow.hasChanges = true
                                    Qt.callLater(function() {
                                        depList.positionViewAtIndex(newIndex, ListView.Contain)
                                        depList.pendingFocusIndex = newIndex
                                    })
                                }
                            }
                            ToolTip.text: qsTr("Add to %1").arg(section)
                            ToolTip.visible: sectionAddMa.containsMouse
                            ToolTip.delay: 400
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: mainWindow.clrBorder
                        opacity: 0.5
                    }
                }

                Timer {
                    id: focusTimer
                    interval: 100
                    repeat: false
                    property int targetIndex: -1
                    onTriggered: {
                        if (targetIndex < 0) return
                        depList.currentIndex = targetIndex
                        var item = depList.currentItem
                        if (item) {
                            // forceActiveFocus on the whole item — the cursor will land in the translated field
                            var tf = item.findChild ? item.findChild("translatedEdit") : null
                            if (tf) tf.forceActiveFocus()
                        }
                    }
                }

                delegate: Rectangle {
                    id: delegateRoot
                    width: depList.width
                    height: 36
                    color: "transparent"

                    // focus on tInput when adding a new line
                    Component.onCompleted: {
                        if (depList.pendingFocusIndex === index) {
                            depList.pendingFocusIndex = -1
                            origInput.forceActiveFocus()
                            origInput.selectAll()
                        }
                    }

                    // separator
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        height: 1
                        color: mainWindow.clrBorder
                        opacity: 0.25
                    }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 2

                        // Original on the left
                        Rectangle {
                            width: (parent.width - 24 - 16 - 4 - 4) / 2
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 6
                            // edited only if it is a new line (original is empty upon creation)
                            property bool isNew: model.original === "" && model.translated === ""
                            color: origInput.activeFocus && isNew
                                   ? Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.08)
                                   : "transparent"
                            border.width: 1
                            border.color: origInput.activeFocus && isNew ? mainWindow.clrAccentBorder
                                          : origHover.containsMouse && isNew ? mainWindow.clrBorder
                                          : "transparent"
                            Behavior on border.color { ColorAnimation { duration: 95 } }

                            TextEdit {
                                id: origInput
                                anchors.fill: parent
                                anchors.margins: 4
                                text: model.original
                                color: mainWindow.clrSubtle
                                font.pixelSize: 12
                                font.family: "monospace"
                                readOnly: false
                                selectByMouse: true
                                verticalAlignment: TextEdit.AlignVCenter
                                wrapMode: TextEdit.NoWrap
                                clip: true
                                selectedTextColor: color
                                selectionColor: Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.35)
                                cursorVisible: activeFocus && !readOnly

                                onTextEdited: {
                                    depsListModel.setProperty(index, "original", text)
                                    editDependenciesWindow.hasChanges = true
                                }
                            }

                            MouseArea {
                                id: origHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: origInput.readOnly ? Qt.IBeamCursor : Qt.IBeamCursor
                            }
                        }

                        // arrow
                        Text {
                            width: 24
                            height: parent.height
                            text: "→"
                            color: mainWindow.clrAccentFocus
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Translation on the right
                        Rectangle {
                            width: (parent.width - 24 - 16 - 4 - 4) / 2
                            height: 28
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 6
                            color: tInput.activeFocus
                                   ? Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.08)
                                   : "transparent"
                            border.width: 1
                            border.color: tInput.activeFocus ? mainWindow.clrAccentBorder
                                          : inputHover.containsMouse ? mainWindow.clrBorder
                                          : "transparent"
                            Behavior on border.color { ColorAnimation { duration: 95 } }

                            TextEdit {
                                id: tInput
                                anchors.fill: parent
                                anchors.margins: 4
                                text: model.translated
                                color: mainWindow.clrText
                                font.pixelSize: 12
                                font.family: "monospace"
                                selectByMouse: true
                                verticalAlignment: TextEdit.AlignVCenter
                                wrapMode: TextEdit.NoWrap
                                clip: true
                                selectedTextColor: color
                                selectionColor: Qt.rgba(mainWindow.clrAccent.r, mainWindow.clrAccent.g, mainWindow.clrAccent.b, 0.35)

                                onTextChanged: {
                                    if (text !== model.translated) {
                                        depsListModel.setProperty(index, "translated", text)
                                        editDependenciesWindow.hasChanges = true
                                    }
                                }
                            }

                            MouseArea {
                                id: inputHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.IBeamCursor
                            }
                        }

                        // space between translation and button
                        Item { width: 4; height: 1 }

                        // button − deletion
                        Rectangle {
                            width: 16
                            height: 16
                            radius: 4
                            anchors.verticalCenter: parent.verticalCenter
                            color: deleteMa.containsMouse
                                   ? Qt.rgba(1, 0.2, 0.2, 0.22)
                                   : "transparent"
                            border.width: 1
                            border.color: deleteMa.containsMouse ? "#ff5555" : mainWindow.clrBorder
                            Behavior on color        { ColorAnimation { duration: 80 } }
                            Behavior on border.color { ColorAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: "−"
                                font.pixelSize: 13
                                color: deleteMa.containsMouse ? "#ff5555" : mainWindow.clrMuted
                                Behavior on color { ColorAnimation { duration: 80 } }
                            }

                            MouseArea {
                                id: deleteMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    depsListModel.remove(index)
                                    editDependenciesWindow.hasChanges = true
                                }
                            }

                            ToolTip.text: qsTr("Remove")
                            ToolTip.visible: deleteMa.containsMouse
                            ToolTip.delay: 400
                        }
                    }
                }
            }

            Item {
                id: dependenciesFooter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 47
                z: 10

                FastBlur {
                    anchors.fill: parent
                    radius: 64
                    source: ShaderEffectSource {
                        sourceItem: depList
                        sourceRect: Qt.rect(0, depList.height - dependenciesFooter.height, dependenciesFooter.width, dependenciesFooter.height)
                        live: true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Qt.rgba(mainWindow.clrBg.r, mainWindow.clrBg.g, mainWindow.clrBg.b, 0.6)
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: mainWindow.clrBorder
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12

                    Rectangle {
                        width: Math.max(80, acceptTxt.implicitWidth + 24); height: 36; radius: 8
                        color: mainWindow.clrBgAlt
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: "transparent"; border.width: 1.5
                            border.color: acceptMa1.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                            Behavior on border.color { ColorAnimation { duration: 95 } }
                        }
                        Text {
                            id: acceptTxt
                            anchors.centerIn: parent; text: qsTr("Accept")
                            font.pixelSize: 13
                            color: acceptMa1.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrText
                            Behavior on color { ColorAnimation { duration: 95 } }
                        }
                        MouseArea {
                            id: acceptMa1; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.saveDepsEditResult(editDependenciesWindow.buildResult())
                                editDependenciesWindow.forceClose = true
                                editDependenciesWindow.visible = false
                            }
                        }
                    }

                    Rectangle {
                        width: Math.max(80, skipTxt.implicitWidth + 24); height: 36; radius: 8
                        color: mainWindow.clrBgAlt
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: "transparent"; border.width: 1.5
                            border.color: skipMa1.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                            Behavior on border.color { ColorAnimation { duration: 95 } }
                        }
                        Text {
                            id: skipTxt
                            anchors.centerIn: parent; text: qsTr("Skip")
                            font.pixelSize: 13
                            color: skipMa1.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrText
                            Behavior on color { ColorAnimation { duration: 95 } }
                        }
                        MouseArea {
                            id: skipMa1; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                // Save empty result — skip translation
                                backend.saveDepsEditResult([])
                                editDependenciesWindow.forceClose = true
                                editDependenciesWindow.visible = false
                            }
                        }
                        ToolTip.text: qsTr("Skip dependency translation")
                        ToolTip.visible: skipMa1.containsMouse
                        ToolTip.delay: 500
                    }

                    Rectangle {
                        width: Math.max(80, cancelTxt.implicitWidth + 24); height: 36; radius: 8
                        color: mainWindow.clrBgAlt
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: "transparent"; border.width: 1.5
                            border.color: cancelMa1.containsMouse ? mainWindow.clrAccentBorder : mainWindow.clrBorder
                            Behavior on border.color { ColorAnimation { duration: 95 } }
                        }
                        Text {
                            id: cancelTxt
                            anchors.centerIn: parent; text: qsTr("Cancel")
                            font.pixelSize: 13
                            color: cancelMa1.containsMouse ? mainWindow.clrAccentHover : mainWindow.clrText
                            Behavior on color { ColorAnimation { duration: 95 } }
                        }
                        MouseArea {
                            id: cancelMa1; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (editDependenciesWindow.hasChanges) {
                                    depsUnsavedDialog.open()
                                } else {
                                    editDependenciesWindow.forceClose = true
                                    editDependenciesWindow.visible = false
                                    backend.cancel()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MainWindow connections
    Connections {
        target: backend

        onNotificationActionClicked: function() {
            completeDialog.close()
        }

        onShowAi402ErrorDialog: function() {
            var p = backend.aiProvider
            var name = p === "gemini"      ? "Gemini"
                     : p === "openai"      ? "OpenAI"
                     : p === "huggingface" ? "HuggingFace"
                     : p === "copilot"     ? "Copilot"
                     : p === "openrouter"  ? "OpenRouter"
                     : "AI"
            var url  = p === "gemini"      ? "https://aistudio.google.com/apikey"
                     : p === "openai"      ? "https://platform.openai.com/account/billing"
                     : p === "huggingface" ? "https://huggingface.co/settings/billing"
                     : p === "copilot"     ? "https://github.com/settings/billing"
                     :                      "https://openrouter.ai/credits"

            var sub = qsTr("Your %1 account has reached its usage limit (error 402).").arg(name)

            if (modalWindow.visible) {
                ai402ErrorDialog.subtitle = sub
                ai402ErrorDialog.currentUrl = url
                ai402ErrorDialog.currentName = name
                ai402ErrorDialog.open()
            } else if (modalWindow2.visible) {
                ai402ErrorDialog2.subtitle = sub
                ai402ErrorDialog2.currentUrl = url
                ai402ErrorDialog2.currentName = name
                ai402ErrorDialog2.open()
            } else {
                ai402ErrorDialogNotModal.subtitle = sub
                ai402ErrorDialogNotModal.currentUrl = url
                ai402ErrorDialogNotModal.currentName = name
                ai402ErrorDialogNotModal.open()
            }
        }

        onExecutablesReady: function(execs) {
            if (!modalWindow.visible) return
            executableModel.clear()
            for (var i = 0; i < execs.length; i++) {
                var fp = execs[i]
                executableModel.append({ "name": fp.substring(fp.lastIndexOf('/') + 1), "path": fp })
            }
            if (execs.length > 0) {
                executableList.currentIndex = 0
                if (!backend.hasAiAccess) backend.executable = execs[0]
            }
            if (backend.hasAiAccess)
                backend.analyzeWithAI(backend.getExtractedDir(), backend.archiveLocation, "")
            else if (execs.length > 0)
                backend.executable = execs[0]
        }

        onIconsReady: function(icons) {
            if (!modalWindow.visible) return
            for (var j = 0; j < icons.length; j++) {
                var ip = icons[j]
                iconModel.append({ "name": ip.substring(ip.lastIndexOf('/') + 1), "path": ip })
            }
            if (icons.length > 0) {
                iconGrid.currentIndex = 1
                backend.iconPath = icons[0]
            }
        }

        onShowUnknownError: function() {
            mainWindow.installSuccess = false
            unknownErrorDialog.open()
        }

        onShowCompleteDialog: function() {
            backend.rmAlltempfiles()
            mainWindow.installSuccess = true
            completeDialog.open()
            if (!mainWindow.anyWindowFocused && mainWindow.notificationsEnabled)
                backend.sendDesktopNotification("success")
                mainWindow.installSuccess = false
            Qt.callLater(consoleListView.positionViewAtEnd)
        }

        onShowErrorDialog: function() {
            backend.rmAlltempfiles()
            mainWindow.installFailed = true
            errorDialog.open()
            if (!mainWindow.anyWindowFocused && mainWindow.notificationsEnabled)
                backend.sendDesktopNotification("error")
            Qt.callLater(consoleListView.positionViewAtEnd)
        }

        onShowAiAuthErrorDialog: function(packagePath, isAppimage) {
            aiAuthErrorDialog.open()
        }

        onShowDepsEditWindow: function(deps) {
            depsListModel.clear()

            var sectionOrder = ["Depends", "Pre-Depends", "Recommends", "Suggests",
                                "Enhances", "Breaks", "Conflicts", "Replaces", "Provides"]

            var buckets = {}
            for (var s = 0; s < sectionOrder.length; s++)
                buckets[sectionOrder[s]] = []

            for (var i = 0; i < deps.length; i++) {
                var section = deps[i].key
                var rawValue = deps[i].value
                if (typeof rawValue !== "string" || rawValue === "") continue
                try {
                    var pairs = JSON.parse(rawValue)
                    if (!Array.isArray(pairs)) continue
                    var seenOrig = {}
                    for (var j = 0; j < pairs.length; j++) {
                        var orig  = String(pairs[j].o || "")
                        var trans = String(pairs[j].t || orig)
                        if (orig !== "" && seenOrig[orig]) continue
                        if (orig !== "") seenOrig[orig] = true
                        if (orig.length > 0 || trans.length > 0) {
                            if (!buckets[section]) buckets[section] = []
                            buckets[section].push({
                                section:    section,
                                original:   orig,
                                translated: trans
                            })
                        }
                    }
                } catch(e) {
                    console.log("DepsEdit parse error:", section, e, rawValue)
                }
            }

            // Add to model in the correct section order
            for (var si = 0; si < sectionOrder.length; si++) {
                var sec = sectionOrder[si]
                var items = buckets[sec]
                if (!items || items.length === 0) continue
                for (var ki = 0; ki < items.length; ki++) {
                    depsListModel.append(items[ki])
                }
            }

            // Add sections that are not in sectionOrder (custom)
            for (var ck in buckets) {
                if (sectionOrder.indexOf(ck) === -1) {
                    var customItems = buckets[ck]
                    for (var ci = 0; ci < customItems.length; ci++)
                        depsListModel.append(customItems[ci])
                }
            }

            editDependenciesWindow.hasChanges = false
            editDependenciesWindow.forceClose = false
            editDependenciesWindow.visible = true
        }

        onLanguageChanged: function() {
            mainWindow.retranslate()
            settingsWindow.retranslate()
            modalWindow.retranslate()
            modalWindow2.retranslate()
        }

        onShowNoAiDebWarning: function() {
            noAiDebWarningDialog.open()
        }

        onShowNoAiRpmWarning: function() {
            noAiRpmWarningDialog.open()
        }

        onAskReloadUi: function() {
            reloadDialog.open()
        }
        property bool extracting: false

        onOpenFileRequested: function(filePath) {
            mainWindow.consoleHidden = false
            if (backend.isDirectoryPath(filePath)) {
                    confirmationDialog.subtitle = qsTr("Do you want to install \"%1\"?").arg(filePath.substring(filePath.lastIndexOf('/') + 1))
                    confirmationDialog.pendingPath = filePath
                    confirmationDialog.open()
                    return
                }
            var supported = filePath.endsWith(".deb") || filePath.endsWith(".rpm") || filePath.endsWith(".flatpakref") || filePath.endsWith(".flatpak") ||
                            filePath.endsWith(".tar.gz") || filePath.endsWith(".tar.bz2") || filePath.endsWith(".tar.xz") ||
                            filePath.endsWith(".tar.zst") || filePath.endsWith(".tar") || filePath.endsWith(".tgz") ||
                            filePath.endsWith(".zip") || filePath.endsWith(".AppImage")
            if (!supported) return
            confirmationDialog.subtitle = qsTr("Do you want to install \"%1\"?").arg(filePath.substring(filePath.lastIndexOf('/') + 1))
            confirmationDialog.pendingPath = filePath
            confirmationDialog.open()
        }
        onShowShUnsapportedDialog: function() {
            shUnsapported.open()
        }

        onUpdateLastLogMessage: function(line) {
            if (consoleLines.count > 0) {
                // Replace the last line
                consoleLines.set(consoleLines.count - 1, { "line": line })
            } else {
                consoleLines.append({ "line": line })
            }
        }

        onLogMessage: function(log) {
            if (log === "__CLEAR__") {
                consoleLines.clear()
                return
            }

            // if (!consoleHidden) {
            var parts = log.split("<br>")
            for (var i = 0; i < parts.length; i++) {
                if (parts[i].trim().length > 0) {
                    consoleLines.append({ "line": parts[i] })
                }
            }
            // }

            while (consoleLines.count > 300) {
                consoleLines.remove(0)
            }
        }

        onRequestReinstall: function(pkgName, location) {
            reinstallDialog.subtitle = "Package \"" + pkgName + "\" is already installed. Reinstall?"
            reinstallDialog.pkgName = pkgName
            reinstallDialog.location = location
            reinstallDialog.open()
        }

        onSwitchToPage1:      function() {
            modalWindow.close()
        }
        onSwitchToPage2:      function() {
            modalWindow.show()
        }
        onSwitchToPage3:      function() {
            modalWindow.show()
        }

        onCompleted: {
            notificationsEnabled = backend.loadNotificationsEnabled()
            isDependenciesSwitch = backend.loadDependenciesSwitch()
        }

        onShowAiCustomErrorDialog: function(model, error, status) {

            var url  = model === "Gemini"      ? "https://aistudio.google.com/apikey"
                     : model === "OpenAI"      ? "https://platform.openai.com/account/billing"
                     : model === "Hugging Face" ? "https://huggingface.co/settings/billing"
                     : model === "Mistral"     ? "https://admin.mistral.ai/organization/api-keys"
                     :                      "https://openrouter.ai/credits"

            if (status === 1) {
                aiCustomErrorDialog.settingbut = false
                aiCustomErrorDialog2.settingbut = false
                aiCustomErrorDialog3.settingbut = false
                aiCustomErrorDialog.currentUrl = url
                aiCustomErrorDialog2.currentUrl = url
                aiCustomErrorDialog3.currentUrl = url
            } else if (status === 0) {
                aiCustomErrorDialog.currentUrl = ""
                aiCustomErrorDialog2.currentUrl = ""
                aiCustomErrorDialog3.currentUrl = ""
                aiCustomErrorDialog.settingbut = true
                aiCustomErrorDialog2.settingbut = true
                aiCustomErrorDialog3.settingbut = true
            }

            if (modalWindow.visible) {
                aiCustomErrorDialog2.title = model + qsTr(" error")
                aiCustomErrorDialog2.subtitle = "\n" + error + qsTr("\nAi metadata will not be applied")
                aiCustomErrorDialog2.open()
            } else if (modalWindow2.visible) {
                aiCustomErrorDialog3.title = model + qsTr(" error")
                aiCustomErrorDialog3.subtitle = "\n" + error + qsTr("\nAi metadata will not be applied")
                aiCustomErrorDialog3.open()
            } else {
                aiCustomErrorDialog.title = model + qsTr(" error")
                aiCustomErrorDialog.subtitle = "\n" + error + qsTr("\nAi metadata will not be applied")
                aiCustomErrorDialog.open()
            }
        }

        onShowKillPacmanButton: function() {
            confirmOnClose = true
            installFinished = false
            if (backend.alwaysShowConsole) {
                consoleOverlay = true
            }
        }
        onHideKillPacmanButton: function() {
            confirmOnClose = false
            consoleOverlay = backend.alwaysShowConsole
            installFinished = true
        }
        onRequestToken: function(pendingLocation) { mainWindow.pendingDebLocation = pendingLocation
            settingsWindow.show()
        }
        onShowAppimageDialog: function() {
            modalWindow2.show()
        }
        onAskInstallFlatpak:  function() {
            installFlatpakDialog.open()
        }
        onNotArch: function() {
            notArchDialog.open()
        }

        onAskReinstallFlatpak: function(appId) {
            reinstallFlatpakDialog.subtitle = qsTr("Flatpak application \"%1\" is already installed. Reinstall it?").arg(appId)
            reinstallFlatpakDialog.open()
        }
        onAiAppNameChanged: function() {
            if (modalWindow2.visible && backend.aiAppName !== "")
            aiNameField.text = backend.aiAppName
        }
        onAiAppDescriptionChanged: function() {
            if (modalWindow2.visible && backend.aiAppDescription !== "")
            aiDescField.text = backend.aiAppDescription
        }
        onAiAppDescriptionUpdated: function() {
            if (modalWindow2.visible) {
                aiDescField.text = backend.aiAppDescription
                aiDescField.cursorPosition = 0
            }
        }
        onAiDescriptionUpdated: function() {
            if (modalWindow.visible) {
                descField.updatingFromBackend = true
                descField.text = backend.appDescription
                descField.cursorPosition = 0
                descField.updatingFromBackend = false
            }
        }
        onNoInternetDialog: function() {
            noInternet.open()
        }

        onAiAppCategoryChanged: function() {
            if (modalWindow2.visible && backend.aiAppCategory !== "")
                aiCategoryField.text = backend.aiAppCategory
        }
        onAppNameChanged: function() {
            if (modalWindow.visible) {
                appNameField.updatingFromBackend = true
                appNameField.text = backend.appName
                appNameField.updatingFromBackend = false
            }
        }
        onAppDescriptionChanged: function() {
            if (modalWindow.visible) {
                descField.updatingFromBackend = true
                descField.text = backend.appDescription
                descField.updatingFromBackend = false
            }
        }
        onAppCategoryChanged: function() {
            if (modalWindow.visible) {
                categoryField.updatingFromBackend = true
                categoryField.text = backend.appCategory
                categoryField.updatingFromBackend = false
            }
        }
        onExecCommandChanged: function() {
            if (modalWindow.visible && execCommandField.text !== backend.execCommand)
                execCommandField.text = backend.execCommand
        }
        onAiSuggestedExecutable: function(execPath) {
            if (!modalWindow.visible) return
            for (var i = 0; i < executableModel.count; i++) {
                if (executableModel.get(i).path === execPath) {
                    executableList.currentIndex = i
                    backend.executable = execPath
                    break
                }
            }
        }

        onRequestLogReplacement: function(targetPart, newText) {
            consoleListView.replaceLastLogEntry(targetPart, newText)
        }
    }

    // Dialogs
    Kirigami.PromptDialog {
        id: reinstallDialog
        title: qsTr("Reinstall package")
        subtitle: ""
        property string pkgName
        property string location
        standardButtons: Kirigami.Dialog.Yes | Kirigami.Dialog.No
        onAccepted: backend.reinstallAPP(pkgName, location)
        onRejected: {
            mainWindow.installCancelled = true
            backend.cancel()
        }
    }

    Kirigami.PromptDialog {
        id: notArchDialog
        title: qsTr("Error")
        subtitle: "This program works only in arch linux, sorry)"
        customFooterActions: [
            Kirigami.Action {
                text: qsTr("Exit")
                onTriggered: {
                    mainWindow.forceClose = true
                    mainWindow.close()
                }
            }
        ]
    }

    Kirigami.PromptDialog {
        id: reinstallFlatpakDialog
        title: qsTr("Reinstall Confirmation")
        subtitle: ""
        standardButtons: Kirigami.Dialog.Yes | Kirigami.Dialog.No
        onAccepted: backend.confirmReinstallFlatpak(true)
        onRejected: backend.confirmReinstallFlatpak(false)
    }

    Kirigami.PromptDialog {
        id: completeDialog
        title: qsTr("Successful")
        subtitle: qsTr("Package installation completed successfully")
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: qsTr("Launch app")
                enabled: backend.lastInstalledBinary.length > 0
                onTriggered: {
                    backend.launchInstalledApp()
                    completeDialog.close()
                }
            },
            Kirigami.Action {
                text: qsTr("Close")
                onTriggered: {
                    completeDialog.close()
                    if (confirmationDialog.pendingPath !== "") confirmationDialog.open()
                }
            }
        ]
        onClosed: {
            if (confirmationDialog.pendingPath !== "") confirmationDialog.open()
        }
    }

    Kirigami.PromptDialog {
        id: killDialog
        title: qsTr("Close Window")
        subtitle: qsTr("Do you want to kill the installation process?")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: {
            mainWindow.confirmOnClose = false
            backend.killPacman()
            backend.rmAlltempfiles()
            mainWindow.forceClose = true
            mainWindow.close()
        }
    }

    Kirigami.PromptDialog {
        id: errorDialog
        title: qsTr("Error")
        subtitle: qsTr("An error occurred during installation")
        standardButtons: Kirigami.Dialog.Ok
        onClosed: {
            if (confirmationDialog.pendingPath !== "") confirmationDialog.open()
        }
    }

    Kirigami.PromptDialog {
        id: confirmationDialog
        title: qsTr("Confirmation")
        subtitle: qsTr("Do you want to install this package?")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        property string pendingPath: ""
        onAccepted: {
            if (pendingPath !== "") { handleDrop(pendingPath)
                pendingPath = ""
            }
        }
        onRejected: {
            confirmationDialog.pendingPath = ""
            mainWindow.forceClose = true
            mainWindow.close()
        }
        onClosed:   {
            if (confirmationDialog.pendingPath !== "")
                confirmationDialog.open()
        }
    }

    Kirigami.PromptDialog {
        id: installFlatpakDialog
        title: qsTr("Flatpak not found")
        subtitle: qsTr("Flatpak is not installed on this system. Install it now?")
        standardButtons: Kirigami.Dialog.Yes | Kirigami.Dialog.No
        onAccepted: backend.confirmInstallFlatpak(true)
        onRejected: backend.confirmInstallFlatpak(false)
    }

    Kirigami.PromptDialog {
        id: noAiDebWarningDialog
        title: qsTr("AI mode is off")
        subtitle: qsTr("Dependencies for this .deb package will not be translated automatically. You may need to resolve them manually. Continue anyway?")
        standardButtons: Kirigami.Dialog.NoButton

        customFooterActions: [
            Kirigami.Action {
                text: qsTr("Continue")
                icon.name: "dialog-ok"
                onTriggered: {
                    noAiDebWarningDialog.close()
                    backend.confirmDebWithoutAi(true)
                }
            },
            Kirigami.Action {
                text: qsTr("Don't show again")
                icon.name: "dialog-ok"
                onTriggered: {
                    backend.saveDebNoAiWarningDisabled(true)
                    noAiDebWarningDialog.close()
                    backend.confirmDebWithoutAi(true)
                }
            },
            Kirigami.Action {
                text: qsTr("Cancel")
                icon.name: "dialog-cancel"
                onTriggered: {
                    noAiDebWarningDialog.close()
                    backend.confirmDebWithoutAi(false)
                }
            }
        ]
    }

    Kirigami.PromptDialog {
        id: aiErrorDialog
        title: qsTr("AI Error")
        subtitle: ""
        standardButtons: Kirigami.Dialog.Ok
    }

    Kirigami.PromptDialog {
        id: noInternet
        title: qsTr("Internet error")
        subtitle: qsTr("No internet connection, ai is off")
        standardButtons: Kirigami.Dialog.Ok
    }


    Kirigami.PromptDialog {
        id: noAiRpmWarningDialog
        title: qsTr("AI mode is off")
        subtitle: qsTr("Dependencies for this .rpm package will not be translated automatically. You may need to resolve them manually. Continue anyway?")
        standardButtons: Kirigami.Dialog.NoButton

        customFooterActions: [
            Kirigami.Action {
                text: qsTr("Continue")
                icon.name: "dialog-ok"
                onTriggered: {
                    noAiRpmWarningDialog.close()
                    backend.confirmRpmWithoutAi(true)
                }
            },
            Kirigami.Action {
                text: qsTr("Don't show again")
                icon.name: "dialog-ok"
                onTriggered: {
                    backend.saveRpmNoAiWarningDisabled(true)
                    noAiRpmWarningDialog.close()
                    backend.confirmRpmWithoutAi(true)
                }
            },
            Kirigami.Action {
                text: qsTr("Cancel")
                icon.name: "dialog-cancel"
                onTriggered: {
                    noAiRpmWarningDialog.close()
                    backend.confirmRpmWithoutAi(false)
                }
            }
        ]
    }

    Kirigami.PromptDialog {
        id: unknownErrorDialog
        title: qsTr("Error")
        subtitle: qsTr("Unknown file type detected")
        standardButtons: Kirigami.Dialog.Ok
    }
    Kirigami.PromptDialog {
        id: aiAuthErrorDialog
        title: qsTr("AI Token Error")
        subtitle: qsTr("The AI could not translate package dependencies — your API token appears to be invalid.\n\n") +
                  qsTr("The package was built but dependencies was not translated, so this can cause crashes\n\n") +
                  qsTr("You can proceed with installation anyway, or cancel and fix your token in settings")
        standardButtons: Kirigami.Dialog.NoButton
        customFooterActions: [
            Kirigami.Action {
                text: qsTr("Proceed anyway")
                icon.name: "dialog-ok"
                onTriggered: {
                    aiAuthErrorDialog.close()
                    backend.confirmAiAuthErrorInstall(true)
                }
            },
            Kirigami.Action {
                text: qsTr("Cancel")
                icon.name: "dialog-cancel"
                onTriggered: {
                    aiAuthErrorDialog.close()
                    backend.rmAlltempfiles()
                    backend.confirmAiAuthErrorInstall(false)
                }
            }
        ]
    }

    Kirigami.PromptDialog {
        id: shUnsapported
        title: qsTr("Unsupported file type")
        subtitle: qsTr("\nSh is not supported yet.\n") +
                  qsTr("Maybe later")
        standardButtons: Kirigami.Dialog.Ok
    }

    Kirigami.PromptDialog {
        id: aiCustomErrorDialog
        title: qsTr("")
        subtitle: qsTr("")
        standardButtons: Kirigami.Dialog.NoButton

        property string currentUrl: ""
        property bool settingbut: false

        customFooterActions: [
            Kirigami.Action {
                text: qsTr("Open AI page")
                icon.name: "internet-web-browser"
                visible: aiCustomErrorDialog.currentUrl === "" ? false : true
                onTriggered: {
                    Qt.openUrlExternally(aiCustomErrorDialog.currentUrl)
                    aiCustomErrorDialog.close()
                }
            },
            Kirigami.Action {
                text: qsTr("Open settings")
                icon.name: "settings"
                visible: aiCustomErrorDialog.settingbut ? true : false
                onTriggered: {
                    aiCustomErrorDialog.close()
                    backend.cancel()
                    settingsWindow.show()
                }
            },
            Kirigami.Action {
                text: qsTr("Continue")
                icon.name: "dialog-ok"
                onTriggered: aiCustomErrorDialog.close()
            }
        ]
    }

    Kirigami.PromptDialog {
        id: ai402ErrorDialogNotModal
        title: qsTr("AI limit reached")
        subtitle: ""
        standardButtons: Kirigami.Dialog.NoButton

        property string currentUrl: ""
        property string currentName: ""

        customFooterActions: [
            Kirigami.Action {
                text: qsTr("Open ") + ai402ErrorDialogNotModal.currentName
                icon.name: "internet-web-browser"
                onTriggered: {
                    Qt.openUrlExternally(ai402ErrorDialogNotModal.currentUrl)
                    ai402ErrorDialogNotModal.close()
                }
            },
            Kirigami.Action {
                text: qsTr("Continue without AI")
                icon.name: "dialog-ok"
                onTriggered: ai402ErrorDialogNotModal.close()
            }
        ]
    }
}