#!/bin/bash
set -e

# =============================================================================
# Hytale Server Version Manager
# =============================================================================
# Manages server versions, automatic updates, and data migration
#
# Usage:
#   version-manager [COMMAND] [OPTIONS]
#
# Commands:
#   check       Check for available updates
#   update      Download and install new version if available
#   rollback    Rollback to a previous version
#   list        List all installed versions
#   current     Show current active version
#   cleanup     Remove old versions (keep N most recent)
# =============================================================================

# Configuration
SERVER_ROOT="${SERVER_ROOT:-/server}"
VERSIONS_DIR="${SERVER_ROOT}/versions"
SHARED_DIR="${SERVER_ROOT}/shared"
DOWNLOADS_DIR="${SERVER_ROOT}/downloads"
CURRENT_LINK="${SERVER_ROOT}/current"
VERSION_FILE="${SERVER_ROOT}/.version"
DOWNLOADER="${SERVER_ROOT}/hytale-downloader"
CREDENTIALS="${SERVER_ROOT}/.hytale-downloader-credentials.json"
PATCHLINE="${PATCHLINE:-release}"

# Data to share between versions (symlinked from version dir to shared/)
PERSISTENT_DATA=(
    ".cache"
    "logs"
    "mods"
    "universe"
    "bans.json"
    "config.json"
    "permissions.json"
    "whitelist.json"
)

# Logging functions
log_info() { echo "[INFO] $*"; }
log_warn() { echo "[WARN] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
log_success() { echo "[OK] $*"; }

# =============================================================================
# Helper Functions
# =============================================================================

ensure_directories() {
    mkdir -p "${VERSIONS_DIR}" "${SHARED_DIR}" "${DOWNLOADS_DIR}"

    # Create shared directories
    mkdir -p "${SHARED_DIR}/.cache"
    mkdir -p "${SHARED_DIR}/logs"
    mkdir -p "${SHARED_DIR}/mods"
    mkdir -p "${SHARED_DIR}/universe"

    # Create empty JSON files if they don't exist
    for json_file in bans.json permissions.json whitelist.json; do
        if [[ ! -f "${SHARED_DIR}/${json_file}" ]]; then
            echo "{}" > "${SHARED_DIR}/${json_file}"
        fi
    done
}

get_installed_server_version() {
    if [[ -f "${VERSION_FILE}" ]]; then
        cat "${VERSION_FILE}"
    elif [[ -L "${CURRENT_LINK}" ]]; then
        basename "$(readlink -f "${CURRENT_LINK}")"
    else
        echo ""
    fi
}

get_latest_server_version() {
    local patchline_arg=""
    if [[ "${PATCHLINE}" != "release" ]]; then
        patchline_arg="-patchline ${PATCHLINE}"
    fi

    local cred_arg=""
    if [[ -f "${CREDENTIALS}" ]]; then
        cred_arg="-credentials-path ${CREDENTIALS}"
    fi

    cd "$(dirname "${DOWNLOADER}")"
    "${DOWNLOADER}" -print-version ${patchline_arg} ${cred_arg} -skip-update-check 2>/dev/null | tr -d '\n\r'
}

is_server_version_installed() {
    local version="$1"
    [[ -d "${VERSIONS_DIR}/${version}" ]] && [[ -f "${VERSIONS_DIR}/${version}/Server/HytaleServer.jar" ]]
}

# =============================================================================
# Downloader Management
# =============================================================================

DOWNLOADER_UPDATED=""

update_downloader_if_needed() {
    if [[ ! -x "${DOWNLOADER}" ]]; then
        log_info "Downloader not found, downloading..."
        install_downloader
        DOWNLOADER_UPDATED="installed"
        return
    fi

    cd "$(dirname "${DOWNLOADER}")"
    local update_output
    update_output=$("${DOWNLOADER}" -check-update 2>&1) || true

    if echo "${update_output}" | grep -qi "new version.*available"; then
        log_info "New downloader version available, updating..."
        install_downloader
        DOWNLOADER_UPDATED="updated"
    else
        DOWNLOADER_UPDATED="up-to-date"
    fi
}

install_downloader() {
    local temp_dir
    temp_dir=$(mktemp -d)

    local downloader_url="https://downloader.hytale.com/hytale-downloader.zip"

    log_info "Downloading hytale-downloader..."
    if ! curl -sL "${downloader_url}" -o "${temp_dir}/hytale-downloader.zip"; then
        log_error "Failed to download hytale-downloader"
        rm -rf "${temp_dir}"
        return 1
    fi

    unzip -q "${temp_dir}/hytale-downloader.zip" -d "${temp_dir}/extracted"

    local new_binary
    new_binary=$(find "${temp_dir}/extracted" -name "hytale-downloader" -type f ! -name "*.exe" | head -1)

    if [[ -z "${new_binary}" ]]; then
        new_binary=$(find "${temp_dir}/extracted" -name "hytale-downloader*" -type f ! -name "*.exe" | head -1)
    fi

    if [[ -z "${new_binary}" ]]; then
        log_error "Could not find hytale-downloader in archive"
        rm -rf "${temp_dir}"
        return 1
    fi

    # Backup old downloader if exists
    if [[ -f "${DOWNLOADER}" ]]; then
        mv "${DOWNLOADER}" "${DOWNLOADER}.bak"
    fi

    cp "${new_binary}" "${DOWNLOADER}"
    chmod +x "${DOWNLOADER}"

    rm -rf "${temp_dir}"
    log_success "Downloader installed successfully"
}

# =============================================================================
# Server Version Download and Installation
# =============================================================================

download_server_version() {
    local version="$1"
    local download_path="${DOWNLOADS_DIR}/${version}.zip"

    if [[ -f "${download_path}" ]]; then
        log_info "Server version ${version} already downloaded"
        return 0
    fi

    log_info "Downloading server version ${version}..."

    local patchline_arg=""
    if [[ "${PATCHLINE}" != "release" ]]; then
        patchline_arg="-patchline ${PATCHLINE}"
    fi

    local cred_arg=""
    if [[ -f "${CREDENTIALS}" ]]; then
        cred_arg="-credentials-path ${CREDENTIALS}"
    fi

    cd "$(dirname "${DOWNLOADER}")"
    "${DOWNLOADER}" ${patchline_arg} ${cred_arg} -skip-update-check -download-path "${download_path}"

    if [[ ! -f "${download_path}" ]]; then
        log_error "Download failed"
        return 1
    fi

    log_success "Downloaded server version ${version}"
}

install_server_version() {
    local version="$1"
    local download_path="${DOWNLOADS_DIR}/${version}.zip"
    local install_path="${VERSIONS_DIR}/${version}"

    if is_server_version_installed "${version}"; then
        log_info "Server version ${version} already installed"
        return 0
    fi

    if [[ ! -f "${download_path}" ]]; then
        log_error "Download file not found: ${download_path}"
        return 1
    fi

    log_info "Installing server version ${version}..."

    local temp_extract
    temp_extract=$(mktemp -d)

    unzip -q "${download_path}" -d "${temp_extract}"

    mkdir -p "${install_path}"

    # Copy Server files
    if [[ -d "${temp_extract}/Server" ]]; then
        cp -r "${temp_extract}/Server" "${install_path}/"
        log_info "  Server files copied"
    fi

    # Copy Assets.zip
    if [[ -f "${temp_extract}/Assets.zip" ]]; then
        cp "${temp_extract}/Assets.zip" "${install_path}/"
        log_info "  Assets.zip copied"
    fi

    rm -rf "${temp_extract}"
    log_success "Installed server version ${version}"
}

# =============================================================================
# Data Migration / Symlink Setup
# =============================================================================

setup_shared_links() {
    local version="$1"
    local version_path="${VERSIONS_DIR}/${version}"

    log_info "Setting up shared data links for ${version}..."

    for item in "${PERSISTENT_DATA[@]}"; do
        local shared_path="${SHARED_DIR}/${item}"
        local version_item_path="${version_path}/${item}"

        # If item exists in version directory and is not a symlink, migrate it
        if [[ -e "${version_item_path}" ]] && [[ ! -L "${version_item_path}" ]]; then
            if [[ -d "${version_item_path}" ]]; then
                # Merge directory contents (don't overwrite existing)
                cp -rn "${version_item_path}/"* "${shared_path}/" 2>/dev/null || true
                rm -rf "${version_item_path}"
            elif [[ -f "${version_item_path}" ]]; then
                # Copy file if shared doesn't exist or is empty
                if [[ ! -f "${shared_path}" ]] || [[ ! -s "${shared_path}" ]] || [[ "$(cat "${shared_path}")" == "{}" ]]; then
                    cp "${version_item_path}" "${shared_path}"
                fi
                rm -f "${version_item_path}"
            fi
        fi

        # Remove existing symlink if points elsewhere
        if [[ -L "${version_item_path}" ]]; then
            rm -f "${version_item_path}"
        fi

        # Create symlink to shared data
        ln -sf "${shared_path}" "${version_item_path}"
    done

    log_success "Shared data links configured"
}

# =============================================================================
# Server Version Activation
# =============================================================================

activate_server_version() {
    local version="$1"
    local version_path="${VERSIONS_DIR}/${version}"

    if ! is_server_version_installed "${version}"; then
        log_error "Server version ${version} is not installed"
        return 1
    fi

    log_info "Activating server version ${version}..."

    # Setup shared data links
    setup_shared_links "${version}"

    # Update symlink atomically
    local temp_link="${CURRENT_LINK}.new"
    ln -sfn "${version_path}" "${temp_link}"
    mv -Tf "${temp_link}" "${CURRENT_LINK}"

    # Update version file
    echo "${version}" > "${VERSION_FILE}"

    log_success "Activated server version ${version}"
}

# =============================================================================
# Main Commands
# =============================================================================

cmd_check() {
    ensure_directories

    echo ""
    echo "=== Hytale Downloader ==="
    update_downloader_if_needed
    case "${DOWNLOADER_UPDATED}" in
        "installed") echo "  Status: Newly installed" ;;
        "updated")   echo "  Status: Updated to latest" ;;
        *)           echo "  Status: Up to date" ;;
    esac

    echo ""
    echo "=== Hytale Server ==="
    local installed_version latest_version
    installed_version=$(get_installed_server_version)
    latest_version=$(get_latest_server_version)

    echo "  Installed: ${installed_version:-<none>}"
    echo "  Latest:    ${latest_version:-<unknown>}"

    if [[ -z "${installed_version}" ]]; then
        echo "  Status: Not installed"
    elif [[ -z "${latest_version}" ]]; then
        echo "  Status: Could not check latest version"
    elif [[ "${installed_version}" == "${latest_version}" ]]; then
        echo "  Status: Up to date"
    else
        echo "  Status: Update available!"
    fi
    echo ""
}

cmd_update() {
    local force="${1:-false}"

    ensure_directories
    update_downloader_if_needed

    local installed_version latest_version
    installed_version=$(get_installed_server_version)
    latest_version=$(get_latest_server_version)

    if [[ -z "${latest_version}" ]]; then
        log_error "Could not determine latest server version"
        return 1
    fi

    log_info "Installed server version: ${installed_version:-<none>}"
    log_info "Latest server version: ${latest_version}"

    # Skip if same version (unless force)
    if [[ "${installed_version}" == "${latest_version}" ]] && [[ "${force}" != "true" ]]; then
        log_info "Already running latest server version"
        return 0
    fi

    # Download if needed
    if ! is_server_version_installed "${latest_version}"; then
        download_server_version "${latest_version}" || return 1
        install_server_version "${latest_version}" || return 1
    fi

    # Activate new version
    activate_server_version "${latest_version}"

    log_success "Server update complete: ${latest_version}"
}

cmd_rollback() {
    local target_version="$1"

    ensure_directories

    if [[ -z "${target_version}" ]]; then
        log_info "Available versions for rollback:"
        cmd_list
        echo ""
        log_error "Usage: version-manager rollback <version>"
        return 1
    fi

    if ! is_server_version_installed "${target_version}"; then
        log_error "Server version ${target_version} is not installed"
        return 1
    fi

    local installed_version
    installed_version=$(get_installed_server_version)

    if [[ "${installed_version}" == "${target_version}" ]]; then
        log_info "Already running server version ${target_version}"
        return 0
    fi

    log_info "Rolling back from ${installed_version} to ${target_version}..."
    activate_server_version "${target_version}"

    log_success "Rollback complete"
}

cmd_list() {
    ensure_directories

    local installed_version
    installed_version=$(get_installed_server_version)

    echo "Installed server versions:"

    local found=false
    for version_dir in "${VERSIONS_DIR}"/*; do
        if [[ -d "${version_dir}" ]]; then
            local version
            version=$(basename "${version_dir}")
            if [[ "${version}" == "${installed_version}" ]]; then
                echo "  * ${version} (active)"
            else
                echo "    ${version}"
            fi
            found=true
        fi
    done

    if [[ "${found}" == "false" ]]; then
        echo "  (none)"
    fi
}

cmd_current() {
    local installed_version
    installed_version=$(get_installed_server_version)

    if [[ -n "${installed_version}" ]]; then
        echo "${installed_version}"
    else
        echo "No server version active"
        return 1
    fi
}

cmd_cleanup() {
    local keep="${1:-3}"

    ensure_directories

    local installed_version
    installed_version=$(get_installed_server_version)

    log_info "Cleaning up old server versions (keeping ${keep} most recent)..."

    # Get all versions sorted by date (newest first)
    local versions=()
    while IFS= read -r version_dir; do
        [[ -d "${version_dir}" ]] && versions+=("$(basename "${version_dir}")")
    done < <(ls -dt "${VERSIONS_DIR}"/*/ 2>/dev/null)

    local count=0
    for version in "${versions[@]}"; do
        count=$((count + 1))

        if [[ "${version}" == "${installed_version}" ]]; then
            log_info "  Keeping: ${version} (active)"
            continue
        fi

        if [[ ${count} -le ${keep} ]]; then
            log_info "  Keeping: ${version}"
        else
            log_info "  Removing: ${version}"
            rm -rf "${VERSIONS_DIR}/${version}"
            rm -f "${DOWNLOADS_DIR}/${version}.zip"
        fi
    done

    log_success "Cleanup complete"
}

# =============================================================================
# Legacy Migration (v1 flat structure -> v2 versioned structure)
# =============================================================================

is_legacy_install() {
    # Legacy install has HytaleServer.jar directly in SERVER_ROOT (not in versions/)
    [[ -f "${SERVER_ROOT}/HytaleServer.jar" ]]
}

get_legacy_version() {
    if [[ -f "${SERVER_ROOT}/HytaleServer.jar" ]]; then
        local version_output
        version_output=$(java -jar "${SERVER_ROOT}/HytaleServer.jar" --version 2>/dev/null || true)
        # Extract version from "HytaleServer v2026.01.13-dcad8778f (release)"
        echo "${version_output}" | sed -n 's/.*HytaleServer v\([^ ]*\).*/\1/p' | tr -d '\n\r'
    fi
}

cmd_migrate() {
    echo ""
    echo "=========================================="
    echo "  Legacy Installation Migration"
    echo "=========================================="
    echo ""

    # Check if this is a legacy install
    if ! is_legacy_install; then
        if [[ -L "${CURRENT_LINK}" ]]; then
            log_info "Already using versioned structure. No migration needed."
        else
            log_info "No legacy installation detected."
            log_info "If this is a fresh install, just run: version-manager update"
        fi
        return 0
    fi

    # Get version from existing server
    log_info "Detecting server version..."
    local legacy_version
    legacy_version=$(get_legacy_version)

    if [[ -z "${legacy_version}" ]]; then
        log_error "Could not detect server version from HytaleServer.jar"
        log_error "Try running: java -jar ${SERVER_ROOT}/HytaleServer.jar --version"
        return 1
    fi

    log_success "Detected version: ${legacy_version}"

    # Create directories
    ensure_directories
    local version_path="${VERSIONS_DIR}/${legacy_version}"
    local server_path="${version_path}/Server"

    if [[ -d "${version_path}" ]]; then
        log_error "Version directory already exists: ${version_path}"
        log_error "This might indicate a partial migration. Please check manually."
        return 1
    fi

    mkdir -p "${server_path}"

    echo ""
    log_info "Migrating server files..."

    # Move server binaries to versions/<version>/Server/
    for file in HytaleServer.jar HytaleServer.aot; do
        if [[ -f "${SERVER_ROOT}/${file}" ]]; then
            log_info "  Moving ${file} -> versions/${legacy_version}/Server/"
            mv "${SERVER_ROOT}/${file}" "${server_path}/"
        fi
    done

    # Move Licenses directory
    if [[ -d "${SERVER_ROOT}/Licenses" ]]; then
        log_info "  Moving Licenses/ -> versions/${legacy_version}/Server/"
        mv "${SERVER_ROOT}/Licenses" "${server_path}/"
    fi

    # Move Assets to version directory
    if [[ -f "${SERVER_ROOT}/Assets.zip" ]]; then
        log_info "  Moving Assets.zip -> versions/${legacy_version}/"
        mv "${SERVER_ROOT}/Assets.zip" "${version_path}/"
    elif [[ -d "${SERVER_ROOT}/Assets" ]]; then
        log_info "  Moving Assets/ -> versions/${legacy_version}/"
        mv "${SERVER_ROOT}/Assets" "${version_path}/"
    fi

    echo ""
    log_info "Migrating persistent data to shared/..."

    # Move persistent data to shared/
    for item in "${PERSISTENT_DATA[@]}"; do
        if [[ -e "${SERVER_ROOT}/${item}" ]] && [[ ! -L "${SERVER_ROOT}/${item}" ]]; then
            if [[ -d "${SERVER_ROOT}/${item}" ]]; then
                log_info "  Moving ${item}/ -> shared/"
                # Merge with existing shared data if any
                if [[ -d "${SHARED_DIR}/${item}" ]]; then
                    cp -rn "${SERVER_ROOT}/${item}/"* "${SHARED_DIR}/${item}/" 2>/dev/null || true
                    rm -rf "${SERVER_ROOT}/${item}"
                else
                    mv "${SERVER_ROOT}/${item}" "${SHARED_DIR}/"
                fi
            elif [[ -f "${SERVER_ROOT}/${item}" ]]; then
                log_info "  Moving ${item} -> shared/"
                mv "${SERVER_ROOT}/${item}" "${SHARED_DIR}/"
            fi
        fi
    done

    # Also migrate backup directory if exists (not in PERSISTENT_DATA by default)
    if [[ -d "${SERVER_ROOT}/backup" ]]; then
        log_info "  Moving backup/ -> shared/"
        mv "${SERVER_ROOT}/backup" "${SHARED_DIR}/"
    fi

    echo ""
    log_info "Setting up symlinks..."

    # Setup shared links for the migrated version
    setup_shared_links "${legacy_version}"

    # Activate this version
    ln -sfn "${version_path}" "${CURRENT_LINK}"
    echo "${legacy_version}" > "${VERSION_FILE}"

    echo ""
    echo "=========================================="
    log_success "Migration complete!"
    echo "=========================================="
    echo ""
    echo "  Server version: ${legacy_version}"
    echo "  Version path:   ${version_path}"
    echo "  Shared data:    ${SHARED_DIR}"
    echo ""
    echo "Your server data (config, universe, mods, etc.) has been"
    echo "moved to the shared/ directory and will persist across updates."
    echo ""
    echo "You can now restart the container normally."
    echo ""
}

cmd_help() {
    cat << 'EOF'
Hytale Server Version Manager

Usage:
  version-manager [COMMAND] [OPTIONS]

Commands:
  check              Check for available updates
  update [--force]   Download and install new version if available
  rollback <version> Rollback to a previous version
  list               List all installed versions
  current            Show current active version
  cleanup [N]        Remove old versions (keep N most recent, default: 3)
  migrate            Migrate from legacy (v1) flat structure to versioned structure
  help               Show this help

Environment Variables:
  SERVER_ROOT   Server root directory (default: /server)
  PATCHLINE     Download channel: release or pre-release (default: release)

Examples:
  version-manager check
  version-manager update
  version-manager rollback 2026.01.13-50e69c385
  version-manager cleanup 5
EOF
}

# =============================================================================
# Main Entry Point
# =============================================================================

main() {
    local command="${1:-update}"
    shift || true

    case "${command}" in
        check)
            cmd_check "$@"
            ;;
        update)
            cmd_update "$@"
            ;;
        rollback)
            cmd_rollback "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        current)
            cmd_current "$@"
            ;;
        cleanup)
            cmd_cleanup "$@"
            ;;
        migrate)
            cmd_migrate "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            log_error "Unknown command: ${command}"
            echo "Run 'version-manager help' for usage"
            return 1
            ;;
    esac
}

main "$@"
