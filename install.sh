#!/usr/bin/env bash
# Installs mugen-shell on Arch: the packages, then the pieces people differ on. Re-running is safe.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# AUR-only, so pacman cannot resolve them and the helper has to.
aur_deps=(mpvpaper awww matugen ttf-mplus-git libcava)
default_apps=(kitty thunar firefox)
zsh_pkgs=(zsh starship jp2a fastfetch eza bat ugrep
          zsh-syntax-highlighting zsh-autosuggestions zsh-history-substring-search)

assume_yes=0

say()  { printf '\n\033[1m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[33m  !\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[31m==> %s\033[0m\n' "$1" >&2; exit 1; }

have()      { command -v "$1" > /dev/null 2>&1; }
installed() { pacman -Qq "$1" > /dev/null 2>&1; }

# Announce before the prompt appears, so a sudo password is never a surprise.
as_root() {
  printf '  \033[2msudo:\033[0m %s\n' "$1"; shift
  sudo "$@"
}

preflight() {
  [[ -f /etc/arch-release ]] || die "this installer is for Arch Linux"
  [[ $EUID -ne 0 ]] || die "run as your normal user: makepkg refuses to build as root"
  local missing=()
  have git || missing+=(git)
  # makepkg itself ships with pacman; fakeroot is what only base-devel brings.
  have fakeroot || missing+=(base-devel)
  if (( ${#missing[@]} )); then
    say "Installing build prerequisites"
    as_root "install ${missing[*]}" pacman -S --needed --noconfirm "${missing[@]}"
  fi
}

# Prefer the display manager already in charge; only offer SDDM when nothing is.
dm_present() {
  systemctl list-unit-files --no-legend 'display-manager.service' 2>/dev/null | grep -q . \
    || [[ -e /etc/systemd/system/display-manager.service ]]
}

guess_ime_engine() {
  # An engine that is already installed beats the locale: an English system with Japanese input is common.
  local e
  for e in mozc rime hangul; do
    if installed "fcitx5-$e"; then echo "$e"; return; fi
  done
  case "${LC_CTYPE:-${LANG:-}}" in
    ja_JP*) echo mozc ;;
    ko_KR*) echo hangul ;;
    zh_*)   echo rime ;;
    *)      echo none ;;
  esac
}

ime_engine_known() {
  [[ "$1" =~ ^[a-z0-9-]+$ ]] && pacman -Si "fcitx5-$1" > /dev/null 2>&1
}

want_ime=1
want_zsh=0
want_apps=1
want_dm=1
ime_engine=$(guess_ime_engine)
if [[ "$ime_engine" == none ]]; then want_ime=0; ime_engine=mozc; fi
if dm_present; then want_dm=0; fi

usage() {
  cat <<'USAGE'
usage: ./install.sh [--yes] [--with-X | --without-X] ...

  --yes            take the defaults without showing the menu
  --with-ime=ENGINE   mozc, rime or hangul (default: guessed from $LANG)
  --with-X            X is one of: ime zsh apps dm
  --without-X         the same names, turned off

With no arguments the menu is shown.
USAGE
}

while (( $# )); do
  case "$1" in
    --yes) assume_yes=1 ;;
    --with-ime=*) want_ime=1; ime_engine=${1#*=} ;;
    --with-ime)    want_ime=1   ;; --without-ime)   want_ime=0   ;;
    --with-zsh)    want_zsh=1   ;; --without-zsh)   want_zsh=0   ;;
    --with-apps)   want_apps=1  ;; --without-apps)  want_apps=0  ;;
    --with-dm)     want_dm=1    ;; --without-dm)    want_dm=0    ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; die "unknown option: $1" ;;
  esac
  # Any explicit choice means the caller knows what they want, so skip the menu.
  [[ "$1" == --yes ]] || assume_yes=1
  shift
done

mark() { if [[ ${!1} -eq 1 ]]; then printf 'x'; else printf ' '; fi; }

menu() {
  while :; do
    printf '\n  \033[1mmugen-shell installer\033[0m\n\n'
    printf '    1  [%s] %-14s fcitx5 + %s\n' "$(mark want_ime)"   'IME'          "$ime_engine"
    printf '    2  [%s] %-14s starship, eza, fastfetch\n' "$(mark want_zsh)"  'zsh config'
    printf '    3  [%s] %-14s %s\n' "$(mark want_apps)" 'default apps' "${default_apps[*]}"
    if dm_present; then
      printf '    4  [-] %-14s already configured\n' 'display mgr'
    else
      printf '    4  [%s] %-14s no display manager found\n' "$(mark want_dm)" 'SDDM'
    fi
    printf '\n  mugen-shell, mugen-ai and mugen-audio are always installed.\n'
    printf '  \033[2mnumber to toggle, e to pick the IME engine, Enter to start, q to quit\033[0m\n\n  > '
    local choice engine; read -r choice || choice=q
    case "$choice" in
      1) want_ime=$((1 - want_ime)) ;;
      2) want_zsh=$((1 - want_zsh)) ;;
      3) want_apps=$((1 - want_apps)) ;;
      4) dm_present || want_dm=$((1 - want_dm)) ;;
      e) printf '  engine (mozc/rime/hangul): '; read -r engine
         if ime_engine_known "$engine"; then ime_engine=$engine; else warn "no fcitx5-$engine package"; fi ;;
      "") return 0 ;;
      q|Q) exit 0 ;;
      *) warn "unknown choice: $choice" ;;
    esac
  done
}

ensure_aur_helper() {
  for h in yay paru; do
    if have "$h"; then aur=$h; return 0; fi
  done
  # paru-bin is built against a pinned libalpm and breaks on every pacman bump.
  say "Building yay (no AUR helper found)"
  local tmp; tmp=$(mktemp -d)
  git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
  (cd "$tmp/yay" && makepkg -si --noconfirm)
  rm -rf "$tmp"
  aur=yay
}

aur_install() {
  local want=() p
  for p in "$@"; do installed "$p" || want+=("$p"); done
  (( ${#want[@]} )) || { printf '  already present: %s\n' "$*"; return 0; }
  "$aur" -S --needed --noconfirm "${want[@]}"
}

pac_install() {
  local want=() p
  for p in "$@"; do installed "$p" || want+=("$p"); done
  (( ${#want[@]} )) || { printf '  already present: %s\n' "$*"; return 0; }
  as_root "install ${want[*]}" pacman -S --needed --noconfirm "${want[@]}"
}

# A fresh PKGDEST per build: a glob over the checkout would also pick up packages left by an older pkgver.
build_pkg() {
  local dir=$1; shift
  local dest; dest=$(mktemp -d)
  (cd "$repo/arch/$dir" && PKGDEST=$dest makepkg "$@")
  as_root "install $dir" pacman -U --noconfirm "$dest"/*.pkg.tar.zst
  rm -rf "$dest"
}

# A running unit keeps the old binary until restarted, and the shell reloading mid-extraction fails.
restart_running() {
  local u
  for u in "$@"; do
    if systemctl --user is-active --quiet "$u" 2> /dev/null; then
      printf '  restarting %s onto the new files\n' "$u"
      systemctl --user restart "$u"
    fi
  done
}

# The Yura window is Hyprland's exec-once child, not a unit, and keeps the old QML loaded.
restart_yura_window() {
  local qml="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell/mugen-shell/yura-shell.qml"
  qs kill -p "$qml" 2> /dev/null || return 0
  printf '  restarting the Yura window onto the new files\n'
  hyprctl dispatch "hl.dsp.exec_cmd('$(dirname "$qml")/scripts/yura-window.sh')" > /dev/null
}

build_core() {
  say "Building mugen-shell, mugen-ai and mugen-audio"
  build_pkg mugen-shell -sf --noconfirm
  # The backend first, so the bar comes back up against the new API.
  restart_running mugen-ai.service mugen-shell.service
  restart_yura_window
}

# The panels shell out to nmcli, bluetoothctl and pactl; the packages come with the core, the daemons do not.
enable_services() {
  say "Enabling the system services the panels talk to"
  as_root "enable bluetooth" systemctl enable bluetooth.service
  if systemctl is-enabled --quiet iwd.service systemd-networkd.service dhcpcd.service connman.service 2> /dev/null; then
    printf '  another network service is enabled; not enabling NetworkManager over it\n'
  else
    as_root "enable NetworkManager" systemctl enable NetworkManager.service
  fi
}

setup_ime() {
  say "Installing the input method"
  pac_install fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool "fcitx5-$ime_engine"
  # Apps started outside the compositor never see the session wrapper's XMODIFIERS.
  local env_file=${MUGEN_ENV_FILE:-/etc/environment}   # overridable so the test can drive both branches
  if ! grep -q '^XMODIFIERS=' "$env_file" 2> /dev/null; then
    printf 'XMODIFIERS=@im=fcitx\n' | as_root "add XMODIFIERS to $env_file" tee -a -- "$env_file" > /dev/null
  fi
}

setup_zsh() {
  say "Installing the zsh configuration"
  pac_install "${zsh_pkgs[@]}"
  local line="source /usr/share/mugen-shell/zsh/mugen-shell.zshrc"
  if [[ -f "$HOME/.zshrc" ]] && grep -qF "$line" "$HOME/.zshrc"; then
    printf '  ~/.zshrc already sources it\n'
  else
    printf '%s\n' "$line" >> "$HOME/.zshrc"
    printf '  appended to ~/.zshrc\n'
  fi
}

setup_dm() {
  say "Installing SDDM"
  pac_install sddm
  as_root "enable sddm" systemctl enable sddm.service
}

main() {
  preflight
  (( assume_yes )) || menu
  if (( want_ime )); then ime_engine_known "$ime_engine" || die "no fcitx5-$ime_engine package: mozc, rime or hangul"; fi

  ensure_aur_helper
  say "Installing AUR dependencies"
  aur_install "${aur_deps[@]}"

  build_core
  enable_services
  if (( want_apps ));  then say "Installing the default applications"; pac_install "${default_apps[@]}"; fi
  if (( want_ime ));   then setup_ime; fi
  if (( want_zsh ));   then setup_zsh; fi
  if (( want_dm ));    then setup_dm; fi

  say "Done"
  printf '  Log out and pick \033[1mmugen-shell\033[0m from your display manager.\n'
  printf '  Personal Hyprland tweaks go in ~/.config/hypr/configs/user-overrides.lua\n\n'
}

main "$@"
