import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    id: mainWindow
    width: consoleOutput.visible ? 450 : 380
    height: consoleOutput.visible ? 350 : 180

    minimumWidth: consoleOutput.visible ? 500 : 400
    minimumHeight: consoleOutput.visible ? 350 : 180
    maximumWidth: 850
    maximumHeight: consoleOutput.visible ? 600 : 500

    visible: true
    title: qsTr("Linux App Installer")
    color: "#23242D"

    property bool confirmOnClose: false
    property bool forceClose: false
    property string pendingDebLocation: ""

    onVisibleChanged: {
        if (visible) {
            if (!backend.hasToken) {
                noTokenDialog.open()
            } else if (!backend.hasInternet()) {
                noInternet.open()
            }
        }
    }

    onClosing: function(closeEvent) {
        if (confirmOnClose && !forceClose) {
            closeEvent.accepted = false
            Qt.callLater(function() { killDialog.open() })
        }
    }

    // ── Drop area + console ──────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"

        Column {
            anchors.fill: parent
            spacing: 16

            Item {
                width: parent.width
                height: consoleOutput.visible ? 150 : parent.height

                Shape {
                    id: dropFrame
                    width: parent.width
                    height: consoleOutput.visible ? 150 : parent.height

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
                    onDropped: function(drop) {
                        if (drop.urls.length > 0) {
                            var localPath = Qt.resolvedUrl(drop.urls[0]).toString().replace("file://", "")
                            handleDrop(localPath)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Drag app package here"
                    color: "grey"
                }
            }

            Item {
                id: consoleArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height - 170
                visible: consoleOutput.text.length > 0

                ScrollView {
                    id: scrollView
                    anchors.fill: parent

                    TextArea {
                        id: consoleOutput
                        readOnly: true
                        wrapMode: TextEdit.WrapAnywhere
                        textFormat: TextEdit.RichText
                        color: "white"
                        visible: text.length > 0
                        background: Rectangle { color: "#1E1F29"; radius: 10 }
                    }
                }

                // Спінер — правий нижній кут консолі
                Canvas {
                    id: spinnerCanvas
                    width: 28; height: 28
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    visible: mainWindow.confirmOnClose
                    property real angle: 0
                    property real arcLen: 30

                    NumberAnimation on angle {
                        from: 0; to: 360
                        duration: 1100
                        loops: Animation.Infinite
                        running: spinnerCanvas.visible
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
                        ctx.strokeStyle = "rgba(255,255,255,0.85)"
                        ctx.lineWidth = 2.5
                        ctx.lineCap = "round"
                        var cx = width/2, cy = height/2, r = 10
                        var s = (angle - 90) * Math.PI / 180
                        var e = s + arcLen * Math.PI / 180
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, s, e)
                        ctx.stroke()
                    }
                }
            }
        }
    }

    // ── Drop handler ─────────────────────────────────────────────────────
    function handleDrop(localPath) {
        backend.generateArchPackageList()
        if (localPath.endsWith(".deb")) {
            if (!backend.hasToken) {
                pendingDebLocation = localPath
                tokenInputWindow.visible = true
                return
            }
        }
        backend.installAPP(localPath)
    }

    // ── Token input window ───────────────────────────────────────────────
    Window {
        id: tokenInputWindow
        title: qsTr("Enter OpenRouter API Token")
        width: 440; height: 200
        minimumWidth: 440; minimumHeight: 200
        modality: Qt.ApplicationModal
        visible: false
        color: "#23242D"

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Text { color: "white"; font.pixelSize: 13; text: "No token found in debtap-ai/token.txt"; font.bold: true }
            Text { color: "#aaaaaa"; font.pixelSize: 12; wrapMode: Text.WrapAtWordBoundaryOrAnywhere; width: parent.width
                text: "Enter your OpenRouter API key to enable .deb conversion and AI metadata analysis:" }

            TextField {
                id: tokenField
                width: parent.width
                placeholderText: "sk-or-..."
                color: "white"
                echoMode: TextInput.Password
                background: Rectangle { color: "#1E1F29"; radius: 6 }
            }

            Row {
                spacing: 12
                anchors.horizontalCenter: parent.horizontalCenter

                Button {
                    text: qsTr("Save & Continue")
                    enabled: tokenField.text.trim().length > 0
                    onClicked: {
                        if (backend.saveToken(tokenField.text.trim())) {
                            tokenInputWindow.visible = false
                            tokenField.text = ""
                            if (mainWindow.pendingDebLocation !== "") {
                                backend.installAPP(mainWindow.pendingDebLocation)
                                mainWindow.pendingDebLocation = ""
                            }
                        }
                    }
                }
                Button {
                    text: qsTr("Cancel")
                    onClicked: { tokenInputWindow.visible = false; tokenField.text = ""; mainWindow.pendingDebLocation = "" }
                }
            }
        }
    }

    // ── Installation properties modal (archive) ──────────────────────────
    Window {
        id: modalWindow
        title: "Installation properties"
        width: 480
        height: 655
        minimumWidth: 480
        minimumHeight: 560
        modality: Qt.ApplicationModal
        visible: false
        color: "#23242D"

        property bool forceClose: false

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

            executableModel.clear()
            iconModel.clear()

            var execs = backend.findExecutables(dir, archivePath)
            for (var i = 0; i < execs.length; i++) {
                var fp = execs[i]
                executableModel.append({ "name": fp.substring(fp.lastIndexOf('/') + 1), "path": fp })
            }
            if (execs.length > 0) backend.executable = execs[0]

            var icons = backend.findIcons(dir)
            for (var j = 0; j < icons.length; j++) {
                var ip = icons[j]
                iconModel.append({ "name": ip.substring(ip.lastIndexOf('/') + 1), "path": ip })
            }
            if (icons.length > 0) backend.iconPath = icons[0]

            var suggested = backend.suggestAppName(dir, archivePath)
            appNameField.text    = suggested
            backend.appName      = suggested
            descField.text       = backend.appDescription
            categoryField.text   = backend.appCategory

            backend.analyzeWithAI(dir, archivePath, execs.length > 0 ? execs[0] : "")
        }

        Kirigami.PromptDialog {
            id: killDialog2
            parent: modalWindow.contentItem
            title: qsTr("Cancel")
            subtitle: "Do you want to cancel the installation process?"
            standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
            onAccepted: { modalWindow.forceClose = true; modalWindow.close(); backend.cancel() }
        }

        ListModel { id: executableModel }
        ListModel { id: iconModel }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            color: "transparent"

            ScrollView {
                anchors.fill: parent
                clip: true

                Column {
                    width: parent.parent.width
                    spacing: 10

                    Rectangle {
                        width: parent.width
                        height: aiStatusRow.implicitHeight + 10
                        color: "#2a2b38"
                        radius: 6
                        visible: backend.aiAnalyzing || backend.appDescription !== ""

                        Row {
                            id: aiStatusRow
                            anchors.centerIn: parent
                            spacing: 8

                            BusyIndicator {
                                running: backend.aiAnalyzing
                                visible: backend.aiAnalyzing
                                width: 20; height: 20
                                palette.dark: "#bd93f9"
                            }

                            Text {
                                color: backend.aiAnalyzing ? "#bd93f9" : "#50fa7b"
                                font.pixelSize: 12
                                text: backend.aiAnalyzing
                                      ? "AI is analyzing the application..."
                                      : "✓ AI metadata applied"
                                verticalAlignment: Text.AlignVCenter
                                height: 24
                            }
                        }
                    }

                    Text { color: "white"; text: "Select main executable:"; font.bold: true }

                    Rectangle {
                        width: parent.width
                        height: 110
                        color: "#1E1F29"
                        radius: 6

                        ScrollView {
                            anchors.fill: parent
                            ListView {
                                id: executableList
                                anchors.fill: parent
                                model: executableModel
                                clip: true

                                delegate: Rectangle {
                                    width: executableList.width
                                    height: 40
                                    color: executableList.currentIndex === index ? "#44475a" : "transparent"

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: { executableList.currentIndex = index; backend.executable = model.path }
                                        onDoubleClicked: backend.runFile(model.path)
                                    }
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 8
                                        Kirigami.Icon { source: "application-x-executable"; width: 20; height: 20 }
                                        Column {
                                            Text { text: model.name; color: "white"; font.pixelSize: 13 }
                                            Text { text: model.path; color: "#888"; font.pixelSize: 10 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text { color: "white"; text: "Select icon:"; font.bold: true }

                    Rectangle {
                        width: parent.width
                        height: 120
                        color: "#1E1F29"
                        radius: 6

                        ScrollView {
                            anchors.fill: parent
                            GridView {
                                id: iconGrid
                                anchors.fill: parent
                                model: iconModel
                                clip: true
                                cellWidth: 100; cellHeight: 120
                                flow: GridView.FlowLeftToRight

                                delegate: Rectangle {
                                    width: iconGrid.cellWidth; height: iconGrid.cellHeight
                                    color: iconGrid.currentIndex === index ? "#44475a" : "transparent"
                                    radius: 6

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: { iconGrid.currentIndex = index; backend.iconPath = model.path }
                                        onDoubleClicked: Qt.openUrlExternally("file://" + model.path)
                                    }
                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 6
                                        Image { source: "file://" + model.path; width: 64; height: 64; fillMode: Image.PreserveAspectFit }
                                        Text { text: model.name; color: "white"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; width: parent.width; elide: Text.ElideRight }
                                    }
                                }
                            }
                        }
                    }

                    Text { color: "white"; text: "Application name:"; font.bold: true }
                    TextField {
                        id: appNameField
                        width: parent.width
                        placeholderText: "Enter app name..."
                        color: "white"
                        background: Rectangle { color: "#1E1F29"; radius: 6 }
                        onTextChanged: backend.appName = text
                    }

                    Text { color: "white"; text: "Description:"; font.bold: true }
                    TextField {
                        id: descField
                        width: parent.width
                        placeholderText: "Short description (one sentence)..."
                        color: "white"
                        background: Rectangle { color: "#1E1F29"; radius: 6 }
                        onTextChanged: backend.appDescription = text
                    }

                    Text { color: "white"; text: "Category (freedesktop):"; font.bold: true }

                    Row {
                        width: parent.width
                        spacing: 8

                        TextField {
                            id: categoryField
                            width: parent.width - categoryHelpBtn.width - 8
                            placeholderText: "e.g. Network;WebBrowser;"
                            color: "white"
                            background: Rectangle { color: "#1E1F29"; radius: 6 }
                            onTextChanged: backend.appCategory = text
                        }

                        Button {
                            id: categoryHelpBtn
                            text: "▾"
                            width: 36
                            onClicked: categoryMenu.open()

                            Menu {
                                id: categoryMenu
                                MenuItem { text: "AudioVideo;";               onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Audio;";                    onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Video;";                    onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Development;";              onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Education;";                onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Game;";                     onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Graphics;";                 onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Network;";                  onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Network;WebBrowser;";       onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Office;";                   onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Science;";                  onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Settings;";                 onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "System;";                   onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "System;FileManager;";       onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "System;TerminalEmulator;";  onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Utility;";                  onTriggered: { categoryField.text = text; backend.appCategory = text } }
                                MenuItem { text: "Utility;TextEditor;";       onTriggered: { categoryField.text = text; backend.appCategory = text } }
                            }
                        }
                    }

                    Text {
                        color: "#666"
                        font.pixelSize: 10
                        text: "Format: PrimaryCategory;ExtraCategory;  (e.g. Network;WebBrowser;)"
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        width: parent.width
                    }

                    Row {
                        spacing: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 4

                        Button {
                            text: qsTr("Install")
                            enabled: !backend.aiAnalyzing
                            onClicked: {
                                modalWindow.forceClose = true
                                modalWindow.close()
                                modalWindow.forceClose = false
                                backend.installPackage()
                            }
                        }
                        Button {
                            text: qsTr("Cancel")
                            onClicked: {
                                modalWindow.forceClose = true
                                modalWindow.close()
                                modalWindow.forceClose = false
                                backend.cancel()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── AppImage installation properties modal ───────────────────────────
    Window {
        id: modalWindow2
        title: qsTr("AppImage — Installation properties")
        width: 480
        height: 490
        minimumWidth: 480
        minimumHeight: 520
        modality: Qt.ApplicationModal
        visible: false
        color: "#23242D"

        property bool forceClose: false
        // Шлях до кастомної іконки (порожній = системна)
        property string customIconPath: ""

        onClosing: function(closeEvent) {
            if (!forceClose) {
                closeEvent.accepted = false
                Qt.callLater(function() { killDialog3.open() })
            }
        }

        // Коли вікно відкривається — заповнюємо поля та запускаємо AI
        onVisibleChanged: {
            if (!visible) return

            // Скидаємо кастомну іконку
            customIconPath = ""

            // Підставляємо fallback ім'я з назви файлу
            var fallback = backend.appimageBaseName(backend.appimageLocation)
            aiNameField.text     = fallback
            aiDescField.text     = ""
            aiCategoryField.text = "Utility;"

            // Запускаємо AI-аналіз
            backend.analyzeAppimageWithAI(backend.appimageLocation)
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

        // Діалог вибору файлу іконки
        FileDialog {
            id: iconFileDialog
            title: qsTr("Select icon file")
            nameFilters: ["Image files (*.png *.jpg *.jpeg *.svg *.ico)", "All files (*)"]
            onAccepted: {
                var path = selectedFile.toString().replace("file://", "")
                modalWindow2.customIconPath = path
                customIconPreview.source = selectedFile
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 12
            color: "transparent"

            ScrollView {
                anchors.fill: parent
                clip: true

                Column {
                    width: parent.parent.width
                    spacing: 12

                    // ── AI status banner ──────────────────────────────
                    Rectangle {
                        width: parent.width
                        height: aiAppStatusRow.implicitHeight + 10
                        color: "#2a2b38"
                        radius: 6
                        visible: backend.aiAppimageAnalyzing || backend.aiAppDescription !== ""

                        Row {
                            id: aiAppStatusRow
                            anchors.centerIn: parent
                            spacing: 8

                            BusyIndicator {
                                running: backend.aiAppimageAnalyzing
                                visible: backend.aiAppimageAnalyzing
                                width: 20; height: 20
                                palette.dark: "#bd93f9"
                            }

                            Text {
                                color: backend.aiAppimageAnalyzing ? "#bd93f9" : "#50fa7b"
                                font.pixelSize: 12
                                text: backend.aiAppimageAnalyzing
                                      ? qsTr("AI is analyzing the AppImage...")
                                      : qsTr("✓ AI metadata applied")
                                verticalAlignment: Text.AlignVCenter
                                height: 24
                            }
                        }
                    }

                    // ── Вибір іконки ──────────────────────────────────
                    Text { color: "white"; text: qsTr("Icon:"); font.bold: true }

                    Row {
                        width: parent.width
                        spacing: 12

                        // Прев'ю іконки
                        Rectangle {
                            width: 80; height: 80
                            color: "#1E1F29"
                            radius: 8

                            // Системна іконка (фолбек)
                            Kirigami.Icon {
                                anchors.centerIn: parent
                                source: "application-x-executable"
                                width: 56; height: 56
                                visible: modalWindow2.customIconPath === ""
                            }

                            // Кастомна іконка
                            Image {
                                id: customIconPreview
                                anchors.centerIn: parent
                                width: 64; height: 64
                                fillMode: Image.PreserveAspectFit
                                visible: modalWindow2.customIconPath !== ""
                            }
                        }

                        Column {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter

                            Text {
                                color: "#aaaaaa"
                                font.pixelSize: 11
                                text: modalWindow2.customIconPath === ""
                                      ? qsTr("Default system icon (application-x-executable)")
                                      : modalWindow2.customIconPath.substring(
                                            modalWindow2.customIconPath.lastIndexOf('/') + 1)
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                width: 340
                                elide: Text.ElideMiddle
                            }

                            Row {
                                spacing: 8

                                Button {
                                    text: qsTr("Choose icon…")
                                    onClicked: iconFileDialog.open()
                                }
                                Button {
                                    text: qsTr("Reset")
                                    visible: modalWindow2.customIconPath !== ""
                                    onClicked: {
                                        modalWindow2.customIconPath = ""
                                        customIconPreview.source = ""
                                    }
                                }
                            }
                        }
                    }

                    // ── Ім'я ─────────────────────────────────────────
                    Text { color: "white"; text: qsTr("Application name:"); font.bold: true }
                    TextField {
                        id: aiNameField
                        width: parent.width
                        placeholderText: qsTr("Enter app name...")
                        color: "white"
                        background: Rectangle { color: "#1E1F29"; radius: 6 }
                    }

                    // ── Опис ─────────────────────────────────────────
                    Text { color: "white"; text: qsTr("Description:"); font.bold: true }
                    TextField {
                        id: aiDescField
                        width: parent.width
                        placeholderText: qsTr("Short description (one sentence)...")
                        color: "white"
                        background: Rectangle { color: "#1E1F29"; radius: 6 }
                    }

                    // ── Категорія ─────────────────────────────────────
                    Text { color: "white"; text: qsTr("Category (freedesktop):"); font.bold: true }

                    Row {
                        width: parent.width
                        spacing: 8

                        TextField {
                            id: aiCategoryField
                            width: parent.width - aiCategoryBtn.width - 8
                            placeholderText: "e.g. Network;WebBrowser;"
                            color: "white"
                            background: Rectangle { color: "#1E1F29"; radius: 6 }
                        }

                        Button {
                            id: aiCategoryBtn
                            text: "▾"
                            width: 36
                            onClicked: aiCategoryMenu.open()

                            Menu {
                                id: aiCategoryMenu
                                MenuItem { text: "AudioVideo;";               onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Audio;";                    onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Video;";                    onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Development;";              onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Education;";                onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Game;";                     onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Graphics;";                 onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Network;";                  onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Network;WebBrowser;";       onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Office;";                   onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Science;";                  onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Settings;";                 onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "System;";                   onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "System;FileManager;";       onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "System;TerminalEmulator;";  onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Utility;";                  onTriggered: aiCategoryField.text = text }
                                MenuItem { text: "Utility;TextEditor;";       onTriggered: aiCategoryField.text = text }
                            }
                        }
                    }

                    Text {
                        color: "#666"
                        font.pixelSize: 10
                        text: "Format: PrimaryCategory;ExtraCategory;  (e.g. Network;WebBrowser;)"
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        width: parent.width
                    }

                    // ── Кнопки ───────────────────────────────────────
                    Row {
                        spacing: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 4

                        Button {
                            text: qsTr("Install")
                            enabled: !backend.aiAppimageAnalyzing && aiNameField.text.trim().length > 0
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
                        Button {
                            text: qsTr("Cancel")
                            onClicked: {
                                modalWindow2.forceClose = true
                                modalWindow2.close()
                                modalWindow2.forceClose = false
                                backend.cancel()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Backend connections ──────────────────────────────────────────────
    Connections {
        target: backend

        onLogMessage: function(log) {
            consoleOutput.text += log
            if (scrollView.contentItem.contentHeight > scrollView.height)
                scrollView.contentItem.contentY = scrollView.contentItem.contentHeight - scrollView.height
        }

        onRequestReinstall: function(pkgName, location) {
            reinstallDialog.subtitle = "Package \"" + pkgName + "\" is already installed. Reinstall?"
            reinstallDialog.pkgName  = pkgName
            reinstallDialog.location = location
            reinstallDialog.open()
        }

        onExtractionStarted: function() { confirmOnClose = true }
        onExtractionFinished: function() { /* залишається true до кінця installPackage */ }

        onShowCompleteDialog: function() { completeDialog.open() }
        onShowErrorDialog:    function() { errorDialog.open() }

        onSwitchToPage1: function() { modalWindow.close() }
        onSwitchToPage2: function() { modalWindow.show() }
        onSwitchToPage3: function() { modalWindow.show() }

        onShowKillPacmanButton: function() { confirmOnClose = true  }
        onHideKillPacmanButton: function() { confirmOnClose = false }

        onRequestToken: function(pendingLocation) {
            mainWindow.pendingDebLocation = pendingLocation
            tokenInputWindow.visible = true
        }

        // AppImage — відкриваємо modalWindow2
        onShowAppimageDialog: function() {
            modalWindow2.show()
        }

        // AI оновлює AppImage-поля
        onAiAppNameChanged: function() {
            if (modalWindow2.visible && backend.aiAppName !== "")
                aiNameField.text = backend.aiAppName
        }
        onAiAppDescriptionChanged: function() {
            if (modalWindow2.visible && backend.aiAppDescription !== "")
                aiDescField.text = backend.aiAppDescription
        }
        onAiAppCategoryChanged: function() {
            if (modalWindow2.visible && backend.aiAppCategory !== "")
                aiCategoryField.text = backend.aiAppCategory
        }

        // Синхронізуємо поля коли AI оновлює archive properties
        onAppNameChanged: function() {
            if (modalWindow.visible) appNameField.text = backend.appName
        }
        onAppDescriptionChanged: function() {
            if (modalWindow.visible) descField.text = backend.appDescription
        }
        onAppCategoryChanged: function() {
            if (modalWindow.visible) categoryField.text = backend.appCategory
        }
    }

    // ── Dialogs ──────────────────────────────────────────────────────────
    Kirigami.PromptDialog {
        id: reinstallDialog
        title: qsTr("Reinstall package")
        subtitle: ""
        property string pkgName
        property string location
        standardButtons: Kirigami.Dialog.Yes | Kirigami.Dialog.No
        onAccepted: backend.reinstallAPP(pkgName, location)
        onRejected: backend.cancel()
    }

    Kirigami.PromptDialog {
        id: completeDialog
        title: qsTr("Successful")
        subtitle: "Package installation completed successfully"
        standardButtons: Kirigami.Dialog.Ok
    }

    Kirigami.PromptDialog {
        id: noTokenDialog
        title: qsTr("No API token detected")
        subtitle: "Without ai some functions will be restricted"
        standardButtons: Kirigami.Dialog.Ok
    }

    Kirigami.PromptDialog {
        id: noInternet
        title: qsTr("No internet connection")
        subtitle: "Without ai some functions will be restricted"
        standardButtons: Kirigami.Dialog.Ok
    }

    Kirigami.PromptDialog {
        id: killDialog
        title: qsTr("Close Window")
        subtitle: "Do you want to kill the installation process?"
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: { backend.killPacman(); mainWindow.forceClose = true; mainWindow.close() }
    }

    Kirigami.PromptDialog {
        id: errorDialog
        title: qsTr("Error")
        subtitle: "An error occurred during installation"
        standardButtons: Kirigami.Dialog.Ok
    }
}
