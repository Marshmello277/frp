S=$(uname -s)
ARCH=$(uname -m)

echo "检测到的操作系统：$OS"
echo "检测到的架构：$ARCH"

if ping -c 1 -W 1 google.com > /dev/null 2>&1; then
    prefix=""
    echo "检测到您的网络可以连接到 Google，不使用镜像下载"
else
    prefix="https://mirror.ghproxy.com/"
    echo "检测到您的网络无法连接到 Google，使用镜像下载"
fi

current_dir=$(pwd)
temp_dir=$(mktemp -d)
echo "下载临时文件夹创建在: $temp_dir"
cd "$temp_dir"

case "$OS" in
    Linux)
        case "$ARCH" in
            x86_64)
                url="${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-amd64"
                ;;
            aarch64)
                url="${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-arm64"
                ;;
            armv7l)
                url="${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-armv7l"
                ;;
            armv6l)
                url="${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-linux-armv6l"
                ;;
        esac
        ;;
    Darwin)
        case "$ARCH" in
            x86_64)
                url="${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-darwin-amd64"
                ;;
            arm64)
                url="${prefix}https://github.com/VaalaCat/frp-panel/releases/latest/download/frp-panel-darwin-arm64"
                ;;
        esac
        ;;
    *)
        echo "不支持的操作系统：$OS"
        exit 1
        ;;
esac

if [ -z "$url" ]; then
    echo "未能为您的架构找到下载链接。"
    exit 1
fi

# 优先使用 curl 下载
if command -v curl > /dev/null 2>&1; then
    echo "使用 curl 下载 frp-panel..."
    curl -L -o frp-panel "$url"
    if [ $? -ne 0 ]; then
        echo "使用 curl 下载失败。"
        exit 1
    fi
else
    # 备用使用 wget
    echo "使用 wget 下载 frp-panel..."
    wget --no-check-certificate -O frp-panel "$url"
    if [ $? -ne 0 ]; then
        echo "使用 wget 下载失败。"
        exit 1
    fi
fi

sudo chmod +x frp-panel

cd "$current_dir"

new_executable_path="$temp_dir/frp-panel"

get_start_params() {
    read -p "请输入启动参数：" params
    echo "$params"
}

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

sudo cp "$new_executable_path" .

if [ -n "$1" ]; then
    start_params="$@"
else
    start_params=$(get_start_params)
fi

sudo ./frp-panel install $start_params

echo "frp-panel 服务安装完成, 安装路径：$(pwd)/frp-panel"

sudo systemctl daemon-reload

sudo ./frp-panel start

sudo ./frp-panel version

echo "frp-panel 服务已启动"

sudo systemctl restart frpp

sudo systemctl enable frpp



