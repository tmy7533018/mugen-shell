MPV_SOCKET="${XDG_CACHE_HOME:-$HOME/.cache}/mugen-shell/wallp/mpvpaper.sock"
# vaapi surfaces can't be read back, failing every mpv screenshot; auto-copy lands frames in memory.
MPV_OPTS="no-config no-audio loop cache=yes profile=low-latency \
vo=gpu-next gpu-context=wayland \
hwdec=auto-copy \
keep-open=yes \
input-ipc-server=${MPV_SOCKET} \
screenshot-format=png screenshot-high-bit-depth=no screenshot-png-compression=1"
