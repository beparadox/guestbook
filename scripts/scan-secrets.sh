#!/usr/bin/env bash
# Scan for secrets with gitleaks (native binary if installed, else via Podman/Docker).
#   scripts/scan-secrets.sh            scan every file git WOULD commit (tracked + untracked, minus .gitignore)
#   scripts/scan-secrets.sh --staged   scan only staged changes (used by the pre-commit hook)
title = "guestbook gitleaks"

[extend]
useDefault = true