pragma Singleton
import QtQuick

QtObject {
    // The argv that uninstalls app from a terminal, or null when there is nothing to run.
    function argv(app, terminal) {
        if (!app) return null
        let steamMatch = (app.exec || "").match(/steam:\/\/rungameid\/(\d+)/)
        if (steamMatch) return ["steam", "steam://uninstall/" + steamMatch[1]]
        let df = app.desktopFile || ""
        if (df === "") return null
        // terminal route on purpose: the user sees what gets removed and confirms in the package manager
        let holdTail = "; echo; printf 'Press Enter to close...'; read _"
        let termPrefix = Hypr.terminalArgvPrefix(terminal)
        if (df.indexOf("flatpak/exports/share/applications/") !== -1) {
            let appId = df.split("/").pop().replace(/\.desktop$/, "")
            return termPrefix.concat([
                "sh", "-c",
                "flatpak uninstall \"$1\"" + holdTail, "sh", appId
            ])
        } else {
            // user-local .desktop copies often point at packaged binaries, so use the Exec target's owner.
            let execFirst = (app.exec || "").split(" ")[0]
            let execBase = execFirst.split("/").pop()
            if (execFirst[0] !== "/" || ["env", "sh", "bash", "zsh", "python", "python3"].indexOf(execBase) !== -1) {
                execFirst = ""
            }
            return termPrefix.concat([
                "sh", "-c",
                "if ! command -v pacman >/dev/null 2>&1; then "
                    + "echo 'No system package manager found — on NixOS, remove the app from your Nix config instead.'; "
                    + "echo \"  Entry: $1\"; "
                    + "else "
                    + "pkg=$(pacman -Qoq -- \"$1\" 2>/dev/null); "
                    + "if [ -z \"$pkg\" ] && [ -n \"$2\" ]; then "
                    + "pkg=$(pacman -Qoq -- \"$(realpath \"$2\" 2>/dev/null || printf %s \"$2\")\" 2>/dev/null); fi; "
                    + "if [ -n \"$pkg\" ]; then echo \"Owning package: $pkg\"; echo; "
                    + "if command -v sudo >/dev/null 2>&1; then sudo pacman -R \"$pkg\"; else echo \"sudo not found, run as root: pacman -R $pkg\"; fi; "
                    + "else echo 'No package owns this app — it looks manually installed.'; "
                    + "echo \"  Entry: $1\"; "
                    + "if [ -n \"$2\" ]; then echo \"  Exec:  $2\"; fi; "
                    + "echo 'Remove those files manually to uninstall it.'; fi; fi" + holdTail,
                "sh", df, execFirst
            ])
        }
    }
}
