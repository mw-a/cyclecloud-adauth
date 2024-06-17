#!/bin/sh
set -ex

pkgs="libXp motif libnsl xterm"
pkgcount=$(echo $pkgs | wc -w)
[ "$(rpm -qa $pkgs | wc -l )" -eq $pkgcount ] || dnf install -y $pkgs
