pragma Singleton
import QtQuick

QtObject {
    // The lock face morphs out of the bar, so both clocks have to read identically.
    function clockTime(now, use24Hour, showSeconds) {
        let hours = now.getHours()
        let suffix = ""
        if (!use24Hour) {
            suffix = hours >= 12 ? " PM" : " AM"
            hours = hours % 12
            if (hours === 0) hours = 12
        }
        const hh = use24Hour ? String(hours).padStart(2, "0") : String(hours)
        const mm = String(now.getMinutes()).padStart(2, "0")
        const ss = String(now.getSeconds()).padStart(2, "0")
        return (showSeconds ? hh + ":" + mm + ":" + ss : hh + ":" + mm) + suffix
    }
}
