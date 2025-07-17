## first build
FROM ubuntu:latest AS base

# Switch work dir, so that all subsequent commands are ran from there
WORKDIR /usr/local/bin

# Suppress interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install basic packages, including sudo
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y sudo passwd adduser && \
    # Clears out the apt cache to reduce the image size
    rm -rf /var/lib/apt/lists/*

## second build
FROM base AS embedded-linux
ARG TAGS
# Ensure that the necessary packages are installed in the second stage
RUN apt-get update && \
    apt-get install -y sudo passwd adduser && \
    rm -rf /var/lib/apt/lists/*
# Add a new user and give sudo access without a password
RUN addgroup --gid 1009 melp && \
    adduser --gecos melp --uid 1009 --gid 1009 --disabled-password melp

# Ensure melp can use sudo without a password
RUN echo 'melp ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER melp
ENV USER=melp
WORKDIR /home/melp

# Copy scripts directory to the container and change ownership
COPY --chown=melp:melp scripts scripts

# Run the toolchain script
CMD ["sh", "-c", "./scripts/toolchain.sh"]

