import QtQuick 2.9
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import MuseScore 3.0
import FileIO 3.0

MuseScore {
    id: plugin
    title: "Pulso y Púa"
    description: "Configuración de Tremolos y SoundFonts para bandurria y laúd / Tremolo and SoundFont configuration for bandurria and lute"
    version: "2.0.4"
    pluginType: "dialog"
    width: 650
    height: 700

    // Common properties
    property bool isSpanish: false
    property bool hasSpannersAPI: false  // Whether curScore.spanners is available

    // Add Tremolo properties
    property var minDurationValue: 0.375
    property bool hasSelectionAdd: false
    property bool useSelectionAdd: false

    // Articulations that INCREASE velocity
    property var velocityIncreaseArticulations: [597, 598   // articAccentAbove/Below
        , 599, 600   // articAccentStaccatoAbove/Below
        , 603, 604   // articMarcatoAbove/Below
        , 605, 606   // articMarcatoStaccatoAbove/Below
        , 607, 608   // articMarcatoTenutoAbove/Below
        , 609, 610   // articSoftAccentAbove/Below
        , 611, 612   // articSoftAccentStaccatoAbove/Below
        , 613, 614   // articSoftAccentTenutoAbove/Below
        , 615, 616   // articSoftAccentTenutoStaccatoAbove/Below
        , 628, 629   // articTenutoAccentAbove/Below
        , 2515, 2516  // pluckedSnapPizzicatoAbove/Below
    ]

    // Staccato articulations (any variant that includes staccato behavior)
    property var staccatoArticulations: [623, 624   // articStaccatoAbove/Below
        , 617, 618   // articStaccatissimoAbove/Below
        , 619, 620   // articStaccatissimoStrokeAbove/Below
        , 621, 622   // articStaccatissimoWedgeAbove/Below
        , 599, 600   // articAccentStaccatoAbove/Below
        , 605, 606   // articMarcatoStaccatoAbove/Below
        , 611, 612   // articSoftAccentStaccatoAbove/Below
        , 615, 616   // articSoftAccentTenutoStaccatoAbove/Below
        , 631, 632    // articTenutoStaccatoAbove/Below
    ]

    // Trill and trill-related articulations (should be disabled when adding tremolo)
    property var trillArticulations: [2210       // ornamentPrecompAppoggTrill
        , 2211       // ornamentPrecompAppoggTrillSuffix
        , 2214       // ornamentPrecompCadenceUpperPrefixTurn (includes trill)
        , 2225       // ornamentPrecompSlideTrillBach
        , 2226       // ornamentPrecompSlideTrillDAnglebert
        , 2227       // ornamentPrecompSlideTrillMarpurg
        , 2228       // ornamentPrecompSlideTrillMuffat
        , 2229       // ornamentPrecompSlideTrillSuffixMuffat
        , 2230       // ornamentPrecompTrillLowerSuffix
        , 2231       // ornamentPrecompTrillSuffixDandrieu
        , 2232       // ornamentPrecompTrillWithMordent
        , 2233       // ornamentPrecompTurnTrillBach
        , 2234       // ornamentPrecompTurnTrillDAnglebert
        , 2244       // ornamentShortTrill
        , 2251        // ornamentTrill
    ]

    // Remove Tremolo properties
    property bool hasSelectionRemove: false
    property bool useSelectionRemove: false

    // SoundFont Check properties
    property string userSoundFontsDir: ""
    property string userPluginsDir: ""
    property bool curlAvailable: false
    property bool curlChecked: false  // True after curl availability has been verified
    property var currentProcess: null  // Keep reference to QProcess to prevent garbage collection
    property bool writeBinaryAvailable: false
    property bool directoryExists: false
    property bool remoteUrlValid: false
    property bool checkingRemoteUrl: false

    // List of all managed files (plugin first, then soundfonts)
    property var managedFiles: ["PulsoPua.qml", "Bandurria.sf2", "Bandurria-Con-Tremolo.sf2", "Laud.sf2", "Laud-Con-Tremolo.sf2"]

    // Remote base URL (same for all files)
    property string remoteBaseUrl: "https://raw.githubusercontent.com/manolo/sound-fonts/refs/heads/main"

    // Plugin filename (first in managedFiles)
    property string pluginFilename: managedFiles[0]

    // Status for each file: { found: bool, needsUpdate: bool, localSize: int, remoteSize: int, localDate: string, remoteDate: string, downloading: bool, downloadComplete: bool, downloadError: bool }
    property var filesStatus: ({})

    // Revision counter to force QML to detect changes in filesStatus nested properties
    property int filesStatusRevision: 0

    // Computed properties for backwards compatibility
    property bool pluginUpdateAvailable: filesStatus[pluginFilename] ? filesStatus[pluginFilename].needsUpdate : false
    property bool downloadingPlugin: filesStatus[pluginFilename] ? filesStatus[pluginFilename].downloading : false
    property bool checkingPluginUpdate: false
    property string pluginDownloadStatus: ""

    property bool anyDownloading: false
    property string currentDownloadFile: ""
    property string downloadStatus: ""
    property bool showRestartButton: false
    property var filesToDownload: []
    property int downloadedCount: 0
    property int totalToDownload: 0

    // Compatibility properties (computed from filesStatus)
    property bool soundfontFound: getFoundFilesCount() > 0
    property bool updateAvailable: getUpdatableFilesCount() > 0
    property bool downloading: anyDownloading

    // Use system palette for theme-aware colors
    SystemPalette {
        id: systemPalette
        colorGroup: SystemPalette.Active
    }

    // FileIO for SoundFont checking
    FileIO {
        id: fileChecker
        source: ""
    }

    // Settings for Add Tremolo
    Settings {
        id: settingsAdd
        category: "PulsoPuaAddTremolo"
        property real savedDuration: 0.375
        property bool addTremoloSymbols: true
        property bool setNoteVelocity: true
        property bool disableTiedNotes: true
        property bool disableTremoloPlayback: true
        property bool disableDynamics: true
        property bool disableArticulations: true
        property bool disableOrnaments: true
        property bool disableHairpins: true
    }

    // Settings for Remove Tremolo
    Settings {
        id: settingsRemove
        category: "PulsoPuaRemoveTremolo"
        property bool removeTremolos: true
        property bool restoreVelocity: true
        property bool restoreNotePlayback: true
        property bool restoreDynamics: true
        property bool restoreArticulations: true
        property bool restoreOrnaments: true
        property bool restoreHairpins: true
    }

    // Settings for SoundFont Check
    Settings {
        id: settingsSoundFont
        category: "PulsoPuaSoundfontCheck"
        property string soundFontsDirectory: ""
        property string pluginsDirectory: ""
        property string remoteBaseUrl: ""
    }

    Component.onCompleted: {
        // Detect user language
        var locale = Qt.locale();
        var language = locale.name.substring(0, 2);
        isSpanish = (language === "es");

        // Load saved duration for Add Tremolo
        if (settingsAdd.savedDuration > 0) {
            minDurationValue = settingsAdd.savedDuration;
        }

        // Check for selection (2 or more notes selected)
        if (curScore) {
            // Check if curScore.spanners API is available
            hasSpannersAPI = (typeof curScore.spanners !== 'undefined');

            var selection = curScore.selection;
            hasSelectionAdd = selection && selection.elements && selection.elements.length >= 2;
            hasSelectionRemove = hasSelectionAdd;
        }
        useSelectionAdd = hasSelectionAdd;
        useSelectionRemove = hasSelectionRemove;

        // Initialize SoundFont checking
        // Initialize filesStatus (includes plugin and soundfonts)
        filesStatus = {};

        // Add plugin to filesStatus
        filesStatus[pluginFilename] = {
            found: false,
            needsUpdate: false,
            localSize: 0,
            remoteSize: 0,
            localDate: "",
            remoteDate: "",
            downloading: false,
            downloadComplete: false,
            downloadError: false
        };

        // Add soundfonts to filesStatus
        for (var i = 0; i < managedFiles.length; i++) {
            filesStatus[managedFiles[i]] = {
                found: false,
                needsUpdate: false,
                localSize: 0,
                remoteSize: 0,
                localDate: "",
                remoteDate: "",
                downloading: false,
                downloadComplete: false,
                downloadError: false
            };
        }

        // Defer all slow operations to after UI is shown
        deferredInitTimer.start();
    }

    // Timer to defer slow operations until after UI is rendered
    Timer {
        id: deferredInitTimer
        interval: 50  // Small delay to let UI render first
        repeat: false
        onTriggered: {
            // Load saved SoundFonts directory or use default (normalize paths for platform)
            if (settingsSoundFont.soundFontsDirectory && settingsSoundFont.soundFontsDirectory.length > 0) {
                userSoundFontsDir = normalizePath(settingsSoundFont.soundFontsDirectory);
            } else {
                userSoundFontsDir = getDefaultPath();  // Already normalized
            }

            // Load saved Plugins directory or use default (normalize paths for platform)
            if (settingsSoundFont.pluginsDirectory && settingsSoundFont.pluginsDirectory.length > 0) {
                userPluginsDir = normalizePath(settingsSoundFont.pluginsDirectory);
            } else {
                userPluginsDir = getDefaultPluginsPath();  // Already normalized
            }

            // Load saved remote base URL or use default
            if (settingsSoundFont.remoteBaseUrl && settingsSoundFont.remoteBaseUrl.length > 0) {
                remoteBaseUrl = settingsSoundFont.remoteBaseUrl;
            }

            // Check if writeBinary() API is available (MuseScore 4.5+)
            writeBinaryAvailable = (typeof fileChecker.writeBinary === "function");

            // Check if curl is available
            checkCurlAvailable();

            // Check if soundfonts exist locally
            checkAllSoundfonts();

            // Check remote URL validity
            checkRemoteUrl();

            // Check for updates for all files
            checkAllUpdates();
        }
    }
    // Main UI
    Rectangle {
        anchors.fill: parent
        color: systemPalette.window

        Column {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            // Title section
            Rectangle {
                width: parent.width
                height: 60
                color: systemPalette.window

                Row {
                    anchors.fill: parent
                    anchors.margins: 15
                    anchors.topMargin: 17
                    spacing: 10

                    Text {
                        text: isSpanish ? "Configuración de Tremolos y SoundFonts" : "Tremolo and SoundFont Configuration"
                        font.bold: true
                        font.pixelSize: 16
                        wrapMode: Text.WordWrap
                        color: systemPalette.windowText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Tab Bar (Qt standard implementation)
            TabBar {
                id: tabBar
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                height: 45
                bottomPadding: 0
                background: Item {}

                TabButton {
                    text: isSpanish ? "Añadir Tremolos" : "Add Tremolos"
                    height: 45
                }

                TabButton {
                    text: isSpanish ? "Eliminar Tremolos" : "Remove Tremolos"
                    height: 45
                }

                TabButton {
                    text: isSpanish ? "Actualizaciones" : "Updates"
                    height: 45
                    enabled: curlAvailable || !curlChecked
                    contentItem: Text {
                        text: {
                            if (!curlChecked) {
                                return parent.text + " ...";
                            } else if (!curlAvailable) {
                                return parent.text + " (curl N/A)";
                            } else {
                                return (hasUpdatesAvailable() ? "\u2717 " : "\u2713 ") + parent.text;
                            }
                        }
                        font: parent.font
                        opacity: (curlAvailable || !curlChecked) ? 1.0 : 0.5
                        color: !curlChecked ? systemPalette.windowText : !curlAvailable ? systemPalette.windowText : hasUpdatesOnly() ? "#f44336" : hasMissingFiles() ? "#ff9800" : "#4caf50"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            // Negative spacer to remove gap
            Item {
                width: parent.width
                height: -11
            }

            // Content Area with border and padding (no top border to connect with active tab)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                height: parent.height - 60 - tabBar.height - 50 + 10
                color: systemPalette.window

                // Left border
                Rectangle {
                    width: 1
                    height: parent.height
                    anchors.left: parent.left
                    color: systemPalette.mid
                }

                // Right border
                Rectangle {
                    width: 1
                    height: parent.height
                    anchors.right: parent.right
                    color: systemPalette.mid
                }

                // Bottom border
                Rectangle {
                    width: parent.width
                    height: 1
                    anchors.bottom: parent.bottom
                    color: systemPalette.mid
                }

                StackLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    currentIndex: tabBar.currentIndex

                    // Tab 0: Add Tremolo
                    Item {
                        id: addTremoloContent

                        ScrollView {
                            anchors.fill: parent
                            clip: true

                            Column {
                                spacing: 15
                                width: addTremoloContent.width - 40
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: 20
                                topPadding: 20
                                leftPadding: 20

                                Row {
                                    spacing: 20
                                    width: parent.width

                                    // Left column: Minimum duration
                                    Column {
                                        spacing: 10
                                        width: (parent.width - parent.spacing) * 0.48

                                        Text {
                                            text: isSpanish ? "Valor mínimo para trémolo:" : "Minimum duration for tremolo:"
                                            font.bold: true
                                            font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                            color: systemPalette.windowText
                                        }

                                        ButtonGroup {
                                            id: durationGroup
                                        }

                                        Column {
                                            spacing: 2
                                            width: parent.width

                                            // Dotted eighth
                                            Row {
                                                spacing: 8
                                                width: parent.width
                                                height: 30

                                                Text {
                                                    text: "\uE1D7\u2009\u2009\uE1E7"
                                                    font.family: "Bravura"
                                                    font.pixelSize: 20
                                                    width: 20
                                                    leftPadding: 10
                                                    horizontalAlignment: Text.AlignLeft
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: systemPalette.windowText
                                                }

                                                RadioButton {
                                                    id: radio_dotted8th
                                                    text: isSpanish ? "Corchea con puntillo" : "Dotted eighth"
                                                    ButtonGroup.group: durationGroup
                                                    onCheckedChanged: {
                                                        if (checked) {
                                                            minDurationValue = 0.1875;
                                                            settingsAdd.savedDuration = 0.1875;
                                                        }
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Component.onCompleted: {
                                                        if (Math.abs(minDurationValue - 0.1875) < 0.001) {
                                                            checked = true;
                                                        }
                                                    }
                                                }
                                            }

                                            // Quarter note
                                            Row {
                                                spacing: 8
                                                width: parent.width
                                                height: 30

                                                Text {
                                                    text: "\uE1D5"
                                                    font.family: "Bravura"
                                                    font.pixelSize: 20
                                                    width: 20
                                                    leftPadding: 10
                                                    horizontalAlignment: Text.AlignLeft
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: systemPalette.windowText
                                                }

                                                RadioButton {
                                                    id: radio_quarter
                                                    text: isSpanish ? "Negra" : "Quarter note"
                                                    ButtonGroup.group: durationGroup
                                                    onCheckedChanged: {
                                                        if (checked) {
                                                            minDurationValue = 0.25;
                                                            settingsAdd.savedDuration = 0.25;
                                                        }
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Component.onCompleted: {
                                                        if (Math.abs(minDurationValue - 0.25) < 0.001) {
                                                            checked = true;
                                                        }
                                                    }
                                                }
                                            }

                                            // Dotted quarter
                                            Row {
                                                spacing: 8
                                                width: parent.width
                                                height: 30

                                                Text {
                                                    text: "\uE1D5\u2009\u2009\uE1E7"
                                                    font.family: "Bravura"
                                                    font.pixelSize: 20
                                                    width: 20
                                                    leftPadding: 10
                                                    horizontalAlignment: Text.AlignLeft
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: systemPalette.windowText
                                                }

                                                RadioButton {
                                                    id: radio_dotted_quarter
                                                    text: isSpanish ? "Negra con puntillo" : "Dotted quarter"
                                                    ButtonGroup.group: durationGroup
                                                    onCheckedChanged: {
                                                        if (checked) {
                                                            minDurationValue = 0.375;
                                                            settingsAdd.savedDuration = 0.375;
                                                        }
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Component.onCompleted: {
                                                        if (Math.abs(minDurationValue - 0.375) < 0.001) {
                                                            checked = true;
                                                        }
                                                    }
                                                }
                                            }

                                            // Half note
                                            Row {
                                                spacing: 8
                                                width: parent.width
                                                height: 30

                                                Text {
                                                    text: "\uE1D3"
                                                    font.family: "Bravura"
                                                    font.pixelSize: 20
                                                    width: 20
                                                    leftPadding: 10
                                                    horizontalAlignment: Text.AlignLeft
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: systemPalette.windowText
                                                }

                                                RadioButton {
                                                    id: radio_half
                                                    text: isSpanish ? "Blanca" : "Half note"
                                                    ButtonGroup.group: durationGroup
                                                    onCheckedChanged: {
                                                        if (checked) {
                                                            minDurationValue = 0.5;
                                                            settingsAdd.savedDuration = 0.5;
                                                        }
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Component.onCompleted: {
                                                        if (Math.abs(minDurationValue - 0.5) < 0.001) {
                                                            checked = true;
                                                        }
                                                    }
                                                }
                                            }

                                            // Dotted half
                                            Row {
                                                spacing: 8
                                                width: parent.width
                                                height: 30

                                                Text {
                                                    text: "\uE1D3\u2009\u2009\uE1E7"
                                                    font.family: "Bravura"
                                                    font.pixelSize: 20
                                                    width: 20
                                                    leftPadding: 10
                                                    horizontalAlignment: Text.AlignLeft
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: systemPalette.windowText
                                                }

                                                RadioButton {
                                                    id: radio_dotted_half
                                                    text: isSpanish ? "Blanca con puntillo" : "Dotted half"
                                                    ButtonGroup.group: durationGroup
                                                    onCheckedChanged: {
                                                        if (checked) {
                                                            minDurationValue = 0.75;
                                                            settingsAdd.savedDuration = 0.75;
                                                        }
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Component.onCompleted: {
                                                        if (Math.abs(minDurationValue - 0.75) < 0.001) {
                                                            checked = true;
                                                        }
                                                    }
                                                }
                                            }

                                            // Whole note
                                            Row {
                                                spacing: 8
                                                width: parent.width
                                                height: 30

                                                Text {
                                                    text: "\uE1D2"
                                                    font.family: "Bravura"
                                                    font.pixelSize: 20
                                                    width: 20
                                                    leftPadding: 10
                                                    horizontalAlignment: Text.AlignLeft
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: systemPalette.windowText
                                                }

                                                RadioButton {
                                                    id: radio_whole
                                                    text: isSpanish ? "Redonda" : "Whole note"
                                                    ButtonGroup.group: durationGroup
                                                    onCheckedChanged: {
                                                        if (checked) {
                                                            minDurationValue = 1.0;
                                                            settingsAdd.savedDuration = 1.0;
                                                        }
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Component.onCompleted: {
                                                        if (Math.abs(minDurationValue - 1.0) < 0.001) {
                                                            checked = true;
                                                        }
                                                    }
                                                }
                                            }

                                            // Dotted whole
                                            Row {
                                                spacing: 8
                                                width: parent.width
                                                height: 30

                                                Text {
                                                    text: "\uE1D2\u2009\u2009\uE1E7"
                                                    font.family: "Bravura"
                                                    font.pixelSize: 20
                                                    width: 20
                                                    leftPadding: 10
                                                    horizontalAlignment: Text.AlignLeft
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: systemPalette.windowText
                                                }

                                                RadioButton {
                                                    id: radio_dotted_whole
                                                    text: isSpanish ? "Redonda con puntillo" : "Dotted whole"
                                                    ButtonGroup.group: durationGroup
                                                    onCheckedChanged: {
                                                        if (checked) {
                                                            minDurationValue = 1.5;
                                                            settingsAdd.savedDuration = 1.5;
                                                        }
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    Component.onCompleted: {
                                                        if (Math.abs(minDurationValue - 1.5) < 0.001) {
                                                            checked = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Right column: Processing range
                                    Column {
                                        spacing: 10
                                        width: (parent.width - parent.spacing) * 0.48

                                        Text {
                                            text: isSpanish ? "Aplicar a:" : "Apply to:"
                                            font.bold: true
                                            font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                            color: systemPalette.windowText
                                        }

                                        Column {
                                            width: parent.width
                                            spacing: 1

                                            RadioButton {
                                                id: radioSelectionAdd
                                                text: isSpanish ? "Rango seleccionado" : "Selected range"
                                                enabled: hasSelectionAdd
                                                checked: hasSelectionAdd && useSelectionAdd
                                                onCheckedChanged: {
                                                    if (checked)
                                                        useSelectionAdd = true;
                                                }
                                            }

                                            RadioButton {
                                                id: radioEntireScoreAdd
                                                text: isSpanish ? "Toda la partitura" : "Entire score"
                                                checked: !hasSelectionAdd || !useSelectionAdd
                                                onCheckedChanged: {
                                                    if (checked)
                                                        useSelectionAdd = false;
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    text: isSpanish ? "Operaciones:" : "Operations:"
                                    font.bold: true
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    color: systemPalette.windowText
                                }

                                Column {
                                    width: parent.width

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Añadir símbolos de trémolo" : "Add tremolo symbols"
                                        checked: settingsAdd.addTremoloSymbols
                                        onCheckedChanged: settingsAdd.addTremoloSymbols = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Establecer velocidad de notas a 65 (reproduce trémolo)" : "Set note velocity to 65 (play tremolo sound)"
                                        checked: settingsAdd.setNoteVelocity
                                        onCheckedChanged: settingsAdd.setNoteVelocity = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "No tocar notas ligadas" : "Don't play tied notes"
                                        checked: settingsAdd.disableTiedNotes
                                        onCheckedChanged: settingsAdd.disableTiedNotes = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "No tocar símbolos de trémolo" : "Don't play tremolo symbols"
                                        checked: settingsAdd.disableTremoloPlayback
                                        onCheckedChanged: settingsAdd.disableTremoloPlayback = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "No tocar dinámicas" : "Don't play dynamics"
                                        checked: settingsAdd.disableDynamics
                                        onCheckedChanged: settingsAdd.disableDynamics = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "No tocar articulaciones" : "Don't play articulations"
                                        checked: settingsAdd.disableArticulations
                                        onCheckedChanged: settingsAdd.disableArticulations = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "No tocar ornamentos (trinos, mordentes, etc.)" : "Don't play ornaments (trills, mordents, etc.)"
                                        checked: settingsAdd.disableOrnaments
                                        onCheckedChanged: settingsAdd.disableOrnaments = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "No tocar reguladores" : "Don't play hairpins"
                                        checked: settingsAdd.disableHairpins
                                        onCheckedChanged: settingsAdd.disableHairpins = checked
                                    }
                                }
                            }
                        }

                        // Note at bottom
                        Text {
                            text: isSpanish ? "NOTA: Solo se procesarán instrumentos de bandurria y laúd" : "NOTE: Will only process bandurria and laud instruments"
                            font.pixelSize: 12
                            font.italic: true
                            wrapMode: Text.WordWrap
                            width: parent.width - 30
                            color: systemPalette.windowText
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 10
                        }
                    }

                    // Tab 1: Remove Tremolo
                    Item {
                        id: removeTremoloContent

                        ScrollView {
                            anchors.fill: parent
                            clip: true

                            Column {
                                spacing: 15
                                width: removeTremoloContent.width - 40
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.topMargin: 20
                                topPadding: 20
                                leftPadding: 20

                                Text {
                                    text: isSpanish ? "Operaciones:" : "Operations to perform:"
                                    font.bold: true
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    color: systemPalette.windowText
                                }

                                Column {
                                    width: parent.width

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Eliminar símbolos de trémolo" : "Remove tremolo symbols"
                                        checked: settingsRemove.removeTremolos
                                        onCheckedChanged: settingsRemove.removeTremolos = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Restaurar velocidad de notas (valor predeterminado)" : "Restore note velocity (default value)"
                                        checked: settingsRemove.restoreVelocity
                                        onCheckedChanged: settingsRemove.restoreVelocity = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Restaurar reproducción de notas" : "Restore note playback"
                                        checked: settingsRemove.restoreNotePlayback
                                        onCheckedChanged: settingsRemove.restoreNotePlayback = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Restaurar reproducción de dinámicas" : "Restore dynamics playback"
                                        checked: settingsRemove.restoreDynamics
                                        onCheckedChanged: settingsRemove.restoreDynamics = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Restaurar reproducción de articulaciones" : "Restore articulations playback"
                                        checked: settingsRemove.restoreArticulations
                                        onCheckedChanged: settingsRemove.restoreArticulations = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Restaurar reproducción de ornamentos" : "Restore ornaments playback"
                                        checked: settingsRemove.restoreOrnaments
                                        onCheckedChanged: settingsRemove.restoreOrnaments = checked
                                    }

                                    CheckBox {
                                        height: 22
                                        text: isSpanish ? "Restaurar reproducción de reguladores" : "Restore hairpins playback"
                                        checked: settingsRemove.restoreHairpins
                                        onCheckedChanged: settingsRemove.restoreHairpins = checked
                                    }
                                }

                                Text {
                                    text: isSpanish ? "Aplicar a:" : "Apply to:"
                                    font.bold: true
                                    font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    width: parent.width
                                    color: systemPalette.windowText
                                }

                                Column {
                                    width: parent.width

                                    RadioButton {
                                        id: radioSelectionRemove
                                        height: 22
                                        text: isSpanish ? "Rango seleccionado" : "Selected range"
                                        enabled: hasSelectionRemove
                                        checked: hasSelectionRemove && useSelectionRemove
                                        onCheckedChanged: {
                                            if (checked)
                                                useSelectionRemove = true;
                                        }
                                    }

                                    RadioButton {
                                        id: radioEntireScoreRemove
                                        height: 22
                                        text: isSpanish ? "Toda la partitura" : "Entire score"
                                        checked: !hasSelectionRemove || !useSelectionRemove
                                        onCheckedChanged: {
                                            if (checked)
                                                useSelectionRemove = false;
                                        }
                                    }
                                }
                            }
                        }

                        // Note at bottom
                        Text {
                            text: isSpanish ? "NOTA: Solo se procesarán instrumentos de bandurria y laúd" : "NOTE: Will only process bandurria and laud instruments"
                            font.pixelSize: 12
                            font.italic: true
                            wrapMode: Text.WordWrap
                            width: parent.width - 30
                            color: systemPalette.windowText
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottomMargin: 10
                        }
                    }

                    // Tab 2: SoundFont Check
                    Item {
                        Component.onCompleted: {
                            // Initial check when tab is created
                            checkAllSoundfonts();
                            checkAllUpdates();
                            checkPluginUpdate();
                        }

                        Column {
                            spacing: 15
                            anchors.fill: parent
                            anchors.margins: 20

                            // Status section - List of Files (Plugin + SoundFonts)
                            Text {
                                text: isSpanish ? "Estado de archivos:" : "Files Status:"
                                font.bold: true
                                font.pixelSize: 13
                                color: systemPalette.windowText
                            }

                            Row {
                                width: parent.width
                                spacing: 10

                                // Left column: All managed files (plugin + soundfonts)
                                Loader {
                                    width: parent.width * 0.48
                                    // Force reload when filesStatusRevision changes
                                    property int trigger: filesStatusRevision
                                    onTriggerChanged: {
                                        // Force complete reload by setting source to empty then back
                                        var src = sourceComponent;
                                        sourceComponent = null;
                                        sourceComponent = src;
                                    }

                                    sourceComponent: Column {
                                        width: parent.width
                                        spacing: 5

                                        Repeater {
                                            model: managedFiles

                                            Rectangle {
                                                width: parent.width
                                                height: 32
                                                color: {
                                                    var _ = filesStatusRevision;  // Force dependency on revision counter
                                                    if (!filesStatus[modelData])
                                                        return systemPalette.base;
                                                    var status = filesStatus[modelData];
                                                    var isPlugin = (modelData === pluginFilename);

                                                    // Show download progress
                                                    if (status.downloading)
                                                        return "#d1ecf1";  // Azul claro
                                                    if (status.downloadComplete)
                                                        return "#d4edda";  // Verde claro
                                                    if (status.downloadError)
                                                        return "#f8d7da";  // Rojo claro

                                                    // Normal status colors
                                                    if (status.found) {
                                                        return status.needsUpdate ? "#fff3cd" : "#d4edda";  // Naranja claro : Verde claro
                                                    }
                                                    // Plugin siempre está "found" localmente, soundfonts no
                                                    return isPlugin ? "#d4edda" : "#f8d7da";
                                                }
                                                border.color: {
                                                    var _ = filesStatusRevision;  // Force dependency on revision counter
                                                    if (!filesStatus[modelData])
                                                        return "#ccc";
                                                    var status = filesStatus[modelData];
                                                    var isPlugin = (modelData === pluginFilename);

                                                    if (status.downloading)
                                                        return "#1976d2";
                                                    if (status.downloadComplete)
                                                        return "#4caf50";
                                                    if (status.downloadError)
                                                        return "#f44336";

                                                    if (status.found) {
                                                        return status.needsUpdate ? "#ff9800" : "#4caf50";
                                                    }
                                                    return isPlugin ? "#4caf50" : "#f44336";
                                                }
                                                border.width: 1
                                                radius: 4
                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                spacing: 10

                                                Text {
                                                    text: {
                                                        var _ = filesStatusRevision;  // Force dependency on revision counter
                                                        if (!filesStatus[modelData])
                                                            return "?";
                                                        var status = filesStatus[modelData];
                                                        var isPlugin = (modelData === pluginFilename);

                                                        if (status.downloading)
                                                            return "⏳";
                                                        if (status.downloadComplete)
                                                            return "✓";
                                                        if (status.downloadError)
                                                            return "✗";

                                                        if (status.found) {
                                                            return status.needsUpdate ? "⚠" : "✓";
                                                        }
                                                        return isPlugin ? "✓" : "✗";
                                                    }
                                                    font.pixelSize: 16
                                                    font.bold: true
                                                    color: {
                                                        var _ = filesStatusRevision;  // Force dependency on revision counter
                                                        if (!filesStatus[modelData])
                                                            return systemPalette.windowText;
                                                        var status = filesStatus[modelData];
                                                        var isPlugin = (modelData === pluginFilename);

                                                        if (status.downloading)
                                                            return "#1976d2";
                                                        if (status.downloadComplete)
                                                            return "#4caf50";
                                                        if (status.downloadError)
                                                            return "#f44336";

                                                        if (status.found) {
                                                            return status.needsUpdate ? "#ff9800" : "#4caf50";
                                                        }
                                                        return isPlugin ? "#4caf50" : "#f44336";
                                                    }
                                                    anchors.verticalCenter: parent.verticalCenter
                                                }

                                                Column {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    spacing: 1
                                                    width: parent.width - 40

                                                    Text {
                                                        text: modelData
                                                        font.pixelSize: 11
                                                        font.bold: true
                                                        color: "#333333"
                                                    }

                                                    Text {
                                                        id: sizesText
                                                        property bool isDownloading: {
                                                            var _ = filesStatusRevision;
                                                            return filesStatus[modelData] ? (filesStatus[modelData].downloading === true) : false;
                                                        }
                                                        visible: !isDownloading
                                                        text: {
                                                            var _ = filesStatusRevision;
                                                            if (!filesStatus[modelData]) return "";
                                                            var s = filesStatus[modelData];
                                                            var local = s.localSize ? s.localSize : 0;
                                                            var remote = s.remoteSize ? s.remoteSize : 0;
                                                            return "Local: " + local + " | Remote: " + remote;
                                                        }
                                                        font.pixelSize: 8
                                                        color: "#666666"
                                                        font.family: "monospace"
                                                    }

                                                    Text {
                                                        visible: sizesText.isDownloading
                                                        text: isSpanish ? "Descargando..." : "Downloading..."
                                                        font.pixelSize: 9
                                                        color: "#1976d2"
                                                        font.italic: true
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                }

                                // Right column: Status and instructions area (unified)
                                Rectangle {
                                    visible: anyDownloading || downloadStatus.length > 0 || hasUpdatesAvailable()
                                    width: parent.width * 0.48
                                    height: 180
                                    color: {
                                        if (downloadStatus.length > 0) {
                                            return downloadStatus.indexOf("✓") === 0 ? "#e8f5e9" : downloadStatus.indexOf("✗") === 0 ? "#ffebee" : "#e3f2fd";
                                        }
                                        return "#f5f5f5";  // Instructions background
                                    }
                                    border.color: {
                                        if (downloadStatus.length > 0) {
                                            return downloadStatus.indexOf("✓") === 0 ? "#4caf50" : downloadStatus.indexOf("✗") === 0 ? "#f44336" : "#2196f3";
                                        }
                                        return "#ccc";  // Instructions border
                                    }
                                    border.width: 2
                                    radius: 5

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: 15
                                        spacing: 5

                                        // Download status (when downloading or has status message)
                                        Text {
                                            visible: downloadStatus.length > 0
                                            text: downloadStatus
                                            font.pixelSize: 11
                                            color: downloadStatus.indexOf("✓") === 0 ? "#2e7d32" : downloadStatus.indexOf("✗") === 0 ? "#c62828" : "#1976d2"
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                        }

                                        Text {
                                            visible: anyDownloading
                                            text: isSpanish ? "Descargando archivo binario..." : "Downloading binary file..."
                                            font.pixelSize: 10
                                            color: "#1976d2"
                                            width: parent.width
                                            wrapMode: Text.WordWrap
                                        }

                                        // Instructions (when files need update and not downloading)
                                        Text {
                                            visible: hasUpdatesAvailable() && !anyDownloading && downloadStatus.length === 0
                                            text: isSpanish ? "1. Verifica que el directorio SoundFonts sea correcto\n2. Verifica que la URL remota sea correcta\n3. Haz clic en 'Descargar' para obtener los archivos\n4. Después de instalar, reinicia MuseScore\n5. En el Mixer (F10), selecciona el SoundFont deseado" : "1. Verify the SoundFonts directory is correct\n2. Verify the remote URL is correct\n3. Click 'Download' to get the files\n4. After installation, restart MuseScore\n5. In the Mixer (F10), select the desired SoundFont"
                                            font.pixelSize: 11
                                            wrapMode: Text.WordWrap
                                            width: parent.width
                                            color: "#333333"
                                        }
                                    }
                                }
                            }

                            // Configuration section below
                            Column {
                                width: parent.width
                                spacing: 10

                                // SoundFonts directory location (editable)
                                Text {
                                    text: isSpanish ? "Directorio SoundFonts:" : "SoundFonts Directory:"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: systemPalette.windowText
                                    width: parent.width
                                }

                                Column {
                                    width: parent.width
                                    spacing: 5

                                    Row {
                                        width: parent.width
                                        spacing: 5

                                        TextField {
                                            id: soundFontsDirField
                                            width: parent.width - existsIndicator.width - parent.spacing
                                            text: userSoundFontsDir
                                            font.pixelSize: 11
                                            font.family: "monospace"
                                            selectByMouse: true
                                            onTextChanged: {
                                                userSoundFontsDir = normalizePath(text);
                                                settingsSoundFont.soundFontsDirectory = userSoundFontsDir;
                                                checkAllSoundfonts();
                                                checkAllUpdates();
                                            }
                                        }

                                        Text {
                                            id: existsIndicator
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: directoryExists ? "✓" : "✗"
                                            font.bold: true
                                            color: directoryExists ? "green" : "red"
                                        }
                                    }

                                    Text {
                                        visible: !directoryExists
                                        text: isSpanish ? "⚠ Directorio no encontrado" : "⚠ Directory not found"
                                        font.pixelSize: 10
                                        color: "orange"
                                        font.italic: true
                                    }
                                }

                                // Plugins directory location (editable)
                                Text {
                                    text: isSpanish ? "Directorio Plugins:" : "Plugins Directory:"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: systemPalette.windowText
                                    width: parent.width
                                }

                                Column {
                                    width: parent.width
                                    spacing: 5

                                    Row {
                                        width: parent.width
                                        spacing: 5

                                        TextField {
                                            id: pluginsDirField
                                            width: parent.width - pluginsExistsIndicator.width - parent.spacing
                                            text: userPluginsDir
                                            font.pixelSize: 11
                                            font.family: "monospace"
                                            selectByMouse: true
                                            onTextChanged: {
                                                userPluginsDir = normalizePath(text);
                                                settingsSoundFont.pluginsDirectory = userPluginsDir;
                                            }
                                        }

                                        Text {
                                            id: pluginsExistsIndicator
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: {
                                                fileChecker.source = userPluginsDir;
                                                return fileChecker.exists() ? "✓" : "✗";
                                            }
                                            font.bold: true
                                            color: {
                                                fileChecker.source = userPluginsDir;
                                                return fileChecker.exists() ? "green" : "red";
                                            }
                                        }
                                    }

                                    Text {
                                        visible: {
                                            fileChecker.source = userPluginsDir;
                                            return !fileChecker.exists();
                                        }
                                        text: isSpanish ? "⚠ Directorio no encontrado" : "⚠ Directory not found"
                                        font.pixelSize: 10
                                        color: "orange"
                                        font.italic: true
                                    }
                                }

                                Text {
                                    text: isSpanish ? "URL Base Remota para archivos:" : "Remote Base URL for files:"
                                    font.bold: true
                                    font.pixelSize: 12
                                    color: systemPalette.windowText
                                    width: parent.width
                                }

                                Column {
                                    width: parent.width
                                    spacing: 5

                                    Row {
                                        width: parent.width
                                        spacing: 10

                                        TextField {
                                            id: remoteUrlField
                                            width: parent.width - urlIndicator.width - parent.spacing
                                            text: remoteBaseUrl
                                            font.pixelSize: 11
                                            font.family: "monospace"
                                            selectByMouse: true
                                            onTextChanged: {
                                                remoteBaseUrl = text;
                                                settingsSoundFont.remoteBaseUrl = text;
                                                checkRemoteUrl();
                                            }
                                        }

                                        Text {
                                            id: urlIndicator
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: checkingRemoteUrl ? "⋯" : (remoteUrlValid ? "✓" : "✗")
                                            font.bold: true
                                            color: checkingRemoteUrl ? "blue" : (remoteUrlValid ? "green" : "red")
                                        }
                                    }

                                    Text {
                                        visible: !checkingRemoteUrl && !remoteUrlValid
                                        text: isSpanish ? "⚠ URL no válida o inaccesible" : "⚠ Invalid or inaccessible URL"
                                        font.pixelSize: 10
                                        color: "red"
                                        font.italic: true
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Bottom bar with copyright and buttons
            Item {
                width: parent.width
                height: 50

                // Copyright aligned left
                Text {
                    text: "\u00A9 2025 - Manolo Carrasco (do2tis) - v" + version
                    font.pixelSize: 11
                    color: systemPalette.windowText
                    anchors.left: parent.left
                    anchors.leftMargin: 20
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Common buttons at bottom right
                Row {
                    spacing: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 20
                    height: parent.height

                    // Add/Remove Tremolo buttons (visible for tabs 0 and 1)
                    Button {
                        visible: tabBar.currentIndex === 0 || tabBar.currentIndex === 1
                        text: isSpanish ? "Aplicar" : "Apply"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            if (tabBar.currentIndex === 0) {
                                settingsAdd.savedDuration = minDurationValue;
                                processAddTremolo();
                            } else if (tabBar.currentIndex === 1) {
                                processRemoveTremolo();
                            }
                        }
                    }

                    // Apply & Close button (visible for tabs 0 and 1)
                    Button {
                        visible: tabBar.currentIndex === 0 || tabBar.currentIndex === 1
                        text: isSpanish ? "Aplicar y Cerrar" : "Apply && Close"
                        leftPadding: 15
                        rightPadding: 15
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            if (tabBar.currentIndex === 0) {
                                settingsAdd.savedDuration = minDurationValue;
                                processAddTremolo();
                            } else if (tabBar.currentIndex === 1) {
                                processRemoveTremolo();
                            }
                            quit();
                        }
                    }

                    // Download button (visible for tab 2)
                    Button {
                        visible: tabBar.currentIndex === 2 && hasUpdatesAvailable() && !anyDownloading && !showRestartButton
                        text: isSpanish ? "Descargar" : "Download"
                        leftPadding: 15
                        rightPadding: 15
                        highlighted: true
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            // Download all files that need update (plugin + soundfonts)
                            downloadFiles(managedFiles);
                        }
                    }

                    Button {
                        visible: tabBar.currentIndex === 2 && showRestartButton
                        text: isSpanish ? "Reiniciar MuseScore" : "Restart MuseScore"
                        leftPadding: 15
                        rightPadding: 15
                        highlighted: true
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            cmd("restart");
                        }
                    }

                    // Common Close button (always visible)
                    Button {
                        text: isSpanish ? "Cerrar" : "Close"
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: {
                            quit();
                        }
                    }
                }
            }
        }
    }

    // ===== Common Helper Functions =====

    // Function to check if a staff belongs to bandurria or laúd
    function isBandurriaOrLaud(staff) {
        if (!staff || !staff.part)
            return false;

        var names = [(staff.part.longName || "").toLowerCase(), (staff.part.shortName || "").toLowerCase(), (staff.part.instrumentId || "").toLowerCase()];

        var keywords = ["bandurria", "laúd", "laud"];

        for (var i = 0; i < names.length; i++) {
            for (var j = 0; j < keywords.length; j++) {
                if (names[i].indexOf(keywords[j]) !== -1) {
                    return true;
                }
            }
        }

        return false;
    }

    // ===== Add Tremolo Helper Functions =====

    // Function to check if chord has staccato articulation
    function hasStaccato(chord) {
        if (!chord || !chord.articulations) {
            return false;
        }

        for (var i = 0; i < chord.articulations.length; i++) {
            var artic = chord.articulations[i];
            if (!artic || !artic.symbol) {
                continue;
            }

            var symId = artic.symbol;
            if (staccatoArticulations.indexOf(symId) !== -1) {
                return true;
            }
        }

        return false;
    }

    // Function to check if chord has trill articulation
    function hasTrill(chord) {
        if (!chord || !chord.articulations) {
            return false;
        }

        for (var i = 0; i < chord.articulations.length; i++) {
            var artic = chord.articulations[i];
            if (!artic || !artic.symbol) {
                continue;
            }

            var symId = artic.symbol;
            if (trillArticulations.indexOf(symId) !== -1) {
                return true;
            }
        }

        return false;
    }

    // Function to check if chord has articulation that increases velocity
    function increasesVelocity(chord) {
        if (!chord || !chord.articulations) {
            return false;
        }

        for (var i = 0; i < chord.articulations.length; i++) {
            var artic = chord.articulations[i];
            if (!artic || !artic.symbol) {
                continue;
            }

            var symId = artic.symbol;
            if (velocityIncreaseArticulations.indexOf(symId) !== -1) {
                return true;
            }
        }

        return false;
    }

    // Function to check if note duration matches criteria for tremolo
    function shouldAddTremolo(chord) {
        if (!chord || !chord.duration)
            return false;

        var durationValue = chord.duration.numerator / chord.duration.denominator;
        if (durationValue < (minDurationValue - 0.001)) {
            return false;
        }

        if (hasStaccato(chord)) {
            return false;
        }

        return true;
    }

    // Function to check if note is short (below duration threshold)
    function isShortNote(chord) {
        if (!chord || !chord.duration)
            return false;

        var durationValue = chord.duration.numerator / chord.duration.denominator;
        return durationValue < (minDurationValue - 0.001);
    }

    // Function to check if this chord is the first in a tied chain
    function isFirstInTiedChain(chord) {
        if (!chord || !chord.notes)
            return true;

        for (var i = 0; i < chord.notes.length; i++) {
            if (chord.notes[i].tieBack) {
                return false;
            }
        }

        return true;
    }

    // Process score for adding tremolo
    function processAddTremolo() {
        console.log("Processing score with settings:");
        console.log("  minDuration=" + minDurationValue + ", addTremoloSymbols=" + settingsAdd.addTremoloSymbols + ", setNoteVelocity=" + settingsAdd.setNoteVelocity + ", disableTiedNotes=" + settingsAdd.disableTiedNotes + ", disableTremoloPlayback=" + settingsAdd.disableTremoloPlayback + ", disableDynamics=" + settingsAdd.disableDynamics + ", disableArticulations=" + settingsAdd.disableArticulations + ", disableOrnaments=" + settingsAdd.disableOrnaments + ", disableHairpins=" + settingsAdd.disableHairpins + ", useSelection=" + useSelectionAdd);

        var useSelectionRange = hasSelectionAdd && useSelectionAdd;

        // Build unified spanners cache (emulates curScore.spanners API when not available)
        var spannersCache = { spanners: [] };
        if (settingsAdd.disableHairpins) {
            if (hasSpannersAPI) {
                spannersCache.spanners = curScore.spanners;
            } else {
                // If no selection, select all to access hairpins
                if (!useSelectionRange) {
                    curScore.startCmd();
                    curScore.selection.selectRange(0, curScore.lastSegment.tick + 1, 0, curScore.nstaves);
                    curScore.endCmd();
                }

                var elements = curScore.selection.elements;
                var prevSpanner = null;

                for (var i = 0; i < elements.length; i++) {
                    var e = elements[i];
                    if (e.type === Element.HAIRPIN_SEGMENT) {
                        var spanner = e.spanner;
                        var isDuplicate = prevSpanner && spanner.is(prevSpanner);
                        if (!isDuplicate) {
                            spannersCache.spanners.push(spanner);
                        }
                        prevSpanner = spanner;
                    }
                }

                // Clear selection only if we created it
                if (!useSelectionRange) {
                    curScore.startCmd();
                    curScore.selection.clear();
                    curScore.endCmd();
                }

                console.log("Built spanners cache with " + spannersCache.spanners.length + " hairpins");
            }
        }

        curScore.startCmd();

        try {
            var cursor = curScore.newCursor();
            var processedCount = 0;
            var hairpinsDisabled = 0;

            // Get selection bounds
            var startTick, endTick;
            if (useSelectionRange) {
                cursor.rewind(Cursor.SELECTION_START);
                startTick = cursor.segment ? cursor.segment.tick : 0;
                cursor.rewind(Cursor.SELECTION_END);
                endTick = cursor.segment ? cursor.segment.tick : curScore.lastSegment.tick + 1;
                console.log("Processing selected range: tick " + startTick + " to " + endTick);
            } else {
                startTick = 0;
                endTick = curScore.lastSegment.tick + 1;
                console.log("Processing entire score: tick " + startTick + " to " + endTick);
            }

            // Build list of bandurria/laúd staff indices
            var bandurriaLaudStaves = [];
            for (var s = 0; s < curScore.nstaves; s++) {
                var staffElement = curScore.staves[s];
                if (isBandurriaOrLaud(staffElement)) {
                    bandurriaLaudStaves.push(s);
                    console.log("Staff " + s + " is bandurria/laúd");
                }
            }

            if (bandurriaLaudStaves.length === 0) {
                console.log("ERROR: No bandurria or laúd instruments found in score");
                curScore.endCmd(false);
                return;
            }

            // Iterate through bandurria/laúd staves
            for (var staffIdx = 0; staffIdx < bandurriaLaudStaves.length; staffIdx++) {
                var staff = bandurriaLaudStaves[staffIdx];
                console.log("Processing staff " + staff);

                for (var voice = 0; voice < 4; voice++) {
                    cursor.staffIdx = staff;
                    cursor.voice = voice;
                    cursor.rewind(Cursor.SCORE_START);

                    // Move to selection start
                    while (cursor.segment && cursor.segment.tick < startTick) {
                        cursor.next();
                    }

                    // Process elements in range
                    while (cursor.segment && cursor.segment.tick < endTick) {
                        if (cursor.element && cursor.element.type === Element.CHORD) {
                            var chord = cursor.element;

                            // Rule 1: Long notes (>= minDuration) - add tremolo if no staccato
                            if (shouldAddTremolo(chord)) {
                                var isFirst = isFirstInTiedChain(chord);

                                // Set velocity to 65 if enabled
                                if (settingsAdd.setNoteVelocity) {
                                    for (var i = 0; i < chord.notes.length; i++) {
                                        chord.notes[i].userVelocity = 65;
                                    }
                                }

                                // Disable tied notes playback if enabled
                                if (settingsAdd.disableTiedNotes && !isFirst) {
                                    for (var i = 0; i < chord.notes.length; i++) {
                                        chord.notes[i].play = false;
                                    }
                                }

                                // Add tremolo symbol if enabled and not present
                                if (settingsAdd.addTremoloSymbols && !chord.tremolo) {
                                    try {
                                        var tremolo = newElement(Element.TREMOLO_SINGLECHORD);
                                        if (tremolo) {
                                            tremolo.tremoloType = TremoloType.R32;

                                            if (settingsAdd.disableTremoloPlayback) {
                                                tremolo.play = false;
                                            }

                                            chord.add(tremolo);
                                        }
                                    } catch (e) {
                                        console.log("Error adding tremolo: " + e);
                                    }
                                }

                                // Disable ornament articulations (trills, etc.) if present and ornament disabling is enabled
                                if (settingsAdd.disableOrnaments && chord.articulations) {
                                    for (var i = 0; i < chord.articulations.length; i++) {
                                        var artic = chord.articulations[i];
                                        if (artic && artic.symbol) {
                                            var symId = artic.symbol;
                                            if (trillArticulations.indexOf(symId) !== -1) {
                                                console.log("LONG NOTE with tremolo: Disabling ornament articulation symId=" + symId);
                                                artic.play = false;
                                            }
                                        }
                                    }
                                }

                                // Disable ornament spanners (trill lines) if present and ornament disabling is enabled
                                if (settingsAdd.disableOrnaments) {
                                    for (var i = 0; i < chord.notes.length; i++) {
                                        if (chord.notes[i].spannerForward) {
                                            for (var j = 0; j < chord.notes[i].spannerForward.length; j++) {
                                                var spanner = chord.notes[i].spannerForward[j];
                                                if (spanner && spanner.type === Element.TRILL) {
                                                    console.log("LONG NOTE with tremolo: Disabling ornament spanner (trill line)");
                                                    spanner.play = false;
                                                }
                                            }
                                        }
                                    }
                                }

                                processedCount++;
                            } else
                            // Rule 2: Short notes (< minDuration) - disable velocity-increasing articulations
                            if (isShortNote(chord) && settingsAdd.disableArticulations) {
                                if (chord.articulations) {
                                    for (var i = 0; i < chord.articulations.length; i++) {
                                        var artic = chord.articulations[i];
                                        if (artic && artic.symbol) {
                                            var symId = artic.symbol;
                                            if (velocityIncreaseArticulations.indexOf(symId) !== -1) {
                                                console.log("SHORT NOTE: Disabling velocity-increasing articulation symId=" + symId);
                                                artic.play = false;
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Disable dynamics if requested
                        if (settingsAdd.disableDynamics && cursor.segment.annotations) {
                            for (var i = 0; i < cursor.segment.annotations.length; i++) {
                                var annotation = cursor.segment.annotations[i];
                                if (!annotation || annotation.track === undefined)
                                    continue;

                                var elemStaff = Math.floor(annotation.track / 4);
                                if (bandurriaLaudStaves.indexOf(elemStaff) === -1)
                                    continue;

                                if (annotation.type === Element.DYNAMIC || annotation.type === Element.EXPRESSION) {
                                    annotation.play = false;
                                }
                            }
                        }

                        cursor.next();
                    }
                }
            }

            // Process hairpins using unified spannersCache
            if (settingsAdd.disableHairpins && spannersCache.spanners.length > 0) {
                console.log("Processing " + spannersCache.spanners.length + " spanners...");

                for (var i = 0; i < spannersCache.spanners.length; i++) {
                    var spanner = spannersCache.spanners[i];

                    // Only process hairpins
                    if (spanner.type !== Element.HAIRPIN) continue;

                    // Check if hairpin's track belongs to a bandurria/laúd staff
                    var spannerStaff = Math.floor(spanner.track / 4);
                    if (bandurriaLaudStaves.indexOf(spannerStaff) === -1) continue;

                    // Check if hairpin is in the selected range
                    if (useSelectionRange) {
                        var spannerTick = spanner.spannerTick ? spanner.spannerTick.ticks : spanner.tick;
                        if (spannerTick < startTick || spannerTick >= endTick) continue;
                    }

                    spanner.play = false;
                    hairpinsDisabled++;
                }

                console.log("Disabled " + hairpinsDisabled + " hairpins");
            }

            console.log("Processed " + processedCount + " chords, disabled " + hairpinsDisabled + " hairpins");
            curScore.endCmd();
        } catch (e) {
            console.log("Error: " + e.toString());
            curScore.endCmd(true);
        }
    }

    // ===== Remove Tremolo Function =====

    function processRemoveTremolo() {
        console.log("Removing tremolo symbols and restoring playback settings...");
        console.log("Options: removeTremolos=" + settingsRemove.removeTremolos + ", restoreVelocity=" + settingsRemove.restoreVelocity + ", restoreNotePlayback=" + settingsRemove.restoreNotePlayback + ", restoreDynamics=" + settingsRemove.restoreDynamics + ", restoreArticulations=" + settingsRemove.restoreArticulations + ", restoreOrnaments=" + settingsRemove.restoreOrnaments + ", restoreHairpins=" + settingsRemove.restoreHairpins + ", useSelection=" + useSelectionRemove);

        var useSelectionRange = hasSelectionRemove && useSelectionRemove;

        // Build unified spanners cache (emulates curScore.spanners API when not available)
        var spannersCache = { spanners: [] };
        if (settingsRemove.restoreHairpins) {
            if (hasSpannersAPI) {
                spannersCache.spanners = curScore.spanners;
            } else {
                // If no selection, select all to access hairpins
                if (!useSelectionRange) {
                    curScore.startCmd();
                    curScore.selection.selectRange(0, curScore.lastSegment.tick + 1, 0, curScore.nstaves);
                    curScore.endCmd();
                }

                var elements = curScore.selection.elements;
                var prevSpanner = null;

                for (var i = 0; i < elements.length; i++) {
                    var e = elements[i];
                    if (e.type === Element.HAIRPIN_SEGMENT) {
                        var spanner = e.spanner;
                        var isDuplicate = prevSpanner && spanner.is(prevSpanner);
                        if (!isDuplicate) {
                            spannersCache.spanners.push(spanner);
                        }
                        prevSpanner = spanner;
                    }
                }

                // Clear selection only if we created it
                if (!useSelectionRange) {
                    curScore.startCmd();
                    curScore.selection.clear();
                    curScore.endCmd();
                }

                console.log("Built spanners cache with " + spannersCache.spanners.length + " hairpins");
            }
        }

        curScore.startCmd();

        try {
            var cursor = curScore.newCursor();
            var tremolosRemoved = 0;
            var notesRestored = 0;
            var dynamicsRestored = 0;
            var articulationsRestored = 0;
            var hairpinsRestored = 0;

            // Get selection bounds
            var startTick, endTick;
            if (useSelectionRange) {
                cursor.rewind(Cursor.SELECTION_START);
                startTick = cursor.segment ? cursor.segment.tick : 0;
                cursor.rewind(Cursor.SELECTION_END);
                endTick = cursor.segment ? cursor.segment.tick : curScore.lastSegment.tick + 1;
                console.log("Processing selected range: tick " + startTick + " to " + endTick);
            } else {
                startTick = 0;
                endTick = curScore.lastSegment.tick + 1;
                console.log("Processing entire score: tick " + startTick + " to " + endTick);
            }

            // Build list of bandurria/laúd staff indices
            var bandurriaLaudStaves = [];
            for (var s = 0; s < curScore.nstaves; s++) {
                var staffElement = curScore.staves[s];
                if (isBandurriaOrLaud(staffElement)) {
                    bandurriaLaudStaves.push(s);
                    console.log("Staff " + s + " is bandurria/laúd");
                }
            }

            if (bandurriaLaudStaves.length === 0) {
                console.log("ERROR: No bandurria or laúd instruments found in score");
                curScore.endCmd(false);
                return;
            }

            // Iterate through bandurria/laúd staves only
            for (var staffIdx = 0; staffIdx < bandurriaLaudStaves.length; staffIdx++) {
                var staff = bandurriaLaudStaves[staffIdx];
                console.log("Processing staff " + staff);

                for (var voice = 0; voice < 4; voice++) {
                    cursor.staffIdx = staff;
                    cursor.voice = voice;
                    cursor.rewind(Cursor.SCORE_START);

                    // Move to selection start
                    while (cursor.segment && cursor.segment.tick < startTick) {
                        cursor.next();
                    }

                    // Process elements in the selected range
                    while (cursor.segment && cursor.segment.tick < endTick) {
                        if (cursor.element && cursor.element.type === Element.CHORD) {
                            var chord = cursor.element;

                            // Restore note properties
                            for (var n = 0; n < chord.notes.length; n++) {
                                var note = chord.notes[n];

                                if (settingsRemove.restoreVelocity) {
                                    note.userVelocity = 0;
                                }

                                if (settingsRemove.restoreNotePlayback) {
                                    note.play = true;
                                }

                                notesRestored++;
                            }

                            // Remove tremolo if present and enabled
                            if (settingsRemove.removeTremolos) {
                                if (chord.tremoloSingleChord) {
                                    try {
                                        removeElement(chord.tremoloSingleChord);
                                        tremolosRemoved++;
                                    } catch (e) {
                                        console.log("Error removing single-chord tremolo: " + e);
                                    }
                                }

                                if (chord.tremoloTwoChord) {
                                    try {
                                        removeElement(chord.tremoloTwoChord);
                                        tremolosRemoved++;
                                    } catch (e) {
                                        console.log("Error removing two-chord tremolo: " + e);
                                    }
                                }
                            }

                            // Restore articulations playback if enabled
                            // ONLY restore velocity-increasing articulations on SHORT notes
                            if (settingsRemove.restoreArticulations && chord.articulations) {
                                if (isShortNote(chord)) {
                                    // Short notes: restore ONLY velocity-increasing articulations
                                    for (var i = 0; i < chord.articulations.length; i++) {
                                        var artic = chord.articulations[i];
                                        if (artic && artic.symbol) {
                                            var symId = artic.symbol;
                                            if (velocityIncreaseArticulations.indexOf(symId) !== -1) {
                                                console.log("SHORT NOTE: Restoring velocity-increasing articulation symId=" + symId);
                                                artic.play = true;
                                                articulationsRestored++;
                                            }
                                        }
                                    }
                                } else {
                                    // Long notes: restore ALL articulations (but NOT ornaments - those are separate)
                                    for (var i = 0; i < chord.articulations.length; i++) {
                                        var artic = chord.articulations[i];
                                        if (artic && artic.symbol) {
                                            var symId = artic.symbol;
                                            // Skip ornaments if they should be restored separately
                                            if (trillArticulations.indexOf(symId) !== -1) {
                                                continue;  // Handle ornaments separately below
                                            }
                                            artic.play = true;
                                            articulationsRestored++;
                                        }
                                    }
                                }
                            }

                            // Restore ornaments playback if enabled (separate from articulations)
                            if (settingsRemove.restoreOrnaments && chord.articulations) {
                                for (var i = 0; i < chord.articulations.length; i++) {
                                    var artic = chord.articulations[i];
                                    if (artic && artic.symbol) {
                                        var symId = artic.symbol;
                                        if (trillArticulations.indexOf(symId) !== -1) {
                                            console.log("Restoring ornament articulation symId=" + symId);
                                            artic.play = true;
                                            articulationsRestored++;
                                        }
                                    }
                                }
                            }

                            // Check for ornament spanners (trills) via note spanners if enabled
                            if (settingsRemove.restoreOrnaments) {
                                for (var i = 0; i < chord.notes.length; i++) {
                                    if (chord.notes[i].spannerForward) {
                                        for (var j = 0; j < chord.notes[i].spannerForward.length; j++) {
                                            var spanner = chord.notes[i].spannerForward[j];
                                            if (spanner) {
                                                if (spanner.type === Element.TRILL) {
                                                    console.log("Restoring ornament spanner (trill line)");
                                                    spanner.play = true;
                                                    articulationsRestored++;
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Restore dynamics in annotations if enabled
                        if (cursor.segment.annotations) {
                            for (var i = 0; i < cursor.segment.annotations.length; i++) {
                                var annotation = cursor.segment.annotations[i];
                                if (!annotation || annotation.track === undefined)
                                    continue;

                                var elemStaff = Math.floor(annotation.track / 4);
                                if (bandurriaLaudStaves.indexOf(elemStaff) === -1)
                                    continue;

                                if (settingsRemove.restoreDynamics && (annotation.type === Element.DYNAMIC || annotation.type === Element.EXPRESSION)) {
                                    annotation.play = true;
                                    dynamicsRestored++;
                                }
                            }
                        }

                        cursor.next();
                    }
                }
            }

            // Process hairpins using unified spannersCache
            if (settingsRemove.restoreHairpins && spannersCache.spanners.length > 0) {
                console.log("Processing " + spannersCache.spanners.length + " spanners...");

                for (var i = 0; i < spannersCache.spanners.length; i++) {
                    var spanner = spannersCache.spanners[i];

                    // Only process hairpins
                    if (spanner.type !== Element.HAIRPIN) continue;

                    // Check if hairpin's track belongs to a bandurria/laúd staff
                    var spannerStaff = Math.floor(spanner.track / 4);
                    if (bandurriaLaudStaves.indexOf(spannerStaff) === -1) continue;

                    // Check if hairpin is in the selected range
                    if (useSelectionRange) {
                        var spannerTick = spanner.spannerTick ? spanner.spannerTick.ticks : spanner.tick;
                        if (spannerTick < startTick || spannerTick >= endTick) continue;
                    }

                    spanner.play = true;
                    hairpinsRestored++;
                }

                console.log("Restored " + hairpinsRestored + " hairpins");
            }

            console.log("Removed " + tremolosRemoved + " tremolo symbols");
            console.log("Restored " + notesRestored + " notes");
            console.log("Restored " + dynamicsRestored + " dynamics");
            console.log("Restored " + articulationsRestored + " articulations");
            console.log("Restored " + hairpinsRestored + " hairpins");

            curScore.endCmd();
        } catch (e) {
            console.log("Error: " + e.toString());
            curScore.endCmd(true);
        }
    }

    // ===== SoundFont Helper Functions =====

    // Normalize path separators for the current platform
    function normalizePath(path) {
        if (Qt.platform.os === "windows") {
            // Convert all forward slashes to backslashes on Windows
            return path.replace(/\//g, "\\");
        } else {
            // Convert all backslashes to forward slashes on Unix
            return path.replace(/\\/g, "/");
        }
    }

    function getDefaultPath() {
        var home = fileChecker.homePath();
        var path;

        if (Qt.platform.os === "osx" || Qt.platform.os === "macos") {
            path = home + "/Documents/MuseScore4/SoundFonts";
        } else if (Qt.platform.os === "windows") {
            path = home + "/Documents/MuseScore4/SoundFonts";
        } else {
            fileChecker.source = home + "/.local/share/MuseScore/MuseScore4/SoundFonts";
            path = fileChecker.exists() ? fileChecker.source : home + "/Documents/MuseScore4/SoundFonts";
        }
        return normalizePath(path);
    }

    function getDefaultPluginsPath() {
        var home = fileChecker.homePath();
        var path;

        if (Qt.platform.os === "osx" || Qt.platform.os === "macos") {
            path = home + "/Documents/MuseScore4/Plugins";
        } else if (Qt.platform.os === "windows") {
            path = home + "/Documents/MuseScore4/Plugins";
        } else {
            fileChecker.source = home + "/.local/share/MuseScore/MuseScore4/Plugins";
            path = fileChecker.exists() ? fileChecker.source : home + "/Documents/MuseScore4/Plugins";
        }
        return normalizePath(path);
    }

    function checkDirectory() {
        fileChecker.source = userSoundFontsDir;
        directoryExists = fileChecker.exists();
        return directoryExists;
    }

    function getFoundFilesCount() {
        var _ = filesStatusRevision;  // Force dependency on revision counter
        var count = 0;
        for (var i = 0; i < managedFiles.length; i++) {
            var status = filesStatus[managedFiles[i]];
            if (status && status.found) {
                count++;
            }
        }
        return count;
    }

    function getUpdatableFilesCount() {
        var _ = filesStatusRevision;  // Force dependency on revision counter
        var count = 0;
        for (var i = 0; i < managedFiles.length; i++) {
            var status = filesStatus[managedFiles[i]];
            if (status && status.found && status.needsUpdate) {
                count++;
            }
        }
        return count;
    }

    // Force UI update by reassigning filesStatus object and incrementing revision counter
    // QML doesn't detect changes to nested properties, so we need to reassign the whole object
    // and increment the revision counter to force re-evaluation of all bindings
    // Also reassign managedFiles to force Repeater to re-render
    function forceFilesStatusUpdate() {
        var temp = filesStatus;
        filesStatus = {};
        filesStatus = temp;
        filesStatusRevision++;

        // Force Repeater to re-render by creating a new array copy
        // Using concat([]) creates a shallow copy with new reference
        managedFiles = managedFiles.concat([]);
    }

    function checkAllSoundfonts() {
        // First check if directory exists
        if (!checkDirectory()) {
            console.log("✗ Directory does not exist: " + userSoundFontsDir);
            return;
        }

        var separator = (Qt.platform.os === "windows") ? "\\" : "/";

        for (var i = 0; i < managedFiles.length; i++) {
            var filename = managedFiles[i];
            var targetDir = getTargetDirectory(filename);
            var testPath = targetDir + (targetDir.endsWith("/") || targetDir.endsWith("\\") ? "" : separator) + filename;

            fileChecker.source = testPath;
            var exists = fileChecker.exists();

            // Initialize status object if it doesn't exist
            if (!filesStatus[filename]) {
                filesStatus[filename] = {
                    found: false,
                    needsUpdate: false,
                    localSize: 0,
                    remoteSize: 0,
                    localDate: "",
                    remoteDate: "",
                    downloading: false,
                    downloadComplete: false,
                    downloadError: false
                };
            }

            filesStatus[filename].found = exists;

            if (exists) {
                console.log("✓ Found: " + filename);
            } else {
                console.log("✗ Not found: " + filename);
            }
        }

        // Force UI update
        forceFilesStatusUpdate();
    }

    function checkRemoteUrl() {
        if (checkingRemoteUrl)
            return;

        checkingRemoteUrl = true;
        remoteUrlValid = false;

        // Test URL by checking if first managed file exists
        var testUrl = remoteBaseUrl + "/" + managedFiles[0];
        console.log("Checking remote base URL: " + testUrl);

        var xhr = new XMLHttpRequest();
        xhr.open("HEAD", testUrl, true);
        xhr.timeout = 5000;

        xhr.onload = function () {
            checkingRemoteUrl = false;
            if (xhr.status === 200) {
                remoteUrlValid = true;
                console.log("✓ Remote URL is valid");
            } else {
                remoteUrlValid = false;
                console.log("✗ Remote URL returned status: " + xhr.status);
            }
        };

        xhr.onerror = function () {
            checkingRemoteUrl = false;
            remoteUrlValid = false;
            console.log("✗ Remote URL check failed");
        };

        xhr.ontimeout = function () {
            checkingRemoteUrl = false;
            remoteUrlValid = false;
            console.log("✗ Remote URL check timed out");
        };

        xhr.send();
    }

    function getLocalFileSize(filePath) {
        fileChecker.source = filePath;
        if (!fileChecker.exists()) {
            return 0;
        }

        // Use system command to get actual file size in bytes
        var process = Qt.createQmlObject('import MuseScore 3.0; QProcess {}', plugin);

        var command, args;
        if (Qt.platform.os === "windows") {
            // Windows: use PowerShell to get file size
            command = "powershell";
            args = ["-Command", "(Get-Item '" + filePath + "').Length"];
        } else {
            // Unix/macOS: use stat command
            if (Qt.platform.os === "osx" || Qt.platform.os === "macos") {
                command = "stat";
                args = ["-f", "%z", filePath];
            } else {
                // Linux
                command = "stat";
                args = ["-c", "%s", filePath];
            }
        }

        process.startWithArgs(command, args);

        if (process.waitForFinished(5000)) {
            var output = process.readAllStandardOutput();
            // Convert to string and trim
            var outputStr = String(output).trim();
            var size = parseInt(outputStr);
            if (!isNaN(size) && size > 0) {
                console.log("Local file size from stat: " + size + " bytes");
                return size;
            } else {
                console.log("Could not parse file size from output: '" + outputStr + "'");
            }
        } else {
            console.log("Process timeout or failed for: " + filePath);
        }

        return 0;
    }

    // Helper function to check if any file needs update or download
    function hasUpdatesAvailable() {
        var _ = filesStatusRevision;  // Force dependency on revision counter
        for (var i = 0; i < managedFiles.length; i++) {
            var filename = managedFiles[i];
            if (!filesStatus[filename])
                continue;
            if (!filesStatus[filename].found || filesStatus[filename].needsUpdate) {
                return true;
            }
        }
        return false;
    }

    // Helper function to check if any file needs update (not missing, just update)
    function hasUpdatesOnly() {
        var _ = filesStatusRevision;  // Force dependency on revision counter
        for (var i = 0; i < managedFiles.length; i++) {
            var filename = managedFiles[i];
            if (!filesStatus[filename])
                continue;
            if (filesStatus[filename].found && filesStatus[filename].needsUpdate) {
                return true;
            }
        }
        return false;
    }

    // Helper function to check if any file is missing
    function hasMissingFiles() {
        var _ = filesStatusRevision;  // Force dependency on revision counter
        for (var i = 0; i < managedFiles.length; i++) {
            var filename = managedFiles[i];
            if (!filesStatus[filename])
                continue;
            if (!filesStatus[filename].found) {
                return true;
            }
        }
        return false;
    }

    // Helper function to get the target directory for a file
    function getTargetDirectory(filename) {
        // Plugin goes to plugins directory, soundfonts to soundfonts directory
        var dir = (filename === pluginFilename) ? userPluginsDir : userSoundFontsDir;
        return normalizePath(dir);
    }

    // Helper function to get the full local path for a file
    function getLocalPath(filename) {
        var separator = (Qt.platform.os === "windows") ? "\\" : "/";
        var dir = getTargetDirectory(filename);
        if (dir.charAt(dir.length - 1) !== "/" && dir.charAt(dir.length - 1) !== "\\") {
            dir += separator;
        }
        return normalizePath(dir + filename);
    }

    function checkAllUpdates() {
        var separator = (Qt.platform.os === "windows") ? "\\" : "/";

        for (var i = 0; i < managedFiles.length; i++) {
            var filename = managedFiles[i];

            // Skip if file not found or status not initialized
            if (!filesStatus[filename] || !filesStatus[filename].found) {
                continue;
            }

            var targetDir = getTargetDirectory(filename);
            var localPath = targetDir + (targetDir.endsWith("/") || targetDir.endsWith("\\") ? "" : separator) + filename;
            var remoteUrl = remoteBaseUrl + "/" + filename;

            // Get local file size and date
            var localSize = getLocalFileSize(localPath);
            filesStatus[filename].localSize = localSize;

            fileChecker.source = localPath;
            var localTimestamp = fileChecker.modifiedTime();
            if (localTimestamp > 0) {
                var localDate = new Date(localTimestamp * 1000);
                filesStatus[filename].localDate = Qt.formatDateTime(localDate, "dd/MM/yyyy hh:mm");
            }

            // Check remote size
            checkFileUpdate(filename, localPath, remoteUrl);
        }
    }

    function checkFileUpdate(filename, localPath, remoteUrl) {
        var xhr = new XMLHttpRequest();
        xhr.open("HEAD", remoteUrl, true);

        xhr.onload = function () {
            if (xhr.status === 200) {
                var contentLength = parseInt(xhr.getResponseHeader("Content-Length"));

                if (contentLength > 0) {
                    filesStatus[filename].remoteSize = contentLength;

                    // Compare sizes
                    if (filesStatus[filename].localSize > 0 && contentLength !== filesStatus[filename].localSize) {
                        filesStatus[filename].needsUpdate = true;
                        console.log("✓ Update available for " + filename);
                    } else {
                        filesStatus[filename].needsUpdate = false;
                        console.log("✓ " + filename + " is up to date");
                    }

                    // Force UI update
                    forceFilesStatusUpdate();
                }
            }
        };

        xhr.onerror = function () {
            console.log("Error checking update for " + filename);
        };

        xhr.send();
    }

    function checkCurlAvailable() {
        console.log("Checking if curl is available...");
        var process = Qt.createQmlObject('import MuseScore 3.0; QProcess {}', plugin);

        process.finished.connect(function (exitCode, exitStatus) {
            curlAvailable = (exitCode === 0 || exitCode === 2);
            curlChecked = true;
            console.log("curl available: " + curlAvailable);

            // Check for plugin updates if curl is available
            if (curlAvailable) {
                checkPluginUpdate();
            }
        });

        process.startWithArgs("curl", ["--version"]);
    }

    // Unified download function for all managed files (plugin + soundfonts)
    function downloadFiles(filesList) {
        if (anyDownloading) {
            return;
        }

        // Build list of files to download (not found or needs update)
        filesToDownload = [];
        for (var i = 0; i < filesList.length; i++) {
            var filename = filesList[i];
            if (filesStatus[filename] && (!filesStatus[filename].found || filesStatus[filename].needsUpdate)) {
                filesToDownload.push(filename);
            }
        }

        if (filesToDownload.length === 0) {
            downloadStatus = isSpanish ? "✓ Todos los archivos están actualizados" : "✓ All files are up to date";
            return;
        }

        totalToDownload = filesToDownload.length;
        downloadedCount = 0;

        console.log("Files to download: " + filesToDownload.join(", "));

        // Check if we can download
        if (!writeBinaryAvailable && !curlAvailable) {
            downloadStatus = isSpanish ? "✗ curl no está disponible\n\n" + "Por favor, instala curl para descargar automáticamente:\n\n" + getCurlInstallInstructions() : "✗ curl is not available\n\n" + "Please install curl to download automatically:\n\n" + getCurlInstallInstructions();
            return;
        }

        // Start downloading the first file
        downloadNextFile();
    }

    function downloadNextFile() {
        if (downloadedCount >= filesToDownload.length) {
            // All files downloaded
            anyDownloading = false;
            downloadStatus = isSpanish ? "✓ Todos los archivos instalados correctamente!\n\n" + "Haz clic en 'Reiniciar MuseScore' para usar los nuevos archivos." : "✓ All files installed successfully!\n\n" + "Click 'Restart MuseScore' to use the new files.";
            showRestartButton = true;
            console.log("All downloads complete!");

            // Refresh file status
            checkAllSoundfonts();
            checkAllUpdates();
            checkPluginUpdate();
            return;
        }

        currentDownloadFile = filesToDownload[downloadedCount];
        anyDownloading = true;

        // Mark file as downloading
        filesStatus[currentDownloadFile].downloading = true;
        filesStatus[currentDownloadFile].downloadComplete = false;
        filesStatus[currentDownloadFile].downloadError = false;

        // Force UI update
        var temp = filesStatus;
        filesStatus = {};
        filesStatus = temp;

        var progressText = "(" + (downloadedCount + 1) + "/" + totalToDownload + ")";
        downloadStatus = isSpanish ? "Descargando " + currentDownloadFile + " " + progressText + "..." : "Downloading " + currentDownloadFile + " " + progressText + "...";

        console.log("Starting download: " + currentDownloadFile);

        // Always use curl for all downloads
        if (curlAvailable) {
            downloadFileWithCurl(currentDownloadFile);
        } else {
            anyDownloading = false;
            filesStatus[currentDownloadFile].downloading = false;
            filesStatus[currentDownloadFile].downloadError = true;
            forceFilesStatusUpdate();
            downloadStatus = isSpanish ? "✗ No se puede descargar: curl no disponible" : "✗ Cannot download: curl not available";
        }
    }

    function downloadTextFileWithXHR(filename) {
        var targetPath = getLocalPath(filename);
        var fileUrl = remoteBaseUrl + "/" + filename;

        console.log("Downloading text file from: " + fileUrl);
        console.log("Target path: " + targetPath);
        console.log("userPluginsDir: " + userPluginsDir);

        var xhr = new XMLHttpRequest();
        xhr.open("GET", fileUrl, true);

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    console.log("Download complete, writing text file...");
                    var content = xhr.responseText;
                    console.log("File size: " + content.length + " bytes");
                    console.log("Writing to: " + targetPath);

                    // Write as text file
                    fileChecker.source = targetPath;
                    var writeResult = fileChecker.write(content);
                    console.log("Write result: " + writeResult);
                    if (writeResult) {
                        console.log("OK " + filename + " installed successfully");

                        // Update file status
                        filesStatus[filename].found = true;
                        filesStatus[filename].localSize = content.length;
                        filesStatus[filename].needsUpdate = false;
                        filesStatus[filename].downloading = false;
                        filesStatus[filename].downloadComplete = true;
                        filesStatus[filename].downloadError = false;
                        forceFilesStatusUpdate();

                        // Move to next file
                        downloadedCount++;
                        downloadNextFile();
                    } else {
                        anyDownloading = false;
                        filesStatus[filename].downloading = false;
                        filesStatus[filename].downloadComplete = false;
                        filesStatus[filename].downloadError = true;
                        forceFilesStatusUpdate();
                        downloadStatus = isSpanish ? "✗ Error: " + filename + " no se pudo guardar" : "✗ Error: " + filename + " could not be saved";
                        console.log("Error: Installation failed for " + filename);
                    }
                } else {
                    anyDownloading = false;
                    filesStatus[filename].downloading = false;
                    filesStatus[filename].downloadComplete = false;
                    filesStatus[filename].downloadError = true;
                    forceFilesStatusUpdate();
                    downloadStatus = isSpanish ? "✗ Error de descarga (HTTP " + xhr.status + ")" : "✗ Download error (HTTP " + xhr.status + ")";
                    console.log("Download failed for " + filename + ". HTTP status: " + xhr.status);
                }
            }
        };

        xhr.onerror = function () {
            anyDownloading = false;
            filesStatus[filename].downloading = false;
            filesStatus[filename].downloadComplete = false;
            filesStatus[filename].downloadError = true;
            forceFilesStatusUpdate();
            downloadStatus = isSpanish ? "✗ Error de conexión descargando " + filename : "✗ Connection error downloading " + filename;
            console.log("Network error downloading " + filename);
        };

        xhr.send();
    }

    function downloadFileWithXHR(filename) {
        var targetPath = getLocalPath(filename);
        var fileUrl = remoteBaseUrl + "/" + filename;

        console.log("Downloading from: " + fileUrl);
        console.log("Target path: " + targetPath);

        var xhr = new XMLHttpRequest();
        xhr.open("GET", fileUrl, true);
        xhr.responseType = "arraybuffer";

        xhr.onload = function () {
            if (xhr.status === 200) {
                console.log("Download complete, writing file...");

                // Convert ArrayBuffer to string of bytes (0-255)
                var buffer = new Uint8Array(xhr.response);
                var binaryString = "";
                for (var i = 0; i < buffer.length; i++) {
                    binaryString += String.fromCharCode(buffer[i]);
                }

                console.log("File size: " + buffer.length + " bytes");

                // Install to user's directory
                fileChecker.source = targetPath;
                if (fileChecker.writeBinary(binaryString)) {
                    console.log("✓ " + filename + " installed successfully");

                    // Update file status
                    filesStatus[filename].found = true;
                    filesStatus[filename].localSize = buffer.length;
                    filesStatus[filename].needsUpdate = false;
                    filesStatus[filename].downloading = false;
                    filesStatus[filename].downloadComplete = true;
                    filesStatus[filename].downloadError = false;
                    forceFilesStatusUpdate();

                    // Move to next file
                    downloadedCount++;
                    downloadNextFile();
                } else {
                    anyDownloading = false;
                    filesStatus[filename].downloading = false;
                    filesStatus[filename].downloadComplete = false;
                    filesStatus[filename].downloadError = true;
                    forceFilesStatusUpdate();
                    downloadStatus = isSpanish ? "✗ Error: " + filename + " no se pudo guardar" : "✗ Error: " + filename + " could not be saved";
                    console.log("Error: Installation failed for " + filename);
                }
            } else {
                anyDownloading = false;
                filesStatus[filename].downloading = false;
                filesStatus[filename].downloadComplete = false;
                filesStatus[filename].downloadError = true;
                forceFilesStatusUpdate();
                downloadStatus = isSpanish ? "✗ Error de descarga (HTTP " + xhr.status + ")\n" + "Archivo: " + filename : "✗ Download error (HTTP " + xhr.status + ")\n" + "File: " + filename;
                console.log("Download failed for " + filename + ". HTTP status: " + xhr.status);
            }
        };

        xhr.onerror = function () {
            anyDownloading = false;
            filesStatus[filename].downloading = false;
            filesStatus[filename].downloadComplete = false;
            filesStatus[filename].downloadError = true;
            forceFilesStatusUpdate();
            downloadStatus = isSpanish ? "✗ Error de conexión descargando " + filename : "✗ Connection error downloading " + filename;
            console.log("Network error downloading " + filename);
        };

        xhr.send();
    }

    function downloadFileWithCurl(filename) {
        var targetPath = getLocalPath(filename);
        var fileUrl = remoteBaseUrl + "/" + filename;

        console.log("Downloading from: " + fileUrl);
        console.log("Target path: " + targetPath);

        var process = Qt.createQmlObject('import MuseScore 3.0; QProcess {}', plugin);

        process.finished.connect(function (exitCode, exitStatus) {
            console.log("Download process finished for " + filename + ". Exit code: " + exitCode);

            if (exitCode === 0) {
                // Verify the file exists and has content
                fileChecker.source = targetPath;
                if (fileChecker.exists()) {
                    console.log("✓ " + filename + " installed successfully");

                    // Update file status
                    var localSize = getLocalFileSize(targetPath);
                    filesStatus[filename].found = true;
                    filesStatus[filename].localSize = localSize;
                    filesStatus[filename].needsUpdate = false;
                    filesStatus[filename].downloading = false;
                    filesStatus[filename].downloadComplete = true;
                    filesStatus[filename].downloadError = false;
                    forceFilesStatusUpdate();

                    downloadStatus = isSpanish ? "✓ " + filename + " instalado" : "✓ " + filename + " installed";

                    // Move to next file
                    downloadedCount++;
                    downloadNextFile();
                } else {
                    anyDownloading = false;
                    filesStatus[filename].downloading = false;
                    filesStatus[filename].downloadComplete = false;
                    filesStatus[filename].downloadError = true;
                    forceFilesStatusUpdate();
                    downloadStatus = isSpanish ? "✗ Error: " + filename + " no se pudo guardar" : "✗ Error: " + filename + " could not be saved";
                    console.log("Error: File does not exist after download");
                }
            } else {
                var output = process.readAllStandardOutput();
                console.log("Download failed for " + filename + ". Output: " + output);
                anyDownloading = false;
                filesStatus[filename].downloading = false;
                filesStatus[filename].downloadComplete = false;
                filesStatus[filename].downloadError = true;
                forceFilesStatusUpdate();
                downloadStatus = isSpanish ? "✗ Error de descarga (código " + exitCode + ")\nArchivo: " + filename : "✗ Download error (code " + exitCode + ")\nFile: " + filename;
            }
        });

        // Use curl to download (available on macOS/Linux, and modern Windows 10+)
        process.startWithArgs("curl", ["-L", "-o", targetPath, fileUrl]);
    }

    function getCurlInstallInstructions() {
        if (Qt.platform.os === "osx" || Qt.platform.os === "macos") {
            return isSpanish ? "macOS: curl ya debería estar instalado.\nSi no funciona, reinstala con: brew install curl" : "macOS: curl should already be installed.\nIf not working, reinstall with: brew install curl";
        } else if (Qt.platform.os === "windows") {
            return isSpanish ? "Windows 10+: curl está incluido.\nSi no funciona: winget install curl" : "Windows 10+: curl is included.\nIf not working: winget install curl";
        } else {
            return isSpanish ? "Linux: sudo apt install curl\n    o: sudo yum install curl" : "Linux: sudo apt install curl\n    or: sudo yum install curl";
        }
    }

    // ===== Plugin Update Functions =====

    function checkPluginUpdate() {
        console.log("Checking for plugin update...");
        checkingPluginUpdate = true;

        // Get current plugin file path
        var pluginPath = Qt.resolvedUrl("PulsoPua.qml").toString();
        if (pluginPath.indexOf("file://") === 0) {
            pluginPath = pluginPath.substring(7);
        }
        // Windows: remove extra leading slash for paths like /C:/...
        if (Qt.platform.os === "windows" && pluginPath.charAt(0) === '/') {
            pluginPath = pluginPath.substring(1);
        }

        // Initialize plugin in filesStatus if needed
        if (!filesStatus[pluginFilename]) {
            filesStatus[pluginFilename] = {
                found: false,
                needsUpdate: false,
                localSize: 0,
                remoteSize: 0,
                localDate: "",
                remoteDate: "",
                downloading: false,
                downloadComplete: false,
                downloadError: false
            };
        }

        // Get local plugin size
        var localSize = getLocalFileSize(pluginPath);
        filesStatus[pluginFilename].localSize = localSize;
        filesStatus[pluginFilename].found = (localSize > 0);
        console.log("Local plugin size: " + localSize);

        // Get local file date
        fileChecker.source = pluginPath;
        var localTimestamp = fileChecker.modifiedTime();
        if (localTimestamp > 0) {
            var localDate = new Date(localTimestamp * 1000);
            filesStatus[pluginFilename].localDate = Qt.formatDateTime(localDate, "dd/MM/yyyy hh:mm");
        }

        // Check remote plugin size using curl HEAD request (same method as soundfonts)
        var pluginRemoteUrl = remoteBaseUrl + "/" + pluginFilename;

        var process = Qt.createQmlObject('import MuseScore 3.0; QProcess {}', plugin);

        process.finished.connect(function (exitCode, exitStatus) {
            checkingPluginUpdate = false;
            if (exitCode === 0) {
                var output = String(process.readAllStandardOutput());
                // Extract Content-Length from headers (get the last one after redirects)
                var matches = output.match(/[Cc]ontent-[Ll]ength:\s*(\d+)/g);
                if (matches && matches.length > 0) {
                    var lastMatch = matches[matches.length - 1].match(/(\d+)/);
                    if (lastMatch) {
                        var remoteSize = parseInt(lastMatch[1]);
                        filesStatus[pluginFilename].remoteSize = remoteSize;
                        console.log("Remote plugin size: " + remoteSize);

                        // Compare sizes
                        if (remoteSize > 0 && localSize > 0 && remoteSize !== localSize) {
                            filesStatus[pluginFilename].needsUpdate = true;
                            console.log("Update available for plugin");
                        } else {
                            filesStatus[pluginFilename].needsUpdate = false;
                            console.log("Plugin is up to date");
                        }

                        // Force UI update
                        forceFilesStatusUpdate();
                    }
                }
            } else {
                console.log("Failed to check plugin update via curl");
            }
        });

        // Use curl with HEAD request to get Content-Length
        process.startWithArgs("curl", ["-sLI", pluginRemoteUrl]);
    }

    onRun: {
        console.log("Starting Pulso y Púa plugin...");

        if (!curScore) {
            console.log("No score open");
            quit();
            return;
        }
    }
}
