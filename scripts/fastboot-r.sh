#!/data/data/com.termux/files/usr/bin/bash
# Wrapper fastboot yang dijalankan sebagai root.
#
# Contoh:
#   su -c "$PWD/scripts/fastboot-r.sh devices"
set -euo pipefail

export TMPDIR=/data/local/tmp

: "${TERMUX_HOME:=/data/data/com.termux/files/home}"
export HOME="$TERMUX_HOME"

: "${TERMUX_PREFIX:=/data/data/com.termux/files/usr}"
export PATH="$TERMUX_PREFIX/bin:$PATH"

exec "$TERMUX_PREFIX/bin/fastboot" "$@"
