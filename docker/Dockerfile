FROM python:3.12-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    ocrmypdf \
    tmux \
    jbig2 \
    snapd \
    && rm -rf /var/lib/apt/lists/* \
    && snap install jbig2enc --edge

WORKDIR /app

COPY ocr_sequencial /app/ocr_sequencial

RUN chmod +x /app/ocr_sequencial

ENTRYPOINT ["/app/ocr_sequencial"]