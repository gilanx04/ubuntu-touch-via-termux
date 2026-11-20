# Manifest bahan instalasi

| | |
|---|---|
| Target | Xiaomi Poco X3 NFC (`surya`) |
| Ubuntu Touch | 24.04-1.4 (build 5) |
| Channel | `24.04-1.x/arm64/android9plus/stable` |
| Base firmware | MIUI V12.0.9.0.QJGMIXM (Android 10, SDK 29) |
| Tanggal pengujian | 20 November 2026 |

---

## 1. Bootstrap

Sumber:
<https://github.com/ubuntu-touch-surya/ubuntu-touch-surya/releases/tag/stable-repartition>

| File | Ukuran (byte) | SHA-256 |
|---|---:|---|
| `recovery.img` | 134.217.728 | `357b32fe91a76879babcc24a0b2ad51e767283955e454ca58cf3e7f75b0fbdd5` |
| `dtbo.img` | 256.344 | `f08d0116435d600d7e3ac002813031644d6d3ad8fb3e078ec6985d956dde8158` |
| `super.img` | 4.536 | `2d8b05f9aefa946b8a055249c77d38377970acc2f2fe6722877d5522d3bff10d` |
| `vendor.img` | 1.321.787.392 | `8b5cb118fcb0c34af5443eaac2cd703ac9ab8e104f420eaa07276e5b0e532029` |

URL unduh:

```
https://github.com/ubuntu-touch-surya/ubuntu-touch-surya/releases/download/stable-repartition/recovery.img
https://github.com/ubuntu-touch-surya/ubuntu-touch-surya/releases/download/stable-repartition/dtbo.img
https://github.com/ubuntu-touch-surya/ubuntu-touch-surya/releases/download/stable-repartition/super.img
https://github.com/ubuntu-touch-surya/ubuntu-touch-surya/releases/download/stable-repartition/vendor.img
```

---

## 2. System image Ubuntu Touch 24.04-1.4 (build 5)

Index:
<https://system-image.ubports.com/24.04-1.x/arm64/android9plus/stable/surya/index.json>

Build yang dipakai: `version = 5`, `type = full`,
`tag = 24.04-1.4`, `version_detail`:

```
rootfs=2026-07-13T01:56:29Z_arm64_ubports/24.04-1.x_336_ee1a6261b7db2a262c137d81a40ee3323a0019d9
device=20260608-2438
boot=20260619-004143Z
keyring=archive-master
tag=24.04-1.4
version=5
```

| File | Ukuran (byte) | SHA-256 |
|---|---:|---|
| `rootfs-cf2d4f00...tar.xz` | 524.458.440 | `39e20445998586232934bc7640b2106102f4bde8dbd49aaff6072c8e23a3dd52` |
| `device-cd3ef6bd...tar.xz` | 143.989.368 | `1caa4e5489ad058b7089822f6fa76bdb783a472d47031b89c242c70ecc17bb14` |
| `boot-923c260e...tar.xz` | 21.573.408 | `d729c6be4fa326885be08ed40be753a41b9926ad30f390ad714a2b6e84f9d7a1` |
| `keyring-162141ca...tar.xz` | 1.560 | `afc915925ff6b23316b99c032435220bd791990b52db9bed25981754b3708e0a` |
| `version-5.tar.xz` | 548 | `cbdd0a3ccf056a8cdd7f8f8d3ac8edef276c3810e6af7924df62749550c58f96` |
| `image-master.tar.xz` | 900 | `5b2f6dabdeb2cf712849c805f439fbb7c6dabcf222d05fdc94b62128bea6b018` |
| `image-signing.tar.xz` | 952 | `e6a01be33e78c770e7f5643175715a3efe9ed609cf27b3e1ce8577d5bbd827e3` |
| `ubuntu_command` | 889 | `6e84dc8e5b1966a8c8b72d7aa60d5761502e8dd5ce1459c001ce863533603519` |

Lima image utama (tanpa GPG/command): **690.023.324 byte**.
Total 15 file yang dipush ke `/cache/recovery`: **690.029.481 byte**.

URL pattern (base `https://system-image.ubports.com`):

```
/pool/rootfs-cf2d4f00668360d35298ea34e1b47b4434b96fb93509dc738906950ef9e261ab.tar.xz
/pool/device-cd3ef6bd7fbed7b68e2d908ecf5afd79eb96521cf2e2de285f69f32579121dc8.tar.xz
/pool/boot-923c260ed5ed00e0a3e641c04a13784087d8861aabc627db60a5d574b1cc8c9c.tar.xz
/pool/keyring-162141caf64cd64c4ca014760930c524e4ee051e0afe1200c47c42cebf11fd44.tar.xz
/24.04-1.x/arm64/android9plus/stable/surya/version-5.tar.xz
/gpg/image-master.tar.xz
/gpg/image-signing.tar.xz
```

Setiap file di atas punya pasangan `.asc` di URL yang sama dengan suffix `.asc`.

> [!NOTE]
> File `.asc` adalah tanda tangan GPG. Verifikasi final dilakukan oleh
> `system-image-upgrader` di recovery memakai keyring `image-master` dan
> `image-signing`, bukan oleh `sha256sum` di host.

---

## 3. MIUI Recovery ROM (opsional)

| | |
|---|---|
| Nama | `miui_SURYAGlobal_V12.0.9.0.QJGMIXM_7f83537667_10.0.zip` |
| Ukuran | 2.445.296.513 byte (2,28 GiB) |
| MD5 resmi Xiaomi | `7f835376675f18a173d04cfb725ff621` |
| SHA-256 lokal | `2fc6848bed1a0aecd78f9477edea76409b92a1a4fc5879e74b96ff5863671c68` |

Sumber langsung:

```
https://bkt-sgp-miui-ota-update-alisgp.oss-ap-southeast-1.aliyuncs.com/V12.0.9.0.QJGMIXM/miui_SURYAGlobal_V12.0.9.0.QJGMIXM_7f83537667_10.0.zip
```

Cadangan: cari nama file yang sama di halaman resmi Xiaomi atau
XMFirmwareUpdater. Ini **Recovery ROM** (flash via TWRP), bukan fastboot ROM.

Metadata dari dalam zip:

```
pre-device       = surya
post-build       = POCO/surya_global/surya:10/QKQ1.200512.002/V12.0.9.0.QJGMIXM
post-sdk-level   = 29 (Android 10)
ota-type         = BLOCK
dynamic partition= ya (system/vendor/product di dalam super)
```

ARB:

- Nilai anti-rollback firmware ini = **2** (dikonfirmasi dari
  `fastboot getvar anti` pada perangkat uji).
- Zip Recovery ROM tidak memuat `anti_version.txt`; nilai ARB hanya ada di
  fastboot ROM dan di perangkat (`fastboot getvar anti`).
- Jangan flash firmware dengan ARB lebih tinggi dari perangkat.

> [!NOTE]
> Xiaomi hanya menerbitkan **MD5** untuk ROM ini. SHA-256 di atas adalah catatan
> integritas lokal, bukan pembanding resmi.

---

## 4. Ringkasan checksum

Semua checksum ada di [`SHA256SUMS.txt`](SHA256SUMS.txt). Verifikasi:

```bash
cd ~/ubuntu-touch-via-termux
sha256sum -c data/SHA256SUMS.txt
```

Baris MIUI akan gagal jika file MIUI tidak ada — itu wajar karena opsional.
Gunakan `scripts/verifikasi.sh` yang menangani kasus ini.
