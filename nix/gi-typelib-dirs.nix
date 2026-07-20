# Imported by both the NixOS and home-manager modules so they can't drift.
# Gtk-3.0.typelib needs namespaces spread across every one of these closures
# (xlib/cairo ship with gobject-introspection, Atk with at-spi2-core); drop
# one and list-apps.py's gi import throws, leaving the launcher list empty.
pkgs:
map (p: "${p}/lib/girepository-1.0") [
  pkgs.gtk3
  pkgs.glib.out
  pkgs.gobject-introspection.out
  pkgs.pango.out
  pkgs.gdk-pixbuf
  pkgs.harfbuzz
  pkgs.at-spi2-core
]
