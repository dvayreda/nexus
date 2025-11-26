FROM n8nio/n8n:latest

USER root

# Install Python3, Pillow, and other system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-pillow \
    jpeg-dev \
    zlib-dev \
    freetype-dev \
    sox

# Install factsmind python dependencies directly
RUN pip install --no-cache-dir \
    google-generativeai \
    requests \
    PyYAML \
    python-dotenv \
    Pillow \
    psycopg2-binary

# Create symlinks for ffmpeg static builds (mounted from /srv/bin)
# This allows 'ffmpeg' command to use the full-featured static build
RUN ln -sf /data/bin/ffmpeg-full /usr/local/bin/ffmpeg && \
    ln -sf /data/bin/ffprobe-full /usr/local/bin/ffprobe

USER node
