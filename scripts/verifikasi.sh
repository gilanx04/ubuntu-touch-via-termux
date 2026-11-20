#!/data/data/com.termux/files/usr/bin/bash
# Verifikasi semua bahan: bootstrap, system image, dan MIUI (jika ada).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0

check() {
  local algo="$1" file="$2" expected="$3" actual
  if [ ! -f "$file" ]; then
    echo "MISSING  $file"
    fail=1
    return
  fi
  if [ "$algo" = "md5" ]; then
    actual="$(md5sum "$file" | awk '{print $1}')"
  else
    actual="$(sha256sum "$file" | awk '{print $1}')"
  fi
  if [ "$actual" = "$expected" ]; then
    printf 'OK       %-7s %s\n' "$algo" "$file"
  else
    printf 'FAIL     %-7s %s\n' "$algo" "$file"
    echo "         expected: $expected"
    echo "         actual  : $actual"
    fail=1
  fi
}

exists() {
  if [ -s "$1" ]; then
    printf 'OK       exists  %s\n' "$1"
  else
    printf 'MISSING  %s\n' "$1"
    fail=1
  fi
}

echo "== Bootstrap (SHA-256) =="
check sha256 bootstrap/recovery.img 357b32fe91a76879babcc24a0b2ad51e767283955e454ca58cf3e7f75b0fbdd5
check sha256 bootstrap/dtbo.img     f08d0116435d600d7e3ac002813031644d6d3ad8fb3e078ec6985d956dde8158
check sha256 bootstrap/super.img    2d8b05f9aefa946b8a055249c77d38377970acc2f2fe6722877d5522d3bff10d
check sha256 bootstrap/vendor.img   8b5cb118fcb0c34af5443eaac2cd703ac9ab8e104f420eaa07276e5b0e532029

echo
echo "== Ubuntu Touch 24.04-1.4 (SHA-256) =="
D=system-image/24.04-1.4
check sha256 "$D/rootfs-cf2d4f00668360d35298ea34e1b47b4434b96fb93509dc738906950ef9e261ab.tar.xz" 39e20445998586232934bc7640b2106102f4bde8dbd49aaff6072c8e23a3dd52
check sha256 "$D/device-cd3ef6bd7fbed7b68e2d908ecf5afd79eb96521cf2e2de285f69f32579121dc8.tar.xz" 1caa4e5489ad058b7089822f6fa76bdb783a472d47031b89c242c70ecc17bb14
check sha256 "$D/boot-923c260ed5ed00e0a3e641c04a13784087d8861aabc627db60a5d574b1cc8c9c.tar.xz" d729c6be4fa326885be08ed40be753a41b9926ad30f390ad714a2b6e84f9d7a1
check sha256 "$D/keyring-162141caf64cd64c4ca014760930c524e4ee051e0afe1200c47c42cebf11fd44.tar.xz" afc915925ff6b23316b99c032435220bd791990b52db9bed25981754b3708e0a
check sha256 "$D/version-5.tar.xz" cbdd0a3ccf056a8cdd7f8f8d3ac8edef276c3810e6af7924df62749550c58f96
check sha256 "$D/ubuntu_command" 6e84dc8e5b1966a8c8b72d7aa60d5761502e8dd5ce1459c001ce863533603519

echo
echo "== Signature & GPG files =="
exists "$D/rootfs-cf2d4f00668360d35298ea34e1b47b4434b96fb93509dc738906950ef9e261ab.tar.xz.asc"
exists "$D/device-cd3ef6bd7fbed7b68e2d908ecf5afd79eb96521cf2e2de285f69f32579121dc8.tar.xz.asc"
exists "$D/boot-923c260ed5ed00e0a3e641c04a13784087d8861aabc627db60a5d574b1cc8c9c.tar.xz.asc"
exists "$D/keyring-162141caf64cd64c4ca014760930c524e4ee051e0afe1200c47c42cebf11fd44.tar.xz.asc"
exists "$D/version-5.tar.xz.asc"
exists "$D/image-master.tar.xz"
exists "$D/image-master.tar.xz.asc"
exists "$D/image-signing.tar.xz"
exists "$D/image-signing.tar.xz.asc"

echo
echo "== MIUI V12.0.9.0.QJGMIXM Recovery ROM (opsional) =="
MIUI="miui/miui_SURYAGlobal_V12.0.9.0.QJGMIXM_7f83537667_10.0.zip"
if [ -f "$MIUI" ]; then
  check md5 "$MIUI" 7f835376675f18a173d04cfb725ff621
  echo "SHA-256 lokal:"
  sha256sum "$MIUI"
else
  echo "SKIP     $MIUI (tidak ada — hanya diperlukan untuk flash ulang MIUI)"
fi

echo
if [ "$fail" -eq 0 ]; then
  echo "HASIL: SEMUA VALID"
else
  echo "HASIL: ADA YANG GAGAL / BELUM LENGKAP"
fi
exit "$fail"
