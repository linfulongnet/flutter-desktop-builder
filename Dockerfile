# syntax=docker/dockerfile:1
#
# Flutter Desktop/Web Builder
#
# 基于官方 cirruslabs/flutter 镜像（其底层为 Ubuntu 24.04 / noble），
# 补充编译 Web / Linux 平台应用所需的系统工具链。
#
# 注意：本镜像只负责 Linux / Web 平台。Flutter 的 Windows 桌面应用无法在
# Linux 上交叉编译（需要 VS Build Tools + Windows SDK），须另用 Windows 容器
# 或 Windows CI runner 构建，见 docs/windows-build.md。
#
# 构建方式（版本通过 build-arg 传入，见 build.sh）：
#   docker build \
#     --build-arg FLUTTER_BASE_TAG=3.44.0 \
#     --build-arg CMAKE_VERSION=3.30.5 \
#     --build-arg NINJA_VERSION=1.12.1 \
#     -t flutter-desktop-builder:latest .
#
ARG FLUTTER_BASE_TAG=3.44.0

FROM ghcr.io/cirruslabs/flutter:${FLUTTER_BASE_TAG}

USER root

# ---------------------------------------------------------------
# 可覆盖的工具版本（build.sh 会透传）
# ---------------------------------------------------------------
# cmake / ninja 通过 Ubuntu 24.04 官方仓库安装，版本较新；
# 若系统仓库版本满足不了需求，可用下面 ARG 强制从源码/官方二进制安装。
# 工具版本必须有默认值（不能为空，会与 build.sh 保持一致）。
ARG CMAKE_VERSION=3.31.6
ARG NINJA_VERSION=1.13.2

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# ---------------------------------------------------------------
# 1) 各平台编译依赖
#    - Web:    无需额外系统工具（Dart 直接编译为 JS/WASM）
#    - Linux:  clang / cmake / ninja-build / pkg-config / GTK3 开发库
#              + libstdc++-12-dev（处理宿主 GCC 与构建链的 ABI 兼容）
#    - Windows: 不支持在本镜像交叉编译，见 docs/windows-build.md
# ---------------------------------------------------------------
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        wget \
        git \
        unzip \
        xz-utils \
        # ---- Linux 桌面平台 ----
        clang \
        lld \
        cmake \
        ninja-build \
        pkg-config \
        libgtk-3-dev \
        libstdc++-12-dev \
        liblzma-dev \
        libsecret-1-dev \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------
# 2) 可选：当指定了 CMAKE_VERSION 时，安装官方预编译二进制 cmake
#    覆盖系统仓库版本，保证跨平台统一版本。
# ---------------------------------------------------------------
RUN set -eux; \
    if [ -n "${CMAKE_VERSION}" ]; then \
        arch="$(dpkg --print-architecture)"; \
        case "$arch" in \
            amd64) cmake_arch="x86_64" ;; \
            arm64) cmake_arch="aarch64" ;; \
            *)     cmake_arch="x86_64" ;; \
        esac; \
        tarball="cmake-${CMAKE_VERSION}-linux-${cmake_arch}.tar.gz"; \
        url="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${tarball}"; \
        curl -fsSL "$url" -o /tmp/cmake.tar.gz; \
        tar -xzf /tmp/cmake.tar.gz -C /opt; \
        rm -f /tmp/cmake.tar.gz; \
        ln -sf "/opt/cmake-${CMAKE_VERSION}-linux-${cmake_arch}/bin/"* /usr/local/bin/; \
    fi

# ---------------------------------------------------------------
# 3) 可选：当指定了 NINJA_VERSION 时，安装官方预编译二进制 ninja
# ---------------------------------------------------------------
RUN set -eux; \
    if [ -n "${NINJA_VERSION}" ]; then \
        url="https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip"; \
        curl -fsSL "$url" -o /tmp/ninja.zip; \
        unzip -o /tmp/ninja.zip -d /usr/local/bin; \
        chmod +x /usr/local/bin/ninja; \
        rm -f /tmp/ninja.zip; \
    fi

# ---------------------------------------------------------------
# 4) Flutter Linux 桌面与 Web 平台预编译缓存
#    - Linux / Web 的 Dart 平台产物均需 precache；
#    - Windows 桌面不在本镜像构建（见 docs/windows-build.md）。
# ---------------------------------------------------------------
RUN flutter precache --linux --web \
    && flutter config --enable-linux-desktop \
    && flutter doctor -v \
    && chown -R root:root ${FLUTTER_HOME}

# 确保工具链可被识别
ENV PATH="/usr/local/bin:${PATH}"

WORKDIR /tmp

CMD ["/bin/bash"]
