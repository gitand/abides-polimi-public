#!/usr/bin/env bash
# Legacy host-install path. The supported way to set up an ABIDES environment
# for the course is via Docker — see the "Quickstart for Students" section of
# the README. This script is kept for users who specifically need a host
# install.
#
# Requirements:
#   - Python 3.9 (other 3.x versions may work but are not tested by the course)
#   - C/C++ build tools for numba, llvmlite, pomegranate
#       macOS: xcode-select --install
#       Ubuntu/Debian: sudo apt install build-essential
#       Windows: install Visual Studio "Build Tools for C++" (or just use Docker)
set -euo pipefail

python3 -m pip install --upgrade pip setuptools wheel

# Prefer the pinned lockfile when present; otherwise fall back to the
# direct-deps files (slower resolution, but works on a fresh clone).
if [ -f requirements.lock ]; then
    python3 -m pip install -r requirements.lock
else
    python3 -m pip install -r requirements.in -r requirements-dev.in
fi

# Editable installs of the three sub-packages.
# (With requirements.lock, deps are pre-resolved and pip verifies them.
#  Without it, pip resolves the sub-package install_requires here.)
python3 -m pip install -e ./abides-core
python3 -m pip install -e ./abides-markets
python3 -m pip install -e ./abides-gym
