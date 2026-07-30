import QtQuick
import Qt5Compat.GraphicalEffects
import "../../lib" as Theme

Item {
    id: root

    property string source: ""
    property int bleed: 0
    property int blurRadius: 64
    property int blurTexels: 96
    property int fadeDuration: 600

    property bool _aIsFront: true

    onSourceChanged: root.adopt()

    function adopt() {
        if (root.source === "") return
        const front = root._aIsFront ? layerA : layerB
        const back = root._aIsFront ? layerB : layerA
        if (root.source === front.url) return
        back.url = root.source
        root.promote()
    }

    function promote() {
        const front = root._aIsFront ? layerA : layerB
        const back = root._aIsFront ? layerB : layerA
        if (back.url === "" || !back.loaded) return
        fade.stop()
        front.opacity = 1
        front.z = 0
        back.opacity = 0
        back.z = 1
        root._aIsFront = !root._aIsFront
        fade.target = back
        fade.restart()
    }

    NumberAnimation {
        id: fade
        property: "opacity"
        from: 0
        to: 1
        duration: root.fadeDuration
        easing.type: Theme.Motion.easeMove
    }

    component ArtLayer: Item {
        id: art

        property var owner
        property string url: ""
        property int margin: 0
        property int texels: 96
        property int softness: 64

        readonly property bool loaded: image.status === Image.Ready

        anchors.fill: parent

        onLoadedChanged: if (art.owner) art.owner.promote()

        Image {
            id: image
            anchors.fill: parent
            anchors.margins: -art.margin
            source: art.url
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            smooth: true
            visible: false

            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(art.texels,
                                       Math.max(2, Math.round(art.texels * height / Math.max(1, width))))
        }

        FastBlur {
            anchors.fill: image
            source: image
            radius: art.softness
        }
    }

    ArtLayer {
        id: layerA
        owner: root
        margin: root.bleed
        texels: root.blurTexels
        softness: root.blurRadius
    }

    ArtLayer {
        id: layerB
        owner: root
        margin: root.bleed
        texels: root.blurTexels
        softness: root.blurRadius
    }
}
