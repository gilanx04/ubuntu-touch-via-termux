#!/data/data/com.termux/files/usr/bin/bash
# Flash bootstrap UBports ke surya lewat fastboot + fastbootd.
#
# DESTRUKTIF: memformat cache + userdata dan menimpa recovery/dtbo/vendor.
# Jalankan hanya setelah membaca README.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FB="$ROOT/scripts/fastboot-r.sh"
BOOT="$ROOT/bootstrap"

cat <<'EOF'
============================================================
  PERINGATAN: SEMUA DATA DI TARGET AKAN DIHAPUS
  - format cache
  - format userdata
  - flash recovery, dtbo, vendor
  - wipe super
============================================================
EOF

if [ "${SAYA_SETUJU:-}" != "1" ]; then
  echo
  echo "Jalankan ulang dengan:"
  echo "  SAYA_SETUJU=1 bash scripts/flash-bootstrap.sh"
  exit 1
fi

if ! su -c id 2>/dev/null | grep -q 'uid=0'; then
  echo "Root tidak aktif. Jalankan 'su -c id' dan pastikan uid=0." >&2
  exit 1
fi

for f in recovery.img dtbo.img super.img vendor.img; do
  if [ ! -s "$BOOT/$f" ]; then
    echo "File hilang: $BOOT/$f" >&2
    echo "Jalankan: bash scripts/unduh-bootstrap.sh" >&2
    exit 1
  fi
done

fb() { su -c "$FB $(printf '%q ' "$@")"; }

echo "== Cek fastboot =="
if ! fb devices 2>/dev/null | grep -q 'fastboot'; then
  echo "Target tidak terdeteksi di fastboot. Boot ke bootloader dulu." >&2
  exit 1
fi

echo "== Cek identitas =="
PRODUCT="$(fb getvar product 2>&1 | awk -F': ' '/product:/{print $2; exit}')"
UNLOCKED="$(fb getvar unlocked 2>&1 | awk -F': ' '/unlocked:/{print $2; exit}')"
ANTI="$(fb getvar anti 2>&1 | awk -F': ' '/anti:/{print $2; exit}')"
USERSPACE="$(fb getvar is-userspace 2>&1 | awk -F': ' '/is-userspace:/{print $2; exit}')"

echo "product     : $PRODUCT"
echo "unlocked    : $UNLOCKED"
echo "anti        : $ANTI"
echo "is-userspace: $USERSPACE"

[ "$PRODUCT" = "surya" ] || { echo "Bukan surya: $PRODUCT" >&2; exit 1; }
[ "$UNLOCKED" = "yes" ] || { echo "Bootloader belum unlocked." >&2; exit 1; }
[ "$USERSPACE" = "no" ] || { echo "Sudah di fastbootd; reboot ke bootloader dulu." >&2; exit 1; }

case "$ANTI" in
  ''|*[!0-9]*) echo "Tidak bisa membaca anti-rollback: $ANTI" >&2; exit 1;;
esac
if [ "$ANTI" -gt 2 ]; then
  echo "ARB perangkat ($ANTI) lebih tinggi dari firmware (2). STOP." >&2
  exit 1
fi

echo
echo "== 1/7 format cache =="
fb format cache

echo "== 2/7 format userdata (ext4) =="
fb format:ext4 userdata

echo "== 3/7 flash recovery =="
fb flash recovery "$BOOT/recovery.img"

echo "== 4/7 flash dtbo =="
fb flash dtbo "$BOOT/dtbo.img"

echo "== 5/7 reboot ke fastbootd =="
fb reboot fastboot

echo "   menunggu fastbootd..."
OK=0
for _ in $(seq 1 40); do
  sleep 2
  if fb devices 2>/dev/null | grep -q 'fastboot'; then
    US="$(timeout 10 su -c "$FB getvar is-userspace" 2>/dev/null | awk -F': ' '/is-userspace:/{print $2; exit}')"
    if [ "$US" = "yes" ]; then OK=1; break; fi
  fi
done
[ "$OK" = "1" ] || { echo "fastbootd tidak muncul. Cek kabel/USB." >&2; exit 1; }
echo "   fastbootd aktif"

echo "== 6/7 wipe-super + flash vendor =="
fb wipe-super "$BOOT/super.img"
echo "   vendor.img 1,3 GB — jangan cabut kabel..."
fb flash vendor "$BOOT/vendor.img"

echo "== 7/7 reboot ke recovery =="
fb reboot recovery

cat <<'EOF'

Bootstrap selesai.
Lanjut:
  su -c "$ADB wait-for-device"
  su -c "$ADB shell getprop ro.ubuntu.recovery"   # harus true
  su -c "$ADB shell 'df -h /cache'"               # harus ~103G
EOF
