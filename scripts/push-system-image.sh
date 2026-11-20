#!/data/data/com.termux/files/usr/bin/bash
# Push system image Ubuntu Touch ke /cache/recovery, verifikasi SHA-256,
# lalu reboot recovery untuk memicu system-image-upgrader.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADB="$ROOT/scripts/adb-r.sh"
SRC="$ROOT/system-image/24.04-1.4"

if [ "${SAYA_SETUJU:-}" != "1" ]; then
  echo "Script ini akan menimpa /cache/recovery dan memicu instalasi."
  echo "Jalankan ulang dengan:"
  echo "  SAYA_SETUJU=1 bash scripts/push-system-image.sh"
  exit 1
fi

if ! su -c id 2>/dev/null | grep -q 'uid=0'; then
  echo "Root tidak aktif." >&2
  exit 1
fi

if [ ! -s "$SRC/ubuntu_command" ]; then
  echo "Bahan belum lengkap di $SRC" >&2
  echo "Jalankan: bash scripts/unduh-system-image.sh" >&2
  exit 1
fi

adb() { su -c "$ADB $(printf '%q ' "$@")"; }

echo "== Menunggu recovery =="
STATE=""
for _ in $(seq 1 90); do
  STATE="$(adb devices 2>/dev/null | awk 'NR>1 && $2!="" {print $2; exit}')"
  case "$STATE" in
    device|recovery) break;;
  esac
  sleep 2
done

case "$STATE" in
  device|recovery) echo "   terdeteksi: $STATE";;
  unauthorized)
    echo "ADB unauthorized. Tap Allow di layar target, lalu ulangi." >&2
    exit 1;;
  *)
    echo "Target tidak terdeteksi via adb." >&2
    exit 1;;
esac

REC="$(adb shell getprop ro.ubuntu.recovery 2>/dev/null | tr -d '\r')"
if [ "$REC" != "true" ]; then
  echo "Target bukan UBports Recovery (ro.ubuntu.recovery='$REC')." >&2
  echo "Masuk recovery dulu: su -c \"$ADB reboot recovery\"" >&2
  exit 1
fi

echo "== Cek mount /cache =="
CACHE_ID="$(adb shell 'stat -c "%d %i" /cache' | tr -d '\r')"
DATA_CACHE_ID="$(adb shell 'stat -c "%d %i" /data/cache' | tr -d '\r')"
adb shell 'df -h /cache' || true

if [ "$CACHE_ID" != "$DATA_CACHE_ID" ]; then
  echo >&2
  echo "PERINGATAN: /cache bukan bind-mount /data/cache." >&2
  echo "Partisi cache 344 MB kemungkinan menumpuk di atas /cache." >&2
  echo "Jalankan:" >&2
  echo "  su -c \"$ADB shell umount /cache\"" >&2
  echo "lalu ulangi script ini." >&2
  exit 1
fi

echo "   /cache = /data/cache (device+inode sama)"

echo "== Push 15 file ke /cache/recovery =="
adb shell 'mkdir -p /cache/recovery'
adb shell 'rm -f /cache/recovery/*.tar.xz /cache/recovery/*.asc /cache/recovery/ubuntu_command'

mapfile -t FILES < <(cd "$SRC" && printf '%s\n' "$PWD"/*.tar.xz "$PWD"/*.tar.xz.asc "$PWD"/ubuntu_command)
if [ "${#FILES[@]}" -lt 15 ]; then
  echo "Jumlah file tidak lengkap: ${#FILES[@]} (harus 15)." >&2
  exit 1
fi
adb push "${FILES[@]}" /cache/recovery/
adb shell sync

echo "== Verifikasi SHA-256 di perangkat =="
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
(cd "$SRC" && sha256sum ./*.tar.xz) > "$TMP/host.txt"
adb shell 'cd /cache/recovery && busybox sha256sum ./*.tar.xz' | tr -d '\r' > "$TMP/device.txt"

if diff -u "$TMP/host.txt" "$TMP/device.txt"; then
  echo "   SHA-256 COCOK"
else
  echo "SHA-256 TIDAK COCOK. Jangan lanjut." >&2
  exit 1
fi

echo "== Memicu installer (reboot recovery) =="
adb reboot recovery
echo
echo "Installer berjalan otomatis. Jangan cabut kabel."
echo "Pantau dengan: bash scripts/pantau-instalasi.sh"
