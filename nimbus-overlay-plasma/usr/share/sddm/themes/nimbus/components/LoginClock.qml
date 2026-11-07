import QtQuick
import QtQuick.Layouts

// LoginClock — reloj + fecha del login (F2-T02). Sin dependencias SDDM.
Item {
    id: root

    property bool clock24h: true
    property string textColor: "#FFFFFF"
    property string subColor: "#EBEBF5"
    property real subAlpha: 0.6
    property string fontFamily: "Inter"

    function tick() {
        var d = new Date();
        var h = d.getHours();
        var m = d.getMinutes();
        if (!clock24h) {
            var ap = h >= 12 ? " PM" : " AM";
            h = h % 12;
            if (h === 0)
                h = 12;

            clockLabel.text = h + ":" + ("0" + m).slice(-2) + ap;
        } else {
            clockLabel.text = ("0" + h).slice(-2) + ":" + ("0" + m).slice(-2);
        }
        var days = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"];
        var months = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"];
        dateLabel.text = days[d.getDay()] + ", " + d.getDate() + " de " + months[d.getMonth()];
    }

    implicitWidth: clockLabel.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        spacing: 4

        Text {
            id: clockLabel

            Layout.alignment: Qt.AlignHCenter
            color: root.textColor
            font.family: root.fontFamily
            font.pixelSize: 76
            font.weight: Font.DemiBold
        }

        Text {
            id: dateLabel

            Layout.alignment: Qt.AlignHCenter
            color: root.subColor
            opacity: root.subAlpha
            font.family: root.fontFamily
            font.pixelSize: 17
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tick()
    }
}
