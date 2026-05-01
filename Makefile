SHELL := /bin/bash

REPO_ROOT := $(shell pwd)

.PHONY: help install install-ai install-symlinks uninstall uninstall-ai uninstall-symlinks

help:
	@echo "Targets:"
	@echo "  install            install-symlinks + install-ai"
	@echo "  install-symlinks   point ~/.config entries at this repo (shell, system/*)"
	@echo "  install-ai         build mugen-ai, install systemd unit, enable service"
	@echo "  uninstall          uninstall-ai + uninstall-symlinks"
	@echo "  uninstall-symlinks remove the symlinks created by install-symlinks"
	@echo "  uninstall-ai       disable service, remove binary and unit"

install: install-symlinks install-ai

install-symlinks:
	@echo "==> Linking ~/.config entries to $(REPO_ROOT)"
	mkdir -p $$HOME/.config/quickshell
	ln -sfn $(REPO_ROOT)/shell           $$HOME/.config/quickshell/mugen-shell
	ln -sfn $(REPO_ROOT)/system/cava     $$HOME/.config/cava
	ln -sfn $(REPO_ROOT)/system/fastfetch $$HOME/.config/fastfetch
	ln -sfn $(REPO_ROOT)/system/hypr     $$HOME/.config/hypr
	ln -sfn $(REPO_ROOT)/system/kitty    $$HOME/.config/kitty
	ln -sfn $(REPO_ROOT)/system/matugen  $$HOME/.config/matugen
	ln -sfn $(REPO_ROOT)/system/starship.toml $$HOME/.config/starship.toml
	@echo "Done. Reload Hyprland (Super+Shift+R) and restart Quickshell."

install-ai:
	@echo "==> Building and installing mugen-ai binary (go install)"
	cd ai && go install .
	@echo "==> Installing systemd user unit"
	install -Dm644 ai/contrib/systemd/mugen-ai.service \
		$$HOME/.config/systemd/user/mugen-ai.service
	systemctl --user daemon-reload
	@echo "==> Enabling and starting mugen-ai service"
	systemctl --user enable --now mugen-ai.service
	@echo
	@echo "mugen-ai installed. Check status: systemctl --user status mugen-ai"

uninstall: uninstall-ai uninstall-symlinks

uninstall-symlinks:
	-rm -f $$HOME/.config/quickshell/mugen-shell
	-rm -f $$HOME/.config/cava
	-rm -f $$HOME/.config/fastfetch
	-rm -f $$HOME/.config/hypr
	-rm -f $$HOME/.config/kitty
	-rm -f $$HOME/.config/matugen
	-rm -f $$HOME/.config/starship.toml
	@echo "Symlinks removed."

uninstall-ai:
	-systemctl --user disable --now mugen-ai.service
	-rm -f $$HOME/.config/systemd/user/mugen-ai.service
	-rm -f $$(go env GOBIN 2>/dev/null || echo $$HOME/go/bin)/mugen-ai
	systemctl --user daemon-reload
	@echo "mugen-ai uninstalled."
