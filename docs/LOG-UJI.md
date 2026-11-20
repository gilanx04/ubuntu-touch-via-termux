# Log pengujian end-to-end

Log asli dari pengujian 20 November 2026, disunting seperlunya:
nomor seri, SSID Wi-Fi, dan path pribadi dihapus. Perintah dijalankan dari
Termux di host Android 17 dengan root KernelSU.

---

## 1. Identitas target (fastboot)

```
$ fastboot getvar product
product: surya

$ fastboot getvar unlocked
unlocked: yes

$ fastboot getvar is-userspace
is-userspace: no

$ fastboot getvar anti
anti: 2

$ fastboot getvar current-slot
getvar:current-slot FAILED (remote: 'GetVar Variable Not found')
```

`current-slot` gagal karena surya **A-only** — normal.

---

## 2. Bootstrap

```
$ fastboot format cache
Sending 'cache' (380 KB)                           OKAY [  0.011s]
Writing 'cache'                                    OKAY [  0.005s]
Finished. Total time: 0.050s

$ fastboot format:ext4 userdata
Sending 'userdata' (7369 KB)                       OKAY [  0.161s]
Writing 'userdata'                                  OKAY [  0.009s]
Finished. Total time: 0.404s

$ fastboot flash recovery recovery.img
Sending 'recovery' (131072 KB)                     OKAY [  2.752s]
Writing 'recovery'                                 OKAY [  0.671s]
Finished. Total time: 3.436s

$ fastboot flash dtbo dtbo.img
Sending 'dtbo' (250 KB)                            OKAY [  0.009s]
Writing 'dtbo'                                     OKAY [  0.002s]
Finished. Total time: 0.028s

$ fastboot reboot fastboot
Rebooting into fastboot                            OKAY [  0.001s]
< waiting for any device >
Finished. Total time: 13.013s

$ fastboot getvar is-userspace
is-userspace: yes

$ fastboot wipe-super super.img
Warning: skip copying super image avb footer due to sparse image.
Sending 'super' (264 KB)                           OKAY [  0.006s]
Writing 'super'                                    OKAY [  0.024s]

$ fastboot flash vendor vendor.img
Writing 'vendor'                                   OKAY [  3.268s]
Sending sparse 'vendor' 3/3 (231725 KB)            OKAY [  5.182s]
Writing 'vendor'                                   OKAY [  1.694s]
Finished. Total time: 37.749s

$ fastboot reboot recovery
Rebooting into recovery                            OKAY [  0.001s]
```

---

## 3. UBports Recovery dan /cache

```
$ adb devices -l
ABCD1234EF   recovery usb:1-1 product:lineage_surya model:M2007J20CG device:surya

$ adb shell getprop ro.ubuntu.recovery
true

$ adb shell df -h /cache
Filesystem       Size  Used Avail Use% Mounted on
/dev/block/sda16 103G  152K  103G   1% /cache

$ adb shell stat -c '%d %i %n' /cache /data/cache
66304 4456449 /cache
66304 4456449 /data/cache
```

Device dan inode sama → `/cache` adalah bind-mount `/data/cache` (userdata).

---

## 4. Push system image

```
$ adb push ./*.tar.xz ./*.tar.xz.asc ubuntu_command /cache/recovery/
...
15 files pushed, 0 skipped. 32.6 MB/s (690029481 bytes in 20.192s)
```

Verifikasi SHA-256 di perangkat:

```
boot-923c260e...tar.xz      d729c6be4fa32688...
device-cd3ef6bd...tar.xz    1caa4e5489ad058b...
image-master.tar.xz         5b2f6dabdeb2cf71...
image-signing.tar.xz        e6a01be33e78c770...
keyring-162141ca...tar.xz   afc915925ff6b233...
rootfs-cf2d4f00...tar.xz    39e2044599858623...
version-5.tar.xz            cbdd0a3ccf056a8c...
```

Hasil: **semua cocok** dengan checksum host.

---

## 5. Upgrader

Target reboot recovery dengan `ubuntu_command` di `/cache/recovery`.
Log `/cache/ubuntu_updater.log`:

```
...
Formatting: data
Keyring doesn't exist: device-signing
Applying update: rootfs-cf2d4f00668360d35298ea34e1b47b4434b96fb93509dc738906950ef9e261ab.tar.xz
Keyring doesn't exist: device-signing
Applying update: device-cd3ef6bd7fbed7b68e2d908ecf5afd79eb96521cf2e2de285f69f32579121dc8.tar.xz
Keyring doesn't exist: device-signing
Applying update: boot-923c260ed5ed00e0a3e641c04a13784087d8861aabc627db60a5d574b1cc8c9c.tar.xz
Flashing boot at /dev/block/bootdevice/by-name/boot
Invalid sparse file format at header magic
Failed to read sparse file
16+0 records in
16+0 records out
134217728 bytes (128 M) copied, 0.769767 s, 166 M/s
Keyring doesn't exist: device-signing
Applying update: keyring-162141caf64cd64c4ca014760930c524e4ee051e0afe1200c47c42cebf11fd44.tar.xz
Keyring doesn't exist: device-signing
Applying update: version-5.tar.xz
Done upgrading...
tune2fs 1.44.4 (18-Aug-2018)
Setting reserved blocks percentage to 5% (1373976 blocks)
```

Catatan:

- `Formatting: data` menghapus userdata, tetapi **tidak** menghapus
  `/data/cache` (tempat image).
- `Keyring doesn't exist: device-signing` normal.
- `Invalid sparse file format` / `Failed to read sparse file` normal; boot
  di-flash raw setelah fallback.

---

## 6. Hasil akhir

```
$ adb shell system-image-cli -i
current build number: 5
device name: surya
channel: 24.04-1.x/arm64/android9plus/stable
last update: 1971-06-20 22:14:40
version version: 5
version tag: 24.04-1.4
version rootfs: 2026-07-13T01:56:29Z_arm64_ubports/24.04-1.x_336_ee1a6261b7db2a262c137d81a40ee3323a0019d9
version keyring: archive-master
version device: 20260608-2438
version boot: 20260619-004143Z
```

```
$ adb shell uname -a
Linux ubuntu-phablet 4.14.221-perf+ #1 SMP PREEMPT Fri Jun 19 00:40:58 UTC 2026 aarch64 aarch64 aarch64 GNU/Linux

$ adb shell cat /etc/os-release
PRETTY_NAME="Ubuntu 24.04.4 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.4 LTS (Noble Numbat)"
VERSION_CODENAME=noble
ID=ubuntu
ID_LIKE=debian
...
VARIANT=Touch
VARIANT_ID=touch
```

```
$ adb shell df -h / /android/data
Filesystem          Size  Used Avail Use% Mounted on
/dev/mapper/system  4.9G  2.9G  2.0G  60% /
/dev/sda16          103G  341M   98G   1% /android/data
```

```
$ adb shell mount | grep -E ' / | /android'
/dev/mapper/system on / type ext4 (ro,relatime,errors=remount-ro,data=ordered)
/dev/mapper/vendor on /android/vendor type ext4 (ro,relatime)
/dev/sda16 on /android/data type ext4 (rw,relatime,discard,nodelalloc,errors=remount-ro,stripe=2,data=journal)
/dev/sda16 on /android/cache type ext4 (rw,relatime,discard,nodelalloc,errors=remount-ro,stripe=2,data=journal)
```

Wi-Fi terhubung, baterai 66% (charging), dan welcome wizard siap diselesaikan.
