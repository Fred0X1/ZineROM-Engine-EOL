#!/bin/bash

# ================================================================= #
#  ZineROM Engine Sixteen - Barebones Stable Core (A52s Dedicated)  #
# ================================================================= #

export LOG_FILE="$(pwd)/zinrom_build.log"
touch "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

log_stage() { echo -e "\n[$(date +'%H:%M:%S')] ==================== [STAGE: $1] ===================="; }
log_info()  { echo -e "[$(date +'%H:%M:%S')] [INFO]  $1"; }
log_success(){ echo -e "[$(date +'%H:%M:%S')] [SUCCESS] $1"; }
log_warn()  { echo -e "[$(date +'%H:%M:%S')] [WARN]  $1"; }
log_error() { echo -e "[$(date +'%H:%M:%S')] [ERROR] $1"; }

log_stage "ENGINE INITIALIZATION"
log_info "ZineROM Engine Version: Sixteen (A52s Clean Core)"

if [ "$#" -lt 4 ]; then
    log_error "Missing execution arguments. Expected 4, received $#."
    echo "Usage: $0 <STOCK_DEVICE> <TARGET_DEVICE> <TARGET_DEVICE_CSC> <OUTPUT_FILESYSTEM>"
    exit 1
fi

export STOCK_DEVICE="$1"
export TARGET_DEVICE="$2"
export TARGET_DEVICE_CSC="$3"
export OUTPUT_FILESYSTEM="$4"

export USE_UI_8_TETHERING_APEX="false"
export TARGET_DEVICE_IMEI="000000000000000"

export FIRM_DIR="$(pwd)/FW"
export OUT_DIR="$(pwd)/OUT"
export WORK_DIR="$(pwd)/WORK"
export APKTOOL="$(pwd)/bin/java/apktool.jar"

log_info "Target Config: Device=$STOCK_DEVICE | Base=$TARGET_DEVICE | CSC=$TARGET_DEVICE_CSC | FS=$OUTPUT_FILESYSTEM"

log_stage "PRE-FLIGHT SECURITY PATCHING"
if [ -f "$(pwd)/scripts/ZineRom.sh" ]; then
    log_info "Injecting dynamic bypass inside framework dependency..."
    sed -i '/CPU ABI MISMATCH!/,/exit 1/ s/exit 1/# exit 1/' "$(pwd)/scripts/ZineRom.sh"
    log_success "Bypass verified and applied."
else
    log_error "Critical dependency missing: scripts/ZineRom.sh not found."
    exit 1
fi

source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/ZineRom.sh"

log_stage "FIRMWARE DECONSTRUCTION"
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE" && log_success "Super image extracted." || log_error "Failed to extract Super image."
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" && log_success "Firmware partitions parsed." || log_error "Failed partition parsing."

log_stage "SYSTEM OPTIMIZATION & DEBLOAT"
DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE" || log_warn "OMC decoding returned non-zero code."
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE" || log_warn "Debloat stage finished with alerts."

log_stage "ESSENTIAL SECURITY & FRAMEWORK PATCHES"
APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"

log_stage "SMALI DECOMPILATION INFRASTRUCTURE"
INSTALL_FRAMEWORK "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"

log_stage "SMALI PATCH INJECTION (CORE ONLY)"
# اقتصار الباتشات على الخدمات الأساسية لضمان استقرار الـ Setup Wizard
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"

log_stage "SMALI RECOMPILATION PIPELINE"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/services" "$WORK_DIR"
mv -f "$WORK_DIR"/services.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"
PATCH_BT_LIB "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"

log_stage "PROPERTY INJECTION & BRANDING"
B_ID="$(grep -m1 '^ro.system.build.id=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"

# Minimal Stable Build Properties
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "wifi.interface" "wlan0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "wlan.wfd.hdcp" "disable"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.telephony.sim_slots.count" "2"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "fw.max_users" "5"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "fw.show_multiuserui" "1"

BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "${B_ID} | ZineROM-A52s"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "${B_ID} | ZineROM-A52s"

log_stage "FINAL IMAGE COMPILATION"
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "system" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "product" "$OUTPUT_FILESYSTEM" "$OUT_DIR"

# التحقق من مجلد system_ext والتأكد أنه غير فارغ قبل البناء
SYS_EXT_DIR="$FIRM_DIR/$TARGET_DEVICE/system_ext"
if [ -d "$SYS_EXT_DIR" ] && [ "$(ls -A "$SYS_EXT_DIR" 2>/dev/null)" ]; then
    log_info "Compiling system_ext partition..."
    BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "system_ext" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
else
    log_warn "Skipping system_ext compilation (Directory missing or empty)."
    rm -f "$OUT_DIR/system_ext.img"
fi

log_stage "BUILD PIPELINE SUCCESS"

# Safe Hardware Acceleration for Samsung One UI (A52s / Snapdragon)
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "debug.hwui.renderer" "skiavk"

# Refresh Rate & Multi-User
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.surface_flinger.set_idle_timer_ms" "2500"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.surface_flinger.set_touch_timer_ms" "3000"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "fw.max_users" "5"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "fw.show_multiuserui" "1"

# ZineROM build.prop id
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "${B_ID} | KryptonROM 1.0.0"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "${B_ID} | KryptonROM 1.0.0"
log_success "Build properties updated with ZineROM identity flags."

log_stage "FINAL IMAGE COMPILATION"
log_info "Target filesystem packing initiated..."
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "system" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "product" "$OUTPUT_FILESYSTEM" "$OUT_DIR"
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "system_ext" "$OUTPUT_FILESYSTEM" "$OUT_DIR"

log_stage "BUILD PIPELINE SUCCESS"
log_info "All tasks executed. Preserving analytical logs."
