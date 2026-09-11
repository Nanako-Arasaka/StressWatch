#!/bin/bash
# 打出可交给 Sideloadly 安装的 IPA
#
# 模式 A（默认，推荐给 Sideloadly）：无签名 IPA
#   ./build_ipa.sh
#   不需要 Team ID / 付费账号。产物 build/StressWatch.ipa 交给 Sideloadly 重签安装。
#
# 模式 B：Xcode 自动签名导出（需要 Apple ID Team）
#   ./build_ipa.sh <DEVELOPMENT_TEAM_ID> [BUNDLE_ID]
#
# 注意：Sideloadly 只安装，不编译。本脚本用 xcodebuild CLI 完成编译打包。

set -euo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

PROJECT="StressWatch.xcodeproj"
SCHEME="StressWatch"
OUT_DIR="build"
PAYLOAD_DIR="$OUT_DIR/Payload"
ARCHIVE_PATH="$OUT_DIR/StressWatch.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/StressWatch.app"

echo "==> 清理旧产物"
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  # ---- 模式 B：签名导出 ----
  TEAM_ID="$1"
  BUNDLE_ID="${2:-com.yourname.StressWatch}"

  echo "==> archive（Team=$TEAM_ID, Bundle=$BUNDLE_ID）"
  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    -allowProvisioningUpdates \
    -allowProvisioningDeviceRegistration

  echo "==> 导出 IPA"
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$OUT_DIR" \
    -exportOptionsPlist ExportOptions.plist \
    DEVELOPMENT_TEAM="$TEAM_ID"
else
  # ---- 模式 A：无签名 IPA，给 Sideloadly ----
  echo "==> archive（无签名，Release / generic iOS）"
  xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM=""

  echo "==> 打包 Payload"
  mkdir -p "$PAYLOAD_DIR"
  # 去掉内嵌的签名，交给 Sideloadly 重签
  rm -rf "$APP_PATH/_CodeSignature"
  find "$APP_PATH" -name '_CodeSignature' -type d -exec rm -rf {} + 2>/dev/null || true
  find "$APP_PATH" -name 'embedded.mobileprovision' -delete 2>/dev/null || true
  cp -R "$APP_PATH" "$PAYLOAD_DIR/"

  echo "==> zip → IPA"
  (
    cd "$OUT_DIR"
    # 标准 IPA 结构：Payload/StressWatch.app
    rm -f StressWatch.ipa
    zip -qry StressWatch.ipa Payload
  )
fi

IPA="$OUT_DIR/StressWatch.ipa"
if [[ -f "$IPA" ]]; then
  echo "✅ 完成：$IPA"
  echo "   大小：$(du -h "$IPA" | awk '{print $1}')"
  echo "   下一步：打开 Sideloadly → 拖入 .ipa → 选设备 → 填 Apple ID → Start"
  echo "   Sideloadly 里建议勾选：Use automatically selected signing certificate"
  echo "   若 Widget/健康数据异常：Sideloadly → Advanced → 启用 HealthKit / App Groups"
else
  echo "❌ 未生成 IPA，请检查上面的 xcodebuild 报错"
  exit 1
fi
