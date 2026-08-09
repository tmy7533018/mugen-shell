pragma Singleton
import QtQuick
import Quickshell

QtObject {
    // Neighbouring months come along so a grid's leading and trailing cells have events too.
    function rangeArgv(year, month) {
        return ["python3", Quickshell.shellDir + "/scripts/calendar-cli.py", "list-range",
                "--start", Qt.formatDate(new Date(year, month - 1, 1), "yyyy-MM-dd"),
                "--end", Qt.formatDate(new Date(year, month + 2, 0), "yyyy-MM-dd")]
    }
}
