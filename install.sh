#!/usr/bin/env bash
set -euo pipefail

# install.sh - 安装脚本，将 bin 目录添加到 PATH

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

# 获取当前 shell
get_shell_rc() {
    local shell_path="${SHELL:-}"
    
    if [[ -z "$shell_path" ]]; then
        error "无法获取 SHELL 环境变量"
        exit 1
    fi
    
    local shell_name
    shell_name=$(basename "$shell_path")
    
    case "$shell_name" in
        bash)
            echo "$HOME/.bashrc"
            ;;
        zsh)
            echo "$HOME/.zshrc"
            ;;
        *)
            error "不支持的 shell: $shell_name (仅支持 bash 和 zsh)"
            exit 1
            ;;
    esac
}

# 获取 bin 目录的绝对路径
get_bin_path() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "${script_dir}/bin"
}

# 将 bin 目录添加到 PATH
add_to_path() {
    local bin_path="$1"
    local rc_file="$2"
    
    # 检查是否已经在 PATH 中
    if [[ ":$PATH:" == *":${bin_path}:"* ]]; then
        info "bin 目录已在 PATH 中: $bin_path"
        return 0
    fi
    
    # 检查是否已经在 rc 文件中
    if [[ -f "$rc_file" ]] && grep -q "$bin_path" "$rc_file" 2>/dev/null; then
        warn "bin 目录已添加到 $rc_file，但可能未生效"
        info "请运行: source $rc_file"
        return 0
    fi
    
    # 添加到 rc 文件
    local export_line="export PATH=\"$bin_path:\$PATH\""
    echo "" >> "$rc_file"
    echo "# Added by pwn-scripts install.sh" >> "$rc_file"
    echo "$export_line" >> "$rc_file"
    
    success "已将 bin 目录添加到 $rc_file"
    info "请运行以下命令使配置生效:"
    echo "  source $rc_file"
}

main() {
    info "开始安装..."
    
    local bin_path
    bin_path="$(get_bin_path)"
    
    if [[ ! -d "$bin_path" ]]; then
        error "bin 目录不存在: $bin_path"
        exit 1
    fi
    
    info "bin 目录: $bin_path"
    
    local rc_file
    rc_file="$(get_shell_rc)"
    
    info "检测到 shell rc 文件: $rc_file"
    
    add_to_path "$bin_path" "$rc_file"
    
    success "安装完成！"
}

main "$@"
