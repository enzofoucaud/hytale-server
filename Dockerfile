# Hytale Dedicated Server - Version Manager Edition
# Documentation: https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual

FROM eclipse-temurin:25-jre

LABEL maintainer="enzo"
LABEL description="Hytale Dedicated Server with automatic version management"

# Create non-root user for security
RUN groupadd -r hytale && useradd -r -g hytale hytale

# Working directory
WORKDIR /server

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY --chmod=755 scripts/entrypoint.sh /entrypoint.sh
COPY --chmod=755 scripts/version-manager.sh /usr/local/bin/version-manager

# Create required directories
RUN mkdir -p /server/versions /server/shared /server/downloads \
    && mkdir -p /server/shared/.cache /server/shared/logs \
    && mkdir -p /server/shared/mods /server/shared/universe \
    && chown -R hytale:hytale /server

# QUIC port (UDP only!)
EXPOSE 5520/udp

# Default environment variables
ENV JAVA_HEAP_SIZE="4G"
ENV SERVER_PORT="5520"
ENV USE_AOT_CACHE="true"
ENV EXTRA_JAVA_ARGS=""
ENV EXTRA_SERVER_ARGS=""
ENV AUTO_UPDATE="true"
ENV PATCHLINE="release"

# Non-root user
USER hytale

ENTRYPOINT ["/entrypoint.sh"]
