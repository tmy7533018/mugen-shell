-- Personal animation tuning; applied after the shipped Hyprland defaults.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 10, bezier = "softIn", style = "popin 70%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 8, bezier = "fadeSoft", style = "popin 90%" })

-- Slightly reduce the desktop scale on the built-in display.
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = "1.25" })
