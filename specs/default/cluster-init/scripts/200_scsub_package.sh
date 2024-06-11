#!/bin/sh

pkgs="python2"
pkgcount=$(echo $pkgs | wc -w)
[ "$(rpm -qa $pkgs | wc -l )" -eq $pkgcount ] || dnf install -y $pkgs
