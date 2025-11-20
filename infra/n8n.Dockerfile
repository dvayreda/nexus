FROM n8nio/n8n:latest

USER root

# Install Python3, Pillow, ffmpeg, and sox for media processing
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-pillow \
    jpeg-dev \
    zlib-dev \
    freetype-dev \
    ffmpeg \
    sox

USER node
