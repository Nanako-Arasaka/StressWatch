#!/bin/zsh

set -uo pipefail

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export PATH="$DEVELOPER_DIR/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin"

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
PROJECT_PATH="$PROJECT_DIR/StressWatch.xcodeproj"
SCHEME="StressWatch"
XCODE_DEVICE_ID="${STRESSWATCH_XCODE_DEVICE_ID:-}"
CORE_DEVICE_ID="${STRESSWATCH_CORE_DEVICE_ID:-}"
DERIVED_DATA="$HOME/Library/Developer/Xcode/DerivedData/StressWatchAutoSign"
APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphoneos/StressWatch.app"
LOG_DIR="$HOME/Library/Logs/StressWatch"
LOCK_DIR="${TMPDIR:-/tmp}/com.stresswatch.refresh-signing.lock"
PROFILE_DIR="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
PROFILE_REFRESH_WINDOW="${STRESSWATCH_PROFILE_REFRESH_WINDOW_SECONDS:-172800}"

mkdir -p "$LOG_DIR"
exec >>"$LOG_DIR/refresh-signing.log" 2>&1

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

discover_device_ids() {
    if [[ -n "$XCODE_DEVICE_ID" && -n "$CORE_DEVICE_ID" ]]; then
        return 0
    fi

    local device_json
    device_json=$(mktemp)
    if ! xcrun devicectl list devices --json-output "$device_json" >/dev/null; then
        rm -f "$device_json"
        return 1
    fi

    CORE_DEVICE_ID="${CORE_DEVICE_ID:-$(plutil -extract result.devices.0.identifier raw "$device_json" 2>/dev/null || true)}"
    XCODE_DEVICE_ID="${XCODE_DEVICE_ID:-$(plutil -extract result.devices.0.hardwareProperties.udid raw "$device_json" 2>/dev/null || true)}"
    rm -f "$device_json"

    [[ -n "$XCODE_DEVICE_ID" && -n "$CORE_DEVICE_ID" ]]
}

archive_expiring_profiles() {
    [[ -d "$PROFILE_DIR" ]] || return 0

    local now_epoch expiration expiration_epoch profile_name backup_dir
    local archived_count=0
    now_epoch=$(date +%s)
    backup_dir="$LOG_DIR/profile-backups/$(date '+%Y%m%d-%H%M%S')"

    for profile in "$PROFILE_DIR"/*.mobileprovision(N); do
        profile_name=$(security cms -D -i "$profile" 2>/dev/null | plutil -extract Name raw - 2>/dev/null || true)
        [[ "$profile_name" == *"com.stresswatch.demo"* ]] || continue

        expiration=$(security cms -D -i "$profile" 2>/dev/null | plutil -extract ExpirationDate raw - 2>/dev/null || true)
        expiration_epoch=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$expiration" '+%s' 2>/dev/null || echo 0)
        if (( expiration_epoch == 0 || expiration_epoch - now_epoch > PROFILE_REFRESH_WINDOW )); then
            continue
        fi

        mkdir -p "$backup_dir"
        mv "$profile" "$backup_dir/"
        archived_count=$((archived_count + 1))
        echo "[$(timestamp)] Archived expiring profile: $profile_name"
    done

    return "$archived_count"
}

build_signed_app() {
    xcodebuild \
        -project "$PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration Debug \
        -destination "id=$XCODE_DEVICE_ID" \
        -derivedDataPath "$DERIVED_DATA" \
        -allowProvisioningUpdates \
        -allowProvisioningDeviceRegistration \
        clean build
}

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "[$(timestamp)] Another signing refresh is already running; skipping."
    exit 0
fi
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT

echo "[$(timestamp)] Starting StressWatch signing refresh."

if ! discover_device_ids; then
    echo "[$(timestamp)] No connected physical iPhone was found; will retry on the next schedule."
    exit 2
fi

if ! xcrun devicectl list devices | grep -Fq "$CORE_DEVICE_ID"; then
    echo "[$(timestamp)] iPhone $CORE_DEVICE_ID is not available; will retry on the next schedule."
    exit 2
fi

archive_expiring_profiles
archived_profiles=$?

if ! build_signed_app; then
    if (( archived_profiles > 0 )); then
        echo "[$(timestamp)] Retrying after Xcode refreshed its provisioning cache."
        sleep 3
        if ! build_signed_app; then
            echo "[$(timestamp)] Signed device build failed after retry."
            exit 3
        fi
    else
        echo "[$(timestamp)] Signed device build failed."
        exit 3
    fi
fi

if [[ ! -d "$APP_PATH" ]]; then
    echo "[$(timestamp)] Built app was not found at $APP_PATH."
    exit 4
fi

if ! xcrun devicectl device install app --device "$CORE_DEVICE_ID" "$APP_PATH"; then
    echo "[$(timestamp)] App installation failed."
    exit 5
fi

echo "[$(timestamp)] StressWatch was signed and installed successfully."
