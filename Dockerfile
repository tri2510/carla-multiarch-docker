# Multi-architecture CARLA Dockerfile for x86_64 and ARM64 (Jetson Orin)
# Supports direct display output and Logitech wheel controllers

ARG TARGETPLATFORM
ARG BUILDPLATFORM

# Base stage - common dependencies
FROM ubuntu:20.04 as base

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install common dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python and build tools
    python3 \
    python3-pip \
    python3-dev \
    python3-numpy \
    python3-pygame \
    build-essential \
    git \
    wget \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    # Display and graphics
    xorg \
    xserver-xorg-core \
    xserver-xorg-video-all \
    libx11-6 \
    libxext6 \
    libxrender1 \
    libxrandr2 \
    libxi6 \
    libgl1 \
    libglx0 \
    libglvnd0 \
    libegl1 \
    libgles2 \
    libvulkan1 \
    mesa-vulkan-drivers \
    mesa-utils \
    x11-utils \
    x11-xserver-utils \
    # Input devices
    libusb-1.0-0 \
    libudev1 \
    joystick \
    jstest-gtk \
    evtest \
    # Audio
    pulseaudio \
    pulseaudio-utils \
    alsa-utils \
    # Networking
    net-tools \
    iputils-ping \
    # Other utilities
    vim \
    nano \
    htop \
    tmux \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip3 install --no-cache-dir \
    numpy \
    pygame \
    pillow \
    opencv-python-headless \
    pyyaml \
    argparse \
    pyserial \
    inputs

# Create carla user
RUN useradd -m -s /bin/bash carla && \
    usermod -aG video,audio,input,plugdev carla && \
    echo "carla ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

WORKDIR /home/carla

# x86_64 stage - use official CARLA image binaries
FROM base as carla-amd64

# Install NVIDIA Container Toolkit requirements
RUN apt-get update && apt-get install -y --no-install-recommends \
    libvulkan1 \
    nvidia-utils-470 \
    && rm -rf /var/lib/apt/lists/* || true

# Download and install CARLA 0.9.15 for x86_64
ENV CARLA_VERSION=0.9.15
RUN wget -q https://carla-releases.s3.us-east-005.backblazeb2.com/Linux/CARLA_${CARLA_VERSION}.tar.gz && \
    tar -xzf CARLA_${CARLA_VERSION}.tar.gz && \
    rm CARLA_${CARLA_VERSION}.tar.gz && \
    chown -R carla:carla /home/carla

# Install CARLA Python API
RUN cd /home/carla/PythonAPI/carla/dist && \
    pip3 install carla-*-cp3*-linux_x86_64.whl

# ARM64 stage - build from source or use community builds
FROM base as carla-arm64

# Install additional dependencies for building CARLA
RUN apt-get update && apt-get install -y --no-install-recommends \
    cmake \
    make \
    g++ \
    clang \
    ninja-build \
    libpng-dev \
    libtiff5-dev \
    libjpeg-dev \
    tzdata \
    sed \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# For Jetson Orin - install NVIDIA libraries
RUN apt-get update && apt-get install -y --no-install-recommends \
    nvidia-l4t-core \
    nvidia-l4t-cuda \
    nvidia-l4t-multimedia \
    || echo "Jetson packages not available, will be installed at runtime"

# Note: Building CARLA from source on ARM takes 4-6 hours
# For production, you should pre-build and use the binary
# This is a placeholder that will be enhanced with actual build or binary download
RUN mkdir -p /home/carla/carla-bin && \
    echo "CARLA ARM build will be mounted or built separately" > /home/carla/README.txt

# Install CARLA Python API (will be provided by mounted volume or build)
RUN pip3 install --no-cache-dir carla || echo "CARLA Python API will be installed from mounted volume"

# Final stage - select based on target platform
FROM carla-${TARGETARCH} as final

# Copy helper scripts
COPY scripts/ /home/carla/scripts/
RUN chmod +x /home/carla/scripts/*.sh && \
    chown -R carla:carla /home/carla/scripts

# Setup environment
ENV DISPLAY=:0
ENV SDL_VIDEODRIVER=x11
ENV CARLA_ROOT=/home/carla
ENV PYTHONPATH="${CARLA_ROOT}/PythonAPI/carla/dist/carla-*.egg:${CARLA_ROOT}/PythonAPI/carla:${PYTHONPATH}"

# Create directories for configs and data
RUN mkdir -p /home/carla/configs /home/carla/data /home/carla/logs && \
    chown -R carla:carla /home/carla

# Switch to carla user
USER carla

# Expose CARLA ports
EXPOSE 2000 2001 2002

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:2000 || exit 1

# Default command
CMD ["/home/carla/scripts/start-carla.sh"]
