#FROM python:3.12-slim
#FROM debian:bookworm-slim
FROM jbarlow83/ocrmypdf:latest

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    coreutils \
    findutils \
    ocrmypdf \
    tmux \
    jbig2 \
    snapd \
    && rm -rf /var/lib/apt/lists/* \
    && snap install jbig2enc --edge

WORKDIR /app

COPY ocr_sequencial.sh /app/ocr_sequencial.sh

RUN chmod +x /app/ocr_sequencial.sh

ENTRYPOINT ["/app/ocr_sequencial.sh"]