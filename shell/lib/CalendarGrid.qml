pragma Singleton
import QtQuick

QtObject {
    // month is 0-based. minCells keeps a fixed-row grid from reflowing on short months.
    function cells(year, month, weekStart, minCells) {
        const lead = (new Date(year, month, 1).getDay() - weekStart + 7) % 7
        const days = new Date(year, month + 1, 0).getDate()
        const span = Math.max(minCells || 0, Math.ceil((lead + days) / 7) * 7)
        const out = []
        for (let i = 0; i < span; i++) {
            const d = new Date(year, month, 1 - lead + i)
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month,
                key: Qt.formatDate(d, "yyyy-MM-dd")
            })
        }
        return out
    }
}
