SHELL := /bin/bash

.PHONY: help install-ai uninstall-ai

help:
	@echo "Targets:"
	@echo "  install-ai     Build mugen-ai, install systemd unit, enable service"
	@echo "  uninstall-ai   Disable service, remove binary and unit"

install-ai:
	@echo "==> Building and installing mugen-ai binary (go install)"
	cd mugen-ai && go install .
	@echo "==> Installing systemd user unit"
	install -Dm644 mugen-ai/contrib/systemd/mugen-ai.service \
		$$HOME/.config/systemd/user/mugen-ai.service
	systemctl --user daemon-reload
	@echo "==> Enabling and starting mugen-ai service"
	systemctl --user enable --now mugen-ai.service
	@echo
	@echo "mugen-ai installed. Check status: systemctl --user status mugen-ai"

uninstall-ai:
	-systemctl --user disable --now mugen-ai.service
	-rm -f $$HOME/.config/systemd/user/mugen-ai.service
	-rm -f $$(go env GOBIN 2>/dev/null || echo $$HOME/go/bin)/mugen-ai
	systemctl --user daemon-reload
	@echo "mugen-ai uninstalled."
