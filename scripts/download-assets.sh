#!/bin/bash
set -e

# Script to download Hytale server files using hytale-downloader
# Usage: download-assets [--pre-release]

DOWNLOAD_DIR="/server"
DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
PATCHLINE="release"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pre-release)
            PATCHLINE="pre-release"
            shift
            ;;
        --help)
            echo "Usage: download-assets [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --pre-release  Download from pre-release channel"
            echo "  --help         Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=========================================="
echo "  Hytale Downloader"
echo "=========================================="
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

echo "-> Downloading hytale-downloader..."
curl -sL "${DOWNLOADER_URL}" -o "${TEMP_DIR}/hytale-downloader.zip"

echo "-> Extracting..."
unzip -q "${TEMP_DIR}/hytale-downloader.zip" -d "${TEMP_DIR}"

# Find hytale-downloader binary (may be in a subdirectory)
DOWNLOADER_BIN=$(find "${TEMP_DIR}" -name "hytale-downloader" -type f | head -1)

if [[ -z "${DOWNLOADER_BIN}" ]]; then
    # Try with .exe extension for Windows or find any executable
    DOWNLOADER_BIN=$(find "${TEMP_DIR}" -name "hytale-downloader*" -type f | head -1)
fi

if [[ -z "${DOWNLOADER_BIN}" ]]; then
    echo "[ERROR] Cannot find hytale-downloader in archive"
    echo "Archive contents:"
    find "${TEMP_DIR}" -type f
    exit 1
fi

echo "-> Binary found: ${DOWNLOADER_BIN}"

# Make executable (Linux)
chmod +x "${DOWNLOADER_BIN}" 2>/dev/null || true

DOWNLOADER_DIR="$(dirname "${DOWNLOADER_BIN}")"

echo "-> Downloading server files (channel: ${PATCHLINE})..."
echo "   This may take several minutes..."
echo "   (Interactive authentication if first launch)"
echo ""

cd "${DOWNLOADER_DIR}"

if [[ "${PATCHLINE}" == "pre-release" ]]; then
    "${DOWNLOADER_BIN}" -patchline pre-release -download-path game.zip
else
    "${DOWNLOADER_BIN}" -download-path game.zip
fi

echo ""
echo "-> Extracting server files..."
unzip -q game.zip -d game_files

# Copy server files
echo "-> Installing files..."

if [[ -d "game_files/Server" ]]; then
    cp -r game_files/Server/* "${DOWNLOAD_DIR}/"
    echo "   [OK] Server files copied"
fi

if [[ -f "game_files/Assets.zip" ]]; then
    cp game_files/Assets.zip "${DOWNLOAD_DIR}/"
    echo "   [OK] Assets.zip copied"
fi

echo ""
echo "=========================================="
echo "  [OK] Download complete!"
echo "=========================================="
echo ""
echo "Files installed in: ${DOWNLOAD_DIR}"
ls -la "${DOWNLOAD_DIR}"
