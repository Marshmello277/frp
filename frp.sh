#!/usr/bin/env /bin/bash

# 获取操作系统和架构信息
OS=$(uname -s)
ARCH=$(uname -m)

# 输出操作系统和架构信息
echo "检测到的操作系统：$OS"
echo "检测到的架构：$ARCH"

# 判断网络是否能访问 Google
if ping -c 1 -W 1 google.com > /dev/null 2>&1; then
    prefix=""
    echo "检测到您的网络可以连接到 Google，不使用镜像下载"
else
    prefix="https://gh.gylcyh.us.kg/"
    echo "检测到您的网络无法连接到 Google，使用镜像下载"
fi

# 创建临时文件夹
current_dir=$(pwd)
temp_dir=$(mktemp -d)
echo "下载临时文件夹创建在: $temp_dir"
cd "$temp_dir"

# 操作系统和架构的判断
case "$OS" in
    Linux)
        case "$ARCH" in
            x86_64)
                echo "下载 x86_64 架构的文件"
                if ! curl -o frp-panel -fSL "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-amd64"; then
                    wget -O frp-panel "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-amd64" || { echo "下载失败"; exit 1; }
                fi
                ;;
            aarch64)
                echo "下载 aarch64 架构的文件"
                if ! curl -o frp-panel -fSL "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-arm64"; then
                    wget -O frp-panel "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-arm64" || { echo "下载失败"; exit 1; }
                fi
                ;;
            armv7l)
                echo "下载 armv7l 架构的文件"
                if ! curl -o frp-panel -fSL "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-armv7l"; then
                    wget -O frp-panel "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-armv7l" || { echo "下载失败"; exit 1; }
                fi
                ;;
            armv6l)
                echo "下载 armv6l 架构的文件"
                if ! curl -o frp-panel -fSL "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-armv6l"; then
                    wget -O frp-panel "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-armv6l" || { echo "下载失败"; exit 1; }
                fi
                ;;
            *)
                echo "不支持的架构：$ARCH"
                exit 1
                ;;
        esac
        ;;
    Darwin)
        case "$ARCH" in
            x86_64)
                echo "下载 x86_64 架构的文件"
                if ! curl -o frp-panel -fSL "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-darwin-amd64"; then
                    wget -O frp-panel "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-darwin-amd64" || { echo "下载失败"; exit 1; }
                fi
                ;;
            arm64)
                echo "下载 arm64 架构的文件"
                if ! curl -o frp-panel -fSL "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-darwin-arm64"; then
                    wget -O frp-panel "${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-darwin-arm64" || { echo "下载失败"; exit 1; }
                fi
                ;;
            *)
                echo "不支持的架构：$ARCH"
                exit 1
                ;;
        esac
        ;;
    *)
        echo "不支持的操作系统：$OS"
        exit 1
        ;;
esac

# 给下载的文件添加执行权限
sudo chmod +x frp-panel

# 返回当前目录
cd "$current_dir"

# 新的可执行文件路径
new_executable_path="$temp_dir/frp-panel"

# 获取启动参数
get_start_params() {
    read -p "请输入启动参数：" params
    echo "$params"
}

# 查找 frpp 服务的执行文件路径
find_frpp_executable() {
    service_file=$(systemctl show -p FragmentPath frpp.service 2>/dev/null | cut -d'=' -f2)
    if [[ -z "$service_file" || ! -f "$service_file" ]]; then
        echo ""
        return 1
    fi
    exec_start=$(grep -oP '^ExecStart=\K.*' "$service_file")
    if [[ -z "$exec_start" ]]; then
        echo ""
        return 1
    fi
    executable_path=$(echo "$exec_start" | awk '{print $1}')
    echo "$executable_path"
}

# 检查 frpp 服务是否存在
if systemctl list-units --type=service | grep -q frpp; then
    echo "frpp 服务存在"
    executable_path=$(find_frpp_executable)
    if [ -z "$executable_path" ]; then
        echo "无法找到 frpp 服务的执行文件路径，请检查 systemd 文件"
        exit 1
    fi
    echo "更新程序到原路径：$executable_path"
    sudo rm -rf "$executable_path"
    sudo cp "$new_executable_path" "$executable_path"
    sudo systemctl restart frpp
    echo "frpp 服务已更新。"
    $executable_path version
    exit 0
else
    echo "frpp 服务不存在，进行安装"
fi

# 安装 frp-panel
sudo cp "$new_executable_path" .

# 获取启动参数
if [ -n "$1" ]; then
    start_params="$@"
else
    start_params=$(get_start_params)
fi

sudo ./frp-panel install $start_params

echo "frp-panel 服务安装完成, 安装路径：$(pwd)/frp-panel"

# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启动 frp-panel 服务
sudo ./frp-panel start

# 查看版本
sudo ./frp-panel version

echo "frp-panel 服务已启动"

# 启动并启用 frpp 服务
sudo systemctl restart frpp
sudo systemctl enable frpp
