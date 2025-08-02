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
    echo "2. 卸载 gost"
    echo "————————————"
    echo "3. 启动 gost"
    echo "4. 停止 gost"
    echo "5. 重启 gost"
    echo "————————————"
    echo "6. 新增配置"
    echo "7. 查看配置"
    echo "8. 删除配置"
    echo "————————————"
    echo "9. 定时重启"
    echo "10. 自定义TLS证书"
    echo "0. 退出"
    read -p "请选择操作: " choice
    case $choice in
        1) install_gost ;;
        2) uninstall_gost ;;
        3) start_gost ;;
        4) stop_gost ;;
        5) restart_gost ;;
        6) add_gost_config ;;
        7) view_gost_config ;;
        8) delete_gost_config ;;
        9) schedule_gost_restart ;;
        10) custom_tls_config ;;
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


    # 清理 shell 启动文件中包含 gm 的 PATH、alias、export 配置
    for file in ~/.bashrc ~/.bash_profile ~/.zshrc /etc/profile; do
        if [ -f "$file" ]; then
            sed -i '/gm/d' "$file"
            sed -i '/GM/d' "$file"
            sed -i '/gost/d' "$file"
        fi
    done

    # 验证卸载结果
    if ! command -v gost >/dev/null 2>&1 && [ ! -f /usr/local/bin/gost ] && [ ! -f /usr/local/bin/gm ]; then
        echo "gost 及相关脚本和软链接已全部卸载完成。"
    else
        echo "部分文件未能成功删除，请手动检查。"
    fi
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