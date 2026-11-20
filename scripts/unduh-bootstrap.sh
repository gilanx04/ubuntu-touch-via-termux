#!/data/data/com.termux/files/usr/bin/bash
# Unduh bootstrap UBports untuk surya dan verifikasi SHA-256.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/bootstrap"
BASE="https://github.com/ubuntu-touch-surya/ubuntu-touch-surya/releases/download/stable-repartition"

mkdir -p "$DEST"

declare -A SHA=(
  [recovery.img]="357b32fe91a76879babcc24a0b2ad51e767283955e454ca58cf3e7f75b0fbdd5"
  [dtbo.img]="f08d0116435d600d7e3ac002813031644d6d3ad8fb3e078ec6985d956dde8158"
  [super.img]="2d8b05f9aefa946b8a055249c77d38377970acc2f2fe6722877d5522d3bff10d"
  [vendor.img]="8b5cb118fcb0c34af5443eaac2cd703ac9ab8e104f420eaa07276e5b0e532029"
)

for f in recovery.img dtbo.img super.img vendor.img; do
  echo "== $f"
  if [ ! -s "$DEST/$f" ]; then
    curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
      --continue-at - --user-agent 'Mozilla/5.0' \
      -o "$DEST/$f" "$BASE/$f"
  fi
  echo "${SHA[$f]}  $DEST/$f" | sha256sum -c -
done

echo "Bootstrap OK."
