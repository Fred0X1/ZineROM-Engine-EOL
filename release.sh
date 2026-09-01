#!/bin/bash

set -e

# Required env vars from GITHUB_ENV or Fallbacks:
ONE_UI_VER="${ONE_UI_VERSION:-7}"
TARGET_DEV="${TARGET_DEVICE:-Target}"
STOCK_DEV="${STOCK_DEVICE:-Stock}"

TAG_NAME="${TARGET_DEV}-$(date +%s)"

# تنسيق المسمى المطلوب
RELEASE_NAME="KryptonROM ${TARGET_DEV} OneUI ${ONE_UI_VER}${STOCK_DEV}"

# اسم الملف المضغوط
NEW_ZIP_NAME="KryptonROM_${TARGET_DEV}_OneUI_${ONE_UI_VER}_${STOCK_DEV}.zip"
NEW_ZIP_NAME=$(echo "$NEW_ZIP_NAME" | tr ' ' '_')

# التأكد من وجود ملف الـ ZIP
if [ -z "$ZIP_PATH" ] \vert{}\vert{} [ ! -f "$ZIP_PATH" ]; then
  echo "❌ Error: ZIP_PATH is not set or file does not exist ($ZIP_PATH)!"
  exit 1
fi

# إعادة تسمية الملف قبل الرفع
DIR_NAME=$(dirname "$ZIP_PATH")
NEW_ZIP_PATH="${DIR_NAME}/${NEW_ZIP_NAME}"
mv "$ZIP_PATH" "$NEW_ZIP_PATH"
ZIP_PATH="$NEW_ZIP_PATH"

echo "Uploading to GoFile..."
if [ -f "upload.sh" ]; then
  GOFILE_LINK=$(sudo bash upload.sh "$ZIP_PATH" | tail -n1 || echo "FAILED_UPLOAD")
else
  echo "⚠️ upload.sh not found!"
  GOFILE_LINK="FAILED_UPLOAD"
fi

echo "🌎 File uploaded status/link: $GOFILE_LINK"

# File info
FILE_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
MD5_SUM=$(md5sum "$ZIP_PATH" | awk '{print $1}')

# Release body
RELEASE_BODY="#### 🌎 Download:
$GOFILE_LINK

#### 📊 File Info:
• Size: $FILE_SIZE
• Build Time: ${BUILD_TIME:-N/A}
• MD5: $MD5_SUM

#### 📱 Rom Info:
• Ported For: $STOCK_DEV
• Ported From: $TARGET_DEV
• One UI Version: $ONE_UI_VER

#### ⚙️ Build Options:
• Filesystem: ${OUTPUT_FILESYSTEM:-N/A}
• Compressed IMG: ${COMPRESS_IMG_TO_XZ:-N/A}
• Used OneUI 8 Tethering APEX: ${USE_UI_8_TETHERING_APEX:-N/A}
"

# 🚀 طباعة كارت ملخص التحميل المباشر في صفحة GitHub Summary 🚀
if [ -n "$GITHUB_STEP_SUMMARY" ]; then
  echo "## 🚀 Exion Build Completed Successfully!" >> $GITHUB_STEP_SUMMARY
  echo "" >> $GITHUB_STEP_SUMMARY
  echo "### 🌎 [اضغط هنا لتحميل الروم من GoFile]($GOFILE_LINK)" >> $GITHUB_STEP_SUMMARY
  echo "" >> $GITHUB_STEP_SUMMARY
  echo "```text" >> $GITHUB_STEP_SUMMARY
  echo "$RELEASE_BODY" >> $GITHUB_STEP_SUMMARY
  echo "```" >> $GITHUB_STEP_SUMMARY
fi

# Convert to JSON-safe string
JSON_BODY=$(printf '%s' "$RELEASE_BODY" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')

# Create release
if [ -n "$GIT_TOKEN" ]; then
  echo "Creating GitHub release..."

  curl -s -X POST "https://api.github.com/repos/${GITHUB_REPOSITORY}/releases" \
    -H "Authorization: token $GIT_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
      \"tag_name\": \"$TAG_NAME\",
      \"name\": \"$RELEASE_NAME\",
      \"body\": $JSON_BODY,
      \"draft\": false,
      \"prerelease\": false
    }"
else
  echo "⚠️ GIT_TOKEN not found. Skipping GitHub release."
fi
