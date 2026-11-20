#!/usr/bin/env python3
"""Cetak mode DRM aktif dan refresh rate-nya, tanpa header libdrm.

Dipakai sebagai verifikasi independen setelah `mirout`. Jalankan di Ubuntu
Touch (paket python3 dan libdrm sudah tersedia):

    python3 cek-refresh.py /dev/dri/card0

Baris pentingnya adalah `ACTIVE CRTC`, misalnya:

    ACTIVE CRTC 115: 1080x2400 @ 120Hz  name=1080x2400x120x143404
"""
import ctypes as C
import ctypes.util
import os
import sys

lib = None
for _name in filter(None, [ctypes.util.find_library("drm"), "libdrm.so.2", "libdrm.so"]):
    try:
        lib = C.CDLL(_name)
        break
    except OSError:
        continue
if lib is None:
    raise SystemExit("libdrm tidak ditemukan")

DRM_MODE_NAME_LEN = 32


class drm_mode_modeinfo(C.Structure):
    _fields_ = [
        ("clock", C.c_uint32),
        ("hdisplay", C.c_uint16),
        ("hsync_start", C.c_uint16),
        ("hsync_end", C.c_uint16),
        ("htotal", C.c_uint16),
        ("hskew", C.c_uint16),
        ("vdisplay", C.c_uint16),
        ("vsync_start", C.c_uint16),
        ("vsync_end", C.c_uint16),
        ("vtotal", C.c_uint16),
        ("vscan", C.c_uint16),
        ("vrefresh", C.c_uint32),
        ("flags", C.c_uint32),
        ("type", C.c_uint32),
        ("name", C.c_char * DRM_MODE_NAME_LEN),
    ]


class drmModeRes(C.Structure):
    _fields_ = [
        ("count_fbs", C.c_int),
        ("fbs", C.POINTER(C.c_uint32)),
        ("count_crtcs", C.c_int),
        ("crtcs", C.POINTER(C.c_uint32)),
        ("count_connectors", C.c_int),
        ("connectors", C.POINTER(C.c_uint32)),
        ("count_encoders", C.c_int),
        ("encoders", C.POINTER(C.c_uint32)),
        ("min_width", C.c_uint32),
        ("max_width", C.c_uint32),
        ("min_height", C.c_uint32),
        ("max_height", C.c_uint32),
    ]


class drmModeConnector(C.Structure):
    _fields_ = [
        ("connector_id", C.c_uint32),
        ("encoder_id", C.c_uint32),
        ("connector_type", C.c_uint32),
        ("connector_type_id", C.c_uint32),
        ("connection", C.c_int),
        ("mmWidth", C.c_uint32),
        ("mmHeight", C.c_uint32),
        ("subpixel", C.c_int),
        ("count_modes", C.c_int),
        ("modes", C.POINTER(drm_mode_modeinfo)),
        ("count_props", C.c_int),
        ("props", C.POINTER(C.c_uint32)),
        ("prop_values", C.POINTER(C.c_uint64)),
        ("count_encoders", C.c_int),
        ("encoders", C.POINTER(C.c_uint32)),
    ]


class drmModeEncoder(C.Structure):
    _fields_ = [
        ("encoder_id", C.c_uint32),
        ("encoder_type", C.c_uint32),
        ("crtc_id", C.c_uint32),
        ("possible_crtcs", C.c_uint32),
        ("possible_clones", C.c_uint32),
    ]


class drmModeCrtc(C.Structure):
    _fields_ = [
        ("crtc_id", C.c_uint32),
        ("buffer_id", C.c_uint32),
        ("x", C.c_uint32),
        ("y", C.c_uint32),
        ("width", C.c_uint32),
        ("height", C.c_uint32),
        ("mode_valid", C.c_int),
        ("mode", drm_mode_modeinfo),
        ("gamma_size", C.c_int),
    ]


lib.drmModeGetResources.argtypes = [C.c_int]
lib.drmModeGetResources.restype = C.POINTER(drmModeRes)
lib.drmModeGetConnector.argtypes = [C.c_int, C.c_uint32]
lib.drmModeGetConnector.restype = C.POINTER(drmModeConnector)
lib.drmModeGetEncoder.argtypes = [C.c_int, C.c_uint32]
lib.drmModeGetEncoder.restype = C.POINTER(drmModeEncoder)
lib.drmModeGetCrtc.argtypes = [C.c_int, C.c_uint32]
lib.drmModeGetCrtc.restype = C.POINTER(drmModeCrtc)
for _f in ("drmModeFreeResources", "drmModeFreeConnector", "drmModeFreeEncoder", "drmModeFreeCrtc"):
    getattr(lib, _f).argtypes = [C.c_void_p]


def mode_str(mode):
    return f"{mode.hdisplay}x{mode.vdisplay} @ {mode.vrefresh}Hz"


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "/dev/dri/card0"
    fd = os.open(path, os.O_RDWR)
    res = lib.drmModeGetResources(fd)
    if not res:
        print("drmModeGetResources gagal (perlu akses ke /dev/dri/card0?)")
        return 1

    r = res.contents
    print(f"connectors={r.count_connectors} crtcs={r.count_crtcs} encoders={r.count_encoders}")
    for i in range(r.count_connectors):
        conn = lib.drmModeGetConnector(fd, r.connectors[i])
        if not conn:
            continue
        c = conn.contents
        print(f"\nconnector {c.connector_id}: encoder_id={c.encoder_id} connected={c.connection}")
        print(f"  modes ({c.count_modes}):")
        for j in range(c.count_modes):
            m = c.modes[j]
            print(f"    - {mode_str(m)}  name={m.name.decode(errors='replace')}")

        if c.encoder_id:
            enc = lib.drmModeGetEncoder(fd, c.encoder_id)
            if enc and enc.contents.crtc_id:
                crtc = lib.drmModeGetCrtc(fd, enc.contents.crtc_id)
                if crtc:
                    cr = crtc.contents
                    if cr.mode_valid:
                        print(
                            f"  ACTIVE CRTC {cr.crtc_id}: {mode_str(cr.mode)}"
                            f"  name={cr.mode.name.decode(errors='replace')}"
                            f"  clock={cr.mode.clock}kHz"
                        )
                    else:
                        print(f"  CRTC {cr.crtc_id}: mode_valid=0")
                    lib.drmModeFreeCrtc(crtc)
                lib.drmModeFreeEncoder(enc)
        lib.drmModeFreeConnector(conn)

    lib.drmModeFreeResources(res)
    os.close(fd)
    return 0


if __name__ == "__main__":
    sys.exit(main())
