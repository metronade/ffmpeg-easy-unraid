# ==============================================================================
# Dockerfile: FFmpeg-Easy-Unraid
# Project:    Simple H265 and AV1 Batch Transcoder
# Author:     metronade
# Base:       Ubuntu 24.04 (Includes FFmpeg 6.1 native)
# ==============================================================================

FROM ubuntu:24.04

# Metadata
LABEL maintainer="metronade"
LABEL description="Simple H265 and AV1 Batch Transcoder"

ENV DEBIAN_FRONTEND=noninteractive

# --- CONFIG DEFAULTS ---
ENV ENCODE_METHOD=cpu_h265
ENV ENCODE_PRESET=default
ENV ENCODE_THREADS=0

# Custom Arguments
ENV FFMPEG_CUSTOM_ARGS=""

# Unraid Permissions
ENV UNRAID_UID=99
ENV UNRAID_GID=100

# Leave empty for smart defaults
ENV ENCODE_CRF=""
ENV ENCODE_CQ=""

# 1. Install Dependencies & FFmpeg & Drivers
# Ubuntu 24.04 hat FFmpeg 6.1+ bereits in den offiziellen Quellen (universe).
# Wir installieren auch die Intel Treiber für QSV.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ffmpeg \
    intel-media-va-driver \
    i965-va-driver \
    libva-drm2 \
    libva-x11-2 \
    vainfo \
    bc \
    curl \
    wget \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Root directories for simplified access
WORKDIR /

COPY transcode.sh /usr/local/bin/transcode.sh
RUN chmod +x /usr/local/bin/transcode.sh

ENTRYPOINT ["/usr/local/bin/transcode.sh"]
