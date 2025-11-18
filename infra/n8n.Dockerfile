FROM n8nio/n8n:latest

USER root

# Install ImageMagick, Python3, and required dependencies
RUN apk add --no-cache \
    imagemagick \
    python3 \
    py3-pip \
    py3-pillow \
    jpeg-dev \
    zlib-dev \
    freetype-dev

USER node
