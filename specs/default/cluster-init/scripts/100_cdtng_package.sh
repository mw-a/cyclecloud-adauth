#!/bin/sh

pkgs="perl-Locale-Maketext perl-Sys-Syslog"
pkgcount=$(echo $pkgs | wc -w)
[ "$(rpm -qa $pkgs | wc -l )" -eq $pkgcount ] || dnf install -y $pkgs
