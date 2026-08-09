pragma Singleton
import QtQuick

QtObject {
    // Every shell process re-reads these on change, and one hitting a truncate would clobber it.
    function atomicWriteArgv(dir, file, json) {
        return ["bash", "-c",
                // $$ in the scratch name keeps two concurrent savers apart.
                "mkdir -p \"$1\" && tmp=\"$2.$$.tmp\""
                + " && cat > \"$tmp\" <<'MUGEN_JSON_EOF' && mv \"$tmp\" \"$2\"\n"
                + json + "\nMUGEN_JSON_EOF",
                "bash", dir, file]
    }
}
