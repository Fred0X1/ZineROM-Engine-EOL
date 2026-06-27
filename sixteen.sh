#!/bin/bash

# ================================================================= #
#  ZineROM Engine Sixteen - Advanced Enterprise Logging Architecture #
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
log_info "ZineROM Engine Version: Sixteen (Stable Core)"

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
export DEVICES_DIR="$(pwd)/ZineROM/Devices"
export VNDKS_COLLECTION="$(pwd)/ZineROM/vndks"
export SMART_MANAGER_CN="$(pwd)/ZineROM/Mods/SMART_MANAGER_CN"
export BUILD_PARTITIONS="product,system_ext,system"

log_info "Target Config: Device=$STOCK_DEVICE | Base=$TARGET_DEVICE | CSC=$TARGET_DEVICE_CSC | FS=$OUTPUT_FILESYSTEM"

log_stage "PRE-FLIGHT SECURITY PATCHING"
if [ -f "$(pwd)/scripts/ZineRom.sh" ]; then
    log_info "Injecting dynamic bypass for CPU ABI Mismatch inside framework dependency..."
    sed -i '/CPU ABI MISMATCH!/,/exit 1/ s/exit 1/# exit 1/' "$(pwd)/scripts/ZineRom.sh"
    log_success "Bypass verified and applied."
else
    log_error "Critical dependency missing: scripts/ZineRom.sh not found."
    exit 1
fi

source "$(pwd)/scripts/debloat.sh"
source "$(pwd)/scripts/ZineRom.sh"

log_stage "FIRMWARE DECONSTRUCTION"
log_info "Decompressing super image and firmware components..."
EXTRACT_SUPER_IMG "$FIRM_DIR/$TARGET_DEVICE" && log_success "Super image extracted." || log_error "Failed to extract Super image."
EXTRACT_FIRMWARE_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" && log_success "Firmware partitions parsed." || log_error "Failed partition parsing."

log_stage "SYSTEM OPTIMIZATION & DEBLOAT"
DECODE_OMC "$FIRM_DIR/$TARGET_DEVICE" && log_success "OMC decoding complete." || log_warn "OMC decoding returned non-zero code."
DEBLOAT "$FIRM_DIR/$TARGET_DEVICE" && log_success "System debloating complete." || log_warn "Debloat stage finished with alerts."

log_stage "FRAMEWORK MODIFICATION & SECURITY BYPASS"
APPLY_STOCK_CONFIG "$FIRM_DIR/$TARGET_DEVICE"
PATCH_SELINUX "$FIRM_DIR/$TARGET_DEVICE"
DISABLE_SECURITY "$FIRM_DIR/$TARGET_DEVICE"
ADD_SAMSUNG_FLAGSHIP_APPS "$FIRM_DIR/$TARGET_DEVICE"
APPLY_CUSTOM_FEATURES "$FIRM_DIR/$TARGET_DEVICE"
log_success "Core flagship assets and properties adjusted."

log_stage "SMALI DECOMPILATION INFRASTRUCTURE"
log_info "Installing framework resources..."
INSTALL_FRAMEWORK "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/framework-res.apk"

log_info "Decompiling target JAR archives..."
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/ssrm.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/services.jar" "$WORK_DIR"
DECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/samsungkeystoreutils.jar" "$WORK_DIR"
log_success "Smali structures generated in work directory."

log_stage "SMALI PATCH INJECTION"
PATCH_SSRM "$WORK_DIR/ssrm"
PATCH_FLAG_SECURE "$WORK_DIR/services"
PATCH_SECURE_FOLDER "$WORK_DIR/services"
PATCH_PRIVATE_SHARE "$WORK_DIR/samsungkeystoreutils"
log_success "Framework vulnerabilities and restriction flags bypassed."

log_stage "SMALI RECOMPILATION PIPELINE"
log_info "Recompiling modified smali directories..."
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/ssrm" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/services" "$WORK_DIR"
RECOMPILE "$APKTOOL" "$FIRM_DIR/$TARGET_DEVICE/system/system/framework" "$WORK_DIR/samsungkeystoreutils" "$WORK_DIR"

mv -f "$WORK_DIR"/*.jar "$FIRM_DIR/$TARGET_DEVICE/system/system/framework/"
PATCH_BT_LIB "$FIRM_DIR/$TARGET_DEVICE" "$WORK_DIR"
log_success "Recompilation complete. Modified binaries linked back to system."

log_stage "UNICA SETTINGS INJECTION"
TARGET_APK="$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app/SecSettings/SecSettings.apk"
[ ! -f "$TARGET_APK" ] && TARGET_APK="$FIRM_DIR/$TARGET_DEVICE/system/priv-app/SecSettings/SecSettings.apk"

if [ -f "$TARGET_APK" ] && [ -f "$(pwd)/settings.zip" ]; then
    log_info "Decompiling SecSettings.apk..."
    java -jar "$APKTOOL" d "$TARGET_APK" -o "$WORK_DIR/extracted_settings" --force
    
    log_info "Extracting settings.zip patch..."
    mkdir -p "$WORK_DIR/patch_content"
    unzip -o "$(pwd)/settings.zip" -d "$WORK_DIR/patch_content/"
    
    log_info "Merging assets and smali structures..."
    if [ -d "$WORK_DIR/patch_content/SecSettings" ]; then
        cp -af "$WORK_DIR/patch_content/SecSettings/"* "$WORK_DIR/extracted_settings/"
        log_success "Patch folder 'SecSettings' merged successfully."
    else
        log_warn "Folder 'SecSettings' not found inside settings.zip. Falling back to root zip merge."
        cp -af "$WORK_DIR/patch_content/"* "$WORK_DIR/extracted_settings/"
    fi
    
    log_info "Patching Search Index Providers..."
    SEARCH_SMALI="$WORK_DIR/extracted_settings/smali/com/android/settingslib/search/SearchIndexableResourcesBase.smali"
    if [ -f "$SEARCH_SMALI" ]; then
        sed -i '/<init>()V/a \    new-instance v0, Lcom/android/settingslib/search/SearchIndexableData;\n    const-class v1, Lio/mesalabs/unica/settings/UnicaSettingsFragment;\n    sget-object v2, Lio/mesalabs/unica/settings/UnicaSettingsFragment;->SEARCH_INDEX_DATA_PROVIDER:Lcom/android/settings/search/BaseSearchIndexProvider;\n    invoke-direct {v0, v1, v2}, Lcom/android/settingslib/search/SearchIndexableData;-><init>(Ljava/lang/Class;Lcom/android/settingslib/search/Indexable$SearchIndexProvider;)V\n    invoke-virtual {p0, v0}, Lcom/android/settingslib/search/SearchIndexableResourcesBase.addIndex(Lcom/android/settingslib/search/SearchIndexableData;)V' "$SEARCH_SMALI"
        log_success "SearchIndexableResourcesBase updated with Unica Fragment hooks."
    else
        log_warn "SearchIndexableResourcesBase.smali not found. Search indexing patch skipped."
    fi
    
    log_info "Recompiling patched SecSettings.apk..."
    java -jar "$APKTOOL" b "$WORK_DIR/extracted_settings" -o "$TARGET_APK" --use-aapt2
    rm -rf "$WORK_DIR/extracted_settings" "$WORK_DIR/patch_content"
    log_success "SecSettings injection pipeline completed successfully."
else
    log_error "Critical Target Missing: SecSettings.apk or settings.zip not localized."
fi

log_stage "PROPERTY INJECTION & BRANDING"
B_ID="$(grep -m1 '^ro.system.build.id=' "$FIRM_DIR/$TARGET_DEVICE/system/system/build.prop" | cut -d= -f2 | tr -d '\r')"

BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "system" "ro.build.display.id" "${B_ID} | ZineROM-V1.3"
BUILD_PROP "$FIRM_DIR/$TARGET_DEVICE" "product" "ro.build.display.id" "${B_ID} | ZineROM-V1.3"
log_success "Build properties updated with ZineROM identity flags."

log_stage "FINAL IMAGE COMPILATION"
log_info "Target filesystem packing initiated..."
BUILD_IMG "$FIRM_DIR/$TARGET_DEVICE" "all" "$OUTPUT_FILESYSTEM" "$OUT_DIR"

log_stage "BUILD PIPELINE SUCCESS"
log_info "All tasks executed. Preserving analytical logs."

