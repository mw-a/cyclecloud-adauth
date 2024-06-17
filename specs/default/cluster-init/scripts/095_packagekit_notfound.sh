#!/bin/sh
set -e

! rpm -q PackageKit-command-not-found >/dev/null 2>&1 || dnf remove -y PackageKit-command-not-found
