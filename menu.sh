#!/usr/bin/env bash
# Fastlane Interactive Assistant Launcher
cd "$(dirname "$0")" || exit 1
ruby scripts/interactive_menu.rb
