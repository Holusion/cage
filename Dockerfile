FROM debian:12-slim
ENV DEBIAN_FRONTEND=noninteractive
#debian 12 "bookworm" is required to have a recent-enough built-in meson.
# backports are required for a recent-enough libdrm

# Install build tools
RUN  apt-get -qqy update \
  && apt-get -qqy --no-install-recommends install \
    git \
    ca-certificates \
    build-essential \
    cmake \
    pkgconf \
    meson \
    ninja-build \
  && rm -rf /var/lib/apt/lists/*


# Wayland build-deps
# They are all wayland-scanner dependencies that are no longer required once the build completes
RUN  apt-get -qqy update \
&& apt-get -qqy --no-install-recommends install \
  libexpat1-dev \
  libffi-dev \
&& rm -rf /var/lib/apt/lists/*

# libdrm build dependencies
RUN  apt-get -qqy update \
&& apt-get -qqy --no-install-recommends install \
  libpciaccess-dev \
&& rm -rf /var/lib/apt/lists/*


# wlroots build-deps (https://packages.debian.org/source/bookworm/wlroots)
RUN  apt-get -qqy update \
&& apt-get -qqy --no-install-recommends install \
  libavformat-dev \
  libavcodec-dev \
  libcap-dev \
  libvulkan-dev \
  glslang-tools \
  libegl1-mesa-dev \
  libgbm-dev \
  libgles2-mesa-dev \
  libinput-dev \
  libpixman-1-dev \
  libpng-dev \
  libseat-dev \
  libsystemd-dev\
  libxcb1-dev \
  libxcb-composite0-dev \
  libxcb-dri3-dev \
  libxcb-icccm4-dev \
  libxcb-image0-dev \
  libxcb-present-dev \
  libxcb-render0-dev \
  libxcb-render-util0-dev \
  libxcb-res0-dev \
  libxcb-xfixes0-dev \
  libxcb-xinput-dev \
  libx11-xcb-dev \
  libxkbcommon-dev \
  hwdata \
  xwayland \
  libxcb-ewmh-dev \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN meson setup build --default-library=static --prefer-static --buildtype=release -Dwerror=false \
  -Dwlroots:xwayland=enabled -Dwlroots:examples=false \
  -Dwlroots:auto_features=enabled -Dwlroots:backends=auto -Dwlroots:renderers=auto \
  -Dwayland:documentation=false -Dwayland:dtd_validation=false \
  -Dlibdrm:intel=enabled \
  -Dman-pages=disabled -Dinput_calibration=enabled

RUN ninja -C build
# Makes the image unusable, but useful to use with `docker buildx build --output=type=local`as we are.
RUN rm -rf /usr /var