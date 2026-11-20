# Catatan teknis

Dokumen ini menjelaskan **kenapa** perintah di README bekerja, khususnya bagian
yang tidak terlihat sebagai “sihir”: partisi, bind-mount `/cache`, dan cara
`system-image-upgrader` memasang Ubuntu Touch.

---

## 1. Peta partisi

### Sebelum bootstrap (MIUI Android 10)

| Partisi | Isi |
|---|---|
| `boot` | Kernel + ramdisk MIUI |
| `dtbo` | Device tree overlay |
| `recovery` | TWRP / recovery stock |
| `super` | Dynamic partitions: `system`, `vendor`, `product` |
| `userdata` | Data pengguna (±103 GB) |
| `cache` | Cache fisik (±344 MB) |
| `metadata` | Metadata Android |

### Setelah bootstrap + instalasi

| Partisi / mount | Isi | Ukuran teramati |
|---|---|---|
| `boot` | Kernel Halium + initramfs Ubuntu Touch | 128 MB (image raw) |
| `dtbo` | DTBO port surya | 250 KB |
| `recovery` | **UBports Recovery** | 128 MB |
| `super` | Tabel partisi baru: `system` + `vendor` | metadata 4.536 B |
| `system` (`/dev/mapper/system`) | Rootfs Ubuntu 24.04 | ±4,9 GB |
| `vendor` (`/dev/mapper/vendor`) | Vendor Android untuk Halium | ±1,3 GB |
| `userdata` (`/dev/sda16`) | `/android/data`, `/android/cache`, `/opt/click.ubuntu.com` | 103 GB |
| `cache` (`/dev/sda11`) | Tidak dipakai saat instalasi | 344 MB |

Saat sistem berjalan:

```
/dev/mapper/system   /                  ext4  ro
/dev/mapper/vendor   /android/vendor    ext4  ro
/dev/sda16           /android/data      ext4  rw
/dev/sda16           /android/cache     ext4  rw
/dev/sda16           /opt/click.ubuntu.com ext4 rw
```

---

## 2. Peran file bootstrap

| File | Ukuran | Peran |
|---|---|---|
| `recovery.img` | 134.217.728 B | UBports Recovery: menjalankan `system-image-upgrader`, menyediakan adb, membaca `ubuntu_command` |
| `dtbo.img` | 256.344 B | Device tree overlay yang cocok dengan kernel Halium port surya |
| `super.img` | 4.536 B | **Sparse metadata** super: mendefinisikan partisi `system` + `vendor` tanpa data |
| `vendor.img` | 1.321.787.392 B | Blob vendor Android 10 yang dibutuhkan Halium (kamera, sensor, radio, GPU, dll.) |

`super.img` yang hanya 4.536 byte sering membingungkan. Itu bukan image sistem
penuh — ia hanya tabel partisi. `fastboot wipe-super super.img` menulis tabel
tersebut, lalu `fastboot flash vendor vendor.img` mengisi partisi vendor.
Partisi `system` dibiarkan kosong sampai upgrader memformatnya.

---

## 3. Kenapa `/cache` adalah `/data/cache`

Di UBports Recovery untuk surya, init memasang userdata di `/data`, lalu
**bind-mount** `/data/cache` ke `/cache`. Partisi cache fisik (344 MB) tidak
dipakai karena terlalu kecil untuk system image ±690 MB.

Akibatnya:

```
/cache        == /data/cache        (userdata, 103 GB)
/data/cache   == direktori di userdata
```

Buktinya:

```bash
stat -c '%d %i %n' /cache /data/cache
# 66304 4456449 /cache
# 66304 4456449 /data/cache
```

Device dan inode sama → keduanya direktori yang sama.

### Jebakan `mount -a`

Kalau menjalankan `mount -a` di recovery, entri fstab untuk partisi cache fisik
ikut dipasang dan **menumpuk** di atas bind-mount:

```
/dev/block/sda11 344M ... /cache
```

Setelah itu:

- `df -h /cache` menunjukkan 344 MB;
- push ±690 MB gagal `No space left on device`;
- file yang sudah dipush “hilang” di balik mount.

Solusi: `umount /cache` (satu lapisan), lalu cek inode kembali. **Jangan**
`mount -a` di recovery ini.

### Kenapa `format data` tidak menghapus image

`system-image-upgrader` menghapus isi `/data` dengan loop:

```sh
for entry in /data/* /data/.writable_image /data/.factory_wipe /data/.fscrypt; do
    ...
    if [ "$entry" == "/data/cache" ]; then
        continue
    fi
    ...
    rm -Rf $entry
done
```

Ada pengecualian eksplisit untuk `/data/cache` — justru karena di beberapa
perangkat (termasuk surya) cache di-bind dari sana dan dipakai menyimpan image
selama instalasi.

---

## 4. Isi `ubuntu_command`

File `data/ubuntu_command-24.04-1.4` (889 byte):

```
format system
load_keyring image-master.tar.xz image-master.tar.xz.asc
load_keyring image-signing.tar.xz image-signing.tar.xz.asc
mount system
format data
update rootfs-cf2d4f00668360d35298ea34e1b47b4434b96fb93509dc738906950ef9e261ab.tar.xz rootfs-....tar.xz.asc
update device-cd3ef6bd7fbed7b68e2d908ecf5afd79eb96521cf2e2de285f69f32579121dc8.tar.xz device-....tar.xz.asc
update boot-923c260ed5ed00e0a3e641c04a13784087d8861aabc627db60a5d574b1cc8c9c.tar.xz boot-....tar.xz.asc
update keyring-162141caf64cd64c4ca014760930c524e4ee051e0afe1200c47c42cebf11fd44.tar.xz keyring-....tar.xz.asc
update version-5.tar.xz version-5.tar.xz.asc
unmount system
```

Urutannya penting:

1. `format system` — siapkan partisi rootfs.
2. `load_keyring` — pasang kunci GPG untuk verifikasi.
3. `mount system` — mount rootfs kosong.
4. `format data` — hapus userdata (kecuali `/data/cache`).
5. `update` rootfs → device → boot → keyring → version.
6. `unmount system`.

---

## 5. Alur recovery → upgrader

1. Target reboot ke recovery.
2. `recovery.cpp` melihat `/cache/recovery/ubuntu_command` ada, lalu menambahkan
   argumen `ubuntu`.
3. `update_ubuntu_package` diarahkan ke `/sbin/system-image-upgrader`.
4. `do_ubuntu_update()` menjalankan:

   ```sh
   /sbin/system-image-upgrader /cache/recovery/ubuntu_command \
       &> /cache/ubuntu_updater.log
   ```

5. Script membaca perintah baris per baris, memverifikasi `.asc`, mengekstrak
   tarball, dan menulis boot image.
6. Setelah selesai: `Done upgrading...`, lalu `sync` dan `tune2fs -m 5` pada
   `/data`.
7. Script memindahkan `ubuntu_command` menjadi `ubuntu_command.applying` sejak
   awal, lalu menghapusnya di akhir. Karena itu instalasi **tidak terulang**
   saat recovery di-boot lagi.

Karena itu, **cukup `adb reboot recovery`** setelah file dipush — tidak perlu
menekan menu “Install” apa pun.

---

## 6. `format system`: system partition vs `ubuntu.img`

Upgrader mendeteksi apakah perangkat punya partisi `system` terpisah:

- **USE_SYSTEM_PARTITION=1** (kasus surya): `mkfs.ext4` langsung ke partisi
  system. Log menunjukkan:

  ```
  /dev/block/dm-0: 11/327680 files (0.0% non-contiguous), 39518/1310720 blocks
  ```

  1.310.720 blok × 4 KB = 5,37 GB (≈5 GiB).

- **USE_SYSTEM_PARTITION=0**: membuat `/data/ubuntu.img` sparse ±3,8 GiB,
  `mkfs.ext4` di file itu, lalu memount-nya sebagai rootfs.

Pada surya, bootstrap sudah menyiapkan partisi system, jadi rootfs berada di
`/dev/mapper/system` dan **bukan** di `/data/ubuntu.img`. Inilah sebabnya
`ls /data/ubuntu.img` setelah instalasi tidak menemukan apa-apa — itu normal.

---

## 7. Update boot dan pesan sparse

Saat `update boot-...tar.xz`:

1. Upgrader mengekstrak `boot.img` dari tarball.
2. Mencoba `simg2img` (konversi sparse → raw).
3. Karena image bukan sparse, muncul:

   ```
   Invalid sparse file format at header magic
   Failed to read sparse file
   ```

4. Fallback: `dd` menulis image **raw** ke partisi `boot`:

   ```
   16+0 records in
   16+0 records out
   134217728 bytes (128 M) copied
   ```

Pesan error itu tidak fatal selama log berakhir `Done upgrading...`.

---

## 8. Rantai verifikasi

| Tahap | Yang diverifikasi |
|---|---|
| Unduh bootstrap | SHA-256 terhadap rilis `stable-repartition` |
| Unduh system image | SHA-256 terhadap index system-image |
| Push ke perangkat | SHA-256 host vs `/cache/recovery` (script) |
| Instalasi | GPG `.asc` diverifikasi `system-image-upgrader` memakai keyring `image-signing` |
| Boot | Kernel/initramfs Halium memount rootfs |

`Keyring doesn't exist: device-signing` muncul karena hanya keyring
`image-signing` yang tersedia; upgrader tetap memverifikasi dengan keyring itu.
Bukan error.

---

## 9. A-only, fastboot, dan fastbootd

Surya adalah perangkat **A-only**:

- Tidak ada slot A/B.
- `fastboot getvar current-slot` gagal — normal.
- `fastboot getvar is-userspace` membedakan mode:
  - `no` → bootloader (fastboot biasa)
  - `yes` → fastbootd (userspace fastboot, bagian dari recovery)

`wipe-super` dan `flash vendor` harus dijalankan di **fastbootd**, karena
fastboot biasa tidak bisa mengelola dynamic partitions.

---

## 10. Kenapa butuh root di host

Node USB di Android dimiliki `root:root` dengan mode ketat:

```
/dev/bus/usb/001/002
```

Aplikasi biasa (Termux) tidak bisa membukanya. Ada dua jalur:

1. **Tanpa root** — `termux-usb` meminta izin ke framework USB, lalu meneruskan
   file descriptor ke proses. Ini bergantung pada aplikasi Termux:API dan
   layanan background-nya; di Android baru sering hang.
2. **Dengan root** — `adb`/`fastboot` berjalan sebagai root dan membuka node USB
   langsung, sama seperti di PC. Tidak ada dialog izin USB, tidak ada jembatan
   aplikasi.

Repo ini memakai jalur 2. Wrapper `scripts/adb-r.sh` dan `fastboot-r.sh`
menangani tiga detail: `TMPDIR`, `HOME` (kunci ADB), dan `PATH` setelah `su`.

---

## 11. Anti-rollback (ARB)

- V12.0.9.0.QJGMIXM → ARB **2**.
- Nilai ARB tidak ada di dalam zip Recovery ROM; hanya di fastboot ROM
  (`anti_version.txt`) dan di perangkat (`fastboot getvar anti`).
- Flash firmware dengan ARB lebih tinggi dari perangkat bisa brick.
- Selalu cek `getvar anti` sebelum flash firmware baru.

---

## 12. Display dan refresh rate 120 Hz

Surya memakai panel 1080×2400 dengan timing 120 Hz. Di DTBO port, kedua varian
panel (Huaxing dan Tianma) punya `timing@0` pada 120 fps, dengan daftar DFPS:

```text
qcom,dsi-supported-dfps-list = <120 90 60 50 30>;
```

`msm_drm.dsi_display0=...:configX` di cmdline memilih topologi DSI, bukan
timing. Timing default tetap `timing@0` (120 fps). Kernel membuat lima mode DRM
(120/90/60/50/30), dan mode pertama yang dipakai HWC adalah 120 Hz.

Mir di Android platform tidak mengekspos pemilihan mode ke UI. Platform memakai
config HWC yang aktif (`HwcPowerModeControl::active_config_for`), jadi yang
terlihat di `mirout` adalah mode yang benar-benar dipakai compositor.

Hasil pengujian pada 20 November 2026:

```text
$ mirout /run/mir_socket
Output 1: LVDS, connected, 1080x2400+0+0, enabled, on, ...
    1080x2400    120.00*+

$ python3 cek-refresh.py /dev/dri/card0
...
ACTIVE CRTC 115: 1080x2400 @ 120Hz  name=1080x2400x120x143404  clock=143404kHz
```

`*` = mode aktif, `+` = mode preferred. Baris `ACTIVE CRTC` adalah pengecekan
independen: mode yang sedang dipakai CRTC memang 120 Hz, bukan sekadar mode
preferred.

DFPS yang didukung panel adalah 120/90/60/50/30, sehingga rate bisa turun saat
konten statis. Karena itu, 120 Hz paling terasa saat scroll/animasi; angka di
`mirout` menunjukkan mode compositor, bukan hasil pengukuran frame per detik.

Untuk mengubah rate sementara:

```bash
mirout /run/mir_socket output 1 rate 120
```

Ini bukan pengaturan permanen; setelah reboot Mir kembali memakai config HWC
default. Tidak ada `xrandr` di Ubuntu Touch karena stack display-nya Mir/Wayland.

---

## 13. Referensi sumber

- Port surya: <https://github.com/ubuntu-touch-surya/ubuntu-touch-surya>
- Konfigurasi perangkat UBports Installer:
  <https://github.com/ubports/installer-configs/blob/master/v2/devices/surya.yml>
- UBports Installer (plugin `systemimage`):
  <https://github.com/ubports/ubports-installer>
- Android recovery UBports ( `recovery.cpp`, `ubupdater.cpp`):
  <https://github.com/ubports/android_bootable_recovery>
- System image server:
  <https://system-image.ubports.com/24.04-1.x/arm64/android9plus/stable/surya/index.json>
- Termux: <https://termux.dev/>
- android-tools: <https://github.com/termux/termux-packages>
