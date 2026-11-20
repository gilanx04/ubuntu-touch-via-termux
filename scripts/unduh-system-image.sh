#!/data/data/com.termux/files/usr/bin/bash
# Unduh system image Ubuntu Touch 24.04-1.4 (build 5) untuk surya,
# lalu generate /cache/recovery/ubuntu_command dan verifikasi SHA-256.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/system-image/24.04-1.4"
BASE="https://system-image.ubports.com"

# Nama file persis seperti di index system-image build 5 (tag 24.04-1.4).
ROOTFS="rootfs-cf2d4f00668360d35298ea34e1b47b4434b96fb93509dc738906950ef9e261ab.tar.xz"
DEVICE="device-cd3ef6bd7fbed7b68e2d908ecf5afd79eb96521cf2e2de285f69f32579121dc8.tar.xz"
BOOT="boot-923c260ed5ed00e0a3e641c04a13784087d8861aabc627db60a5d574b1cc8c9c.tar.xz"
KEYRING="keyring-162141caf64cd64c4ca014760930c524e4ee051e0afe1200c47c42cebf11fd44.tar.xz"
VERSION="version-5.tar.xz"

declare -A SHA=(
  ["$ROOTFS"]="39e20445998586232934bc7640b2106102f4bde8dbd49aaff6072c8e23a3dd52"
  ["$DEVICE"]="1caa4e5489ad058b7089822f6fa76bdb783a472d47031b89c242c70ecc17bb14"
  ["$BOOT"]="d729c6be4fa326885be08ed40be753a41b9926ad30f390ad714a2b6e84f9d7a1"
  ["$KEYRING"]="afc915925ff6b23316b99c032435220bd791990b52db9bed25981754b3708e0a"
  ["$VERSION"]="cbdd0a3ccf056a8cdd7f8f8d3ac8edef276c3810e6af7924df62749550c58f96"
)

mkdir -p "$DEST"

PATHS=(
  "/pool/$ROOTFS"
  "/pool/$DEVICE"
  "/pool/$BOOT"
  "/pool/$KEYRING"
  "/24.04-1.x/arm64/android9plus/stable/surya/$VERSION"
  "/gpg/image-master.tar.xz"
  "/gpg/image-signing.tar.xz"
)

for p in "${PATHS[@]}"; do
  name="$(basename "$p")"
  for suffix in "" ".asc"; do
    out="$DEST/$name$suffix"
    if [ ! -s "$out" ]; then
      echo "== $name$suffix"
      curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
        --continue-at - --user-agent 'Mozilla/5.0' \
        -o "$out" "$BASE$p$suffix"
    fi
  done
done

# File perintah yang dibaca UBports Recovery saat boot.
{
  echo "format system"
  echo "load_keyring image-master.tar.xz image-master.tar.xz.asc"
  echo "load_keyring image-signing.tar.xz image-signing.tar.xz.asc"
  echo "mount system"
  echo "format data"
  for f in "$ROOTFS" "$DEVICE" "$BOOT" "$KEYRING" "$VERSION"; do
    echo "update $f $f.asc"
  done
  echo "unmount system"
} > "$DEST/ubuntu_command"

echo "== Verifikasi SHA-256 =="
for f in "$ROOTFS" "$DEVICE" "$BOOT" "$KEYRING" "$VERSION"; do
  echo "${SHA[$f]}  $DEST/$f" | sha256sum -c -
done

EXPECTED_CMD="6e84dc8e5b1966a8c8b72d7aa60d5761502e8dd5ce1459c001ce863533603519"
ACTUAL_CMD="$(sha256sum "$DEST/ubuntu_command" | awk '{print $1}')"
if [ "$ACTUAL_CMD" != "$EXPECTED_CMD" ]; then
  echo "ubuntu_command checksum mismatch" >&2
  echo "expected: $EXPECTED_CMD" >&2
  echo "actual  : $ACTUAL_CMD" >&2
  exit 1
fi

echo "System image 24.04-1.4 OK."
