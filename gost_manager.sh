#!/bin/bash

# singbox 节点管理脚本

# 全局配置文件路径
SERVICE_FILE="/etc/systemd/system/gost.service"
GOST_BIN="/usr/local/bin/gost"
CONFIG_FILE="/etc/gost/config.json"

# 菜单相关函数
function main_menu() {
    clear
    echo "========================="
    echo "      gost 节点管理      "
    echo "========================="
    echo "1. 安装 gost"
    echo "2. 卸载 gost"
    echo "5. 重启 gost"
    echo "6. 新增规则"
    echo "7. 删除规则"
    echo "8. 查看日志"
    echo "0. 退出"
    read -p "请选择操作: " choice
    case $choice in
        1) install_gost ;;
        2) uninstall_gost ;;
        3) start_gost ;;
        4) stop_gost ;;
        5) restart_gost ;;
        6) add_gost_rules ;;
        7) delete_gost_rules ;;
        8) view_gost_logs ;;
        0) exit 0 ;;
        *) echo "无效选择"; read -p "按回车继续..."; main_menu ;;
    esac
}

# 检查系统类型和架构
function check_sys() {
    if [[ -f /etc/redhat-release ]]; then
        release="centos"
    elif grep -qi "debian" /etc/issue; then
        release="debian"
    elif grep -qi "ubuntu" /etc/issue; then
        release="ubuntu"
    elif grep -qi "centos" /etc/issue; then
        release="centos"
    elif grep -qi "debian" /proc/version; then
        release="debian"
    elif grep -qi "ubuntu" /proc/version; then
        release="ubuntu"
    elif grep -qi "centos" /proc/version; then
        release="centos"
    else
        release="unknown"
    fi

    arch=$(uname -m)
    if [[ "$arch" == "x86_64" || "$arch" == "amd64" ]]; then
        bit="amd64"
    elif [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
        bit="arm64"
    else
        bit="amd64"
    fi
}

# 安装 gost 2.11.2（自动适配架构）
function install_gost() {
    # 检查是否已安装
    if command -v gost >/dev/null 2>&1; then
        INSTALLED_VERSION=$(gost -V 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        echo "检测到 gost 已安装，版本：$INSTALLED_VERSION"
        return 0
    fi

    GOST_VERSION="2.11.2"
    INSTALL_PATH="/usr/local/bin/gost"
    TEMP_DIR="/tmp/gost_install"
    check_sys  # 设置 $bit
    GOST_URL="https://github.com/ginuerzh/gost/releases/download/v${GOST_VERSION}/gost-linux-${bit}-${GOST_VERSION}.gz"
    
    # 清理之前的临时文件
    rm -rf "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
    
    echo "正在下载 gost $GOST_VERSION [$bit]..."
    if ! wget --no-check-certificate -O "$TEMP_DIR/gost.gz" "$GOST_URL"; then
        echo "gost 下载失败，请检查网络连接或手动下载。"
        return 1
    fi
    
    echo "正在解压 gost..."
    cd "$TEMP_DIR"
   
    if ! gunzip -f gost.gz; then
        echo "gost 解压失败！"
        return 1
    fi
   
    # 查找实际的可执行文件 - 针对 gost 的目录结构
    # gost 解压后通常是 gost-linux-架构-版本/ 目录，里面有 gost-linux-架构 可执行文件
    GOST_BINARY=$(find . -name "gost-linux-*" -type f | head -1)
    
    if [ -z "$GOST_BINARY" ]; then
        # 备用方案：查找任何可执行文件
        GOST_BINARY=$(find . -type f -executable | head -1)
    fi
    
    if [ -z "$GOST_BINARY" ]; then
        # 最后方案：查找目录中的文件（可能权限还没设置）
        GOST_BINARY=$(find . -type f ! -name "*.gz" | grep -E "(gost|GOST)" | head -1)
    fi
    
    # 检查是否找到了文件
    if [ -z "$GOST_BINARY" ] || [ ! -f "$GOST_BINARY" ]; then
        echo "错误：找不到 gost 可执行文件！"
        echo "临时目录内容："
        ls -la
        return 1
    fi
   
    # 复制到安装目录
    echo "正在复制 $GOST_BINARY 执行文件到安装目录..."
    if ! cp "$GOST_BINARY" "$INSTALL_PATH"; then
        echo "复制文件失败！"
        return 1
    fi
    
    chmod +x "$INSTALL_PATH"
    
    # 清理临时文件
    rm -rf "$TEMP_DIR"
    
    if command -v gost >/dev/null 2>&1; then
        echo "gost 安装成功，版本信息如下："
        gost -V
        # 创建 gost systemd 服务文件
        create_gost_service
    else
        echo "gost 安装失败！"
        return 1
    fi
}




# 卸载 gost
function uninstall_gost() {
    echo "正在卸载 gost..."

    # 停止并禁用 systemd 服务（如果存在）
    if systemctl list-unit-files | grep -q '^gost.service'; then
        systemctl stop gost.service
        systemctl disable gost.service
        rm -f /etc/systemd/system/gost.service
        systemctl daemon-reload
        echo "已移除 systemd 服务。"
    fi

    # 删除主程序
    if [ -f /usr/local/bin/gost ]; then
        rm -f /usr/local/bin/gost
        echo "已删除 /usr/local/bin/gost"
    fi

    # 删除 gm 软链接
    if [ -f /usr/local/bin/gm ]; then
        rm -f /usr/local/bin/gm
        echo "已删除 /usr/local/bin/gm"
    fi

    # 删除配置文件和目录
    if [ -d /etc/gost ]; then
        rm -rf /etc/gost
        echo "已删除 /etc/gost 配置目录"
    fi

    # 删除脚本目录（支持家目录和当前目录）
    if [ -d "$HOME/gost-manager-main" ]; then
        rm -rf "$HOME/gost-manager-main"
        echo "已删除 $HOME/gost-manager-main 脚本目录"
    elif [ -d "./gost-manager-main" ]; then
        rm -rf "./gost-manager-main"
        echo "已删除 ./gost-manager-main 脚本目录"
    fi


    # 验证卸载结果
    if ! command -v gost >/dev/null 2>&1 && [ ! -f /usr/local/bin/gost ] && [ ! -f /usr/local/bin/gm ]; then
        echo "gost 及相关脚本和软链接已全部卸载完成。"
    else
        echo "部分文件未能成功删除，请手动检查。"
    fi
}


# 启动 gost
function start_gost() {
    echo "正在启动 gost 服务..."
    sudo systemctl start gost
    if [ $? -eq 0 ]; then
        echo "gost 服务已启动。"
    else
        echo "gost 服务启动失败，请检查服务状态。"
    fi
}

# 停止 gost
function stop_gost() {
    echo "正在停止 gost 服务..."
    sudo systemctl stop gost
    if [ $? -eq 0 ]; then
        echo "gost 服务已停止。"
    else
        echo "gost 服务停止失败，请检查服务状态。"
    fi
}


# 重启 gost
function restart_gost() {
    echo "正在重启 gost 服务..."
    sudo systemctl restart gost
    if [ $? -eq 0 ]; then
        echo "gost 服务已成功重启。"
    else
        echo "gost 服务重启失败，请检查服务状态。"
    fi
}


# 查看 gost 实时日志
function view_gost_logs() {
    echo "正在显示 gost 实时日志（按 Ctrl+C 退出）..."
    sudo journalctl -u gost -f
}

# 新增gost转发配置
function add_gost_rules() {
    # 新增一条 gost 转发配置
    select_port
    select_gost_protocol
    input_gost_target
    input_gost_target_port
    add_gost_rule_and_restart
}


# 查看现有转发规则
function view_gost_rules() {
    CONFIG_FILE="/etc/gost/config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "未找到配置文件。"
        return 1
    fi
    echo "现有转发规则："
    jq -r '
        .ServeNodes[]
        | capture("^(?<proto>[a-z+]+)://:(?<listen_port>[0-9]+|\\*)/(?<target>.+):(?<target_port>[0-9]+)$")
        | "监听端口: \(.listen_port), 协议: \(.proto), 目标: \(.target), 目标端口: \(.target_port)"
    ' "$CONFIG_FILE" | nl -w1 -s': '
}



function delete_gost_rules() {
    CONFIG_FILE="/etc/gost/config.json"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "未找到配置文件。"
        return 1
    fi

    # 展示现有规则
    view_gost_rules

    # 让用户输入要删除的监听端口
    read -p "请输入要删除的监听端口: " del_port
    if [[ ! "$del_port" =~ ^[0-9]+$ ]] || [ "$del_port" -lt 1 ] || [ "$del_port" -gt 65535 ]; then
        echo "无效端口号。"
        return 1
    fi

    # 删除对应端口的所有规则
    tmp=$(mktemp)
    jq --arg port ":$del_port/" '
        .ServeNodes |= map(select(test($port) | not))
    ' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"

    echo "已删除监听端口为 $del_port 的所有规则。"

    # 重启 gost 服务
    restart_gost
}

# gost定时重启配置
function schedule_gost_restart() {
    # 配置 gost 的定时重启任务
    echo "正在配置 gost 的定时重启任务..."
}



# 检查是否为 root 用户
function check_root() {
    # 如果不是 root 用户，则提示并退出
    if [ "$(id -u)" != "0" ]; then
        echo "请以 root 用户身份运行此脚本！"
        exit 1
    fi
}


# 选择端口
function select_port() {
    CONFIG_FILE="/etc/gost/config.json"
    echo "========================="
    echo "      选择 gost 监听端口"
    echo "========================="
    echo "1) 随机端口（默认）"
    echo "2) 自定义端口"
    while true; do
        read -p "请选择端口设置方式 [1/2]: " mode
        if [[ -z "$mode" ]]; then
            mode="1"
        fi
        case $mode in
            1)
                # 随机分配端口
                local max_attempts=10
                local attempt=0
                while [ $attempt -lt $max_attempts ]; do
                    port=$((2000 + RANDOM % 58001))
                    # 用 jq 检查 ServeNodes 是否已包含该端口
                    if [ -f "$CONFIG_FILE" ] && jq -e --arg p "$port" '.ServeNodes[] | select(test(":" + $p + "$"))' "$CONFIG_FILE" >/dev/null; then
                        ((attempt++))
                        continue
                    fi
                    # 检查系统端口占用
                    if ss -tuln | grep -q ":$port "; then
                        ((attempt++))
                        continue
                    fi
                    GOST_PORT=$port
                    echo "随机选择端口: $GOST_PORT"
                    break
                done
                if [ -z "$GOST_PORT" ]; then
                    echo "无法找到可用的随机端口，请选择自定义端口"
                    continue
                fi
                ;;
            2)
                while true; do
                    read -p "请输入端口号 (1-65535): " port
                    if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                        echo "无效端口号，请输入1-65535之间的数字"
                        continue
                    fi
                    # 用 jq 检查 ServeNodes 是否已包含该端口
                    if [ -f "$CONFIG_FILE" ] && jq -e --arg p "$port" '.ServeNodes[] | select(test(":" + $p + "$"))' "$CONFIG_FILE" >/dev/null; then
                        echo "端口 $port 已被 gost 配置使用，请选择其他端口"
                        continue
                    fi
                    if ss -tuln | grep -q ":$port "; then
                        read -p "端口 $port 可能已被系统其他服务占用，是否继续? (y/n): " confirm
                        if [[ $confirm =~ ^[Yy]$ ]]; then
                            GOST_PORT=$port
                            break
                        else
                            continue
                        fi
                    else
                        GOST_PORT=$port
                        break
                    fi
                done
                ;;
            *)
                echo "无效选择，请输入 1 或 2"
                continue
                ;;
        esac
        break
    done
    echo "设置端口: $GOST_PORT"
}

function create_gost_service() {
    echo "正在创建 gost systemd 服务文件..."

    # 创建默认配置文件（如不存在）
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p /etc/gost
        cat <<EOF > "$CONFIG_FILE"
{
    "Debug": true,
    "Retries": 0,
    "ServeNodes": [
        "udp://127.0.0.1:65532"
    ]
}
EOF
        echo "已生成默认配置文件：$CONFIG_FILE"
    fi

    # 创建 systemd 服务文件
    cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=GOST Proxy Service
After=network.target

[Service]
Type=simple
ExecStart=$GOST_BIN -C $CONFIG_FILE
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    echo "gost 服务已创建"
    # 设置开机自启动
    enable_gost_autostart
    # 重启 gost 服务
    restart_gost
}

# 选择协议
function select_gost_protocol() {
    echo "========================="
    echo "      选择 gost 协议"
    echo "========================="
    echo "1) tcp（默认）"
    echo "2) udp"
    echo "3) tcp+udp"
    while true; do
        read -p "请选择协议 [1/2/3]: " proto
        if [[ -z "$proto" ]]; then
            proto="1"
        fi
        case $proto in
            1)
                GOST_PROTOCOL="tcp"
                ;;
            2)
                GOST_PROTOCOL="udp"
                ;;
            3)
                GOST_PROTOCOL="tcp+udp"
                ;;
            *)
                echo "无效选择，请输入 1、2 或 3"
                continue
                ;;
        esac
        break
    done
    echo "已选择协议: $GOST_PROTOCOL"
}

# 输入目标
function input_gost_target() {
    while true; do
        read -p "请输入目标IP或域名: " target
        # 检查是否为空
        if [[ -z "$target" ]]; then
            echo "目标不能为空，请重新输入。"
            continue
        fi
        # 如果是IPv6（包含冒号且不是以[开头），自动加上[]
        if [[ "$target" =~ : ]] && [[ ! "$target" =~ ^\[.*\]$ ]]; then
            GOST_TARGET="[$target]"
        else
            GOST_TARGET="$target"
        fi
        # 简单校验：IP格式或域名格式
        if [[ "$GOST_TARGET" =~ ^\[?[0-9a-fA-F:.]+\]?$ ]] || [[ "$GOST_TARGET" =~ ^[a-zA-Z0-9.-]+$ ]]; then
            break
        else
            echo "输入格式不正确，请重新输入。"
        fi
    done
    echo "已设置目标: $GOST_TARGET"
}

# 输入目标端口
function input_gost_target_port() {
    while true; do
        read -p "请输入目标端口 (1-65535): " port
        if [[ ! "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            echo "无效端口号，请输入1-65535之间的数字。"
            continue
        fi
        GOST_TARGET_PORT="$port"
        break
    done
    echo "已设置目标端口: $GOST_TARGET_PORT"
}

function add_gost_rule_and_restart() {
    # 构造新的 ServeNode
    local new_node=""
    case "$GOST_PROTOCOL" in
        tcp)
            new_node="tcp://:$GOST_PORT/$GOST_TARGET:$GOST_TARGET_PORT"
            ;;
        udp)
            new_node="udp://:$GOST_PORT/$GOST_TARGET:$GOST_TARGET_PORT"
            ;;
        tcp+udp)
            new_node="tcp://:$GOST_PORT/$GOST_TARGET:$GOST_TARGET_PORT"
            new_node2="udp://:$GOST_PORT/$GOST_TARGET:$GOST_TARGET_PORT"
            ;;
        *)
            echo "未知协议类型: $GOST_PROTOCOL"
            return 1
            ;;
    esac

    # 如果配置文件不存在，先创建一个基础结构
    if [ ! -f "$CONFIG_FILE" ]; then
        mkdir -p /etc/gost
        cat <<EOF > "$CONFIG_FILE"
{
    "Debug": true,
    "Retries": 0,
    "ServeNodes": []
}
EOF
    fi

    # 添加规则到 ServeNodes
    if [[ "$GOST_PROTOCOL" == "tcp+udp" ]]; then
        tmp=$(mktemp)
        jq --arg node "$new_node" --arg node2 "$new_node2" \
            '.ServeNodes += [$node, $node2]' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
    else
        tmp=$(mktemp)
        jq --arg node "$new_node" \
            '.ServeNodes += [$node]' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
    fi

    echo "已添加规则: $new_node"
    if [[ "$GOST_PROTOCOL" == "tcp+udp" ]]; then
        echo "已添加规则: $new_node2"
    fi

    # 重启 gost 服务
    restart_gost

}

# 设置开机自启动
function enable_gost_autostart() {
    # 检查 systemd 服务文件是否存在
    if [ ! -f /etc/systemd/system/gost.service ]; then
        echo "未找到 /etc/systemd/system/gost.service，请先创建服务文件。"
        return 1
    fi

    sudo systemctl enable gost
    if [ $? -eq 0 ]; then
        echo "gost 服务已设置为开机自启动。"
    else
        echo "gost 服务开机自启动设置失败，请检查 systemd 状态。"
    fi
}

# 启动主菜单

main_menu 