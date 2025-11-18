FROM n8nio/n8n:latest

USER root

# Install Python3 and Pillow for image composition
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-pillow \
    jpeg-dev \
    zlib-dev \
    freetype-dev

USER node
