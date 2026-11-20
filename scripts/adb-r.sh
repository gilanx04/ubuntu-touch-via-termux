#!/data/data/com.termux/files/usr/bin/bash
# Wrapper ADB yang dijalankan sebagai root.
#
# Contoh:
#   su -c "$PWD/scripts/adb-r.sh devices -l"
#
# Kenapa perlu wrapper:
# - adb sebagai root butuh TMPDIR yang bisa ditulis root.
# - Kunci ADB tersimpan di ~/.android milik user Termux, bukan root.
# - `su -c` biasanya me-reset PATH, jadi path absolut lebih aman.
set -euo pipefail

export TMPDIR=/data/local/tmp

# Default home Termux user 0. Override dengan TERMUX_HOME bila berbeda.
: "${TERMUX_HOME:=/data/data/com.termux/files/home}"
export HOME="$TERMUX_HOME"

# Default prefix Termux. Override dengan TERMUX_PREFIX bila berbeda.
: "${TERMUX_PREFIX:=/data/data/com.termux/files/usr}"
export PATH="$TERMUX_PREFIX/bin:$PATH"

exec "$TERMUX_PREFIX/bin/adb" "$@"
