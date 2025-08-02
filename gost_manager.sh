#!/bin/bash

# 引入添加节点脚本
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/common.sh"


# singbox 节点管理脚本

# 全局配置文件路径
CONFIG_FILE="/etc/gost/config.json"

# 菜单相关函数
function main_menu() {
    clear
    echo "========================="
    echo "      gost 节点管理      "
    echo "========================="
    echo "1. 安装 gost"
    echo "2. 更新 gost"
    echo "3. 卸载 gost"
    echo "————————————"
    echo "4. 启动 gost"
    echo "5. 停止 gost"
    echo "6. 重启 gost"
    echo "————————————"
    echo "7. 新增gost转发配置"
    echo "8. 查看现有gost配置"
    echo "9. 删除一则gost配置"
    echo "————————————"
    echo "10. gost定时重启配置"
    echo "11. 自定义TLS证书配置"
    echo "0. 退出"
    read -p "请选择操作: " choice
    case $choice in
        1) install_gost ;;
        2) update_gost ;;
        3) uninstall_gost ;;
        4) start_gost ;;
        5) stop_gost ;;
        6) restart_gost ;;
        7) add_gost_config ;;
        8) view_gost_config ;;
        9) delete_gost_config ;;
        10) schedule_gost_restart ;;
        11) custom_tls_config ;;
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

    
    # 复制到安装目录
    cp "$GOST_BINARY" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    # 清理临时文件
    rm -rf "$TEMP_DIR"

    if command -v gost >/dev/null 2>&1; then
        echo "gost 安装成功，版本信息如下："
        gost -V
    else
        echo "gost 安装失败！"
        return 1
    fi
}


# 更新 gost
function update_gost() {
    # 更新 gost 到最新版本
    echo "正在更新 gost 到最新版本..."
    
}

# 卸载 gost
function uninstall_gost() {
    # 卸载 gost
    echo "正在卸载 gost..."
}

# 启动 gost
function start_gost() {
    # 启动 gost 服务
    echo "正在启动 gost 服务..."
}

# 停止 gost
function stop_gost() {
    # 停止 gost 服务
    echo "正在停止 gost 服务..."
}

# 重启 gost
function restart_gost() {
    # 重启 gost 服务
    echo "正在重启 gost 服务..."
}

# 新增gost转发配置
function add_gost_config() {
    # 新增一条 gost 转发配置
    echo "正在新增 gost 转发配置..."
}

# 查看现有gost配置
function view_gost_config() {
    # 查看所有已存在的 gost 配置
    echo "正在查看现有 gost 配置..."
}

# 删除一则gost配置
function delete_gost_config() {
    # 删除指定的 gost 配置
    echo "正在删除 gost 配置..."
}

# gost定时重启配置
function schedule_gost_restart() {
    # 配置 gost 的定时重启任务
    echo "正在配置 gost 的定时重启任务..."
}

# 自定义TLS证书配置
function custom_tls_config() {
    # 配置自定义的 TLS 证书
    echo "正在配置自定义的 TLS 证书..."
}

# 检查是否为 root 用户
function check_root() {
    # 如果不是 root 用户，则提示并退出
    if [ "$(id -u)" != "0" ]; then
        echo "请以 root 用户身份运行此脚本！"
        exit 1
    fi
}




# 启动主菜单

main_menu 