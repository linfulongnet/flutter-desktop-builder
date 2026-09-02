#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.2}"
IMAGE_NAME="${IMAGE_NAME:-linfulongnet/flutter-linux-web}"
IMAGE_TAG="${IMAGE_TAG:-}"

usage() {
    cat <<'EOF'
用法: ./build.sh [选项]

选项:
  --flutter <版本>   指定 gmeligio Flutter Linux/Web 基础镜像版本（默认 3.47.2）
  --image <名称>     指定镜像名（默认 linfulongnet/flutter-linux-web）
  --tag <标签>       指定镜像标签（默认跟随 Flutter 版本）
  --platform <平台>  构建平台；上游 3.47.2 镜像仅支持 linux/amd64
  --push             构建完成后推送到 registry
  --no-cache         不使用构建缓存
  -h, --help         显示本帮助

也可通过 FLUTTER_VERSION、IMAGE_NAME、IMAGE_TAG 环境变量覆盖默认值。

示例:
  ./build.sh
  ./build.sh --image ghcr.io/you/flutter-linux-web --push
EOF
}

PLATFORM=""
PUSH=false
NO_CACHE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --flutter)  FLUTTER_VERSION="$2"; shift 2 ;;
        --image)    IMAGE_NAME="$2";       shift 2 ;;
        --tag)      IMAGE_TAG="$2";        shift 2 ;;
        --platform) PLATFORM="$2";         shift 2 ;;
        --push)     PUSH=true;              shift ;;
        --no-cache) NO_CACHE=true;          shift ;;
        -h|--help)  usage; exit 0 ;;
        *) echo "未知选项: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -n "$PLATFORM" && "$PLATFORM" != "linux/amd64" ]]; then
    echo "错误: gmeligio 的 Flutter Linux/Web 基础镜像仅提供 linux/amd64。" >&2
    exit 1
fi

IMAGE_TAG="${IMAGE_TAG:-$FLUTTER_VERSION}"
FULL_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"
BUILD_ARGS=(
    --build-arg "FLUTTER_VERSION=${FLUTTER_VERSION}"
    --tag "$FULL_IMAGE"
)

[[ "$NO_CACHE" == true ]] && BUILD_ARGS+=(--no-cache)

echo "构建镜像: ${FULL_IMAGE}"
echo "基础镜像: ghcr.io/gmeligio/flutter-linux:${FLUTTER_VERSION}"
echo "          ghcr.io/gmeligio/flutter-web:${FLUTTER_VERSION}"

if [[ "$PUSH" == true || -n "$PLATFORM" ]]; then
    if ! docker buildx version >/dev/null 2>&1; then
        echo "错误: --push/--platform 需要 Docker Buildx。" >&2
        exit 1
    fi

    BUILDX_ARGS=("${BUILD_ARGS[@]}" --platform "${PLATFORM:-linux/amd64}")
    if [[ "$PUSH" == true ]]; then
        BUILDX_ARGS+=(--push)
    else
        BUILDX_ARGS+=(--load)
    fi
    docker buildx build "${BUILDX_ARGS[@]}" .
else
    docker build "${BUILD_ARGS[@]}" .
fi

echo "构建完成: ${FULL_IMAGE}"
echo "Web:   docker run --rm -v \"\$PWD:/workspace\" -w /workspace ${FULL_IMAGE} flutter build web --release"
echo "Linux: docker run --rm -v \"\$PWD:/workspace\" -w /workspace ${FULL_IMAGE} flutter build linux --release"
