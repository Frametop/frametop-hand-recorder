// The Hand Recorder's window for SteamVR's dashboard: Qt Quick Controls (Basic style), no
// Kirigami. A port of frametop/hands/rec/main.qml with the same pages, backend calls and texts
// (bounties and the testing session only: no full session or quick round),
// reworded where the person is in the headset using the dashboard. It runs as a fixed panel of
// about 1280x800, clicked with a controller's laser pointer, usually with no keyboard.
// Backend: ft_handrec.py ("backend", started with --qml this file --style Basic); frame sets
// come from its image provider (image://frames/...). The look: Theme.qml and the App* controls.
import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ApplicationWindow {
    id: root
    title: "Frametop Hand Recorder"
    width: 1280
    height: 800
    visible: true
    color: Theme.background
    font.family: Theme.fontFamily
    font.pixelSize: Theme.fontSize

    // For the Basic controls this window doesn't restyle (tool tips, the text areas' selection).
    palette {
        window: Theme.background
        windowText: Theme.text
        base: Theme.raised
        alternateBase: Theme.surface
        text: Theme.text
        button: Theme.raised
        buttonText: Theme.text
        brightText: Theme.accentText
        highlight: Theme.accent
        highlightedText: Theme.accentText
        placeholderText: Theme.dimText
        link: Theme.accent
        linkVisited: Theme.accent
        light: Theme.hover
        midlight: Theme.raised
        mid: Theme.border
        dark: Theme.accent
        shadow: "#000000"
        toolTipBase: Theme.raised
        toolTipText: Theme.text
        disabled.text: Theme.dimText
        disabled.windowText: Theme.dimText
        disabled.buttonText: Theme.dimText
    }

    // The session chosen on the Export page, for the Upload page.
    property string chosenSession: ""
    // The round picked on the Bounties page: a bounty's id, or the testing session's ("debug").
    // roundPicked: something was picked (else Welcome's Continue goes to Bounties).
    property string chosenBounty: ""
    property bool roundPicked: false
    // "Export and upload" on the Session page: once the export is done, the Upload page.
    property bool sendAfterExport: false
    // The navigation entry shown as the current page (Takes and the viewer count as Review).
    property var navPage: null

    // The texts wait for a legal review; until then nobody should contribute.
    component DraftBanner: Banner {
        header: true
        visible: backend.textsDraft
        type: "warning"
        text: "Contributions aren't open yet. These texts are drafts waiting for a legal review: you can "
              + "record and review, but please don't upload anything until this message is gone."
    }

    // Read-only Markdown (CONSENT.md, UPLOAD.md), selectable for copying. Links get the
    // application palette's colour when the text is parsed: set it first.
    component MarkdownText: TextArea {
        property string markdown
        function parse() {
            backend.setLinkColor(Theme.accent)
            text = markdown
        }
        onMarkdownChanged: parse()
        Component.onCompleted: parse()
        textFormat: TextEdit.MarkdownText
        readOnly: true
        selectByMouse: true
        wrapMode: Text.Wrap
        background: null
        padding: 0
        color: Theme.text
        selectionColor: Theme.accent
        selectedTextColor: Theme.accentText
        onLinkActivated: link => Qt.openUrlExternally(link)
    }

    // A dimmer note under a field.
    component Hint: Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        color: Theme.dimText
    }

    component Heading: Label {
        Layout.fillWidth: true
        Layout.topMargin: Theme.spacing
        wrapMode: Text.Wrap
        font.pixelSize: Theme.headingSize
        font.bold: true
        color: Theme.text
    }

    component Busy: BusyIndicator {
        implicitWidth: 44
        implicitHeight: 44
        palette.dark: Theme.accent
    }

    function plural(n, word) {
        return n + " " + word + (n === 1 ? "" : "s")
    }

    function show(page) {
        navPage = page
        pageStack.clear()
        pageStack.push(page)
    }

    // A round picked on the Bounties page: the consent first if it isn't agreed to yet, then
    // Getting ready (SteamVR, the cameras, hand tracking and the headset panel started), then
    // Before you start (the camera check, the privacy checks), then Start. The consent asked for
    // follows the round: the testing session's is TESTING.md, a bounty's the dataset's (CONSENT.md).
    function pickRound(bounty) {
        chosenBounty = bounty
        roundPicked = true
        backend.setConsentKind(backend.roundConsentKind(bounty))
        show(backend.needsConsent ? welcomePage : readyPage)
    }

    // --page bounties|welcome|checklist|session|review|export|upload opens the app on that page;
    // it opens on Bounties. Pages that record or send need the consent: they lead to Welcome.
    function firstPage() {
        return ({ welcome: welcomePage, checklist: backend.needsConsent ? welcomePage : readyPage,
                  session: sessionPage, review: reviewPage, export: exportPage,
                  upload: uploadPage })[startPage] || bountiesPage
    }
    Component.onCompleted: show(firstPage())

    Connections {
        target: backend
        function onMessage(text, isError) {
            root.notify(text, isError)
        }
        function onExportDone(session, ok) {
            if (root.sendAfterExport && session === root.chosenSession) {
                root.sendAfterExport = false
                if (ok)
                    root.show(uploadPage)
            }
        }
    }

    // ---------------------------------------------------------------- The navigation
    component NavButton: Button {
        id: navButton
        property Component page
        property Component alsoPage: null    // a page it leads to, shown as current too
        readonly property bool current: root.navPage === page || (alsoPage !== null && root.navPage === alsoPage)
        Layout.fillWidth: true
        implicitHeight: 64
        focusPolicy: Qt.NoFocus
        leftPadding: Theme.largeSpacing
        rightPadding: Theme.spacing
        onClicked: root.show(page)
        contentItem: Label {
            text: navButton.text
            font.pixelSize: Theme.fontSize
            font.bold: navButton.current
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            color: navButton.current ? Theme.accent : Theme.text
            opacity: navButton.enabled ? 1 : 0.35
        }
        background: Rectangle {
            radius: Theme.radius
            color: navButton.current ? Theme.tint(Theme.accent, navButton.down ? 0.3 : 0.18)
                 : navButton.down ? Theme.pressed
                 : navButton.hovered && navButton.enabled ? Theme.hover : "transparent"
            Rectangle {
                visible: navButton.current
                x: 0
                width: 6
                height: parent.height - 16
                anchors.verticalCenter: parent.verticalCenter
                radius: 3
                color: Theme.accent
            }
        }
    }

    Rectangle {
        id: nav
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Theme.navWidth
        color: Theme.surface

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.spacing
            spacing: 6

            Label {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.spacing
                Layout.topMargin: Theme.spacing
                Layout.bottomMargin: Theme.spacing
                text: "Hand Recorder"
                font.pixelSize: 26
                font.bold: true
                color: Theme.text
                wrapMode: Text.Wrap
            }
            NavButton { text: "Bounties"; page: bountiesPage }
            NavButton { text: "Welcome"; page: welcomePage }
            NavButton {
                text: "Before you start"
                page: readyPage    // through Getting ready
                alsoPage: checklistPage
                enabled: !backend.needsConsent
            }
            NavButton { text: "Session"; page: sessionPage; enabled: !backend.needsConsent }
            NavButton { text: "Review"; page: reviewPage }
            NavButton { text: "Export"; page: exportPage; enabled: !backend.needsConsent }
            NavButton { text: "Upload"; page: uploadPage; enabled: !backend.needsConsent }
            Item { Layout.fillHeight: true }
            Label {
                Layout.fillWidth: true
                Layout.margins: Theme.spacing
                text: backend.toolVersion
                font.pixelSize: 15
                color: Theme.dimText
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }
        Rectangle {
            anchors.right: parent.right
            width: 1
            height: parent.height
            color: Theme.separator
        }
    }

    StackView {
        id: pageStack
        anchors.left: nav.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        // No sliding: nothing moves under the pointer.
        pushEnter: Transition { }
        pushExit: Transition { }
        popEnter: Transition { }
        popExit: Transition { }
        replaceEnter: Transition { }
        replaceExit: Transition { }
    }

    // ---------------------------------------------------------------- Messages
    // The backend's messages, at the bottom for a while (errors longer); a click hides one.
    function notify(text, isError) {
        toastText.text = text
        toast.error = isError
        toast.opacity = 1
        toastTimer.interval = isError ? 10000 : 4000
        toastTimer.restart()
    }

    Rectangle {
        id: toast
        property bool error: false
        z: 10
        anchors.horizontalCenter: pageStack.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        width: Math.min(toastText.implicitWidth, pageStack.width - 120) + 2 * Theme.largeSpacing
        height: toastText.height + 2 * Theme.spacing + 8
        radius: Theme.radius
        color: error ? Qt.tint(Theme.raised, Theme.tint(Theme.negative, 0.35)) : Theme.raised
        border.width: 1
        border.color: error ? Theme.negative : Theme.border
        opacity: 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        Label {
            id: toastText
            anchors.centerIn: parent
            width: Math.min(implicitWidth, pageStack.width - 120)
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            color: Theme.text
        }
        MouseArea {
            anchors.fill: parent
            onClicked: toast.opacity = 0
        }
        Timer {
            id: toastTimer
            onTriggered: toast.opacity = 0
        }
    }

    // Asks before something is deleted for good: ask(title, text, function).
    Dialog {
        id: confirm
        property var action: null
        modal: true
        anchors.centerIn: Overlay.overlay
        width: Math.min(800, root.width - 160)
        padding: Theme.largeSpacing
        topPadding: Theme.spacing
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onAccepted: if (action) action()

        function ask(title, text, fn) {
            confirm.title = title
            confirmText.text = text
            confirm.action = fn
            confirm.open()
        }

        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.6) }
        background: Rectangle {
            radius: Theme.radius + 4
            color: Theme.surface
            border.width: 1
            border.color: Theme.border
        }
        header: Label {
            text: confirm.title
            padding: Theme.largeSpacing
            bottomPadding: Theme.spacing
            wrapMode: Text.Wrap
            font.pixelSize: Theme.headingSize
            font.bold: true
            color: Theme.text
        }
        contentItem: Label {
            id: confirmText
            wrapMode: Text.Wrap
            color: Theme.text
        }
        footer: Item {
            implicitHeight: confirmButtons.implicitHeight + 2 * Theme.largeSpacing
            RowLayout {
                id: confirmButtons
                anchors.right: parent.right
                anchors.rightMargin: Theme.largeSpacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacing
                AppButton {
                    text: "OK"
                    highlighted: true
                    Layout.preferredWidth: 180
                    onClicked: confirm.accept()
                }
                AppButton {
                    text: "Cancel"
                    Layout.preferredWidth: 180
                    onClicked: confirm.reject()
                }
            }
        }
    }

    // Restart SteamVR (the camera check's fix). SteamVR's restart closes every VR app, and this
    // window may go with it: it's then opened again from the dashboard.
    function askRestartSteamVR() {
        confirm.ask("Restart SteamVR?",
                    "SteamVR starts its cameras again, and with them the colour camera module. This closes every "
                    + "VR app, and this window may close too.\n\nIf it does, open the Hand Recorder again from "
                    + "Launch a program in the dashboard once SteamVR is back: it checks the cameras again. If "
                    + "they're still off, restart the headset.",
                    () => backend.restartSteamVR())
    }

    // The camera check's problem, with its fix (a header message on the checklist and session pages).
    component CameraMessage: Banner {
        header: true
        type: backend.restartingSteamVR ? "info" : "error"
        text: backend.restartingSteamVR ? "Restarting SteamVR, then checking the cameras again…" : backend.cameraText
        actions: [
            AppButton {
                text: "Restart SteamVR…"
                enabled: !backend.restartingSteamVR && !backend.sessionActive
                onClicked: root.askRestartSteamVR()
            },
            AppButton {
                text: "Check again"
                enabled: !backend.cameraBusy
                onClicked: backend.checkCameras()
            }
        ]
    }

    // Closing during a session asks first. Quitting closes the window again (Qt 6), so the
    // answer is remembered; the backend stops the session as the app quits.
    property bool quitting: false
    onClosing: close => {
        if (backend.sessionActive && !quitting) {
            close.accepted = false
            confirm.ask("Stop the session?", "A session is recording. Closing stops it; what's recorded so far is kept.",
                        () => { root.quitting = true; Qt.quit() })
        } else if (backend.uploading && !quitting) {
            close.accepted = false
            confirm.ask("Cancel the upload?", "An upload is running. Closing cancels it; you can start it again later.",
                        () => { root.quitting = true; Qt.quit() })
        }
    }

    // ---------------------------------------------------------------- Bounties
    Component {
        id: bountiesPage
        ScrollPage {
            title: "Bounties"
            tools: [
                AppButton {
                    text: "Get the newest board"
                    enabled: backend.boardFetch.state !== "fetching" && !backend.hubDryRun
                    onClicked: backend.refreshBoard()
                }
            ]
            banners: [
                DraftBanner { },
                Banner {
                    header: true
                    visible: backend.runnerError !== ""
                    type: "error"
                    text: backend.runnerError
                },
                Banner {
                    header: true
                    visible: backend.sessionActive
                    type: "info"
                    text: "A session is running."
                    actions: [ AppButton { text: "Go to it"; onClicked: root.show(sessionPage) } ]
                },
                Banner {
                    header: true
                    visible: backend.boardFetch.state === "error" || backend.boardFetch.state === "ok"
                    type: backend.boardFetch.state === "ok" ? "positive" : "info"
                    text: backend.boardFetch.text || ""
                }
            ]

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: "Each bounty is a short round, about 4 minutes, of what the hand tracker needs most. "
                      + "Windows appear in front of you in the headset and you tap, pinch and grab them as you "
                      + "would real ones, while the cameras record your hands. The most wanted come first, and "
                      + "you can do one again. Afterwards you look over the recording and send it "
                      + (backend.roundConsentKind("bounty") === "testing"
                         ? "in: while the bounties are being tested, to a test dataset, for testing only."
                         : "to the hand dataset.") + (backend.boardUpdated ? " (Board of " + backend.boardUpdated + ".)" : "")
            }

            PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: 80
                visible: bountyRows.count === 0
                text: "No bounties"
                explanation: "The board that came with the recorder is missing (hands/rec/bounties.json)."
            }

            Repeater {
                id: bountyRows
                model: backend.bounties

                ListRow {
                    id: bountyRow
                    required property var modelData
                    enabled: modelData.available === "" && !backend.sessionActive
                    onClicked: root.pickRound(modelData.id)

                    contentItem: RowLayout {
                        spacing: Theme.largeSpacing
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                font.bold: true
                                color: Theme.text
                                text: bountyRow.modelData.title
                                      + (bountyRow.modelData.priority === "high" ? " · wanted most"
                                         : bountyRow.modelData.priority === "low" ? " · low priority" : "")
                                      + (bountyRow.modelData.done === 1 ? " · done"
                                         : bountyRow.modelData.done > 1 ? " · done " + bountyRow.modelData.done + " times" : "")
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                color: Theme.text
                                text: bountyRow.modelData.blurb
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                color: Theme.dimText
                                font.pixelSize: Theme.smallFontSize
                                text: [bountyRow.modelData.minutesText,
                                       bountyRow.modelData.lastText ? "last done " + bountyRow.modelData.lastText : "",
                                       bountyRow.modelData.available].filter(s => s !== "").join(" · ")
                            }
                        }
                        AppButton {
                            text: bountyRow.modelData.done > 0 ? "Record again" : "Record"
                            highlighted: bountyRow.modelData.done === 0
                            Layout.preferredWidth: 200
                            enabled: bountyRow.enabled
                            onClicked: bountyRow.clicked()
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- Welcome
    Component {
        id: welcomePage
        ScrollPage {
            title: "Welcome"
            banners: [ DraftBanner { } ]

            MarkdownText {
                Layout.fillWidth: true
                markdown: backend.consentText
            }

            Separator { Layout.fillWidth: true; Layout.topMargin: Theme.spacing; Layout.bottomMargin: Theme.spacing }

            Banner {
                visible: !backend.needsConsent
                type: "positive"
                text: "You agreed to this text (" + backend.consentAccepted + "). Your contributor id is "
                      + backend.contributor + ": keep it if you might want to withdraw later."
            }
            AppButton {
                visible: !backend.needsConsent
                text: "Copy contributor id"
                onClicked: backend.copy(backend.contributor)
            }
            Banner {
                visible: backend.needsConsent && backend.consentAccepted !== ""
                type: "info"
                text: "This text changed since you last agreed to it. Please read it again; your contributor id stays the same."
            }

            AppCheckBox {
                id: adult
                visible: backend.needsConsent
                text: "I'm 18 or older"
            }
            AppCheckBox {
                id: region
                visible: backend.needsConsent
                text: "I don't live in Illinois, Texas or Washington (USA)"
            }
            AppCheckBox {
                id: agree
                visible: backend.needsConsent
                text: "I agree to the text above"
            }
            FieldLabel {
                visible: backend.needsConsent
                text: "Handedness (optional)"
            }
            AppComboBox {
                id: handed
                visible: backend.needsConsent
                model: backend.handednessChoices
                textRole: "text"
                valueRole: "value"
                Component.onCompleted: currentIndex = Math.max(0, indexOfValue(backend.handedness))
            }
            AppButton {
                Layout.topMargin: Theme.spacing
                visible: backend.needsConsent
                enabled: adult.checked && region.checked && agree.checked
                highlighted: true
                text: "Agree and continue"
                onClicked: {
                    backend.acceptConsent(adult.checked, region.checked, agree.checked, handed.currentValue)
                    if (!backend.needsConsent)
                        root.show(root.roundPicked ? readyPage : bountiesPage)
                }
            }
            AppButton {
                visible: !backend.needsConsent
                highlighted: true
                text: "Continue"
                onClicked: root.show(root.roundPicked ? readyPage : bountiesPage)
            }
        }
    }

    // ---------------------------------------------------------------- Getting ready
    // After the consent: SteamVR, the cameras, hand tracking and the headset panel, each started
    // if it isn't running (backend.getReady); on to Before you start once they all are.
    Component {
        id: readyPage
        ScrollPage {
            id: ready
            title: "Getting ready"
            readonly property bool done: backend.readyState === "ok" && backend.readyRound === root.chosenBounty
            // Later, not while the page stack is still pushing this page
            onDoneChanged: if (done) Qt.callLater(root.show, checklistPage)
            // Each time: a part can stop meanwhile (SteamVR restarted), and when all run it's quick
            Component.onCompleted: {
                if (root.chosenBounty === "")
                    Qt.callLater(root.show, bountiesPage)
                else
                    backend.getReady(root.chosenBounty)
            }
            banners: [
                Banner {
                    header: true
                    visible: backend.readyState === "failed"
                    type: "error"
                    text: backend.readyError
                    actions: [
                        AppButton { text: "Try again"; highlighted: true; onClicked: backend.getReady(root.chosenBounty) },
                        AppButton { text: "Back to Bounties"; onClicked: root.show(bountiesPage) }
                    ]
                }
            ]

            Hint {
                text: "Starting what the round needs. This takes a few seconds; put the headset on if SteamVR "
                      + "isn't running."
            }
            Repeater {
                model: backend.readyParts
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.largeSpacing
                    Item {
                        implicitWidth: 44
                        implicitHeight: 44
                        Busy { anchors.centerIn: parent; running: modelData.state === "busy"; visible: running }
                        Label {
                            anchors.centerIn: parent
                            visible: modelData.state === "ok" || modelData.state === "failed"
                            text: modelData.state === "ok" ? "\u2713" : "\u2715"
                            font.pixelSize: Theme.headingSize
                            font.bold: true
                            color: modelData.state === "ok" ? Theme.positive : Theme.negative
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label {
                            Layout.fillWidth: true
                            font.bold: true
                            color: modelData.state === "" ? Theme.dimText : Theme.text
                            text: modelData.title
                        }
                        Label {
                            Layout.fillWidth: true
                            visible: text !== ""
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.smallFontSize
                            color: modelData.state === "failed" ? Theme.negative : Theme.dimText
                            text: modelData.state === "busy" ? "Starting…" : modelData.state === "" ? "Waiting" : modelData.text
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- Before you start
    Component {
        id: checklistPage
        ScrollPage {
            id: checklist
            title: "Before you start"
            readonly property bool privacyOk: privacy1.checked && privacy2.checked && privacy3.checked
            // The round picked on the Bounties page: a bounty's id, or the testing session's.
            readonly property string bountyId: root.chosenBounty
            readonly property bool isDebug: bountyId === "debug"
            readonly property var bounty: {
                for (const b of backend.bounties)
                    if (b.id === bountyId)
                        return b
                return null
            }
            readonly property bool ready: privacyOk && backend.diskOk && bounty !== null
                                          && backend.runnerError === "" && !backend.sessionActive

            // The bounties use no objects and no controllers.
            function answers() {
                return {
                    objects: [],
                    own_objects: [],
                    controllers: "none",
                    sleeves: sleeves.currentValue,
                    rings: rings.checked,
                    watch: watch.checked,
                    notes: notes.text,
                    privacy: privacyOk,
                    voice: isDebug && voice.checked
                }
            }

            banners: [
                DraftBanner { },
                Banner {
                    header: true
                    visible: backend.runnerError !== ""
                    type: "error"
                    text: backend.runnerError
                },
                Banner {
                    header: true
                    visible: backend.sessionActive
                    type: "info"
                    text: "A session is running."
                    actions: [ AppButton { text: "Go to it"; onClicked: root.show(sessionPage) } ]
                },
                CameraMessage {
                    visible: !backend.sessionActive && (backend.cameraText !== "" || backend.restartingSteamVR)
                }
            ]
            Component.onCompleted: backend.checkCameras()

            SectionHeading { text: "Round"; Layout.topMargin: 0 }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                font.bold: true
                color: Theme.text
                text: checklist.bounty ? checklist.bounty.title : "No round picked yet"
            }
            Hint {
                text: checklist.bounty ? checklist.bounty.blurb
                      : checklist.bountyId ? "This recorder doesn't have that bounty."
                      : "Pick a bounty to record on the Bounties page."
            }
            AppButton {
                text: checklist.bounty ? "Pick another…" : "Pick a bounty…"
                enabled: !backend.sessionActive
                onClicked: root.show(bountiesPage)
            }

            SectionHeading { text: "Light" }
            FieldLabel { text: "The cameras see" }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: backend.lightingMeasured || "Not measured yet"
            }
            FieldLabel { text: "Lighting this round" }
            AppComboBox {
                id: lighting
                model: backend.lightingChoices
                textRole: "text"
                valueRole: "value"
                currentIndex: 0
                onActivated: backend.checkLighting(currentValue)
                Component.onCompleted: backend.checkLighting(currentValue)
            }
            Hint {
                text: "Each round in a different light helps the most: dim, a normal room, daylight. The cameras "
                      + "can't tell daylight on their own (a sunlit room has measured as indoor light), so if "
                      + "sunlight comes into the room, pick Daylight here; dim or a normal room the same way."
            }
            Banner {
                visible: backend.lightingNote !== ""
                type: "warning"
                text: backend.lightingNote
            }
            AppButton {
                visible: backend.lightingNote !== "" || backend.lightingMeasured === ""
                text: "Measure the light again"
                onClicked: backend.checkLighting(lighting.currentValue)
            }

            SectionHeading { text: "You" }
            FieldLabel { text: "Sleeves" }
            AppComboBox {
                id: sleeves
                model: backend.sleeveChoices
                textRole: "text"
                valueRole: "value"
            }
            FieldLabel { text: "Wearing" }
            AppCheckBox { id: rings; text: "Rings" }
            AppCheckBox { id: watch; text: "A watch or bracelet" }
            Hint {
                text: "Wear what you normally do: the dataset needs hands with and without them. This only notes it."
            }
            FieldLabel { text: "Notes (optional)" }
            AppTextField {
                id: notes
                Layout.fillWidth: true
                placeholderText: "anything that helps, e.g. a bandage on a finger"
            }

            SectionHeading { text: "Privacy" }
            FieldLabel { text: "I've checked" }
            AppCheckBox {
                id: privacy1
                text: "I'm facing away from other people, mirrors and windows"
            }
            AppCheckBox {
                id: privacy2
                text: "No papers, photos, screens or other private things are in view"
            }
            AppCheckBox {
                id: privacy3
                text: "Nobody else's face or hands will be in view"
            }

            SectionHeading { text: "Space" }
            FieldLabel { text: "Free space" }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: backend.freeText + " (a round takes about 15 GB, and its export about 12 GB more)"
            }
            Banner {
                visible: !backend.diskOk
                type: "error"
                text: "Not enough free space for a round. Export and delete earlier sessions (Review), "
                      + "or free up space, first."
            }

            SectionHeading { text: "Cameras" }
            FieldLabel { text: "Tracking cameras" }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacing
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    text: backend.camerasIgnored ? "Not checked (--ignore-cameras)"
                          : backend.cameraState === "ok" ? "All four are running."
                          : backend.cameraState === "degraded" ? "Not all running: see the message at the top."
                          : backend.cameraState === "unknown" ? "Couldn't tell (" + backend.cameraSummary.replace(/^unknown: /, "")
                                                                + "). The session checks again when it starts."
                          : "Checking…"
                }
                AppButton {
                    id: cameraDetails
                    visible: backend.cameraEvidence !== ""
                    text: "Details"
                    checkable: true
                    ToolTip.text: "What the check looked at"
                    ToolTip.visible: hovered
                    ToolTip.delay: 600
                }
                AppButton {
                    text: "Check again"
                    enabled: !backend.cameraBusy
                    onClicked: backend.checkCameras()
                }
            }
            Label {
                Layout.fillWidth: true
                visible: cameraDetails.checked && backend.cameraEvidence !== ""
                wrapMode: Text.WrapAnywhere
                font.pixelSize: Theme.smallFontSize
                color: Theme.dimText
                textFormat: Text.PlainText
                text: backend.cameraSummary + "\n" + backend.cameraEvidence
            }

            SectionHeading { visible: checklist.isDebug; text: "Your voice" }
            AppCheckBox {
                id: voice
                visible: checklist.isDebug
                text: "Record my voice (optional)"
            }
            Hint {
                visible: checklist.isDebug
                text: "The headset's microphone records while you do: say what went wrong as it happens, e.g. "
                      + "\"that opened the lazy susan, I didn't mean to\". We turn what you say into notes at "
                      + "those moments. It's sent encrypted with the rest, for testing only. Leave it off if "
                      + "other people can be heard."
            }

            SectionHeading { text: "What will happen" }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: checklist.isDebug
                      ? "Press Start and close the dashboard. Press the button on the right side of the headset "
                        + "to start recording: after a 3-2-1 the panel goes away, and you use Frametop as you "
                        + "always do for up to 3 minutes: point, tap, pinch, drag, scroll. Do what gives you "
                        + "trouble. Frametop's hand tracking stays on, and what it made of your hands is recorded "
                        + "with the cameras.\n\n"
                        + "When the tracking gets something wrong, press the headset button at once: that marks "
                        + "the moment (the panel flashes \"Marked\"). Hold the button to finish early."
                        + (voice.checked ? " Say what went wrong too: the microphone is recording." : "") + "\n\n"
                        + "Nothing leaves the headset. Afterwards you watch it in Review, delete anything you "
                        + "don't want to share, and only then export. It's sent encrypted, for testing only."
                      : "Press Start and close the dashboard. After a few seconds of your hands held up, windows "
                        + "appear in front of you, and a band along the top says what to do. Do it as you would "
                        + "on a real window: tap the lit button, pinch the lit corner, grab the lit edge. The "
                        + "windows don't move or click; a ghost outline shows where to take one, and your hand "
                        + "goes there as if it came along. Some steps ask you to stop short or touch without "
                        + "grabbing: those count just as much.\n\n"
                        + "Each step waits until you're ready: press the button on the right side of the headset, "
                        + "or Next on the Session page. The windows appear where you're facing when you press it. "
                        + "Press it twice to record a step again, or hold it to stop. If a keyboard is connected, "
                        + "this window's keys work too: Space next, P pause, R record the last step again, Esc "
                        + "stop.\n\n"
                        + "Nothing leaves the headset. Afterwards you watch the takes in Review, delete anything "
                        + "you don't want to share, and only then export."
            }
            FieldLabel { text: "Pace" }
            AppCheckBox {
                id: autoAdvance
                text: "Advance by itself (no Next between steps)"
            }
            Hint {
                text: (autoAdvance.checked
                       ? "Each step shows for a few seconds and the next follows by itself. Quicker if you "
                         + "know the steps already. "
                       : "") + "Length: " + backend.planText(checklist.answers(), autoAdvance.checked, false,
                                                         checklist.bountyId) + "."
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Theme.spacing
                spacing: Theme.largeSpacing
                AppButton {
                    text: "Start"
                    highlighted: true
                    Layout.preferredWidth: 200
                    enabled: checklist.ready && !backend.camerasBlockStart && !backend.restartingSteamVR
                    onClicked: {
                        if (backend.startSession(checklist.answers(), lighting.currentValue, autoAdvance.checked,
                                                 false, checklist.bountyId))
                            root.show(sessionPage)
                    }
                }
                Hint {
                    visible: (!checklist.ready || backend.camerasBlockStart) && !backend.sessionActive
                    text: !checklist.bounty ? "Pick a bounty first."
                          : !checklist.privacyOk ? "Tick the three privacy checks to start."
                          : backend.camerasBlockStart ? "The headset's cameras aren't all running: see the message at the top." : ""
                }
            }
        }
    }

    // ---------------------------------------------------------------- Session
    // A hand chip like the panel's: seen (green), lost (orange) or hidden.
    component HandChip: Label {
        property var seen
        visible: seen === true || seen === false || seen === "seen" || seen === "lost"
        readonly property bool ok: seen === true || seen === "seen"
        topPadding: 6
        bottomPadding: 6
        leftPadding: Theme.largeSpacing
        rightPadding: Theme.largeSpacing
        color: Theme.accentText
        font.bold: true
        background: Rectangle {
            radius: height / 2
            color: parent.ok ? Theme.positive : Theme.warning
        }
    }

    // The pose picture as the panel shows it: a right hand as drawn, a left hand flipped,
    // both hands as a flipped copy beside it (DESIGN.md "The pose pictures").
    component PosePicture: Row {
        property string path
        property string mode
        property real side: 180
        spacing: 6
        visible: path !== ""
        Image {
            visible: parent.mode === "both"
            width: visible ? parent.side * 0.75 : 0
            height: width
            source: parent.path ? "file://" + parent.path : ""
            fillMode: Image.PreserveAspectFit
            mirror: true
            smooth: true
            mipmap: true
        }
        Image {
            width: parent.mode === "both" ? parent.side * 0.75 : parent.side
            height: width
            source: parent.path ? "file://" + parent.path : ""
            fillMode: Image.PreserveAspectFit
            mirror: parent.mode === "mirror"
            smooth: true
            mipmap: true
        }
    }

    // Where to hold the hands: a front view (left, centre, right, up, down; the push
    // sections' chest, desk and eye) and how far out (near, mid, far), as on the panel.
    component WhereDiagram: RowLayout {
        id: where
        property string position
        property string distance
        readonly property var cell: ({ centre: [1, 1], center: [1, 1], chest: [1, 1], left: [0, 1],
                                       right: [2, 1], up: [1, 0], eye: [1, 0], down: [1, 2],
                                       desk: [1, 2] })[position] || null
        readonly property int step: ["near", "mid", "far"].indexOf(distance)
        readonly property real unit: 24
        readonly property color accent: "#4cd9ff"
        spacing: Theme.largeSpacing
        visible: cell !== null || step >= 0
        ColumnLayout {
            visible: where.cell !== null
            spacing: 6
            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 3
                spacing: 3
                Repeater {
                    model: 9
                    Rectangle {
                        required property int index
                        width: where.unit * 1.33
                        height: where.unit
                        radius: 3
                        readonly property bool on: where.cell !== null && index === where.cell[1] * 3 + where.cell[0]
                        color: on ? where.accent : Theme.tint(Theme.text, 0.12)
                    }
                }
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Theme.smallFontSize
                color: Theme.dimText
                text: ({ left: "To your left", right: "To your right", up: "Up high", down: "Down low",
                         chest: "Chest height", desk: "Desk height", eye: "Eye level" })[where.position]
                      || "In front"
            }
        }
        ColumnLayout {
            visible: where.step >= 0
            spacing: 6
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: where.unit * 0.6
                height: where.unit * 1.2
                // the head, seen from the side, then the arm's reach
                Rectangle {
                    width: where.unit
                    height: width
                    radius: width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.tint(Theme.text, 0.6)
                }
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        readonly property bool on: index === where.step
                        width: on ? where.unit * 0.8 : where.unit * 0.35
                        height: width
                        radius: width / 2
                        anchors.verticalCenter: parent.verticalCenter
                        color: on ? where.accent : Theme.tint(Theme.text, 0.35)
                    }
                }
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: Theme.smallFontSize
                color: Theme.dimText
                text: ["Close: a hand's length", "Halfway out", "Arm stretched out"][Math.max(0, where.step)]
            }
        }
    }

    Component {
        id: sessionPage
        AppPage {
            id: sessionView
            title: "Session"
            readonly property var st: backend.status
            readonly property string runState: st.state || ""
            readonly property bool waiting: !!st.waiting
            readonly property bool stepMode: st.mode !== "auto"
            readonly property bool showBig: !!st.big && runState !== "paused"
            readonly property bool showSecondsLeft: !waiting && runState !== "countdown" && runState !== "ready"
                                                    && st.seconds_left !== undefined && st.seconds_left !== null
                                                    && st.seconds_left > 0
            function chipShown(seen) {
                return seen === true || seen === false || seen === "seen" || seen === "lost"
            }
            readonly property var stateText: ({
                starting: "Starting…", intro: "Get ready", ready: "Get ready", countdown: "Starting",
                running: "Recording", paused: "Paused", between: "Between sections", done: "Done",
                stopped: "Stopped", error: "Error", nohands: "No hands seen"
            })

            // The keys, when a keyboard is connected (the panel in the headset lists them too).
            Shortcut {
                sequence: "Space"
                enabled: backend.sessionActive
                onActivated: backend.nextStep()
            }
            Shortcut {
                sequence: "P"
                enabled: backend.sessionActive
                onActivated: backend.togglePause()
            }
            Shortcut {
                sequence: "R"
                enabled: backend.sessionActive
                onActivated: backend.redo()
            }
            Shortcut {
                sequence: "S"
                enabled: backend.sessionActive
                onActivated: backend.skipSection()
            }
            Shortcut {
                sequence: "Esc"
                enabled: backend.sessionActive
                onActivated: backend.stopSession()
            }
            Shortcut {
                sequence: "M"
                enabled: backend.sessionActive && !!sessionView.st.debug
                onActivated: backend.markMoment()
            }

            banners: [
                Banner {
                    header: true
                    visible: backend.runnerError !== "" || (sessionView.runState === "error" && sessionView.st.error !== backend.cameraText)
                    type: "error"
                    text: backend.runnerError || ("The session stopped with an error: " + (sessionView.st.error || "unknown"))
                },
                // The camera check stopped the session (at its start, or after a step with no hands).
                CameraMessage {
                    visible: (!backend.sessionActive && sessionView.runState !== "" && backend.cameraText !== "")
                             || backend.restartingSteamVR
                }
            ]

            PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - 160
                visible: sessionView.runState === ""
                text: "No session yet"
                explanation: "Pick a bounty, go through Before you start, then press Start there."
                actionText: "Bounties"
                onTriggered: root.show(bountiesPage)
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pageMargin
                anchors.rightMargin: Theme.pageMargin
                anchors.topMargin: Theme.spacing
                anchors.bottomMargin: Theme.spacing
                visible: sessionView.runState !== ""
                spacing: Theme.spacing

                // The state, the section and step, and whether it records
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.largeSpacing
                    Label {
                        Layout.alignment: Qt.AlignBaseline
                        text: sessionView.stateText[sessionView.runState] || sessionView.runState
                        font.pixelSize: Theme.titleSize
                        font.bold: true
                        color: Theme.text
                    }
                    Label {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBaseline
                        visible: (sessionView.st.section_index || 0) > 0
                        wrapMode: Text.Wrap
                        text: "Section " + sessionView.st.section_index + " of " + sessionView.st.section_count
                              + (sessionView.st.title ? ": " + sessionView.st.title : "")
                              + ((sessionView.st.step_index || 0) > 0 && sessionView.stepMode
                                 ? " · step " + sessionView.st.step_index + " of " + sessionView.st.step_count : "")
                        font.bold: true
                        color: Theme.dimText
                    }
                    Item { Layout.fillWidth: true; visible: (sessionView.st.section_index || 0) <= 0 }
                    Label {
                        Layout.alignment: Qt.AlignBaseline
                        visible: !!sessionView.st.take && sessionView.runState !== "paused"
                                 && (sessionView.runState === "countdown" || sessionView.runState === "running"
                                     || !sessionView.stepMode)
                        text: "● Recording"
                        font.bold: true
                        color: Theme.negative
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.largeSpacing + 8

                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        visible: !!sessionView.st.image || !!sessionView.st.position || !!sessionView.st.distance
                        spacing: Theme.spacing
                        PosePicture {
                            Layout.alignment: Qt.AlignHCenter
                            path: sessionView.st.image || ""
                            mode: sessionView.st.image_mode || ""
                        }
                        Label {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.maximumWidth: 260
                            visible: !!sessionView.st.image && !!sessionView.st.caption
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.dimText
                            font.pixelSize: Theme.smallFontSize
                            text: sessionView.st.caption || ""
                        }
                        WhereDiagram {
                            Layout.alignment: Qt.AlignHCenter
                            position: sessionView.st.position || ""
                            distance: sessionView.st.distance || ""
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: Theme.spacing + 4
                        Label {
                            Layout.fillWidth: true
                            visible: !!sessionView.st.prompt
                            wrapMode: Text.Wrap
                            font.pixelSize: 30
                            color: Theme.text
                            text: sessionView.st.prompt || ""
                        }
                        // A sweep's row of pictures, the lit one framed, as on the panel
                        Row {
                            visible: (sessionView.st.strip || []).length > 0
                            spacing: Theme.spacing + 4
                            Repeater {
                                model: sessionView.st.strip || []
                                Column {
                                    id: cueColumn
                                    required property var modelData
                                    required property int index
                                    readonly property bool lit: index === sessionView.st.cue
                                    spacing: 6
                                    Rectangle {
                                        width: 100
                                        height: width
                                        radius: Theme.radius
                                        color: Theme.tint(Theme.text, 0.06)
                                        border.width: cueColumn.lit ? 4 : 0
                                        border.color: "#4cd9ff"
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            source: cueColumn.modelData.image ? "file://" + cueColumn.modelData.image : ""
                                            fillMode: Image.PreserveAspectFit
                                            mirror: cueColumn.modelData.mode === "mirror"
                                            opacity: cueColumn.lit ? 1 : 0.4
                                            smooth: true
                                            mipmap: true
                                        }
                                    }
                                    Label {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: cueColumn.modelData.label || ""
                                        font.pixelSize: Theme.smallFontSize
                                        font.bold: cueColumn.lit
                                        color: cueColumn.lit ? "#4cd9ff" : Theme.text
                                        opacity: cueColumn.lit ? 1 : 0.6
                                    }
                                }
                            }
                        }
                        // The countdown's 3, 2, 1, then the hold's word, big; the hold's time left beside it
                        RowLayout {
                            spacing: Theme.largeSpacing
                            visible: sessionView.showBig || sessionView.showSecondsLeft
                            Label {
                                Layout.alignment: Qt.AlignBaseline
                                visible: sessionView.showBig
                                text: sessionView.st.big || ""
                                font.pixelSize: 64
                                font.bold: true
                                color: Theme.accent
                            }
                            Label {
                                Layout.alignment: Qt.AlignBaseline
                                visible: sessionView.showSecondsLeft
                                text: Math.ceil(sessionView.st.seconds_left || 0) + " s left"
                                color: Theme.dimText
                            }
                        }
                        AppButton {
                            visible: sessionView.waiting && sessionView.runState !== "paused"
                            focusPolicy: Qt.NoFocus
                            highlighted: true
                            text: sessionView.runState === "nohands" ? "Try again" : "Next"
                            font.pixelSize: 32
                            font.bold: true
                            Layout.preferredWidth: 240
                            Layout.preferredHeight: 76
                            onClicked: backend.nextStep()
                        }
                        Hint {
                            visible: sessionView.waiting && sessionView.runState !== "paused"
                            text: sessionView.runState === "nohands"
                                  ? "Try again starts the same step (Space or the headset button do too). Stop ends the session, "
                                    + "keeping what's recorded."
                                  : (sessionView.st.ready_text || "Ready? Press Space or click Next")
                                    + ". A 3-2-1 countdown starts the recording."
                        }
                    }
                }

                // The step's note, the hand chips and the take
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing
                    visible: !!sessionView.st.note || !!sessionView.st.take
                             || (!!sessionView.st.hands && (sessionView.chipShown(sessionView.st.hands.left)
                                                            || sessionView.chipShown(sessionView.st.hands.right)))
                    Banner {
                        visible: !!sessionView.st.note
                        type: "warning"
                        text: sessionView.st.note || ""
                    }
                    HandChip {
                        text: "Left hand"
                        seen: sessionView.st.hands ? sessionView.st.hands.left : undefined
                    }
                    HandChip {
                        text: "Right hand"
                        seen: sessionView.st.hands ? sessionView.st.hands.right : undefined
                    }
                    Item { Layout.fillWidth: true; visible: !sessionView.st.note }
                    Label {
                        visible: !!sessionView.st.take
                        text: "Take " + (sessionView.st.take || "")
                        color: Theme.dimText
                        font.pixelSize: Theme.smallFontSize
                    }
                }

                Item { Layout.fillHeight: true }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.dimText
                    font.pixelSize: Theme.smallFontSize
                    text: sessionView.st.debug
                          ? "Close the dashboard to record; the panel in the headset hides while you do. "
                            + (sessionView.st.button ? "The button on the right side of the headset: next; while "
                               + "recording, press it to mark a moment the tracking got wrong, hold it to finish. " : "")
                            + "With a keyboard connected: Space: next · M: mark · P: pause or resume · Esc: stop. "
                            + "Stopping keeps what's recorded so far."
                          : "The steps appear on a panel in the headset: close the dashboard to record. "
                          + (sessionView.st.button ? "The button on the right side of the headset: "
                             + (sessionView.stepMode ? "next, " : "") + "pause or resume; twice: record the "
                             + "last step again; hold: stop. To skip a section, open the dashboard again and use the "
                             + "buttons below. "
                             : "To stop, redo a step or skip a section, open the dashboard again and use the "
                             + "buttons below. ")
                          + "With a keyboard connected: "
                          + (sessionView.stepMode ? "Space: next · " : "")
                          + "P: pause or resume · R: record the last step again · S: skip section · Esc: stop. "
                          + "Stopping keeps what's recorded so far."
                }
                RowLayout {
                    spacing: Theme.spacing
                    // No keyboard focus on the buttons, so Space always reaches the shortcut.
                    AppButton {
                        visible: !backend.sessionActive
                        focusPolicy: Qt.NoFocus
                        text: "Another round…"
                        onClicked: root.show(bountiesPage)
                    }
                    AppButton {
                        visible: backend.sessionActive
                        focusPolicy: Qt.NoFocus
                        text: sessionView.runState === "paused" ? "Resume" : "Pause"
                        Layout.preferredWidth: 150
                        onClicked: backend.togglePause()
                    }
                    AppButton {
                        visible: backend.sessionActive && !!sessionView.st.debug
                        enabled: sessionView.runState === "running"
                        focusPolicy: Qt.NoFocus
                        text: "Mark" + (sessionView.st.marks ? " · " + sessionView.st.marks : "")
                        onClicked: backend.markMoment()
                    }
                    AppButton {
                        visible: backend.sessionActive && !!sessionView.st.debug
                        enabled: sessionView.runState === "running"
                        focusPolicy: Qt.NoFocus
                        text: "Finish"
                        onClicked: backend.finishSession()
                    }
                    AppButton {
                        visible: backend.sessionActive && !sessionView.st.debug
                        enabled: !!sessionView.st.can_redo
                        focusPolicy: Qt.NoFocus
                        text: "Redo step"
                        onClicked: backend.redo()
                    }
                    AppButton {
                        visible: backend.sessionActive && !sessionView.st.debug
                        focusPolicy: Qt.NoFocus
                        text: "Skip section"
                        onClicked: backend.skipSection()
                    }
                    AppButton {
                        visible: backend.sessionActive
                        focusPolicy: Qt.NoFocus
                        text: "Stop"
                        Layout.preferredWidth: 150
                        onClicked: backend.stopSession()
                    }
                    AppButton {
                        visible: !backend.sessionActive && backend.sessionId !== "" && !backend.exporting
                        focusPolicy: Qt.NoFocus
                        highlighted: true
                        text: "Export and upload"
                        onClicked: {
                            root.chosenSession = backend.sessionId
                            root.sendAfterExport = true
                            backend.exportSession(backend.sessionId, false)
                            root.show(exportPage)
                        }
                    }
                    AppButton {
                        visible: !backend.sessionActive && backend.sessionId !== ""
                        focusPolicy: Qt.NoFocus
                        text: "Review this session"
                        onClicked: {
                            root.show(reviewPage)
                            pageStack.push(takesPage, { session: backend.sessionId })
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- Review
    // A row of the Review and Takes lists.
    component ListRow: ItemDelegate {
        id: listRow
        Layout.fillWidth: true
        padding: Theme.spacing + 4
        leftPadding: Theme.largeSpacing
        rightPadding: Theme.spacing + 4
        background: Rectangle {
            radius: Theme.radius
            color: listRow.down ? Theme.pressed : listRow.hovered ? Theme.hover : Theme.surface
            border.width: 1
            border.color: Theme.separator
        }
    }

    Component {
        id: reviewPage
        ScrollPage {
            id: reviewView
            title: "Review"
            tools: [ AppButton { text: "Refresh"; onClicked: backend.refreshSessions() } ]

            PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: 120
                visible: sessionRows.count === 0
                text: "No sessions yet"
                explanation: "Recorded sessions appear here, to watch and trim before you export them."
            }

            Repeater {
                id: sessionRows
                model: backend.sessions

                ListRow {
                    id: sessionRow
                    required property var modelData
                    onClicked: pageStack.push(takesPage, { session: modelData.id })

                    contentItem: RowLayout {
                        spacing: Theme.largeSpacing
                        // Recording now: a red dot.
                        Rectangle {
                            implicitWidth: 18
                            implicitHeight: 18
                            radius: 9
                            color: sessionRow.modelData.active ? Theme.negative : Theme.tint(Theme.text, 0.25)
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: sessionRow.modelData.label + (sessionRow.modelData.active ? " (recording)" : "")
                                      + (sessionRow.modelData.dry_run ? " (dry run)" : "")
                                font.bold: true
                                color: Theme.text
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                color: Theme.dimText
                                font.pixelSize: Theme.smallFontSize
                                text: root.plural(sessionRow.modelData.takes, "take") + " · " + sessionRow.modelData.sizeText
                                      + (sessionRow.modelData.statusText ? " · " + sessionRow.modelData.statusText : "")
                                      + (sessionRow.modelData.lightingText ? " · " + sessionRow.modelData.lightingText : "")
                                      + (sessionRow.modelData.export_stale ? " · changed since its export"
                                         : sessionRow.modelData.exported ? " · exported (" + sessionRow.modelData.exportText + ")" : "")
                            }
                        }
                        AppButton {
                            text: "Delete session"
                            enabled: !sessionRow.modelData.active
                            onClicked: {
                                const sid = sessionRow.modelData.id
                                confirm.ask("Delete this session?",
                                            "The session of " + sessionRow.modelData.label + " (" + root.plural(sessionRow.modelData.takes, "take")
                                            + ", " + sessionRow.modelData.sizeText + ") and its export are deleted from the "
                                            + "headset for good.",
                                            () => {
                                                if (pageStack.depth > 1)
                                                    pageStack.pop(pageStack.get(0))
                                                backend.deleteSession(sid)
                                            })
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: takesPage
        ScrollPage {
            id: takesView
            property string session: ""
            property var rows: backend.takeList(session)
            title: "Takes"

            Connections {
                target: backend
                function onSessionsChanged() { takesView.rows = backend.takeList(takesView.session) }
            }

            PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: 120
                visible: takeRows.count === 0
                text: "No takes in this session"
            }

            Repeater {
                id: takeRows
                model: takesView.rows

                ListRow {
                    id: takeRow
                    required property var modelData
                    onClicked: pageStack.push(viewerPage, { session: takesView.session, take: modelData.id })

                    contentItem: RowLayout {
                        spacing: Theme.largeSpacing
                        Rectangle {
                            Layout.preferredWidth: 136
                            Layout.preferredHeight: 102
                            radius: 4
                            color: Theme.background
                            Image {
                                anchors.fill: parent
                                anchors.margins: 3
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                source: takeRow.modelData.sets > 0
                                        ? "image://frames/thumb/" + takesView.session + "/" + takeRow.modelData.id : ""
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                text: takeRow.modelData.title
                                font.bold: true
                                color: Theme.text
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                color: Theme.dimText
                                font.pixelSize: Theme.smallFontSize
                                text: takeRow.modelData.status + " · " + takeRow.modelData.durationText + " · "
                                      + takeRow.modelData.sets + " sets"
                                      + (takeRow.modelData.deleted_sets ? " (" + takeRow.modelData.deleted_sets + " deleted)" : "")
                                      + " · " + takeRow.modelData.sizeText
                            }
                        }
                        AppButton {
                            text: "Delete take"
                            onClicked: {
                                const take = takeRow.modelData.id
                                confirm.ask("Delete this take?",
                                            "\"" + takeRow.modelData.title + "\" (" + takeRow.modelData.durationText
                                            + ") is deleted from the headset for good.",
                                            () => {
                                                if (pageStack.currentItem !== takesView)
                                                    pageStack.pop(takesView)
                                                backend.deleteTake(takesView.session, take)
                                            })
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: viewerPage
        AppPage {
            id: viewer
            property string session: ""
            property string take: ""
            property var info: backend.takeInfo(session, take)
            property int index: 0
            property int markStart: -1
            property int markEnd: -1
            title: info.title
            readonly property bool deletedHere: isDeleted(index)

            function step(n) {
                index = Math.max(0, Math.min(info.count - 1, index + n))
            }
            function isDeleted(i) {
                for (const r of info.ranges)
                    if (i >= r[0] && i <= r[1] && r[0] >= 0)
                        return true
                return false
            }
            function deleteMarked() {
                backend.deleteRange(session, take, markStart, markEnd)
                markStart = markEnd = -1
                info = backend.takeInfo(session, take)
            }

            Connections {
                target: backend
                function onSessionsChanged() { viewer.info = backend.takeInfo(viewer.session, viewer.take) }
            }
            StackView.onActivated: keys.forceActiveFocus()

            // Keyboard stepping: arrows one set, Page Up/Down ten, Home/End, [ and ] mark a range,
            // Delete deletes it.
            Item {
                id: keys
                focus: true
                Component.onCompleted: forceActiveFocus()
                Keys.onPressed: event => {
                    const k = event.key
                    if (k === Qt.Key_Left) viewer.step(-1)
                    else if (k === Qt.Key_Right) viewer.step(1)
                    else if (k === Qt.Key_PageUp) viewer.step(-10)
                    else if (k === Qt.Key_PageDown) viewer.step(10)
                    else if (k === Qt.Key_Home) viewer.index = 0
                    else if (k === Qt.Key_End) viewer.index = Math.max(0, viewer.info.count - 1)
                    else if (k === Qt.Key_BracketLeft) viewer.markStart = viewer.index
                    else if (k === Qt.Key_BracketRight) viewer.markEnd = viewer.index
                    else if (k === Qt.Key_Delete && viewer.markStart >= 0 && viewer.markEnd >= 0) viewer.deleteMarked()
                    else return
                    event.accepted = true
                }
            }

            PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - 160
                visible: viewer.info.count === 0
                text: "This take has no frame sets"
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.pageMargin
                anchors.rightMargin: Theme.pageMargin
                anchors.topMargin: Theme.spacing
                anchors.bottomMargin: Theme.spacing
                visible: viewer.info.count > 0
                spacing: Theme.spacing

                Image {
                    id: frame
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    cache: false
                    retainWhileLoading: true
                    source: viewer.info.count > 0
                            ? "image://frames/set/" + viewer.session + "/" + viewer.take + "/" + viewer.index : ""
                    MouseArea { anchors.fill: parent; onClicked: keys.forceActiveFocus() }

                    Rectangle {
                        visible: viewer.deletedHere
                        x: (frame.width - frame.paintedWidth) / 2
                        y: (frame.height - frame.paintedHeight) / 2
                        width: frame.paintedWidth
                        height: frame.paintedHeight
                        color: Qt.rgba(0.8, 0, 0, 0.35)
                        Label {
                            anchors.centerIn: parent
                            text: "Deleted: not exported"
                            color: "white"
                            font.pixelSize: Theme.headingSize
                            font.bold: true
                        }
                    }
                }

                // The slider, with the deleted ranges (red) and the marked range (blue) under it.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: slider.implicitHeight + 8
                    Repeater {
                        model: viewer.info.ranges
                        Rectangle {
                            required property var modelData
                            visible: modelData[0] >= 0
                            readonly property real unit: (slider.availableWidth) / Math.max(1, viewer.info.count - 1)
                            x: slider.leftPadding + modelData[0] * unit - 3
                            width: Math.max(6, (modelData[1] - modelData[0]) * unit + 6)
                            y: slider.topPadding + slider.availableHeight / 2 + 10
                            height: 6
                            radius: 3
                            color: Theme.negative
                        }
                    }
                    Rectangle {
                        visible: viewer.markStart >= 0
                        readonly property int last: viewer.markEnd >= 0 ? viewer.markEnd : viewer.index
                        readonly property real unit: (slider.availableWidth) / Math.max(1, viewer.info.count - 1)
                        x: slider.leftPadding + Math.min(viewer.markStart, last) * unit - 3
                        width: Math.abs(last - viewer.markStart) * unit + 6
                        y: slider.topPadding + slider.availableHeight / 2 - 16
                        height: 6
                        radius: 3
                        color: Theme.accent
                    }
                    AppSlider {
                        id: slider
                        anchors.left: parent.left
                        anchors.right: parent.right
                        focusPolicy: Qt.NoFocus
                        from: 0
                        to: Math.max(0, viewer.info.count - 1)
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: viewer.index
                        onMoved: viewer.index = Math.round(value)
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.text
                        text: "Set " + (viewer.index + 1) + " of " + viewer.info.count + " · "
                              + backend.setTime(viewer.session, viewer.take, viewer.index)
                    }
                    AppButton {
                        focusPolicy: Qt.NoFocus
                        text: viewer.markStart >= 0 ? "Start: " + (viewer.markStart + 1) : "Mark start"
                        onClicked: viewer.markStart = viewer.index
                    }
                    AppButton {
                        focusPolicy: Qt.NoFocus
                        text: viewer.markEnd >= 0 ? "End: " + (viewer.markEnd + 1) : "Mark end"
                        onClicked: viewer.markEnd = viewer.index
                    }
                    AppButton {
                        focusPolicy: Qt.NoFocus
                        enabled: viewer.markStart >= 0 && viewer.markEnd >= 0
                        text: "Delete range"
                        onClicked: viewer.deleteMarked()
                    }
                    AppButton {
                        focusPolicy: Qt.NoFocus
                        visible: viewer.markStart >= 0 || viewer.markEnd >= 0
                        text: "Clear marks"
                        onClicked: viewer.markStart = viewer.markEnd = -1
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: Theme.spacing
                    visible: viewer.info.ranges.length > 0
                    Label {
                        text: "Deleted:"
                        height: Theme.controlHeight
                        verticalAlignment: Text.AlignVCenter
                        color: Theme.text
                    }
                    Repeater {
                        model: viewer.info.ranges
                        AppButton {
                            required property var modelData
                            required property int index
                            focusPolicy: Qt.NoFocus
                            text: (modelData[0] < 0 ? "a range with no sets"
                                   : "sets " + (modelData[0] + 1) + " to " + (modelData[1] + 1)) + ": restore"
                            onClicked: backend.restoreRange(viewer.session, viewer.take, index)
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: Theme.dimText
                    font.pixelSize: Theme.smallFontSize
                    text: "← → step one set, Page Up/Down ten, Home/End. [ and ] mark a range's start and end, "
                          + "Delete deletes it. Deleted sets stay on the headset until export, which leaves them out."
                }
            }
        }
    }

    // ---------------------------------------------------------------- Export
    Component {
        id: exportPage
        ScrollPage {
            id: exportView
            title: "Export"
            property bool worn: backend.headsetWorn()
            readonly property var chosen: {
                const list = backend.sessions
                for (const s of list)
                    if (s.id === sessionBox.currentValue)
                        return s
                return null
            }

            Timer {
                interval: 5000
                running: true
                repeat: true
                onTriggered: exportView.worn = backend.headsetWorn()
            }

            banners: [
                DraftBanner { },
                Banner {
                    header: true
                    visible: root.sendAfterExport
                    type: "info"
                    text: "Exporting your session: the Upload page follows by itself once it's done."
                },
                Banner {
                    header: true
                    visible: exportView.worn && backend.exporting
                    type: "info"
                    text: "Exporting keeps the processor busy for a few minutes, so VR may stutter a little until "
                          + "it's done. You can keep using the headset meanwhile."
                },
                Banner {
                    header: true
                    visible: !backend.zstdFound
                    type: "error"
                    text: "zstd isn't installed on this system, so nothing can be exported."
                }
            ]

            FieldLabel { text: "Session"; Layout.topMargin: 0 }
            AppComboBox {
                id: sessionBox
                Layout.fillWidth: true
                Layout.maximumWidth: 520
                model: backend.sessions
                textRole: "label"
                valueRole: "id"
                enabled: !backend.exporting
                Component.onCompleted: {
                    const i = indexOfValue(root.chosenSession)
                    currentIndex = i >= 0 ? i : (count > 0 ? 0 : -1)
                }
                onActivated: root.chosenSession = currentValue
            }
            FieldLabel { text: "Recorded"; visible: exportView.chosen !== null }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: exportView.chosen !== null
                text: exportView.chosen ? root.plural(exportView.chosen.takes, "take") + ", " + exportView.chosen.sizeText : ""
            }
            FieldLabel { text: "Export"; visible: exportView.chosen !== null }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                visible: exportView.chosen !== null
                text: !exportView.chosen ? ""
                      : exportView.chosen.export_stale ? "changed since it was exported: export it again"
                      : exportView.chosen.exported ? "ready, " + exportView.chosen.exportText : "not exported yet"
            }
            RowLayout {
                Layout.topMargin: Theme.spacing
                spacing: Theme.spacing
                AppButton {
                    text: backend.exporting ? "Exporting…"
                          : exportView.chosen && exportView.chosen.exported ? "Export again" : "Export"
                    highlighted: !(exportView.chosen && exportView.chosen.exported)
                    Layout.minimumWidth: 200
                    enabled: exportView.chosen !== null && !backend.exporting && backend.zstdFound
                             && !exportView.chosen.active
                    onClicked: backend.exportSession(exportView.chosen.id, false)
                }
                // Shows the moment Export is pressed: the first progress can take a few seconds.
                Busy {
                    visible: backend.exporting
                    running: visible
                }
                AppButton {
                    visible: backend.exporting
                    text: "Cancel"
                    onClicked: { root.sendAfterExport = false; backend.cancelExport() }
                }
            }
            FieldLabel { text: "Progress"; visible: backend.exporting }
            ProgressTrack {
                visible: backend.exporting
                fraction: Math.max(0, Math.min(1, backend.exportFraction))
            }
            Label {
                Layout.fillWidth: true
                visible: backend.exportText !== "" && (backend.exporting || backend.exportSessionId === sessionBox.currentValue)
                wrapMode: Text.WrapAnywhere
                text: backend.exportText
                color: Theme.text
            }
            RowLayout {
                visible: exportView.chosen !== null && exportView.chosen.exported && !backend.exporting
                spacing: Theme.spacing
                AppButton {
                    text: "Upload"
                    highlighted: true
                    Layout.minimumWidth: 200
                    onClicked: root.show(uploadPage)
                }
                AppButton {
                    text: "Delete export"
                    onClicked: {
                        const sid = exportView.chosen.id
                        confirm.ask("Delete this export?", "The export is deleted; the session's recordings stay.",
                                    () => backend.deleteExport(sid))
                    }
                }
            }

            footer: Rectangle {
                color: Theme.surface
                implicitHeight: exportNote.implicitHeight
                Separator { width: parent.width }
                Label {
                    id: exportNote
                    width: parent.width
                    padding: Theme.spacing + 4
                    leftPadding: Theme.pageMargin
                    rightPadding: Theme.pageMargin
                    wrapMode: Text.Wrap
                    color: Theme.dimText
                    font.pixelSize: Theme.smallFontSize
                    text: "Export leaves out the ranges you deleted, compresses the rest and adds a manifest and "
                          + "checksums, in " + backend.exportsDir + ". It runs at the lowest priority "
                          + "and takes a few minutes per round; the headset stays awake until it's done. Nothing is "
                          + "uploaded until you press Upload on the Upload page."
                }
            }
        }
    }

    // ---------------------------------------------------------------- Upload
    Component {
        id: uploadPage
        ScrollPage {
            id: uploadView
            title: "Upload"
            readonly property var exported: backend.sessions.filter(s => s.exported)
            readonly property string session: exportBox.currentIndex >= 0 ? exportBox.currentValue || "" : ""
            readonly property var chosen: exportBox.currentIndex >= 0 && exportBox.currentIndex < exported.length
                                          ? exported[exportBox.currentIndex] : null
            readonly property var up: backend.upload
            readonly property var upError: up.error || ({})
            readonly property var upResult: up.result || ({})
            // The upload shown is this export's (the window keeps the last one's result).
            readonly property bool mine: up.session === session
            property var info: ({ previous: {}, uploads: 0 })
            readonly property bool loggedIn: backend.login.state === "ok"
            // Why Upload is off, or "" when it can go.
            readonly property string blocked: {
                if (session === "") return "Choose an export"
                if (chosen && chosen.export_stale) return "Export the session again first"
                if (backend.exporting) return "Wait for the export to finish"
                if (backend.uploading) return ""
                if (backend.hubDryRun) return ""
                if (!backend.uploadAllowedFor(session)) return "Contributions aren't open yet"
                if (!loggedIn) return "Log in first (step 2)"
                return ""
            }

            function refreshInfo() { info = backend.uploadInfo(session) }
            onSessionChanged: refreshInfo()
            Connections {
                target: backend
                function onSessionsChanged() { uploadView.refreshInfo() }
            }
            Component.onCompleted: {
                refreshInfo()
                if (backend.login.state === "unknown") backend.checkLogin()
            }

            function startUpload() {
                if (info.previous && info.previous.export_sha)
                    confirm.ask("Upload this export again?",
                                "It was uploaded on " + info.previous.uploaded + " (" + (info.previous.pr_url || "no link")
                                + "). Uploading it again opens a second pull request.",
                                () => backend.startUpload(uploadView.session, true))
                else
                    backend.startUpload(session, false)
            }

            banners: [
                DraftBanner { },
                Banner {
                    header: true
                    visible: backend.hubDryRun
                    type: "info"
                    text: "Dry run (--hub-dry-run): Upload checks the export and lists what it would send. "
                          + "Nothing goes over the network."
                },
                Banner {
                    header: true
                    visible: backend.textsDraft && backend.allowUploadSet && !backend.hubDryRun
                    type: "warning"
                    text: "Rehearsal: FT_HANDREC_ALLOW_UPLOAD=1 allows uploads to " + backend.datasetFor(uploadView.session)
                          + " while the texts are drafts."
                }
            ]

            PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: 120
                visible: uploadView.exported.length === 0
                text: "Nothing exported yet"
                explanation: "Review a session, then export it. It can be uploaded from here."
                actionText: "Export"
                onTriggered: root.show(exportPage)
            }

            ColumnLayout {
                Layout.fillWidth: true
                visible: uploadView.exported.length > 0
                spacing: Theme.spacing + 4

                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    linkColor: Theme.accent
                    color: Theme.text
                    text: "Your export goes to <a href=\"" + backend.datasetUrlFor(uploadView.session) + "\">"
                          + backend.datasetFor(uploadView.session) + "</a> as a "
                          + "pull request from your own Hugging Face account. Nothing is published until the "
                          + "maintainer has checked it."
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                // 1. The export
                Heading { text: "1. Choose the export" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.largeSpacing
                    AppComboBox {
                        id: exportBox
                        Layout.fillWidth: true
                        Layout.maximumWidth: 520
                        model: uploadView.exported
                        textRole: "label"
                        valueRole: "id"
                        enabled: !backend.uploading
                        Component.onCompleted: currentIndex = Math.max(0, indexOfValue(root.chosenSession))
                        onActivated: root.chosenSession = currentValue
                    }
                    Label {
                        color: Theme.dimText
                        text: uploadView.chosen ? uploadView.chosen.exportText : ""
                    }
                }
                Banner {
                    visible: uploadView.chosen !== null && uploadView.chosen.export_stale
                    type: "warning"
                    text: "This session changed since it was exported. Export it again so the upload has your latest deletions."
                }
                Banner {
                    visible: uploadView.session !== "" && uploadView.info.previous.export_sha !== undefined
                    type: "info"
                    text: "This export was uploaded on " + (uploadView.info.previous.uploaded || "") + ": "
                          + (uploadView.info.previous.pr_url || "") + ". There's no need to upload it again."
                }

                // 2. The login: Log in opens Hugging Face in the browser, where the person approves
                // it. The token goes from there to hub.py, never into this window. The browser may
                // not be usable in the headset: the link and the code work from a phone too.
                Heading { text: "2. Log in to Hugging Face" }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing + 4
                    visible: loginState !== "waiting"
                    readonly property string loginState: backend.login.state
                    Label {
                        visible: parent.loginState === "ok"
                        text: "✓"
                        font.pixelSize: Theme.headingSize
                        font.bold: true
                        color: Theme.positive
                    }
                    Busy {
                        visible: ["checking", "starting", "unknown"].indexOf(parent.loginState) >= 0
                        running: visible
                    }
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: Theme.text
                        text: parent.loginState === "dry" ? "Not needed for a dry run."
                              : parent.loginState === "unknown" ? "Checking your login"
                              : parent.loginState === "none"
                                ? "Press Log in. Hugging Face opens in a browser, and this page shows its link and a "
                                  + "code: sign in, or make a free account, then enter the code. You can open the "
                                  + "link on your phone or computer instead."
                              : backend.login.text || ""
                    }
                    AppButton {
                        visible: ["none", "read", "error", "ok"].indexOf(parent.loginState) >= 0
                        text: parent.loginState === "ok" ? "Use another account" : "Log in"
                        flat: parent.loginState === "ok"
                        highlighted: parent.loginState !== "ok"
                        enabled: !backend.uploading
                        onClicked: backend.logIn()
                    }
                    AppButton {
                        visible: parent.loginState === "error"
                        text: "Check again"
                        onClicked: backend.checkLogin()
                    }
                }
                Banner {
                    visible: backend.login.state === "waiting"
                    type: "info"
                    text: "Hugging Face should be opening in a browser. If you can't use it in the headset, open the "
                          + "link below on your phone or computer instead and enter the code there. Sign in, or make "
                          + "a free account, enter the code and approve the login. If it asks about organizations, "
                          + "leave them unticked. The code works for "
                          + Math.round((backend.login.expires_in || 300) / 60) + " minutes; this page carries on "
                          + "by itself once you've approved."
                    actions: [
                        AppButton { text: "Open again"; onClicked: Qt.openUrlExternally(backend.login.url) },
                        AppButton { text: "Copy code"; onClicked: backend.copy(backend.login.code) },
                        AppButton { text: "Cancel"; onClicked: backend.cancelLogin() }
                    ]
                }
                // The code, and the link to type it in on: selectable, big enough to read off and
                // type into a phone.
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: backend.login.state === "waiting"
                    spacing: 4
                    FieldLabel { text: "Code"; Layout.topMargin: 0 }
                    TextEdit {
                        text: backend.login.code || ""
                        readOnly: true
                        selectByMouse: true
                        font.family: "monospace"
                        font.pixelSize: 52
                        font.bold: true
                        font.letterSpacing: 4
                        color: Theme.text
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                    }
                    FieldLabel { text: "Link" }
                    TextEdit {
                        Layout.fillWidth: true
                        text: backend.login.url || ""
                        readOnly: true
                        selectByMouse: true
                        wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                        font.pixelSize: 30
                        color: Theme.accent
                        selectionColor: Theme.accent
                        selectedTextColor: Theme.accentText
                    }
                }

                // 3. The upload
                Heading { text: "3. Upload" }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    textFormat: Text.StyledText
                    linkColor: Theme.accent
                    color: Theme.text
                    text: "The first time, accept the dataset's terms on <a href=\"" + backend.datasetUrlFor(uploadView.session)
                          + "\">its page</a>. Upload checks the export, opens your pull request, then sends the files."
                    onLinkActivated: link => Qt.openUrlExternally(link)
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing
                    AppButton {
                        text: backend.uploading ? "Uploading…" : backend.hubDryRun ? "Upload (dry run)" : "Upload"
                        highlighted: true
                        Layout.minimumWidth: 200
                        enabled: uploadView.blocked === "" && !backend.uploading
                        onClicked: uploadView.startUpload()
                    }
                    Busy {
                        visible: backend.uploading
                        running: visible
                    }
                    AppButton {
                        visible: backend.uploading
                        text: "Cancel"
                        onClicked: backend.cancelUpload()
                    }
                    Hint {
                        visible: !backend.uploading && uploadView.blocked !== ""
                        text: uploadView.blocked
                    }
                }

                // Progress: a share while the export is checked, a sweeping bar while it's sent
                // (huggingface_hub doesn't report progress).
                ProgressTrack {
                    visible: backend.uploading
                    fraction: uploadView.up.fraction === undefined ? -1 : uploadView.up.fraction
                }
                Label {
                    Layout.fillWidth: true
                    visible: uploadView.mine && (uploadView.up.text || "") !== ""
                             && (backend.uploading || uploadView.up.phase === "failed" && uploadView.upError.kind === "cancelled")
                    wrapMode: Text.Wrap
                    color: Theme.text
                    text: uploadView.up.text || ""
                }

                // The pull request is open and the files are on their way: time to plug in.
                Banner {
                    visible: backend.uploading && uploadView.mine && (uploadView.up.pr_url || "") !== ""
                    type: "positive"
                    text: "Your pull request is open: " + (uploadView.up.pr_url || "") + ". The files are uploading "
                          + "to it now, which can take a while. Plug in the headset and leave it plugged in until "
                          + "this page says Uploaded. You can take the headset off: it stays awake until the upload "
                          + "is done. Keep the Hand Recorder open."
                    actions: [
                        AppButton { text: "Open"; onClicked: Qt.openUrlExternally(uploadView.up.pr_url) },
                        AppButton { text: "Copy link"; onClicked: backend.copy(uploadView.up.pr_url) }
                    ]
                }
                Banner {
                    visible: !backend.uploading && uploadView.mine && uploadView.up.phase === "done"
                    type: "positive"
                    text: uploadView.upResult.dry_run
                          ? "Dry run: the export passed its checks. It would go to " + uploadView.upResult.repo + "/"
                            + uploadView.upResult.path_in_repo + " (" + uploadView.upResult.files + " files). Nothing was sent."
                          : "Uploaded. Your pull request: " + (uploadView.upResult.pr_url || "")
                            + ". The maintainer reviews it before it joins the dataset."
                    showActions: !!uploadView.upResult.pr_url
                    actions: [
                        AppButton { text: "Open"; onClicked: Qt.openUrlExternally(uploadView.upResult.pr_url) },
                        AppButton { text: "Copy link"; onClicked: backend.copy(uploadView.upResult.pr_url) }
                    ]
                }
                Banner {
                    visible: !backend.uploading && uploadView.mine && uploadView.up.phase === "failed"
                             && uploadView.upError.kind !== "cancelled"
                    type: "error"
                    text: (uploadView.upError.text || "")
                          + ((uploadView.upError.errors || []).length ? "\n\n• " + uploadView.upError.errors.join("\n• ") : "")
                    showActions: !!uploadView.upError.link
                    actions: [
                        AppButton { text: "Open"; onClicked: Qt.openUrlExternally(uploadView.upError.link) }
                    ]
                }
                TextArea {
                    Layout.fillWidth: true
                    visible: uploadView.mine && (uploadView.up.log || "") !== ""
                    readOnly: true
                    selectByMouse: true
                    wrapMode: Text.WrapAnywhere
                    font.family: "monospace"
                    font.pixelSize: 16
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.accentText
                    padding: Theme.spacing
                    text: uploadView.up.log || ""
                    background: Rectangle {
                        radius: Theme.radius
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.separator
                    }
                }

                Separator {
                    Layout.fillWidth: true
                    Layout.topMargin: Theme.spacing
                    visible: uploadView.session !== ""
                }
                MarkdownText {
                    Layout.fillWidth: true
                    visible: uploadView.session !== ""
                    markdown: backend.uploadText(uploadView.session)
                }
            }
        }
    }
}
