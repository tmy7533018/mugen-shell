#!/usr/bin/env bash
set -euo pipefail

CONF="${HYPR_CONFIG_FILE:-${XDG_CONFIG_HOME:-${HOME}/.config}/hypr/configs/looknfeel.conf}"

canon() {
    echo "$1" | tr '[:upper:] ' '[:lower:]-' | sed -E 's/[^a-z0-9\-]//g'
}

list_presets() {
    awk '
    BEGIN{inb=0}
    /(^|[[:space:]])blur[[:space:]]*\{/ {inb=1}
    inb && /^[[:space:]]*#[[:space:]]*={3,}.*={3,}[[:space:]]*$/ {
        s=$0
        gsub(/^[[:space:]]*#[[:space:]]*={3,}[[:space:]]*/,"",s)
        gsub(/[[:space:]]*={3,}[[:space:]]*$/,"",s)
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
        print s
    }
    inb && /\}/ {inb=0}
    ' "$CONF"
}

get_current_preset() {
    awk '
    function trim(s){gsub(/^[ \t]+|[ \t]+$/,"",s);return s}
    BEGIN{inb=0; current_preset=""; in_preset=0; has_active=0; found=0}

    /(^|[[:space:]])blur[[:space:]]*\{/ {
        inb=1
        next
    }

    inb && /\}/ {
        if (in_preset == 1 && has_active == 1 && found == 0) {
            print current_preset
            found=1
        }
        inb=0
        next
    }

    inb {
        if ($0 ~ /^[[:space:]]*#[[:space:]]*={3,}.*={3,}[[:space:]]*$/) {
            if (in_preset == 1 && has_active == 1 && found == 0) {
                print current_preset
                found=1
            }
            s=$0
            gsub(/^[[:space:]]*#[[:space:]]*={3,}[[:space:]]*/,"",s)
            gsub(/[[:space:]]*={3,}[[:space:]]*$/,"",s)
            current_preset=trim(s)
            in_preset=1
            has_active=0
            next
        }

        if ($0 ~ /[a-z_]+[[:space:]]*=/ && in_preset == 1) {
            is_commented = ($0 ~ /^[[:space:]]*#/)
            if (!is_commented) {
                has_active=1
            }
            next
        }
    }
    END {
        if (in_preset == 1 && has_active == 1 && found == 0) {
            print current_preset
        }
    }
    ' "$CONF"
}

pick() {
    if [[ $# -gt 0 ]]; then echo "$1"; return; fi
    mapfile -t P < <(list_presets)
    ((${#P[@]})) || { echo "No presets found in blur{ } of $CONF" >&2; exit 1; }

    if command -v rofi >/dev/null; then
        sel="$(printf "%s\n" "${P[@]}" | rofi -dmenu -p "Blur preset")"
    elif command -v fzf >/dev/null; then
        sel="$(printf "%s\n" "${P[@]}" | fzf --prompt='Blur preset> ')"
    else
        echo "Available presets:"; nl -ba <(printf "%s\n" "${P[@]}")
        read -rp "Number: " n; sel="${P[$((n-1))]:-}"
    fi
    [[ -n "${sel:-}" ]] || { echo "No selection." >&2; exit 1; }
    echo "$sel"
}

apply_persistent() {
    local target="$1"
    local tmpfile="${CONF}.tmp.$"

    awk -v tgt="$target" '
    function trim(s){gsub(/^[ \t]+|[ \t]+$/,"",s);return s}
    BEGIN{inb=0; current_preset=""; in_preset=0}

    /(^|[[:space:]])blur[[:space:]]*\{/ {
        inb=1
        print
        next
    }

    inb && /\}/ {
        inb=0
        print
        next
    }

    inb {
        if ($0 ~ /^[[:space:]]*#[[:space:]]*={3,}.*={3,}[[:space:]]*$/) {
            s=$0
            gsub(/^[[:space:]]*#[[:space:]]*={3,}[[:space:]]*/,"",s)
            gsub(/[[:space:]]*={3,}[[:space:]]*$/,"",s)
            current_preset=trim(s)

            print

            if (current_preset == tgt) {
                in_preset=1
            } else {
                in_preset=0
            }
            next
        }

        if ($0 ~ /^[[:space:]]*$/ || ($0 ~ /^[[:space:]]*#[[:space:]]*$/ && $0 !~ /=/)) {
            print
            next
        }

        if ($0 ~ /[a-z_]+[[:space:]]*=/) {
            is_commented = ($0 ~ /^[[:space:]]*#/)

            if (in_preset == 1) {
                line=$0
                gsub(/^[[:space:]]*#[[:space:]]*/,"",line)
                printf "        %s\n", line
            } else {
                if (is_commented) {
                    print
                } else {
                    line=$0
                    gsub(/^[[:space:]]*/,"",line)
                    printf "        # %s\n", line
                }
            }
            next
        }

        print
        next
    }

    !inb {print}
    ' "$CONF" > "$tmpfile"

    mv "$tmpfile" "$CONF"

    echo "Config updated: $CONF"
    echo "Active preset: ${target}"

    if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
        echo "Hyprland config reloaded"
    fi
}

main() {
    if [[ "${1:-}" == "list" ]]; then
        list_presets
        exit 0
    fi

    if [[ "${1:-}" == "current" ]]; then
        get_current_preset
        exit 0
    fi

    if [[ $# -gt 0 ]]; then
        want="$(canon "$*")"
        mapfile -t P < <(list_presets)
        for p in "${P[@]}"; do
            if [[ "$(canon "$p")" == "$want" ]]; then sel="$p"; break; fi
        done
        if [[ -z "${sel:-}" ]]; then
            echo "Preset not found: $*"
            echo "Available:"
            printf '  - %s\n' "${P[@]}"
            exit 1
        fi
    else
        sel="$(pick)"
    fi

    apply_persistent "$sel"
}

main "$@"
