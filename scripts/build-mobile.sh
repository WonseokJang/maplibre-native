#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

make -C "$ROOT_DIR" submodules
make -C "$ROOT_DIR" doctor
make -C "$ROOT_DIR" android
make -C "$ROOT_DIR" ios

echo "Artifacts => $ROOT_DIR/dist"
