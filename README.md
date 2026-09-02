# Flutter Linux/Web Builder

基于以下两个同版本镜像合成，同时支持 Flutter Web 与 Linux desktop 应用编译：

- `ghcr.io/gmeligio/flutter-linux:3.47.2`
- `ghcr.io/gmeligio/flutter-web:3.47.2`

默认生成镜像：

```text
linfulongnet/flutter-linux-web:3.47.2
```

镜像包含 Clang、CMake、Ninja、pkg-config、GTK 3 和 `libsecret-1-dev` 开发库及 Linux engine artifacts，并从 Web 基础镜像合入 Web SDK/engine artifacts。镜像构建过程中会实际编译一次 Web 和 Linux 示例应用，验证两套工具链。

> 上游两个 3.47.2 镜像目前仅提供 `linux/amd64`。

## 构建镜像

```bash
./build.sh
```

等价的 Docker 命令：

```bash
docker build \
  --build-arg FLUTTER_VERSION=3.47.2 \
  -t linfulongnet/flutter-linux-web:3.47.2 .
```

构建并推送到镜像仓库：

```bash
./build.sh \
  --image ghcr.io/your-name/flutter-linux-web \
  --push
```

## 编译 Flutter 应用

在 Flutter 项目目录中编译 Web：

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  linfulongnet/flutter-linux-web:3.47.2 \
  flutter build web --release
```

编译 Linux desktop：

```bash
docker run --rm \
  -v "$PWD:/workspace" \
  -w /workspace \
  linfulongnet/flutter-linux-web:3.47.2 \
  flutter build linux --release
```

镜像默认运行用户为 `root`，容器内可直接使用 `apt-get` 安装额外依赖。上游 SDK 仍由 UID/GID `1001:1001` 的 `flutter` 用户准备；如需非 root 运行，可增加 `--user flutter`，并确保宿主项目目录允许该用户写入 `.dart_tool/` 与 `build/`。
