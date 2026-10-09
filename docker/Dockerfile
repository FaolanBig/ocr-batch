#FROM python:3.12-slim
#FROM debian:bookworm-slim
FROM jbarlow83/ocrmypdf:latest

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    coreutils \
    findutils \
    autoconf \
    automake \
    libtool \
    tmux \
    git \
    ca-certificates \
    pkg-config \
    libtool \
    libleptonica-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

#RUN snap install jbig2enc --edge

RUN git -c http.sslVerify=false clone https://github.com/agl/jbig2enc.git /tmp/jbig2enc && \
    cd /tmp/jbig2enc && \
    ./autogen.sh && \
    ./configure && \
    make -j"$(nproc)" && \
    make install && \
    rm -rf /tmp/jbig2enc

WORKDIR /app

COPY ocr_sequencial.sh /app/ocr_sequencial.sh

RUN chmod +x /app/ocr_sequencial.sh

#ENTRYPOINT ["/app/ocr_sequencial.sh"]
ENTRYPOINT ["tmux","new-session","-d","/app/ocr_sequencial.sh"]