# Single source of truth for the launcher's GI typelib path — imported by
# both the NixOS module and the home-manager module so they can't drift.
# Gtk-3.0.typelib transitively needs namespaces scattered across all of
# these closures (xlib/cairo ship with gobject-introspection, Atk with
# at-spi2-core); missing any one of them makes list-apps.py's gi import
# throw and the launcher list come back empty.
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
