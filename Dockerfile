# Hytale Dedicated Server
# Documentation: https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual

FROM eclipse-temurin:25-jre

LABEL maintainer="enzo"
LABEL description="Hytale Dedicated Server"

# Create non-root user for security
RUN groupadd -r hytale && useradd -r -g hytale hytale

# Working directory
WORKDIR /server

# Install dependencies (unzip for extracting assets, curl for downloader)
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY --chmod=755 scripts/entrypoint.sh /entrypoint.sh
COPY --chmod=755 scripts/download-assets.sh /usr/local/bin/download-assets

# Create required directories
RUN mkdir -p /server/universe /server/mods /server/logs /server/.cache \
    && chown -R hytale:hytale /server

# Volumes for data persistence
VOLUME ["/server/universe", "/server/mods", "/server/logs", "/server/.cache"]

# QUIC port (UDP only!)
EXPOSE 5520/udp

# Default environment variables
ENV JAVA_HEAP_SIZE="4G"
ENV SERVER_PORT="5520"
ENV USE_AOT_CACHE="true"
ENV EXTRA_JAVA_ARGS=""
ENV EXTRA_SERVER_ARGS=""
ENV WAIT_FOR_ASSETS="false"
ENV AUTO_DOWNLOAD="false"

# Non-root user
USER hytale

ENTRYPOINT ["/entrypoint.sh"]
