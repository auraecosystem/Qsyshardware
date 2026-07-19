FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    build-essential make git pkg-config \
    ghdl gnat gtkwave \
    gcc-riscv64-unknown-elf \
 && rm -rf /var/lib/apt/lists/*
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv "$VIRTUAL_ENV"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
RUN useradd -ms /bin/bash dev
USER dev
WORKDIR /work
# Native ARM64 slim Linux base for Apple M4 core speed performance
FROM --platform=linux/arm64 debian:bookworm-slim

# Install the true GNU AWK package
RUN apt-get update && apt-get install -y --no-install-recommends \
    gawk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /pipeline
COPY . .

# Run your gawk analytics engine directly over incoming text streams
ENTRYPOINT ["gawk", "-f", "gawk_monitor.awk"]
