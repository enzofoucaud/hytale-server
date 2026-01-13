# Hytale Dedicated Server - Docker

Docker configuration for hosting a dedicated Hytale server.

## Prerequisites

- Docker & Docker Compose
- Hytale account (for server authentication)
- Hytale server files (HytaleServer.jar + Assets.zip)

## Quick Start

### 1. Get the server files

Copy the files from your Hytale Launcher installation:

```bash
# Linux
cp $XDG_DATA_HOME/Hytale/install/release/package/game/latest/Server/* ./game/
cp $XDG_DATA_HOME/Hytale/install/release/package/game/latest/Assets.zip ./game/

# Windows (WSL)
cp /mnt/c/Users/<USER>/AppData/Roaming/Hytale/install/release/package/game/latest/Server/* ./game/
cp /mnt/c/Users/<USER>/AppData/Roaming/Hytale/install/release/package/game/latest/Assets.zip ./game/
```

### 2. Build and run

```bash
# Build the image
docker compose build

# Start the server (first launch - interactive mode)
docker compose up
```

### 3. Authenticate the server

On first launch, in the server console:

```
> /auth login
```

Follow the instructions to authorize the server via the displayed link.

### 4. Run in background

Once authenticated:

```bash
docker compose up -d
```

## Configuration

### Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `JAVA_HEAP_SIZE` | `4G` | Memory allocated to the server |
| `SERVER_PORT` | `5520` | Server UDP port |
| `USE_AOT_CACHE` | `true` | Use AOT cache for faster startup |
| `AUTO_DOWNLOAD` | `false` | Automatically download assets if missing |
| `WAIT_FOR_ASSETS` | `false` | Keep container running for manual download |
| `USE_PRE_RELEASE` | `false` | Use pre-release channel (with AUTO_DOWNLOAD) |
| `EXTRA_JAVA_ARGS` | `` | Additional JVM arguments |
| `EXTRA_SERVER_ARGS` | `` | Additional server arguments |

### Downloading assets

If you don't have the server files (HytaleServer.jar, Assets.zip), several options:

#### Option 1: Automatic download (recommended)

```yaml
environment:
  - AUTO_DOWNLOAD=true
```

On first launch, a URL will be displayed for OAuth2 authentication. Open it in your browser.

#### Option 2: Manual download (container stays running)

```yaml
environment:
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

```
hytale-server/
├── Dockerfile
├── docker-compose.yml
├── README.md
├── QUICKSTART.md
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
