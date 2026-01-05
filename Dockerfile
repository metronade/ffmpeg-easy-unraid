# ==============================================================================
# Dockerfile: FFmpeg-Easy-Unraid
# Project:    Simple H265 and AV1 Batch Transcoder
# Author:     metronade
# Base:       Ubuntu 22.04 + FFmpeg 6.x
# ==============================================================================

FROM ubuntu:22.04

# Metadata
LABEL maintainer="metronade"
LABEL description="Simple H265 and AV1 Batch Transcoder"

ENV DEBIAN_FRONTEND=noninteractive

# --- CONFIG DEFAULTS ---
# Method: cpu_h265 | cpu_av1 | nvidia_h265 | nvidia_av1 | intel_h265 | intel_av1
ENV ENCODE_METHOD=cpu_h265
ENV ENCODE_PRESET=default
# 0 = Auto-Detect (Checks for pinning)
ENV ENCODE_THREADS=0

# Custom Arguments (Advanced users only). If empty: "-c:a copy -c:s copy"
ENV FFMPEG_CUSTOM_ARGS=""

# Unraid Permissions
ENV UNRAID_UID=99
ENV UNRAID_GID=100

# Leave empty for smart defaults
ENV ENCODE_CRF=""
ENV ENCODE_CQ=""

# 1. Install Dependencies & PPA (FFmpeg 6.x soft-pin)
RUN apt-get update && \
    apt-get install -y software-properties-common curl gpg wget && \
    add-apt-repository ppa:savoury1/ffmpeg4 -y && \
    add-apt-repository ppa:savoury1/ffmpeg6 -y && \
    apt-get update

# 2. Install FFmpeg & Drivers & Tools (bc for calc)
RUN apt-get install -y \
    ffmpeg \
    intel-media-driver \
    i965-va-driver-shaders \
    libva-drm2 \
    libva-x11-2 \
    vainfo \
    bc \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Root directories for simplified access
WORKDIR /

COPY transcode.sh /usr/local/bin/transcode.sh
RUN chmod +x /usr/local/bin/transcode.sh

ENTRYPOINT ["/usr/local/bin/transcode.sh"]
