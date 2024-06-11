#!/bin/sh
set -ex

pkgs="libXp motif"
pkgcount=$(echo $pkgs | wc -w)
[ "$(rpm -qa $pkgs | wc -l )" -eq $pkgcount ] || dnf install -y $pkgs
