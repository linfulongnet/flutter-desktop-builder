# Flutter Desktop Builder

用于在 Linux 容器中构建 Flutter Web 和 Linux desktop 应用的镜像。

## 镜像

```text
ghcr.io/linfulongnet/flutter-desktop-builder:3.44.0
```

镜像包含：

- Flutter 3.44.0
- Web 与 Linux desktop 预缓存 SDK
- Clang、LLD、CMake 3.31.6、Ninja 1.13.2
- GTK3、pkg-config 及 Linux 桌面应用所需的开发库

## 使用

拉取镜像：

```bash
docker pull ghcr.io/linfulongnet/flutter-desktop-builder:3.44.0
```

在项目目录中构建 Web 应用：

```bash
docker run --rm \
  -v "$PWD":/app \
  -w /app \
  ghcr.io/linfulongnet/flutter-desktop-builder:3.44.0 \
  flutter build web --release
```

构建 Linux desktop 应用：

```bash
docker run --rm \
  -v "$PWD":/app \
  -w /app \
  ghcr.io/linfulongnet/flutter-desktop-builder:3.44.0 \
  flutter build linux --release
```

## 本地构建

使用默认版本构建：

```bash
./build.sh
```

指定版本并推送到 GHCR：

```bash
./build.sh \
  --flutter 3.44.0 \
  --cmake 3.31.6 \
  --ninja 1.13.2 \
  --image ghcr.io/linfulongnet/flutter-desktop-builder \
  --push
```

`--platform` 可用于通过 Docker Buildx 构建指定的 Linux 容器架构。
