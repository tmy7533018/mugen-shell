#!/bin/bash

if systemctl --user is-active --quiet hypridle.service; then
    systemctl --user stop hypridle.service
else
    systemctl --user start hypridle.service
fi
