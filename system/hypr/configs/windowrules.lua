-- Window and layer rules, dofile'd by hyprland.lua.

hl.window_rule({ name = "quickshell-nofocus", match = { class = "^(quickshell)$" }, no_focus = true })
hl.layer_rule({ name = "quickshell-blur", match = { namespace = "quickshell" }, blur = true, ignore_alpha = 0 })

hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "fix-xwayland-drag", match = { xwayland = true, class = "^$", title = "^$" }, no_focus = true })

hl.window_rule({ name = "pavucontrol",     match = { class = "^(org\\.pulseaudio\\.pavucontrol)$" }, float = true, size = "(monitor_w*0.5) (monitor_h*0.6)", center = true })
hl.window_rule({ name = "save-dialog",     match = { title = "^(Save As|Save a File|Pick Files)$" },  float = true, size = "(monitor_w*0.5) (monitor_h*0.6)", center = true })
hl.window_rule({ name = "open-files",      match = { initial_title = "^(Open Files)$" },               float = true, size = "(monitor_w*0.5) (monitor_h*0.5)", center = true })
hl.window_rule({ name = "jp-file-dialog",  match = { title = "^(.*ファイル.*)$" },                       float = true, size = "(monitor_w*0.5) (monitor_h*0.5)", center = true })

hl.window_rule({ name = "kitty-float",     match = { class = "^(kitty)$" },  float = true, size = "1050 600", center = true })
hl.window_rule({ name = "thunar-float",    match = { class = "^(thunar)$" }, float = true, size = "1050 600", center = true })
hl.window_rule({ name = "imv-float",       match = { class = "^(imv)$" },    float = true, size = "1050 600", center = true })
hl.window_rule({ name = "mpv-float",       match = { class = "^(mpv)$" },    float = true, size = "1050 600", center = true })

hl.window_rule({ name = "mugen-shortcuts", match = { title = "^(Mugen Shortcuts)$" }, float = true, size = "560 540", center = true })
hl.window_rule({ name = "mugen-calendar",  match = { title = "^(Mugen Calendar)$" },  float = true, size = "900 560", center = true })
-- Sized by the window itself; a rule here would override its implicit size.
hl.window_rule({ name = "mugen-settings",  match = { title = "^(Mugen Settings)$" }, float = true, center = true })
hl.window_rule({ name = "mugen-yura-settings", match = { title = "^(Yura Settings)$" }, float = true, center = true })
hl.window_rule({ name = "steam-settings",  match = { class = "^(steam)$", title = "^(Steam設定)$" }, float = true, size = "1050 600", center = true })
