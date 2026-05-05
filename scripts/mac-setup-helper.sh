#!/usr/bin/env bash
set -euo pipefail

echo "Checking Mac/iOS tooling..."
command -v xcodebuild >/dev/null && xcodebuild -version || echo "xcodebuild not found. Install/open Xcode first."
command -v git >/dev/null && git --version || echo "git not found"
echo "Open EASIEST_START.md for the Xcode target setup steps."
