-- Demo VM only. QEMU's virtio-gpu cursor planes are unreliable.
hl.config({ cursor = { no_hardware_cursors = true } })

-- A fresh VM has no wallpaper, so nothing would seed the generated palette.
hl.on("hyprland.start", function()
    hl.exec_cmd(
        "sh -lc 'sleep 2; " ..
        "test -f ~/.cache/mugen-shell/wallp/current_wallpaper_path.txt || " ..
        "~/.config/quickshell/mugen-shell/scripts/change-wallpaper.sh " ..
        "~/.local/share/mugen-shell/wallpapers/desert-sunset.jpg'"
    )
end)
