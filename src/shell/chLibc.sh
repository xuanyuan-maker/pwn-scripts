#!/usr/bin/env bash
set -euo pipefail

# chLibc - 基于 patchelf 和 glibc-all-in-one，快速匹配并更换目标ELF文件的glibc依赖
# Usage:
#   chLibc <ELF_PATH> <GLIBC_VERSION>

# =============================================================
# Recommendations:
# Add the following variables as global variables to your shell
# initialization script
# =============================================================
GLIBC_ALL_IN_ONE_PATH=${GLIBC_ALL_IN_ONE_PATH:-$HOME/glibc-all-in-one}

# Default config
VERBOS=false

# color
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# print message with color
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

# print usage message
usage() {
  cat <<EOF
Usage: $0 [OPTION] <ELF_PATH> <GLIBC_VERSION>

Options:
    -h    Show help message.
    -v    Show details.

Examples:
    $0 ./pwn 2.23

EOF
}

# parse_args
parse_args() {
  while getopts ":hv" opt; do
    case $opt in
    h)
      usage
      exit 0
      ;;
    v)
      VERBOS=true
      ;;
    \?)
      error "未知选项: -$OPTARG"
      usage
      exit 1
      ;;
    esac
  done

  shift $((OPTIND - 1))

  if [[ $# -ne 2 ]]; then
    error "需要两个参数"
    info "请使用 $0 -h 来获取更多信息"
    exit 1
  fi

  ELF_PATH=$(realpath $1)
  GLIBC_VERSION=$2
}

# check
check() {
  if ! command -v patchelf &>/dev/null; then
    error "patchelf 未安装，请先安装！"
    exit 1
  fi

  if [[ ! -d "$GLIBC_ALL_IN_ONE_PATH" ]]; then
    error "glibc-all-in-one 路径不存在：$GLIBC_ALL_IN_ONE_PATH"
    exit 1
  fi
}

# detect ELF architecture (amd64 or i386)
detect_arch() {
  local elf_path=$1
  local machine

  machine=$(readelf -h "$elf_path" 2>/dev/null | grep "Machine:" | awk '{print $NF}')

  case "$machine" in
  X86-64)
    if [[ "$VERBOS" == "true" ]]; then
      info "该程序架构为：$machine"
    fi
    ARCH=amd64
    ;;
  80386)
    if [[ "$VERBOS" == "true" ]]; then
      info "改程序架构为：$machine"
    fi
    ARCH=i386
    ;;
  *)
    error "不支持架构：$machine"
    exit 1
    ;;
  esac
}

# fing glibc dir
find_glibc_dir() {
  local version="$1"
  local arch="$2"
  local libs_path="$GLIBC_ALL_IN_ONE_PATH/libs"

  # find directories matching version pattern: {version}*_{arch}
  local matches=()
  while IFS= read -r -d '' dir; do
    matches+=("$dir")
  done < <(find "$libs_path" -maxdepth 1 -type d -name "${version}*_${arch}" -print0 2>/dev/null)

  if [[ ${#matches[@]} -eq 0 ]]; then
    error "未找到版本 $version ($arch) 的 glibc"
    info "可用版本列表："
    ls -1 "$libs_path" | grep "_${arch}$" | sed 's/^/  /' >&2
    exit 1
  fi

  # if multiple matches, use the first one (or could prompt user)
  if [[ ${#matches[@]} -gt 1 ]]; then
    warn "找到多个匹配的版本，使用第一个: ${matches[0]##*/}"
    if [[ "$VERBOS" == "true" ]]; then
      info "所有匹配项："
      printf '  %s\n' "${matches[@]##*/}" >&2
    fi
  fi

  GLIBC_DIR="${matches[0]}"

  if [[ "$VERBOS" == "true" ]]; then
    info "使用 glibc 目录: $GLIBC_DIR"
  fi
}

# backup_elf
backup_elf() {
  local original_path="$1"
  local backup_path="${original_path}.bak"

  if [[ -f "$backup_path" ]]; then
    warn "备份文件已经存在：$backup_path"
  fi

  cp "$original_path" "$backup_path"

  if [[ ! -f "$backup_path" ]]; then
    error "备份失败！"
    exit 1
  fi

  if [[ "$VERBOS" == "true" ]]; then
    info "已备份到: $backup_path"
  fi
}

# change glibc

main() {
  parse_args "$@"
  check
  detect_arch "$ELF_PATH"

}

main "$@"
