#!/bin/bash

# 引入添加节点脚本
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
source "$SCRIPT_DIR/add_shadowsocks.sh"
source "$SCRIPT_DIR/add_vless_reality.sh"
source "$SCRIPT_DIR/add_hysteria2.sh"
source "$SCRIPT_DIR/add_tuic.sh"
source "$SCRIPT_DIR/add_http.sh"
source "$SCRIPT_DIR/add_socks5.sh"
source "$SCRIPT_DIR/common.sh"


# singbox 节点管理脚本

# 全局配置文件路径
CONFIG_FILE="/etc/sing-box/config.json"

# 菜单相关函数
function main_menu() {
    clear
    echo "========================="
    echo "      singbox 节点管理      "
    echo "========================="

    # 检查 sing-box 状态
    if command -v sing-box >/dev/null 2>&1; then
        if systemctl is-active --quiet sing-box; then
            STATUS="\033[32m运行中\033[0m"
        else
            STATUS="\033[33m已安装，未运行\033[0m"
        fi
    else
        STATUS="\033[31m未安装\033[0m"
    fi

    echo -e "1. 安装 singbox（$STATUS）"
    echo "2. 管理 singbox"
    echo "3. 卸载 singbox"
    echo "0. 退出"
    read -p "请选择操作: " choice
    case $choice in
        1) install_singbox ;;
        2) manage_singbox ;;
        3) uninstall_singbox_full ;;
        0) exit 0 ;;
        *) echo "无效选择"; read -p "按回车继续..."; main_menu ;;
    esac
}

# 管理 singbox相关函数
function manage_singbox() {
    check_singbox_installed || return
    clear
    echo "===== 管理 singbox ====="
    echo "1. 添加节点"
    echo "2. 删除节点"
    echo "3. 查看节点"
    echo "4. 查看配置文件"
    echo "5. 重启服务"
    echo "6. 查看服务状态"
    echo "7. 查看实时日志"
    echo "8. 切换优先IP模式"
    echo "0. 返回上级菜单"
    read -p "请选择操作: " choice
    case $choice in
        1) add_node_menu ;;
        2) delete_node ;;
        3) view_nodes ;;
        4) view_config ;;
        5) restart_service ;;
        6) check_service_status ;;
        7) view_singbox_realtime_log ;;
        8) switch_ip_preference ;;
        0) main_menu ;;
        *) echo "无效选择"; read -p "按回车继续..."; manage_singbox ;;
    esac
}

function add_node_menu() {
    clear
    echo "===== 添加节点 ====="
    echo "1. VLESS-REALITY（默认）"
    echo "2. Shadowsocks"
    echo "3. Hysteria2"
    echo "4. TUIC"
    echo "5. HTTP"
    echo "6. SOCKS5"
    echo "0. 返回上级菜单"
    read -p "请选择节点类型: " choice
    if [[ -z "$choice" ]]; then
        choice="1"
    fi
    case $choice in
        1) add_vless_reality ;;
        2) add_shadowsocks ;;
        3) add_hysteria2 ;;
        4) add_tuic ;;
        5) add_http ;;
        6) add_socks5 ;;
        0) manage_singbox ;;
        *) echo "无效选择"; read -p "按回车继续..."; add_node_menu ;;
    esac
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "此脚本需要root权限运行"
        print_info "请使用: sudo $0"
        exit 1
    fi
}


check_singbox_installed() {
    if sing-box version 2>&1 | grep -q "version"; then
        return 0  # 已安装且可用
    else
        print_error "请先安装 sing-box"
        read -p "按回车返回主菜单..."
        main_menu
        return 1
    fi
}


check_singbox_service() {
    if ! systemctl is-active --quiet sing-box; then
        print_error "sing-box 服务未运行，请先启动服务。"
        read -p "按回车返回主菜单..."
        main_menu
        return 1
    fi
}


# 安装sing-box（指定版本）
install_singbox() {
    # 检查 sing-box 是否已安装
    if sing-box version 2>&1 | grep -q "version"; then
        version=$(sing-box version | head -n 1)
        print_success "检测到已安装: $version"
        read -p "按回车返回主菜单..."
        main_menu
        return 0
    fi

    print_info "开始安装 sing-box 1.11.15..."
    if ! curl -fsSL https://sing-box.app/install.sh | sh -s -- --version 1.11.15; then
        print_error "sing-box 安装失败"
        exit 1
    fi
    print_success "sing-box 1.11.15 安装完成"
    
    # 安装完毕后，删除原有配置文件再初始化
    if [ -f "$CONFIG_FILE" ]; then
        print_info "检测到默认配置文件，已删除: $CONFIG_FILE"
        sudo rm -f "$CONFIG_FILE"
    fi

    print_info "正在初始化配置文件..."
    sudo mkdir -p "$(dirname "$CONFIG_FILE")"
    sudo tee "$CONFIG_FILE" > /dev/null <<EOF
{
  "log": {
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct",
      "domain_strategy": "prefer_ipv4"
    },
    {
      "type": "direct",
      "tag": "vps-outbound-v4", 
      "domain_strategy": "prefer_ipv4"
    },
    {
      "type": "direct",
      "tag": "vps-outbound-v6",
      "domain_strategy": "prefer_ipv6"
    },
    {
      "type": "block",
      "tag": "block"
    }
  ],
  "route": {
    "rules": [
      {
        "domain_suffix": [
          "ipv4.ping0.cc"
        ],
        "outbound": "vps-outbound-v6"
      },
      {
        "domain_suffix": [
          "api64.ipify.org"
        ],
        "outbound": "vps-outbound-v4"
      },
      {
        "protocol": "bittorrent",
        "outbound": "block"
      },
      {
        "ip_is_private": true,
        "outbound": "direct"
      },
      {
        "outbound": "direct",
        "network": "udp,tcp"
      }
    ],
    "final": "direct",
    "auto_detect_interface": true
  }
}
EOF
    print_success "已初始化配置文件: $CONFIG_FILE"

    # 初始化 node_url.json 文件
    NODE_URL_FILE="/etc/sing-box/node_url/nodes.json"
    if [ ! -f "$NODE_URL_FILE" ]; then
        sudo mkdir -p "/etc/sing-box/node_url"
        sudo tee "$NODE_URL_FILE" > /dev/null <<EOF
{}
EOF
        print_success "已初始化节点URL文件: $NODE_URL_FILE"
    fi
    echo
    print_info "配置目录: /etc/sing-box/"
    print_info "主配置文件: /etc/sing-box/config.json"
    print_info "节点URL文件: /etc/sing-box/node_url/nodes.json"
    print_info "TLS 证书目录: /etc/sing-box/tls/"
    print_info "证书文件命名格式: domain-fullchain.cer"
    print_info "私钥文件命名格式: domain-private.key"
    print_info "系统服务文件: /etc/systemd/system/sing-box.service"

    # 自动注释掉 systemd 服务文件中的 User=sing-box
    if [ -f /lib/systemd/system/sing-box.service ]; then
        sudo sed -i 's/^\(User=sing-box\)/#\1/' /lib/systemd/system/sing-box.service
        print_info "已注释 /lib/systemd/system/sing-box.service 中的 User=sing-box"
        sudo systemctl daemon-reload
        # 设置开机自启
        enable_singbox_autostart
        sudo systemctl restart sing-box
        print_success "sing-box 服务已重启（以 root 用户运行）"
    fi

    while true; do
        read -p "[警告] 请输入 sb 或直接回车启动管理菜单: " user_input
        if [[ -z "$user_input" || "$user_input" == "sb" ]]; then
            sb
            break
        else
            echo "[错误] 无效输入，请输入 sb 或直接回车。"
        fi
    done
}

# 启用并启动服务
enable_service() {
    print_info "启用 sing-box 服务..."
    if systemctl enable sing-box; then
        print_success "sing-box 服务已启用"
    else
        print_error "启用服务失败"
        exit 1
    fi
    print_info "启动 sing-box 服务..."
    if systemctl start sing-box; then
        print_success "sing-box 服务已启动"
    else
        print_error "启动服务失败"
        exit 1
    fi
}

# 完整卸载 singbox 的函数
uninstall_singbox_full() {
    print_info "停止并禁用 sing-box 服务..."
    sudo systemctl stop sing-box 2>/dev/null || true
    sudo systemctl disable sing-box 2>/dev/null || true

    print_info "卸载 sing-box 软件包..."
    sudo dpkg --purge sing-box

    print_info "删除配置目录..."
    sudo rm -rf /etc/sing-box

    print_info "删除可执行文件..."
    sudo rm -f /usr/local/bin/sing-box
    sudo rm -f /usr/bin/sing-box

    print_info "删除 systemd 服务文件..."
    sudo rm -f /etc/systemd/system/sing-box.service

    print_info "重新加载 systemd..."
    sudo systemctl daemon-reload

    print_info "删除 sb 快捷命令软链接..."
    sudo rm -f /usr/local/bin/sb

    print_success "sing-box 及相关文件已全部卸载。"
}



# 检查端口是否已被配置使用
check_port_in_config() {
    local port="$1"
    
    # 检查配置文件中是否已存在该端口
    if jq -e ".inbounds[] | select(.listen_port == $port)" "$CONFIG_FILE" >/dev/null 2>&1; then
        return 1  # 端口已被使用
    fi
    
    return 0  # 端口可用
}










# 切换优先IP模式
switch_ip_preference() {
    print_title "切换 sing-box 优先IP模式"
    echo "请选择优先IP模式："
    echo "1. 优先使用 IPv4"
    echo "2. 优先使用 IPv6"
    echo "3. 仅使用 IPv4"
    echo "4. 仅使用 IPv6"
    read -p "请输入选项(1-4，回车取消): " choice

    case "$choice" in
        1) mode="prefer_ipv4" ;;
        2) mode="prefer_ipv6" ;;
        3) mode="ipv4_only" ;;
        4) mode="ipv6_only" ;;
        *) echo "已取消操作。"; return 0 ;;
    esac

    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "配置文件不存在: $CONFIG_FILE"
        read -p "按回车返回..."
        manage_singbox
        return 1
    fi

    tmp_config=$(mktemp)
    if jq --arg mode "$mode" '(.outbounds[] | select(.tag == "direct") | .domain_strategy) = $mode' "$CONFIG_FILE" > "$tmp_config"; then
        mv "$tmp_config" "$CONFIG_FILE"
        print_success "已将优先IP模式切换为: $mode"
    else
        print_error "配置修改失败"
        rm -f "$tmp_config"
        read -p "按回车返回..."
        manage_singbox
        return 1
    fi

    # 重启 sing-box 服务
    if systemctl restart sing-box; then
        print_success "sing-box 服务已重启"
    else
        print_error "sing-box 服务重启失败，请手动检查"
    fi
    read -p "按回车返回..."
    manage_singbox
}



#添加vless-reality节点
function add_vless_reality() {
    select_sni
    select_port
    get_local_ip
    create_vless_json
    add_node_to_config "$VLESS_CONFIG"
    validate_config_json
    restart_singbox_service
    show_vless_node_info
    read -p "按回车返回..."; add_node_menu
}
#添加shadowsocks节点
function add_shadowsocks() {
    select_ss_method
    select_port
    generate_ss_password
    get_local_ip
    create_shadowsocks_config
    add_node_to_config "$SS_CONFIG"
    validate_config_json
    restart_singbox_service
    show_ss_node_info
    read -p "按回车返回..."; add_node_menu
}
#添加hysteria2节点
function add_hysteria2() {
    select_sni
    select_port
    get_local_ip
    create_hysteria2_config
    add_node_to_config "$HY2_CONFIG"
    validate_config_json
    restart_singbox_service
    show_hysteria2_node_info
    read -p "按回车返回..."; add_node_menu
}
#添加tuic节点
function add_tuic()
 { 
    select_sni
    select_port
    get_local_ip
    create_tuic_config
    add_node_to_config "$TUIC_CONFIG"
    validate_config_json
    restart_singbox_service
    show_tuic_node_info
    read -p "按回车返回..."; add_node_menu; }

#添加http节点
function add_http() {
    select_port
    select_auth_mode
    get_local_ip
    create_http_config
    add_node_to_config "$HTTP_CONFIG"
    validate_config_json
    restart_singbox_service
    show_http_node_info
    read -p "按回车返回..."; add_node_menu; }

#添加socks5节点
function add_socks5() {
    select_port
    select_auth_mode
    get_local_ip
    create_socks5_config
    add_node_to_config "$SOCKS5_CONFIG"
    validate_config_json
    restart_singbox_service
    show_socks5_node_info
    read -p "按回车返回..."; add_node_menu; }


delete_node() {
    print_title "删除 sing-box 节点"
    echo

    # 检查配置文件是否存在
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "配置文件不存在: $CONFIG_FILE"
        return
    fi

    # 列出所有节点名称和端口
    echo "已添加的节点列表："
    jq -r '.inbounds[] | "名称: \(.tag)  端口: \(.listen_port)"' "$CONFIG_FILE"
    echo

    # 读取用户输入
    read -p "请输入要删除的节点端口: " del_port
    if ! [[ "$del_port" =~ ^[0-9]+$ ]]; then
        print_error "端口格式不正确"
        read -p "按回车返回..."
        manage_singbox
        return
    fi

    # 查找对应节点的 tag
    del_tag=$(jq -r --argjson port "$del_port" '.inbounds[] | select(.listen_port == $port) | .tag' "$CONFIG_FILE")
    if [ -z "$del_tag" ]; then
        print_error "未找到该端口对应的节点"
        read -p "按回车返回..."
        manage_singbox
        return
    fi

    # 备份配置文件
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"

    # 删除 config.json 中对应的 inbound 节点
    tmp_config=$(mktemp)
    jq --argjson port "$del_port" ' .inbounds |= map(select(.listen_port != $port)) ' "$CONFIG_FILE" > "$tmp_config" && \
        mv "$tmp_config" "$CONFIG_FILE"

    print_success "已从配置文件中删除端口 $del_port 的节点（$del_tag）"

    # 删除 nodes.json 中对应的节点
    NODE_URL_FILE="/etc/sing-box/node_url/nodes.json"
    if [ -f "$NODE_URL_FILE" ]; then
        tmp_url=$(mktemp)
        jq "del(.\"$del_tag\")" "$NODE_URL_FILE" > "$tmp_url" && \
            sudo mv "$tmp_url" "$NODE_URL_FILE"
        print_success "已从节点URL文件中删除 $del_tag"
    fi

    # 自动重启 sing-box 服务
    restart_singbox_service


    echo
    print_info "节点删除并重启服务完成。"
    read -p "按回车返回..."
    manage_singbox
}


function view_nodes() {
    NODE_URL_FILE="/etc/sing-box/node_url/nodes.json"
    print_title "已添加节点列表"
    if [ ! -f "$NODE_URL_FILE" ] || [ ! -s "$NODE_URL_FILE" ] || [ "$(cat "$NODE_URL_FILE")" = "{}" ]; then
        print_warning "暂无节点信息。"
    else
        jq -r 'to_entries[] | "节点名称: " + .key + "\n节点URL: " + .value + "\n"' "$NODE_URL_FILE"
    fi
    read -p "按回车返回..."
    manage_singbox
}

function view_config() {
    print_title "sing-box 配置文件内容 ($CONFIG_FILE)"
    if [ -f "$CONFIG_FILE" ]; then
        cat "$CONFIG_FILE"
    else
        print_error "配置文件不存在: $CONFIG_FILE"
    fi
    echo
    read -p "按回车返回..."
    manage_singbox
}

function restart_service() {
    print_info "重启sing-box服务..."
    if systemctl restart sing-box; then
        print_success "服务重启成功"
        sleep 2
        if systemctl is-active --quiet sing-box; then
            print_success "服务运行正常"
        else
            print_error "服务启动失败，请检查配置"
            systemctl status sing-box --no-pager -l
        fi
    else
        print_error "服务重启失败"
        exit 1
    fi
    read -p "按回车返回..."
    manage_singbox
}




# 查看 sing-box 服务状态
check_service_status() {
    print_title "sing-box 服务状态（按 Ctrl+C 退出）"
    echo

    # 只显示服务状态
    sudo systemctl status sing-box

    echo
    read -p "按回车返回..."
    manage_singbox
}

# 查看 sing-box 实时日志
view_singbox_realtime_log() {
    print_title "sing-box 实时日志（按 Ctrl+C 退出）"
    echo
    sudo journalctl -u sing-box --output cat -f
    echo
    read -p "按回车返回..."
    manage_singbox
}

# 启动主菜单

main_menu 