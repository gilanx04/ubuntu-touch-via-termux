#!/data/data/com.termux/files/usr/bin/bash
# Pantau /cache/ubuntu_updater.log selama instalasi Ubuntu Touch.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADB="$ROOT/scripts/adb-r.sh"

if ! su -c id 2>/dev/null | grep -q 'uid=0'; then
  echo "Root tidak aktif." >&2
  exit 1
fi

adb() { su -c "$ADB $(printf '%q ' "$@")"; }

echo "Memantau instalasi (Ctrl+C untuk berhenti)..."
LAST=""
for _ in $(seq 1 120); do
  STATE="$(adb devices 2>/dev/null | awk 'NR>1 && $2!="" {print $2; exit}')"
  case "$STATE" in
    device|recovery)
      LINE="$(adb shell 'tail -n 3 /cache/ubuntu_updater.log 2>/dev/null' 2>/dev/null | tr -d '\r')"
      if [ -n "$LINE" ] && [ "$LINE" != "$LAST" ]; then
        echo "[$(date +%H:%M:%S)] $LINE"
        LAST="$LINE"
      fi
      case "$LINE" in
        *"Done upgrading"*) echo; echo "INSTALASI SELESAI."; exit 0;;
      esac
      ;;
    unauthorized)
      echo "[$(date +%H:%M:%S)] adb unauthorized — tap Allow di layar target"
      ;;
    "")
      echo "[$(date +%H:%M:%S)] menunggu adb/recovery..."
      ;;
    *)
      echo "[$(date +%H:%M:%S)] state: $STATE"
      ;;
  esac
  sleep 15
done

echo "Timeout pemantauan. Cek manual:"
echo "  su -c \"$ADB shell 'tail -50 /cache/ubuntu_updater.log'\""
