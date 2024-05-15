FROM debian:12-slim
#debian 12 is required to have a recent-enough built-in meson.
ENV DEBIAN_FRONTEND=noninteractive

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
&& rm -rf /var/lib/apt/lists/*

# wlroots build-deps (https://packages.debian.org/source/bookworm/wlroots)
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
  xwayland \
  libxcb-ewmh-dev \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mkdir -p /app/subprojects

COPY  meson_options.txt meson.build /app/
COPY *.in *.scd .clang-format .clang-format-ignore /app/

COPY subprojects/*.wrap  /app/subprojects/
COPY subprojects/packagefiles /app/subprojects/packagefiles
COPY subprojects/packagecache /app/subprojects/packagecache

COPY ./protocol /app/protocol
COPY *.[ch] /app/


# Fix for the use of local wayland-scanner in subsequent builds
ENV PATH="${PATH}:/app/build/subprojects/wayland-1.22.0/src"

RUN meson setup build --prefer-static --default-library=static --buildtype=release -Dwerror=false \
  -Dxwayland=enabled -Dinput_calibration=enabled -Dman-pages=disabled \
  -Dwlroots:auto_features=enabled -Dwlroots:backends=auto -Dwlroots:renderers=auto \
  -Dwayland:documentation=false -Dwayland:dtd_validation=false

RUN ninja -C build

# Makes the image unusable, but useful to use with `docker buildx build --output=type=local`as we are.
RUN rm -rf /usr /var