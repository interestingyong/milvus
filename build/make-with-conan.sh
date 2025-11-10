#!/bin/bash
# build-with-conan.sh

# 先移除可能存在的远程源
conan remote remove conan-center 2>/dev/null || true
conan remote remove bincrafters 2>/dev/null || true

# 配置 Conan 源
conan remote add conan-center https://mirrors.bfsu.edu.cn/conan/center
conan remote add bincrafters https://bincrafters.jfrog.io/artifactory/api/conan/public-conan

# 显示配置结果
echo "=== Conan 远程源列表 ==="
conan remote list
echo "========================="

# 执行构建命令
make 
make install
