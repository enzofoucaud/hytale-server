#!/bin/bash
set -e

echo "=========================================="
echo "  Hytale Dedicated Server - Docker"
echo "=========================================="

# Function to automatically download assets
auto_download_assets() {
    echo ""
    echo "-> AUTO_DOWNLOAD enabled, downloading server files..."
    echo ""

    DOWNLOAD_ARGS=""
    if [[ "${USE_PRE_RELEASE}" == "true" ]]; then
        DOWNLOAD_ARGS="--pre-release"
    fi

    # Execute download script
    /usr/local/bin/download-assets ${DOWNLOAD_ARGS}
}

# Function to wait for server files
wait_for_assets() {
    echo ""
    echo ":: WAIT_FOR_ASSETS enabled - Waiting for server files..."
    echo "==========================================================="
    echo "The container is staying active. You can now:"
    echo ""
    echo "1. Download assets manually:"
    echo "   docker exec -it <container> download-assets"
    echo ""
    echo "2. Copy files into the container:"
    echo "   docker cp /path/to/HytaleServer.jar <container>:/server/"
    echo "   docker cp /path/to/Assets.zip <container>:/server/"
    echo ""
    echo "The server will start automatically once files are detected."
    echo "==========================================================="
    echo ""

    # Wait loop
    while true; do
        if [[ -f "/server/HytaleServer.jar" ]]; then
            if [[ -f "/server/Assets.zip" ]] || [[ -d "/server/Assets" ]]; then
                echo ""
                echo "[OK] Server files detected! Starting..."
                echo ""
                return 0
            fi
        fi
        sleep 5
    done
}

# Check if server files are present
NEED_DOWNLOAD=false

if [[ ! -f "/server/HytaleServer.jar" ]]; then
    NEED_DOWNLOAD=true
fi

if [[ ! -f "/server/Assets.zip" ]] && [[ ! -d "/server/Assets" ]]; then
    NEED_DOWNLOAD=true
fi

# If files are missing, handle according to configuration
if [[ "${NEED_DOWNLOAD}" == "true" ]]; then
    if [[ "${AUTO_DOWNLOAD}" == "true" ]]; then
        auto_download_assets
    elif [[ "${WAIT_FOR_ASSETS}" == "true" ]]; then
        wait_for_assets
    else
        # Display classic error
        if [[ ! -f "/server/HytaleServer.jar" ]]; then
            echo "[ERROR] HytaleServer.jar not found!"
            echo ""
            echo "Options to get server files:"
            echo "1. Mount files from your Hytale installation:"
            echo "   -v /path/to/hytale/Server:/server/game:ro"
            echo ""
            echo "2. Enable automatic download:"
            echo "   AUTO_DOWNLOAD=true"
            echo ""
            echo "3. Keep container running for manual download:"
            echo "   WAIT_FOR_ASSETS=true"
            echo ""
            exit 1
        fi

        if [[ ! -f "/server/Assets.zip" ]] && [[ ! -d "/server/Assets" ]]; then
            echo "[ERROR] Assets.zip or Assets folder not found!"
            echo "Mount Assets.zip or enable AUTO_DOWNLOAD=true"
            exit 1
        fi
    fi
fi

# Re-check after potential download
if [[ ! -f "/server/HytaleServer.jar" ]]; then
    echo "[ERROR] HytaleServer.jar still not found after download!"
    exit 1
fi

if [[ ! -f "/server/Assets.zip" ]] && [[ ! -d "/server/Assets" ]]; then
    echo "[ERROR] Assets still not found after download!"
    exit 1
fi

# Determine assets path
ASSETS_PATH="/server/Assets.zip"
if [[ -d "/server/Assets" ]]; then
    ASSETS_PATH="/server/Assets"
fi

# Build Java arguments
JAVA_ARGS="-Xmx${JAVA_HEAP_SIZE} -Xms${JAVA_HEAP_SIZE}"

# Add AOT cache if enabled and present
if [[ "${USE_AOT_CACHE}" == "true" ]] && [[ -f "/server/HytaleServer.aot" ]]; then
    echo "[OK] Using AOT cache for faster startup"
    JAVA_ARGS="${JAVA_ARGS} -XX:AOTCache=/server/HytaleServer.aot"
fi

# Add extra Java arguments
if [[ -n "${EXTRA_JAVA_ARGS}" ]]; then
    JAVA_ARGS="${JAVA_ARGS} ${EXTRA_JAVA_ARGS}"
fi

# Build server arguments
SERVER_ARGS="--assets ${ASSETS_PATH} --bind 0.0.0.0:${SERVER_PORT}"

# Add extra server arguments
if [[ -n "${EXTRA_SERVER_ARGS}" ]]; then
    SERVER_ARGS="${SERVER_ARGS} ${EXTRA_SERVER_ARGS}"
fi

# Check if this is first launch (not yet authenticated)
if [[ ! -f "/server/.auth_token" ]] && [[ ! -f "/server/config.json" ]]; then
    echo ""
    echo "[!] FIRST LAUNCH DETECTED"
    echo "==========================================="
    echo "After startup, authenticate with:"
    echo "  /auth login"
    echo ""
    echo "Then visit the displayed URL to authorize the server."
    echo "==========================================="
    echo ""
fi

echo "Configuration:"
echo "  - Heap: ${JAVA_HEAP_SIZE}"
echo "  - Port: ${SERVER_PORT}/udp"
echo "  - Assets: ${ASSETS_PATH}"
echo "  - AOT Cache: ${USE_AOT_CACHE}"
echo ""
echo "Starting server..."
echo ""

# Launch the server
exec java ${JAVA_ARGS} -jar /server/HytaleServer.jar ${SERVER_ARGS}
