from tools.build import mkcpmfs
from build.llvm import llvmrawprogram, llvmclibrary, llvmcfile
from config import (
    MINIMAL_APPS,
    MINIMAL_APPS_SRCS,
    CPM_FILESYSTEM_APP_NAMES,
    BIG_APPS,
    BIG_APPS_SRCS,
    SCREEN_APPS,
    SCREEN_APPS_SRCS,
    BIG_SCREEN_APPS,
    PASCAL_APPS,
    FORTH_APPS,
    Z65_APPS,
    SERIAL_APPS,
    SERIAL_SCREEN_APPS,
)
import re

llvmclibrary(
    name="cfcard",
    srcs=[
        "./blkdev_cfcard.S",
        "./blkdev_layer.S",
        "./cp256.inc"
    ],
    deps=["include"],
)

llvmclibrary(
    name="cfcard_32k",
    srcs=[
        "./blkdev_cfcard.S",
        "./blkdev_layer.S",
        "./cp256.inc"
    ],
    deps=["include"],
    cflags=["-DSMALL"],

)


llvmrawprogram(
    name="cp256_bios",
    srcs=[
        "./cp256.S","./cp256.inc","./screen.S", "./matrix_kbd.S", "./timer-simple.S","./i2c.S"
    ],
    deps=["include", "src/lib+bioslib", ".+cfcard"],
    cflags=["-DPET8096 -DPETKBD"],
#    cflags=["-DPET8096 -DC64KBD"],
    ldflags=["--no-check-sections"],
    linkscript="./cp256.ld",
)

llvmrawprogram(
    name="cp256_bios_32k",
    srcs=[
        "./cp256.S","./cp256.inc", "./screen.S", "./matrix_kbd.S", "./timer-simple.S","./i2c.S"
    ],
    deps=["include", "src/lib+bioslib", ".+cfcard_32k"],
    cflags=["-DSMALL -DPET8096 -DC64KBD"],
#    cflags=["-DSMALL -DPET8096 -DPETKBD"],
    ldflags=["--no-check-sections"],
    linkscript="./cp256-32k.ld",
)

llvmrawprogram(
    name="cp256_bios_ovl",
    srcs=[
        "./cp256.S","./cp256.inc","./timer-simple.S","./i2c.S"
    ],
    deps=["include", "src/lib+bioslib", ".+cfcard_32k"],
    cflags=["-DSMALL -DPET8096 -DC64KBD"],
    ldflags=["--no-check-sections"],
    linkscript="./cp256-ovl.ld",
)



mkcpmfs(
    name="rawdiskimage-sdcard",
    format="sdcard",
    bootimage=".+cp256_bios_32k",
    size=512 * 4096 * 16,
    items={
        "0:ccp.sys@sr": "src+ccp",
        "0:bdos.sys@sr": "src/bdos",
        "0:scrvt100.com": "apps+scrvt100",
        "0:pasc.pas": "third_party/pascal-m+pasc_pas_cpm",
        "0:keyscan.com": "src/arch/cp256/utils+keyscan",
        "0:i2cscan.com": "src/arch/cp256/utils+i2c_scan",
        "0:date.com": "src/arch/cp256/utils+ds3231_date",
        "0:mbrotc.com": "src/arch/cp256/utils+mbrot-col",
        "0:meminf.com": "src/arch/cp256/utils+meminfo",

    }
    | MINIMAL_APPS
    | MINIMAL_APPS_SRCS
    | BIG_APPS
    | BIG_APPS_SRCS
    | SCREEN_APPS
    | BIG_SCREEN_APPS
    | PASCAL_APPS
    | FORTH_APPS
    | SERIAL_APPS
    | SERIAL_SCREEN_APPS
    | Z65_APPS,
)


