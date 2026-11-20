#!/data/data/com.termux/files/usr/bin/bash
# Unduh Recovery ROM MIUI V12.0.9.0.QJGMIXM (opsional, untuk base firmware).
# File ini di-flash lewat TWRP, bukan fastboot.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/miui"
FILE="miui_SURYAGlobal_V12.0.9.0.QJGMIXM_7f83537667_10.0.zip"
URL="https://bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com/V12.0.9.0.QJGMIXM/$FILE"
MD5="7f835376675f18a173d04cfb725ff621"

mkdir -p "$DEST"

if [ ! -s "$DEST/$FILE" ]; then
  echo "== $FILE (2,3 GB)"
  echo "   Jika URL ini sudah tidak berlaku, unduh dari halaman resmi"
  echo "   Xiaomi/XMFirmwareUpdater lalu letakkan di $DEST/"
  curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
    --continue-at - --user-agent 'Mozilla/5.0' \
    -o "$DEST/$FILE" "$URL"
fi

ACTUAL="$(md5sum "$DEST/$FILE" | awk '{print $1}')"
if [ "$ACTUAL" != "$MD5" ]; then
  echo "MD5 mismatch" >&2
  echo "expected: $MD5" >&2
  echo "actual  : $ACTUAL" >&2
  exit 1
fi

echo "MIUI Recovery ROM OK (MD5 resmi Xiaomi)."
sha256sum "$DEST/$FILE"
