# syntax=docker/dockerfile:1

ARG FLUTTER_VERSION=3.47.2

# flutter-web contains the Web engine artifacts, while flutter-linux contains
# the native Linux build toolchain and Linux engine artifacts.
FROM ghcr.io/gmeligio/flutter-web:${FLUTTER_VERSION} AS flutter-web
FROM ghcr.io/gmeligio/flutter-linux:${FLUTTER_VERSION}

LABEL org.opencontainers.image.title="flutter-linux-web" \
      org.opencontainers.image.description="Flutter builder for Web and Linux desktop applications"

USER root

# Keep the platform dependencies explicit in this image. The Linux upstream
# image already contains these packages, so this remains idempotent if its
# package set changes in a future release.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        clang \
        cmake \
        ninja-build \
        pkg-config \
        libgtk-3-dev \
        libsecret-1-dev \
    && rm -rf /var/lib/apt/lists/*

# The SDK is owned by the upstream flutter user. Allow root to invoke Flutter
# without Git's "dubious ownership" protection rejecting that repository.
RUN git config --system --add safe.directory /home/flutter/sdks/flutter

# Both upstream images use the same Flutter release and SDK location. Merge
# only the Web-specific artifacts so the Linux SDK cache is left intact.
COPY --from=flutter-web --chown=flutter:flutter \
    /home/flutter/sdks/flutter/bin/cache/flutter_web_sdk/ \
    /home/flutter/sdks/flutter/bin/cache/flutter_web_sdk/
COPY --from=flutter-web --chown=flutter:flutter \
    /home/flutter/sdks/flutter/bin/cache/flutter_web_sdk.stamp \
    /home/flutter/sdks/flutter/bin/cache/flutter_web_sdk.stamp

USER flutter:flutter
WORKDIR /home/flutter

# The Linux base image installs clang, CMake, Ninja, pkg-config and GTK 3.
# Verify that toolchain, enable both platforms, and compile a smoke-test app so
# missing packages or incomplete platform caches fail during image creation.
RUN command -v clang \
    && command -v cmake \
    && command -v ninja \
    && command -v pkg-config \
    && pkg-config --exists gtk+-3.0 \
    && flutter config --enable-web --enable-linux-desktop \
    && flutter precache --web --linux \
    && flutter create --platforms=web,linux /tmp/flutter_platform_smoke_test \
    && cd /tmp/flutter_platform_smoke_test \
    && flutter build web --release \
    && flutter build linux --release \
    && cd /home/flutter \
    && rm -rf /tmp/flutter_platform_smoke_test \
    && flutter doctor -v

# Root is the default runtime user so callers can install extra build
# dependencies with apt-get. Use `docker run --user flutter ...` when a
# rootless container is preferred.
USER root

CMD ["/bin/bash"]
