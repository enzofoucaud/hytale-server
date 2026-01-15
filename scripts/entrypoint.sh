#!/bin/bash
set -e

echo "=========================================="
echo "  Hytale Dedicated Server - Docker"
echo "  (Version Manager Edition)"
echo "=========================================="

# Configuration
SERVER_ROOT="/server"
VERSION_MANAGER="/usr/local/bin/version-manager"
AUTO_UPDATE="${AUTO_UPDATE:-true}"
PATCHLINE="${PATCHLINE:-release}"

# Export for version manager
export SERVER_ROOT PATCHLINE

# =============================================================================
# Legacy Detection
# =============================================================================

is_legacy_install() {
    # Legacy install has HytaleServer.jar directly in SERVER_ROOT (not in versions/)
    [[ -f "${SERVER_ROOT}/HytaleServer.jar" ]]
}

check_legacy_install() {
    if is_legacy_install; then
        echo ""
        echo "==========================================="
        echo "  LEGACY INSTALLATION DETECTED"
        echo "==========================================="
        echo ""
        echo "Your server is using the old (v1) flat structure."
        echo "This version uses a new versioned structure that allows"
        echo "automatic updates while preserving your data."
        echo ""
        echo "To migrate your existing data, run:"
        echo ""
        echo "  docker exec -it $(hostname) version-manager migrate"
        echo ""
        echo "Then restart this container."
        echo ""
        echo "Your data (config, universe, mods, etc.) will be preserved."
        echo "==========================================="
        echo ""
        echo "Waiting for migration... (container will stay running)"
        echo "Press Ctrl+C to stop."
        echo ""

        # Keep container alive waiting for user to run migrate
        while is_legacy_install; do
            sleep 5
        done

        echo ""
        echo "[OK] Migration detected! Restarting..."
        exec "$0" "$@"
    fi
}

# =============================================================================
# Version Management
# =============================================================================

run_version_check() {
    echo ""
    echo "-> Checking for server updates..."
    echo ""

    if [[ "${AUTO_UPDATE}" == "true" ]]; then
        if ! "${VERSION_MANAGER}" update; then
            echo "[WARN] Update check failed, continuing with current version if available"
        fi
    else
        "${VERSION_MANAGER}" check || true
    fi
}

# =============================================================================
# Detect Server Files
# =============================================================================

detect_server_files() {
    # Versioned structure via symlink
    if [[ -L "${SERVER_ROOT}/current" ]]; then
        local current_path
        current_path=$(readlink -f "${SERVER_ROOT}/current")

        if [[ -f "${current_path}/Server/HytaleServer.jar" ]]; then
            HYTALE_JAR="${current_path}/Server/HytaleServer.jar"
            HYTALE_AOT="${current_path}/Server/HytaleServer.aot"

            if [[ -f "${current_path}/Assets.zip" ]]; then
                ASSETS_PATH="${current_path}/Assets.zip"
            elif [[ -d "${current_path}/Assets" ]]; then
                ASSETS_PATH="${current_path}/Assets"
            fi

            WORKING_DIR="${current_path}"
            return 0
        fi
    fi

    return 1
}

# =============================================================================
# Main Startup Logic
# =============================================================================

# Step 0: Check for legacy installation (blocks until migrated)
check_legacy_install

# Step 1: Run version manager if available
if [[ -x "${VERSION_MANAGER}" ]]; then
    run_version_check
fi

# Step 2: Try to detect server files
if ! detect_server_files; then
    echo "[ERROR] No server files found!"
    echo ""
    echo "The version manager should have downloaded them automatically."
    echo "Check the logs above for errors."
    echo ""
    echo "Manual fix:"
    echo "  docker exec -it hytale-test version-manager update"
    echo ""
    exit 1
fi

# Step 3: Validate detected files
if [[ -z "${HYTALE_JAR}" ]] || [[ ! -f "${HYTALE_JAR}" ]]; then
    echo "[ERROR] HytaleServer.jar not found at: ${HYTALE_JAR}"
    exit 1
fi

if [[ -z "${ASSETS_PATH}" ]]; then
    echo "[ERROR] Assets not found"
    exit 1
fi

# Step 4: Build Java arguments
JAVA_ARGS="-Xmx${JAVA_HEAP_SIZE} -Xms${JAVA_HEAP_SIZE}"

if [[ "${USE_AOT_CACHE}" == "true" ]] && [[ -f "${HYTALE_AOT}" ]]; then
    echo "[OK] Using AOT cache for faster startup"
    JAVA_ARGS="${JAVA_ARGS} -XX:AOTCache=${HYTALE_AOT}"
fi

if [[ -n "${EXTRA_JAVA_ARGS}" ]]; then
    JAVA_ARGS="${JAVA_ARGS} ${EXTRA_JAVA_ARGS}"
fi

# Step 5: Build server arguments
SERVER_ARGS="--assets ${ASSETS_PATH} --bind 0.0.0.0:${SERVER_PORT}"

if [[ -n "${EXTRA_SERVER_ARGS}" ]]; then
    SERVER_ARGS="${SERVER_ARGS} ${EXTRA_SERVER_ARGS}"
fi

# Step 6: First launch detection
if [[ ! -f "${SERVER_ROOT}/shared/config.json" ]] || [[ "$(cat "${SERVER_ROOT}/shared/config.json")" == "{}" ]]; then
    echo ""
    echo "[!] FIRST LAUNCH DETECTED"
    echo "==========================================="
    echo "After startup, authenticate with:"
    echo "  /auth login"
    echo ""
    echo "Then visit the displayed URL to authorize."
    echo "==========================================="
    echo ""
fi

# Step 7: Display configuration
echo ""
echo "Configuration:"
echo "  - Version: $(cat "${SERVER_ROOT}/.version" 2>/dev/null || echo 'unknown')"
echo "  - Heap: ${JAVA_HEAP_SIZE}"
echo "  - Port: ${SERVER_PORT}/udp"
echo "  - Assets: ${ASSETS_PATH}"
echo "  - AOT Cache: ${USE_AOT_CACHE}"
echo "  - Working Dir: ${WORKING_DIR}"
echo ""
echo "Starting server..."
echo ""

# Step 8: Change to working directory and launch
cd "${WORKING_DIR}"
exec java ${JAVA_ARGS} -jar "${HYTALE_JAR}" ${SERVER_ARGS}
