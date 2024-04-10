FROM debian:12-slim
#debian 12 is required to have a recent-enough built-in meson.

# Install build tools
RUN  apt-get -qqy update \
  && apt-get -qqy --no-install-recommends install \
    ca-certificates \
    build-essential \
    cmake \
    pkgconf \
    meson \
    ninja-build \
  && rm -rf /var/lib/apt/lists/*

# libdisplay-info dependencies
RUN apt-get -qqy update \
&& apt-get -qqy --no-install-recommends install \
  edid-decode \
  && rm -rf /var/lib/apt/lists/*


# Wayland build-deps
# most are runtime dependencies that could be removed
RUN  apt-get -qqy update \
&& apt-get -qqy --no-install-recommends install \
  quilt \
  libexpat1-dev \
  libffi-dev \
  libxml2-dev \
&& rm -rf /var/lib/apt/lists/*

# wlroots build-deps (https://packages.debian.org/source/bookworm/wlroots)
# - libwayland-dev is required for wayland-scanner, which is set as "native" but could probablyt be force to use the local file.
#     (https://gitlab.freedesktop.org/wlroots/wlroots/-/blob/master/protocol/meson.build#L8)
RUN  apt-get -qqy update \
&& apt-get -qqy --no-install-recommends install \
  libavformat-dev \
  libavcodec-dev \
  libcap-dev \
  libvulkan-dev \
  glslang-tools \
  libdrm-dev \
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
  libwayland-dev \
  xwayland \
  libxcb-ewmh-dev \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app
RUN meson setup build --prefer-static --default-library=static --buildtype=release -Dwerror=false -Doptimization=2 \
  -Dxwayland=enabled \
  -Dwlroots:auto_features=enabled -Dwlroots:backends=auto -Dwlroots:renderers=auto \
  -Dwayland:documentation=false

RUN ninja -C build