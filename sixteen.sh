#!/bin/bash

# Verification of required arguments
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <STOCK_DEVICE> <TARGET_DEVICE> <TARGET_DEVICE_CSC> <OUTPUT_FILESYSTEM>"
    exit 1
fi

# Exporting core environment variables
export STOCK_DEVICE="$1"
export TARGET_DEVICE="$2"
export TARGET_DEVICE_CSC="$3"
export OUTPUT_FILESYSTEM="$4"

export USE_UI_8_TETHERING_APEX="false"
export TARGET_DEVICE_IMEI="000000000000000"

VERSION="1"

# Directory configuration
export FIRM_DIR="$(pwd)/FW"
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export APKTOOL="$(pwd)/bin/java/apktool.jar"
export DEVICES_DIR="$(pwd)/ZineROM/Devices"
export VNDKS_COLLECTION="$(pwd)/ZineROM/vndks"
export SMART_MANAGER_CN="$(pwd)/ZineROM/Mods/SMART_MANAGER_CN"

export BUILD_PARTITIONS="product,system_ext,system"

# Automated patch to bypass the CPU ABI Mismatch restriction inside ZineRom.sh
if [ -f "$(pwd)/scripts/ZineRom.sh" ]; then
    sed -i '/CPU ABI MISMATCH!/{n;s/exit 1/# exit 1/}' "$(pwd)/scripts/ZineRom.sh"
fi

# Sourcing framework scripts
source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/ZineRom.sh"

# Firmware deconstruction phase
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE"
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all"

DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE"
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE"

APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"
ADD_SAMSUNG_FLAGSHIP_APPS "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"

INSTALL_FRAMEWORK "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"

# Decompilation phase
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/samsungkeystoreutils.jar" "$WORK_DIR"

# Patching phase
PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"
PATCH_PRIVATE_SHARE "$WORK_DIR/samsungkeystoreutils"

# Recompilation phase
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/ssrm" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/services" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/samsungkeystoreutils" "$WORK_DIR"
mv -f "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"

PATCH_BT_LIB "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"

# Base properties injection
B_ID="$(grep -m1 '^ro.system.build.id=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
B_V="$(grep -m1 '^ro.system.build.version.incremental=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "${B_ID} ${B_V} V-${VERSION}: ZineROM"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "${B_ID} ${B_V} V-${VERSION}: ZineROM"

# Final image generation
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
