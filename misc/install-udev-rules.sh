#!/usr/bin/env sh
install="install -o root -g root -m 644"

$install udev-uvcvideo.rules /etc/udev/rules.d/81-uvcvideo.rules
