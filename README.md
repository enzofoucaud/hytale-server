# Hytale Dedicated Server - Docker

Docker configuration for hosting a dedicated Hytale server.

## Prerequisites

- Docker & Docker Compose
- Hytale account (for server authentication)

## Quick Start

### 1. Build and start

```bash
# Build the image
docker compose build

# Start the server in background
docker compose up -d

# Follow the logs
docker compose logs -f
```

### 2. Authenticate for download (first launch)

On first launch, the downloader needs OAuth2 authentication to download server files.

In the logs, you'll see a URL like:

```text
Please visit: https://oauth.accounts.hytale.com...
```

Open this URL in your browser and authorize the download.

### 3. Wait for download

The server files will be downloaded automatically. This may take several minutes.
You'll see progress in the logs.

### 4. Authenticate for players

Once the server is fully booted, you need to authenticate it to allow players to connect.

Wait for this message in the logs:

```text
[HytaleServer] Hytale Server Booted!
```

Then attach to the server console:

```bash
docker attach hytale-server
```

Then type:

```text
/auth login device
```

Follow the displayed URL to authorize the server.

> **Note**: To detach from the console without stopping the server, press `Ctrl+P` then `Ctrl+Q`.

### 5. Ready

Your server is now running and players can connect.

To check the logs anytime:

```bash
docker compose logs -f
```

## Configuration

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_HEAP_SIZE` | `4G` | Memory allocated to the server |
| `SERVER_PORT` | `5520` | Server UDP port |
| `USE_AOT_CACHE` | `true` | Use AOT cache for faster startup |
| `AUTO_DOWNLOAD` | `true` | Automatically download assets if missing |
| `WAIT_FOR_ASSETS` | `false` | Keep container running for manual download |
| `USE_PRE_RELEASE` | `false` | Use pre-release channel (with AUTO_DOWNLOAD) |
| `EXTRA_JAVA_ARGS` | `` | Additional JVM arguments |
| `EXTRA_SERVER_ARGS` | `` | Additional server arguments |

### Downloading assets

By default, `AUTO_DOWNLOAD=true` will automatically download server files on first launch.
A URL will be displayed in the logs for OAuth2 authentication.

#### Alternative: Manual download

If you prefer to download manually, disable auto-download and enable wait mode:

```yaml
environment:
  - AUTO_DOWNLOAD=false
  - WAIT_FOR_ASSETS=true
```

Then in another terminal:

```bash
docker exec -it hytale-server download-assets
```

The server will start automatically once files are detected.

### Additional arguments examples

```yaml
environment:
  # Disable Sentry (recommended for plugin development)
  - EXTRA_SERVER_ARGS=--disable-sentry

  # Increase memory and use G1GC
  - JAVA_HEAP_SIZE=8G
  - EXTRA_JAVA_ARGS=-XX:+UseG1GC -XX:MaxGCPauseMillis=50
```

## File structure

```text
hytale-server/
├── Dockerfile
├── docker-compose.yml
├── README.md
└── scripts/
    ├── entrypoint.sh      # Startup script
    └── download-assets.sh # Asset downloader
```

Server files (HytaleServer.jar, Assets.zip, config.json, etc.) are stored in the `hytale-data` Docker volume.

## Useful commands

```bash
# View logs
docker compose logs -f

# Access the server console
docker attach hytale-server

# Execute a command
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

## Persistent volume

| Volume        | Contents                                                             |
|---------------|----------------------------------------------------------------------|
| `hytale-data` | All server files (jar, assets, config, universe, mods, logs)         |

## Important notes

1. **Authentication**: Each server must be authenticated with a Hytale account
2. **Limit**: Maximum 100 servers per Hytale license
3. **Updates**: The protocol requires exact client/server version match
4. **View distance**: Limit to 12 chunks to save RAM

## Official documentation

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual)
- [Server Provider Authentication Guide](https://support.hytale.com/hc/en-us/articles/45328341414043)
