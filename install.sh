#!/usr/bin/env bash
set -euo pipefail

# install.sh - 安装脚本，将 bin 中的脚本软链接到 ~/.local/bin/

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

get_bin_path() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "${script_dir}/bin"
}

get_src_path() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "${script_dir}/src"
}

sync_scripts_to_bin() {
    local src_path="$1"
    local bin_path="$2"
    local copied_count=0

    mkdir -p "$bin_path"

    while IFS= read -r -d '' src_file; do
        local filename
        filename="$(basename "$src_file")"

        local cmd_name="${filename%.*}"
        local target_path="${bin_path}/${cmd_name}"

        if [[ -e "$target_path" && ! -f "$target_path" ]]; then
            warn "跳过 ${target_path}：目标不是普通文件"
            continue
        fi

        cp "$src_file" "$target_path"
        chmod +x "$target_path"
        copied_count=$((copied_count + 1))
    done < <(find "$src_path" -type f \( -name "*.py" -o -name "*.sh" \) -print0)

    if [[ "$copied_count" -eq 0 ]]; then
        warn "未在 ${src_path} 中找到 .py 或 .sh 脚本"
    else
        success "已同步 ${copied_count} 个脚本到 bin 目录"
    fi
}

symlink_to_local_bin() {
    local bin_path="$1"
    local local_bin="$HOME/.local/bin"
    local symlink_count=0

    mkdir -p "$local_bin"

    while IFS= read -r -d '' bin_file; do
        local name
        name="$(basename "$bin_file")"
        local link_path="${local_bin}/${name}"

        if [[ -L "$link_path" ]]; then
            rm -f "$link_path"
        elif [[ -e "$link_path" ]]; then
            warn "跳过 ${link_path}：已存在非符号链接文件"
            continue
        fi

        ln -s "$bin_file" "$link_path"
        symlink_count=$((symlink_count + 1))
    done < <(find "$bin_path" -maxdepth 1 -type f -print0 2>/dev/null)

    if [[ "$symlink_count" -gt 0 ]]; then
        success "已创建 ${symlink_count} 个符号链接到 ${local_bin}"
    fi
}

add_local_bin_to_path() {
    local local_bin="$HOME/.local/bin"
    local rc_file="$1"

    if [[ ":$PATH:" == *":${local_bin}:"* ]]; then
        info "~/.local/bin 已在 PATH 中"
        return 0
    fi

    if [[ -f "$rc_file" ]] && grep -q "$local_bin" "$rc_file" 2>/dev/null; then
        warn "~/.local/bin 已添加到 $rc_file，但可能未生效"
        info "请运行: source $rc_file"
        return 0
    fi

    local export_line="export PATH=\"$local_bin:\$PATH\""
    echo "" >> "$rc_file"
    echo "# Added by pwn-scripts install.sh" >> "$rc_file"
    echo "$export_line" >> "$rc_file"

    success "已将 ~/.local/bin 添加到 $rc_file"
    info "请运行以下命令使配置生效:"
    echo "  source $rc_file"
}

main() {
    info "开始安装..."

    local src_path
    src_path="$(get_src_path)"

    if [[ ! -d "$src_path" ]]; then
        error "src 目录不存在: $src_path"
        exit 1
    fi

    local bin_path
    bin_path="$(get_bin_path)"

    info "src 目录: $src_path"
    info "bin 目录: $bin_path"

    sync_scripts_to_bin "$src_path" "$bin_path"
    symlink_to_local_bin "$bin_path"

    local rc_file
    rc_file="$(get_shell_rc)"

    info "检测到 shell rc 文件: $rc_file"

    add_local_bin_to_path "$rc_file"

    success "安装完成！"
}

main "$@"
