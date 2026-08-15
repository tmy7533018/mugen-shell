pragma Singleton
import QtQuick

QtObject {
    // Neighbouring months come along so a grid's leading and trailing cells have events too.
    function rangeArgv(year, month) {
        return ["mugen-ai", "calendar", "list-range",
                "--start", Qt.formatDate(new Date(year, month - 1, 1), "yyyy-MM-dd"),
                "--end", Qt.formatDate(new Date(year, month + 2, 0), "yyyy-MM-dd")]
    }
}
