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
  have makepkg || missing+=(base-devel)
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

want_ime=1
want_voice=0
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
  --with-X            X is one of: ime voice zsh apps dm
  --without-X         the same names, turned off

With no arguments the menu is shown.
USAGE
}

while (( $# )); do
  case "$1" in
    --yes) assume_yes=1 ;;
    --with-ime=*) want_ime=1; ime_engine=${1#*=} ;;
    --with-ime)    want_ime=1   ;; --without-ime)   want_ime=0   ;;
    --with-voice)  want_voice=1 ;; --without-voice) want_voice=0 ;;
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
    printf '    2  [%s] %-14s mugen-voice + AivisSpeech (builds onnxruntime, hours)\n' "$(mark want_voice)" 'read-aloud'
    printf '    3  [%s] %-14s starship, eza, fastfetch\n' "$(mark want_zsh)"  'zsh config'
    printf '    4  [%s] %-14s %s\n' "$(mark want_apps)" 'default apps' "${default_apps[*]}"
    if dm_present; then
      printf '    5  [-] %-14s already configured\n' 'display mgr'
    else
      printf '    5  [%s] %-14s no display manager found\n' "$(mark want_dm)" 'SDDM'
    fi
    printf '\n  mugen-shell, mugen-ai and mugen-audio are always installed.\n'
    printf '  \033[2mnumber to toggle, e to pick the IME engine, Enter to start, q to quit\033[0m\n\n  > '
    local choice; read -r choice || choice=q
    case "$choice" in
      1) want_ime=$((1 - want_ime)) ;;
      2) want_voice=$((1 - want_voice)) ;;
      3) want_zsh=$((1 - want_zsh)) ;;
      4) want_apps=$((1 - want_apps)) ;;
      5) dm_present || want_dm=$((1 - want_dm)) ;;
      e) printf '  engine (mozc/rime/hangul): '; read -r ime_engine ;;
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

build_core() {
  say "Building mugen-shell, mugen-ai and mugen-audio"
  (cd "$repo/arch/mugen-shell" && makepkg -sf --noconfirm)
  # Only the three built here: read-aloud is its own pkgbase precisely so this stays cheap.
  as_root "install the three built packages" \
    pacman -U --noconfirm "$repo"/arch/mugen-shell/*.pkg.tar.zst

  # pacman swaps the QML the running shell watches, and a reload landing mid-extraction fails.
  if systemctl --user is-active --quiet mugen-shell.service 2> /dev/null; then
    printf '  restarting the running bar onto the new files\n'
    systemctl --user restart mugen-shell.service
  fi
}

build_voice() {
  say "Building read-aloud (this is the slow one)"
  aur_install python-sherpa-onnx python-sounddevice
  # -d: nothing is compiled here, and the runtime depends were just installed above.
  (cd "$repo/arch/mugen-voice" && makepkg -df --noconfirm)
  as_root "install mugen-voice" pacman -U --noconfirm "$repo"/arch/mugen-voice/*.pkg.tar.zst

  say "Building the AivisSpeech engine (Japanese voice)"
  (cd "$repo/arch/aivisspeech-engine" && makepkg -f --noconfirm)
  as_root "install aivisspeech-engine" \
    pacman -U --noconfirm "$repo"/arch/aivisspeech-engine/*.pkg.tar.zst
}

setup_ime() {
  say "Installing the input method"
  pac_install fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool "fcitx5-$ime_engine"
  # Apps started outside the compositor never see the session wrapper's XMODIFIERS.
  local env_file=${MUGEN_ENV_FILE:-/etc/environment}   # overridable so the test can drive both branches
  if ! grep -q '^XMODIFIERS=' "$env_file" 2> /dev/null; then
    as_root "add XMODIFIERS to $env_file" \
      sh -c "echo XMODIFIERS=@im=fcitx >> '$env_file'"
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

  ensure_aur_helper
  say "Installing AUR dependencies"
  aur_install "${aur_deps[@]}"

  build_core
  if (( want_apps ));  then say "Installing the default applications"; pac_install "${default_apps[@]}"; fi
  if (( want_ime ));   then setup_ime; fi
  if (( want_zsh ));   then setup_zsh; fi
  if (( want_dm ));    then setup_dm; fi
  if (( want_voice )); then build_voice; fi

  say "Done"
  printf '  Log out and pick \033[1mmugen-shell\033[0m from your display manager.\n'
  if (( ! want_voice )); then printf '  Read-aloud was skipped; see SETUP.md if you want it later.\n'; fi
  printf '  Personal Hyprland tweaks go in ~/.config/hypr/configs/user-overrides.lua\n\n'
}

main "$@"
