# Troubleshooting

Kumpulan masalah nyata yang muncul saat pengujian, lengkap dengan penyebab dan
solusinya. Sebelum mulai, siapkan variabel berikut di shell Termux:

```bash
cd ~/ubuntu-touch-via-termux
ADB="$PWD/scripts/adb-r.sh"
FB="$PWD/scripts/fastboot-r.sh"
```

---

## Diagnosa cepat

Jalankan saat target terhubung USB:

```bash
# Root host
su -c id

# ADB
su -c "$ADB kill-server"
su -c "$ADB start-server"
su -c "$ADB devices -l"

# Fastboot (target harus di bootloader)
su -c "$FB devices"

# USB di sisi host
ls /sys/bus/usb/devices
su -c 'cat /sys/bus/usb/devices/1-1/idVendor 2>/dev/null'
```

Arti status ADB:

| Status | Arti |
|---|---|
| `device` | Siap, sudah diotorisasi |
| `recovery` | Siap di recovery |
| `unauthorized` | Belum tap Allow di target |
| `offline` | Koneksi bermasalah; cabut-colok / restart server |
| (kosong) | Tidak ada device, kabel/root/server bermasalah |

---

## 1. `termux-usb -l` hang atau tidak mengeluarkan output

**Gejala**

```bash
termux-usb -l
# (tidak ada output, menggantung)
```

`termux-adb devices` juga kosong.

**Penyebab**

`termux-usb` memakai aplikasi **Termux:API** sebagai jembatan. Di Android baru,
layanan USB plugin dibatasi saat aplikasi di background. `termux-api-start`
membantu sebagian, tetapi pada pengujian ini tetap tidak menghasilkan output.

**Solusi**

Pakai **root + `android-tools`**, bukan `termux-usb`/`termux-adb`:

```bash
pkg install android-tools
su -c "$ADB devices -l"
```

Dengan root, adb/fastboot membuka `/dev/bus/usb` langsung dan tidak perlu
Termux:API sama sekali.

---

## 2. `adb devices` kosong padahal kabel terpasang

**Cek 1 — kabel**

- Harus kabel **data**, bukan charge-only.
- Coba kabel lain.
- Pastikan OTG aktif (host menjadi USB host).

**Cek 2 — USB debugging target**

- Settings → About → tap Build number 7× → Developer options.
- Aktifkan **USB debugging**.
- Cabut-colok kabel.

**Cek 3 — server adb bukan root**

```bash
su -c "$ADB kill-server"
su -c "$ADB start-server"
su -c "$ADB devices -l"
```

**Cek 4 — perangkat terlihat di sysfs**

```bash
ls /sys/bus/usb/devices
# contoh: 1-1  1-1:1.0  1-1:1.1
su -c 'cat /sys/bus/usb/devices/1-1/idVendor'
# 2717 = Xiaomi
```

Jika `1-1` ada tetapi adb kosong, masalahnya di adbd target atau server adb host.

**Cek 5 — TMPDIR**

adb sebagai root butuh `TMPDIR` yang bisa ditulis root. Wrapper sudah menyetel
`TMPDIR=/data/local/tmp`. Jika memanggil `adb` langsung tanpa wrapper, set dulu:

```bash
su -c 'TMPDIR=/data/local/tmp adb devices'
```

---

## 3. `unauthorized`

**Gejala**

```
ABCD1234EF   unauthorized   usb:1-1
```

**Solusi**

Di layar target muncul:

> **Allow USB debugging?**
> RSA fingerprint: …

Centang **“Always allow from this computer”**, lalu **Allow**.

Jika dialog tidak muncul:

```bash
su -c "$ADB kill-server"
su -c "$ADB start-server"
su -c "$ADB devices -l"
```

atau cabut-colok kabel, atau matikan-nyalakan lagi USB debugging.

> [!NOTE]
> Setelah `format data` di proses instalasi, kunci ADB ikut terhapus dan target
> akan meminta otorisasi **lagi**. Ini normal.

---

## 4. `adb: no devices/emulators found` setelah `reboot recovery`

**Penyebab**

Target sedang reboot; adbd recovery belum siap. Pada perangkat ini butuh
10–30 detik, kadang lebih.

**Solusi**

```bash
for i in $(seq 1 30); do
  su -c "$ADB devices" | grep -w -E 'device|recovery' && break
  sleep 3
done

su -c "$ADB shell getprop ro.ubuntu.recovery"
```

Jika tetap kosong, restart server adb:

```bash
su -c "$ADB kill-server"
su -c "$ADB start-server"
su -c "$ADB devices -l"
```

---

## 5. Fastboot menunggu terus (`< waiting for any device >`)

**Gejala**

```
< waiting for any device >
```

**Penyebab**

- Target belum masuk bootloader.
- Driver/USB belum siap.
- Setelah `reboot fastboot`, perangkat butuh 10–20 detik untuk masuk fastbootd.

**Solusi**

```bash
# pastikan target di bootloader
su -c "$ADB reboot bootloader"

# tunggu
for i in $(seq 1 20); do
  su -c "$FB devices" && break
  sleep 3
done
```

Setelah `fastboot reboot fastboot`, cek `is-userspace`:

```bash
su -c "$FB getvar is-userspace"
# bootloader : no
# fastbootd  : yes
```

---

## 6. `/cache` hanya 344 MB / push gagal `No space left on device`

**Gejala**

```
dd: /cache/bigtest: write error: No space left on device
```

atau

```
adb: error: failed to copy ... : remote No space left on device
```

**Penyebab**

Di UBports Recovery, `/cache` adalah **bind-mount dari `/data/cache`**
(userdata 103 GB). Partisi cache fisik hanya 344 MB dan **tidak dipakai**.
Kalau seseorang menjalankan `mount -a`, partisi cache 344 MB menumpuk di atas
`/cache`, sehingga push 659 MB gagal.

**Diagnosa**

```bash
su -c "$ADB shell 'df -h /cache'"
su -c "$ADB shell 'stat -c \"%d %i %n\" /cache /data/cache'"
```

Yang benar:

```
/dev/block/sda16 103G ... /cache

66304 4456449 /cache
66304 4456449 /data/cache
```

Yang salah (cache 344 MB menumpuk):

```
/dev/block/sda11 344M ... /cache
```

**Solusi**

```bash
su -c "$ADB shell 'umount /cache'"
su -c "$ADB shell 'df -h /cache'"          # sekarang 103G
su -c "$ADB shell 'stat -c \"%d %i\" /cache /data/cache"'  # harus sama
```

Lalu ulangi push. **Jangan** menjalankan `mount -a` di recovery ini.

> [!IMPORTANT]
> File yang sudah terlanjur dipush saat cache 344 MB menumpuk bisa “hilang”
> karena tertutup mount. Setelah `umount`, cek ulang isi `/cache/recovery`
> dan push ulang bila perlu.

---

## 7. `wipe-super`: peringatan AVB footer

**Gejala**

```
Warning: skip copying super image avb footer due to sparse image.
Sending 'super' (264 KB) ...
```

**Penyebab**

`super.img` dari rilis bootstrap adalah sparse image metadata (hanya tabel
partisi, 4.536 byte). Fastboot tidak menyalin AVB footer.

**Solusi**

Abaikan. Ini normal dan justru yang diinginkan: `wipe-super` mengosongkan
super lalu `flash vendor` mengisi partisi vendor.

---

## 8. `Failed to read sparse file` saat update boot

**Gejala di `/cache/ubuntu_updater.log`**

```
Flashing boot at /dev/block/bootdevice/by-name/boot
Invalid sparse file format at header magic
Failed to read sparse file
16+0 records in
16+0 records out
134217728 bytes (128 M) copied
```

**Penyebab**

Upgrader mencoba memperlakukan boot image sebagai sparse, gagal, lalu
fallback menulis image **raw** dengan `dd`. Pesan error itu tidak fatal.

**Solusi**

Abaikan selama log berakhir dengan:

```
Done upgrading...
```

---

## 9. `Keyring doesn't exist: device-signing`

**Gejala**

```
Keyring doesn't exist: device-signing
Applying update: rootfs-...
```

**Penyebab**

Tidak ada keyring bertipe `device-signing`; upgrader memakai `image-signing`.

**Solusi**

Abaikan. Ini normal dan bukan error.

---

## 10. Installer terlihat diam / tidak ada progress di layar

**Cek log**

```bash
su -c "$ADB shell 'tail -f /cache/ubuntu_updater.log'"
```

atau:

```bash
bash scripts/pantau-instalasi.sh
```

**Jika adb mati saat instalasi**

Wajar — adbd bisa restart. Tunggu, lalu cek lagi:

```bash
su -c "$ADB devices -l"
su -c "$ADB shell 'tail -50 /cache/ubuntu_updater.log'"
```

**Jika log berhenti di tengah**

- Jangan cabut kabel.
- Cek ruang `/cache` dan `/data`.
- Cek baterai target.
- Jika lebih dari 30 menit tanpa baris baru, reboot recovery dan ulangi push
  (file yang sudah dipush tidak perlu diulang jika masih lengkap).

---

## 11. Setelah instalasi, adb `unauthorized` lagi

**Penyebab**

`format data` menghapus `/data/misc/adb/adb_keys`, termasuk kunci otorisasi.

**Solusi**

Tap **Allow** + **Always allow** di layar target. Tidak perlu ulang instalasi.

---

## 12. `ro.ubuntu.recovery` kosong

**Penyebab**

Target sedang boot ke sistem Ubuntu Touch, bukan recovery. Di sistem normal,
properti ini memang tidak ada.

**Solusi**

```bash
su -c "$ADB devices -l"
# recovery → benar
# device   → sudah di sistem
```

Untuk masuk recovery lagi:

```bash
su -c "$ADB reboot recovery"
```

---

## 13. TWRP menolak zip MIUI

**Gejala**

```
Zip signature verification failed
```

**Penyebab**

Zip MIUI ditandatangani kunci Xiaomi, bukan test-key TWRP.

**Solusi**

Di TWRP: **Install** → matikan **“Zip signature verification”** → flash ulang.

---

## 14. Anti-rollback (ARB)

**Cek**

```bash
su -c "$FB getvar anti"
# anti: 2
```

**Aturan**

- V12.0.9.0.QJGMIXM = ARB **2**.
- Jangan flash firmware dengan ARB lebih tinggi dari perangkat.
- ARB tidak terlihat di dalam zip Recovery ROM; nilainya hanya ada di fastboot
  ROM (`anti_version.txt`) dan di perangkat (`getvar anti`).

Jika `getvar anti` > 2, **stop**.

---

## 15. Bootloop setelah instalasi

**Langkah diagnosa**

1. Masuk recovery:
   ```bash
   su -c "$ADB reboot recovery"
   ```
2. Cek log terakhir:
   ```bash
   su -c "$ADB shell 'tail -80 /cache/ubuntu_updater.log'"
   ```
3. Cek partisi:
   ```bash
   su -c "$ADB shell 'df -h / /cache'"
   ```
4. Coba reboot ke sistem:
   ```bash
   su -c "$ADB reboot"
   ```

**Jika tetap bootloop**

- Ulangi push system image (file mungkin tidak lengkap).
- Pastikan `Done upgrading...` benar-benar muncul.
- Sebagai jalan terakhir, kembali ke MIUI lalu ulangi dari bootstrap.

---

## 16. Kembali ke Android

Setelah Ubuntu Touch, recovery adalah **UBports Recovery**. TWRP sudah tertimpa.

**Opsi A — fastboot ROM MIUI**

1. Unduh fastboot ROM V12.0.9.0.QJGMIXM (`surya`, `.tgz`).
2. Ekstrak, lalu jalankan `flash_all.sh` dengan `fastboot` Termux di `PATH`.
3. Cek ARB sebelum flash.

**Opsi B — TWRP + Recovery ROM**

```bash
su -c "$FB flash recovery twrp.img"
```

Boot TWRP (Volume Up + Power), flash zip MIUI, matikan signature verification.

> [!CAUTION]
> Jangan lock bootloader setelah kembali ke Android.

---

## 17. USB disconnect / perangkat re-enumerate

Saat reboot (bootloader → fastbootd → recovery → sistem), USB akan disconnect
dan muncul lagi dengan nomor device baru. Ini normal. Lihat:

```bash
su -c 'dmesg | grep -i usb | tail -10'
```

Jika perangkat tidak muncul lagi:

- cabut-colok kabel,
- coba port/kabel lain,
- restart server adb,
- reboot target ke mode yang dituju.

---

## 18. `dumpsys usb` / `lsusb` tidak bisa

Di Android, `dumpsys usb` butuh izin `DUMP`:

```
Permission Denial: can't dump UsbService ...
```

Itu normal untuk aplikasi biasa. Gunakan `ls /sys/bus/usb/devices` dan
`adb devices` sebagai gantinya.

---

## 19. `fastboot getvar current-slot` gagal

```
getvar:current-slot FAILED (remote: 'GetVar Variable Not found')
```

**Penyebab**

Poco X3 NFC adalah perangkat **A-only** (tanpa slot A/B).

**Solusi**

Abaikan. Tidak ada `current-slot` yang perlu diurus.

---

## 20. Host kehabisan ruang / thermal

- Bootstrap + system image + MIUI = ±4,3 GB. Pastikan ruang cukup sebelum unduh.
- Flashing `vendor.img` 1,3 GB membuat host dan target hangat. Jangan menutup
  Termux atau mematikan layar host jika itu memutus proses.
- Baterai host dan target > 50%.

---

## Bantuan lebih lanjut

Jika masalahmu tidak tercantum:

1. Simpan log: `su -c "$ADB shell 'cat /cache/ubuntu_updater.log'" > log.txt`
2. Catat langkah terakhir dan pesan error persis.
3. Buka issue di repo dengan log tersebut (hapus serial/IMEI/SSID dulu).
