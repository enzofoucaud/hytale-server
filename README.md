# Hytale Dedicated Server - Docker

Docker setup for hosting a Hytale dedicated server with automatic version management.

## Prerequisites

- Docker and Docker Compose
- Hytale account (for server authentication)

## Quick Start

### 1. Build and launch

```bash
# Build the image
docker compose build

# Start the server (downloads automatically if needed)
docker compose up -d

# View the logs
docker compose logs -f
```

### 2. Authentication for download (first launch)

On first launch, the downloader needs OAuth2 authentication to download server files.

In the logs, you'll see a URL like:

```text
Please visit: https://oauth.accounts.hytale.com...
```

Open this URL in your browser and authorize the download.

### 3. Wait for download

Server files will be downloaded automatically. This may take several minutes.
You'll see the progress in the logs.

### 4. Authentication for players

Once the server is fully started, you need to authenticate it to allow players to connect.

Wait for this message in the logs:

```text
[HytaleServer] Hytale Server Booted!
```

Then attach to the server console:

```bash
docker attach hytale-server
```

Type:

```text
/auth login device
```

Follow the displayed URL to authorize the server.

> **Note**: To detach from the console without stopping the server, press `Ctrl+P` then `Ctrl+Q`.

### 5. Ready

Your server is now running and players can connect.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_HEAP_SIZE` | `4G` | Memory allocated to Java |
| `SERVER_PORT` | `5520` | Server UDP port |
| `USE_AOT_CACHE` | `true` | Use AOT cache for faster startup |
| `AUTO_UPDATE` | `true` | Automatic update on startup |
| `PATCHLINE` | `release` | Channel: `release` or `pre-release` |
| `EXTRA_JAVA_ARGS` | `` | Additional JVM arguments |
| `EXTRA_SERVER_ARGS` | `` | Additional server arguments |

### Argument examples

```yaml
environment:
  # Disable Sentry (recommended for plugin development)
  - EXTRA_SERVER_ARGS=--disable-sentry

  # Increase memory and use G1GC
  - JAVA_HEAP_SIZE=8G
  - EXTRA_JAVA_ARGS=-XX:+UseG1GC -XX:MaxGCPauseMillis=50
```

## Version Manager Commands

All commands are executed via:

```bash
docker exec -it hytale-server version-manager <command>
```

### `check` - Check for updates

Displays the status of the downloader and server.

```bash
docker exec -it hytale-server version-manager check
```

Example output:

```text
=== Hytale Downloader ===
  Status: Up to date

=== Hytale Server ===
  Installed: 2026.01.13-50e69c385
  Latest:    2026.01.13-50e69c385
  Status: Up to date
```

### `update` - Update the server

Downloads and installs the latest version if available.

```bash
docker exec -it hytale-server version-manager update
```

Force reinstallation even if already up to date:

```bash
docker exec -it hytale-server version-manager update --force
```

### `list` - List installed versions

Displays all versions present on the server.

```bash
docker exec -it hytale-server version-manager list
```

Example output:

```text
Installed server versions:
  * 2026.01.13-50e69c385 (active)
    2026.01.10-abc12345
```

### `current` - Show active version

Returns only the currently used version.

```bash
docker exec -it hytale-server version-manager current
```

### `rollback` - Rollback to a previous version

Changes the active version to an already installed version.

```bash
docker exec -it hytale-server version-manager rollback <version>
```

Example:

```bash
docker exec -it hytale-server version-manager rollback 2026.01.10-abc12345
```

### `cleanup` - Clean up old versions

Removes old versions to free up disk space.

```bash
# Keep the 3 most recent versions (default)
docker exec -it hytale-server version-manager cleanup

# Keep the 5 most recent versions
docker exec -it hytale-server version-manager cleanup 5
```

### `migrate` - Migrate from legacy version

If you're using the old structure (v1) with files flat in `/server/`, this command automatically migrates your data to the new versioned structure.

```bash
docker exec -it hytale-server version-manager migrate
```

The migration:

- Detects the existing server version
- Moves server files to `versions/<version>/`
- Moves your data (config, universe, mods...) to `shared/`
- Configures symlinks for the new structure

> **Note**: On startup, if a legacy installation is detected, the container will display a message and wait for you to run the `migrate` command.

### `help` - Show help

```bash
docker exec -it hytale-server version-manager help
```

## Data Structure

```text
/server/                              # Docker volume (hytale-data)
├── hytale-downloader                 # Downloader binary
├── .hytale-downloader-credentials.json  # OAuth2 credentials
├── .version                          # Active version
├── current -> versions/XXXX/         # Symlink to active version
├── shared/                           # Shared persistent data
│   ├── .cache/                       # Optimized files cache
│   ├── logs/                         # Server logs
│   ├── mods/                         # Installed mods
│   ├── universe/                     # Worlds and player data
│   ├── bans.json                     # Ban list
│   ├── config.json                   # Server configuration
│   ├── permissions.json              # Permissions
│   └── whitelist.json                # Whitelist
├── versions/                         # All installed versions
│   └── 2026.01.13-50e69c385/
│       ├── Server/HytaleServer.jar
│       └── Assets.zip
└── downloads/                        # Downloaded archives
```

## Useful Commands

```bash
# View logs
docker compose logs -f

# Access the server console
docker attach hytale-server

# Execute a command in the container
docker exec -it hytale-server bash

# Restart the server
docker compose restart

# Stop the server
docker compose down
```

## Network

- **Protocol**: QUIC over UDP (not TCP!)
- **Default port**: 5520/UDP

Make sure to:

- Open port **5520/UDP** in your firewall
- Configure UDP port forwarding on your router (if self-hosting)

## Important Notes

1. **Authentication**: Each server must be authenticated with a Hytale account
2. **Limit**: Maximum 100 servers per Hytale license
3. **Updates**: The protocol requires exact client/server version match
4. **View distance**: Limit to 12 chunks to save RAM

## Official Documentation

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043)
