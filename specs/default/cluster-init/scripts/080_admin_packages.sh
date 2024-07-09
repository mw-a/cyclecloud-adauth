#!/bin/sh

pkgs="tmux screen"
pkgcount=$(echo $pkgs | wc -w)
[ "$(rpm -qa $pkgs | wc -l )" -eq $pkgcount ] || dnf install -y $pkgs

