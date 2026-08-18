#!/usr/bin/env bash
#
# build.sh —— 构建 flutter-desktop-builder 镜像
#
# 可在命令行指定 Flutter 及主要工具的版本，例如：
#   ./build.sh --flutter 3.44.0 --cmake 3.30.5 --ninja 1.12.1
#
# 所有版本都有默认值，不传则使用默认版本。
#
set -euo pipefail

# ---------------------------------------------------------------
# 默认版本（工具版本必须有默认值，不能为空）
# ---------------------------------------------------------------
FLUTTER_VERSION="${FLUTTER_VERSION:-3.44.0}"
CMAKE_VERSION="${CMAKE_VERSION:-3.31.6}"
NINJA_VERSION="${NINJA_VERSION:-1.13.2}"

IMAGE_NAME="${IMAGE_NAME:-linfulong/flutter-desktop-builder}"
# 镜像 tag 默认跟随 Flutter 版本，例如 linfulong/flutter-desktop-builder:3.44.0
IMAGE_TAG="${IMAGE_TAG:-${FLUTTER_VERSION}}"

usage() {
    cat <<'EOF'
用法: ./build.sh [选项]

选项:
  --flutter <版本>   指定基础镜像 ghcr.io/cirruslabs/flutter 的 tag（默认 3.44.0）
  --cmake <版本>     指定 cmake 版本（默认 3.31.6）
  --ninja <版本>     指定 ninja 版本（默认 1.13.2）
  --image <名称>     指定镜像名（默认 linfulong/flutter-desktop-builder）
  --tag <标签>       指定镜像标签（默认跟随 Flutter 版本）
  --platform <平台>  指定构建平台，如 linux/amd64,linux/arm64（docker buildx）
  --push             构建完成后推送到 registry（需 IMAGE_NAME 为完整 registry 路径）
  --no-cache         不使用构建缓存
  -h, --help         显示本帮助

也可通过环境变量覆盖：FLUTTER_VERSION / CMAKE_VERSION / NINJA_VERSION /
IMAGE_NAME / IMAGE_TAG。

示例:
  # 使用默认版本构建
  ./build.sh

  # 指定 flutter 与 cmake 版本
  ./build.sh --flutter 3.44.0 --cmake 3.30.5

  # 多平台构建并推送
  ./build.sh --platform linux/amd64,linux/arm64 --push --image ghcr.io/you/flutter-desktop-builder
EOF
}

# ---------------------------------------------------------------
# 参数解析
# ---------------------------------------------------------------
PLATFORM=""
PUSH=false
NO_CACHE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --flutter)   FLUTTER_VERSION="$2"; shift 2 ;;
        --cmake)     CMAKE_VERSION="$2";    shift 2 ;;
        --ninja)     NINJA_VERSION="$2";    shift 2 ;;
        --image)     IMAGE_NAME="$2";       shift 2 ;;
        --tag)       IMAGE_TAG="$2";        shift 2 ;;
        --platform)  PLATFORM="$2";         shift 2 ;;
        --push)      PUSH=true;             shift ;;
        --no-cache)  NO_CACHE=true;         shift ;;
        -h|--help)   usage; exit 0 ;;
        *) echo "未知选项: $1" >&2; usage; exit 1 ;;
    esac
done

# ---------------------------------------------------------------
# 构建参数
# ---------------------------------------------------------------
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

BUILD_ARGS=(
    --build-arg "FLUTTER_BASE_TAG=${FLUTTER_VERSION}"
    --build-arg "CMAKE_VERSION=${CMAKE_VERSION}"
    --build-arg "NINJA_VERSION=${NINJA_VERSION}"
)

[[ "$NO_CACHE" == true ]] && BUILD_ARGS+=(--no-cache)

echo "=============================================="
echo "构建参数:"
echo "  基础 Flutter 镜像 tag : ${FLUTTER_VERSION}"
echo "  cmake 版本            : ${CMAKE_VERSION}"
echo "  ninja 版本            : ${NINJA_VERSION}"
echo "  镜像名                : ${FULL_IMAGE}"
echo "  平台                  : ${PLATFORM:-<默认>}"
echo "  推送                  : ${PUSH}"
echo "=============================================="

# ---------------------------------------------------------------
# 构建
# ---------------------------------------------------------------
if [[ -n "$PLATFORM" ]]; then
    # 多平台构建需 buildx 与 QEMU
    if ! docker buildx version >/dev/null 2>&1; then
        echo "错误: 多平台构建需要 Docker Buildx。" >&2
        exit 1
    fi
    docker buildx build \
        --platform "$PLATFORM" \
        --tag "$FULL_IMAGE" \
        "${BUILD_ARGS[@]}" \
        $([ "$PUSH" == true ] && echo --push || echo --load) \
        .
else
    docker build "${BUILD_ARGS[@]}" --tag "$FULL_IMAGE" .
    if [[ "$PUSH" == true ]]; then
        docker push "$FULL_IMAGE"
    fi
fi

echo ""
echo "=============================================="
echo "构建完成: ${FULL_IMAGE}"
echo ""
echo "用法示例:"
echo "  docker run --rm -v \$(pwd):/app -w /app ${FULL_IMAGE} \\"
echo "      flutter build web"      "   # Web 平台"
echo "      flutter build linux"    "   # Linux 桌面平台"
echo "=============================================="
