#!/bin/bash
set -e  # 出现错误时立即退出

# 统一的 Milvus 多架构构建脚本
# 用法: TARGETARCH=arm64 ./build.sh 或 TARGETARCH=amd64 ./build.sh

# 1. 参数验证和初始化
echo "=== Milvus 多架构构建脚本 ==="

# 检查必需的环境变量
if [ -z "$TARGETARCH" ]; then
    echo "错误: 必须设置 TARGETARCH 环境变量 (arm64 或 amd64)"
    echo "TARGETARCH=arm64 ./build-milvus.sh"
    exit 1
fi

if [ "$TARGETARCH" != "arm64" ] && [ "$TARGETARCH" != "amd64" ]; then
    echo "错误: TARGETARCH 必须是 'arm64' 或 'amd64'"
    exit 1
fi

echo "构建架构: $TARGETARCH"

# 2. 生成镜像标签
generate_image_tag() {
    local date=$(date +%Y%m%d)
    local git_short_commit=$(git rev-parse --short HEAD)
    local branch_name=$(git rev-parse --abbrev-ref HEAD)
    local image_tag="${branch_name}-${date}-${git_short_commit}-${TARGETARCH}"
    echo "$image_tag"
}

IMAGE_TAG=$(generate_image_tag)
echo "生成的镜像标签: $IMAGE_TAG"

# 3. 环境准备
echo "=== 环境准备 ==="

# 设置 Docker 镜像加速
if [ -f "./build/set_docker_mirror.sh" ]; then
    echo "设置 Docker 镜像加速..."
    ./build/set_docker_mirror.sh
else
    echo "警告: set_docker_mirror.sh 不存在，跳过镜像加速设置"
fi

# 清理 Makefile 的 dirty 标记
if [ -f "Makefile" ]; then
    echo "清理 Makefile 的 dirty 标记..."
    sed -i. 's/--dirty="-dev"//g' Makefile
else
    echo "错误: Makefile 不存在"
    exit 1
fi

# 设置网络模式
export IS_NETWORK_MODE_HOST="true"
echo "设置网络模式: IS_NETWORK_MODE_HOST=true"

# 4. 缓存管理
#echo "=== 缓存管理 ==="
#CACHE_DIR="/tmp/krte/cache"

# 检查并创建缓存目录
#mkdir -p "$CACHE_DIR"

# 复用 Docker 缓存（如果存在）
#if [ -d "$CACHE_DIR/.docker" ]; then
#    echo "复用 Docker 缓存..."
#    cp -r "$CACHE_DIR/.docker" .
#else
#    echo "无现有缓存，将创建新缓存"
#fi

# 5. 根据架构设置参数
echo "=== 架构配置 ==="
if [ "$TARGETARCH" = "arm64" ]; then
    export PLATFORM_ARCH="arm64"
    BUILD_ARGS="--build-arg TARGETARCH=arm64"
    echo "配置为 ARM64 架构"
else
    export PLATFORM_ARCH="amd64" 
    BUILD_ARGS=""
    echo "配置为 AMD64 架构"
fi

# 6. 编译构建
echo "=== 编译构建 ==="
echo "执行编译命令..."

# 检查 builder.sh 是否存在
if [ ! -f "build/builder.sh" ]; then
    echo "错误: build/builder.sh 不存在"
    exit 1
fi

# 在 build/builder.sh 或 Makefile 中添加
export CARGO_REGISTRIES_CRATES_IO_PROTOCOL=sparse
export CARGO_REGISTRIES_CRATES_IO_INDEX=https://mirrors.ustc.edu.cn/crates.io-index/

# 执行编译
if [ "$TARGETARCH" = "arm64" ]; then
    PLATFORM_ARCH="arm64" build/builder.sh /bin/bash -c "git config --global http.proxy http://192.168.1.202:8889 ; git config --global https.proxy http://192.168.1.202:8889;make clean;make install"
else
    build/builder.sh /bin/bash -c "make install"
fi

# 7. 镜像构建
echo "=== Docker 镜像构建 ==="
export MILVUS_IMAGE_TAG="$IMAGE_TAG"
export DOCKER_BUILDKIT=1

echo "构建镜像标签: $MILVUS_IMAGE_TAG"
echo "构建参数: $BUILD_ARGS"

# 执行镜像构建
if [ -f "build/build_image.sh" ]; then
    #$BUILD_ARGS build/build_image.sh
     bash -x build/build_image.sh
else
    echo "错误: build/build_image.sh 不存在"
    exit 1
fi

# 8. 更新缓存
#echo "=== 更新缓存 ==="
#if [ -d ".docker" ]; then
#    echo "更新 Docker 缓存..."
#    cp -r .docker "$CACHE_DIR/"
#    echo "缓存已更新到: $CACHE_DIR/.docker"
#else
#    echo "警告: .docker 目录不存在，跳过缓存更新"
#fi

# 9. 验证构建结果
echo "=== 构建验证 ==="
if docker images | grep -q "$MILVUS_IMAGE_TAG"; then
    echo "✅ 镜像构建成功: $MILVUS_IMAGE_TAG"
    
    # 显示镜像信息
    echo "镜像信息:"
    docker images | grep "$MILVUS_IMAGE_TAG"
else
    echo "❌ 镜像构建失败"
    exit 1
fi

echo "=== 构建完成 ==="
echo "镜像名称: milvusdb/milvus:$MILVUS_IMAGE_TAG"
echo "架构: $TARGETARCH"
echo "下一步: 使用 docker push 推送镜像到仓库"
