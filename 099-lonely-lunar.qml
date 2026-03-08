import QtQuick 2.1
import Nemo.Configuration 1.0
import org.asteroid.utils 1.0

Item {
    id: root
    anchors.fill: parent
    clip: false

    property bool displayOn: true
    property bool isDesktop: (typeof(desktop) !== "undefined")
    property bool isApp: !isDesktop && !isSettings
    property bool isSettings: (typeof(layerStack) !== "undefined")

    property var newWatchFaceSource

    ConfigurationValue {
        id: previousWatchFaceSource
        key: "/desktop/asteroid/previous-watchface"
        defaultValue: "file:///usr/share/asteroid-launcher/watchfaces/000-default-digital.qml"
    }

    ConfigurationValue {
        id: currentWatchFaceSource
        key: "/desktop/asteroid/watchface"
        defaultValue: "file:///usr/share/asteroid-launcher/watchfaces/000-default-digital.qml"
        onValueChanged: {
            if (!isDesktop) {
                previousWatchFaceSource.value = newWatchFaceSource
                newWatchFaceSource = value
            }
        }
    }

    Timer {
        id: watchfaceTimer
        interval: 150
        repeat: false
        onTriggered: if (isDesktop) watchface.source = previousWatchFaceSource.value
    }

    Component.onCompleted: {
        newWatchFaceSource = currentWatchFaceSource.value
        watchfaceTimer.start()
    }

    Item {
        id: layer2mask
        width: parent.width * 1.1
        height: parent.height * 1.1
        x: -parent.width * 0.05
        y: -parent.height * 0.05
        visible: true
        opacity: 0.0
        layer.enabled: true
        layer.smooth: true

        Rectangle {
            anchors.fill: parent
            color: "black"
        }

        Item {
            anchors.centerIn: parent
            width: root.width
            height: root.height

            AnimatedImage {
                id: moonImage
                cache: !isSettings
                anchors.fill: parent
                fillMode: Image.PreserveAspectFit
                source: "file:///usr/share/asteroid-launcher/watchfaces-img/lunar-libration-phase-img.gif"
                playing: false

                opacity: 0.0

                readonly property int midFrame: frameCount / 2
            }

            Loader {
                id: watchface
                anchors.fill: parent
                active: isDesktop
                visible: isDesktop
                opacity: visible ? 1.0 : 0.0
            }
        }
    }

    ParallelAnimation {
        id: moonTransition
        
        NumberAnimation {
            target: moonImage
            property: "currentFrame"
            duration: 800 
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: moonImage
            property: "opacity"
            duration: 800
            easing.type: Easing.Linear
        }
    }

    Connections {
        target: compositor

        function onDisplayOn() {
            displayOn = true
            moonTransition.stop();
            moonTransition.animations[0].from = moonImage.currentFrame;
            moonTransition.animations[0].to = moonImage.midFrame;
            
            moonTransition.animations[1].from = moonImage.opacity;
            moonTransition.animations[1].to = 1.0;
            
            moonTransition.start();
        }

        function onDisplayOff() {
            displayOn = false
            moonTransition.stop();
            moonTransition.animations[0].from = moonImage.currentFrame;
            moonTransition.animations[0].to = moonImage.frameCount;
            
            moonTransition.animations[1].from = moonImage.opacity;
            moonTransition.animations[1].to = 0.0;
            
            moonTransition.start();
        }
    }

    Rectangle {
        id: _mask
        anchors.fill: layer2mask
        color: Qt.rgba(0, 1, 0, 0)
        visible: true

        Rectangle {
            anchors.fill: parent
            radius: DeviceSpecs.hasRoundScreen ? width/2 : 0
        }

        layer.enabled: true
        layer.samplerName: "maskSource"
        layer.effect: ShaderEffect {
            property variant source: layer2mask
            
            // The coordinate of the screen edge within the texture (0.04545...)
            property real screenEdge: 0.05 / 1.1
            
            // For round screens: The visible radius is 0.5 screen units.
            // In texture units, that is 0.5 / 1.1.
            property real visibleRadius: 0.5 / 1.1
            
            property bool isRound: DeviceSpecs.hasRoundScreen

            fragmentShader: "
                    #extension GL_OES_standard_derivatives: enable
                    #ifdef GL_ES
                        precision lowp float;
                    #endif // GL_ES
                    varying highp vec2 qt_TexCoord0;
                    uniform highp float qt_Opacity;
                    uniform lowp sampler2D source;
                    uniform lowp sampler2D maskSource;
                    
                    uniform lowp float screenEdge;
                    uniform lowp float visibleRadius;
                    uniform lowp bool isRound;
                    
                    void main(void) {
                        lowp float vignette;
                        
                        if (isRound) {
                            // Round Screen Logic
                            lowp float x, y, distSquared;
                            x = qt_TexCoord0.x - 0.5;
                            y = qt_TexCoord0.y - 0.5;
                            distSquared = x * x + y * y;
                            lowp float dist = sqrt(distSquared);

                            // Fade from opaque at visibleRadius to transparent at 0.5 (texture edge)
                            // smoothstep(edge1, edge0, value) -> 1.0 at visibleRadius, 0.0 at 0.5
                            vignette = smoothstep(0.5, visibleRadius, dist);
                        } else {
                            // Square Screen Logic (Rectangular Vignette)
                            // Calculate distance to texture edges
                            lowp float distX = min(qt_TexCoord0.x, 1.0 - qt_TexCoord0.x);
                            lowp float distY = min(qt_TexCoord0.y, 1.0 - qt_TexCoord0.y);
                            
                            // Fade from opaque at screenEdge to transparent at 0.0 (texture edge)
                            // smoothstep(0.0, screenEdge, distX) -> 0.0 at texture edge, 1.0 at screen edge
                            lowp float vigX = smoothstep(0.0, screenEdge, distX);
                            lowp float vigY = smoothstep(0.0, screenEdge, distY);
                            
                            vignette = vigX * vigY;
                        }

                        gl_FragColor = texture2D(source, qt_TexCoord0).rgba * vignette * qt_Opacity;
                    }
                "
        }
    }
}