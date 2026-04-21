#!/usr/bin/env bash
set -euo pipefail

# chLibc - 基于 patchelf 和 glibc-all-in-one，快速匹配并更换目标ELF文件的glibc依赖
# Usage:
#   chLibc [OPTION] <ELF_PATH> <GLIBC_VERSION>

GLIBC_ALL_IN_ONE_PATH="${GLIBC_ALL_IN_ONE_PATH:-$HOME/glibc-all-in-one}"

# Default config
VERBOSE=false
IS_LOCAL_RUNTIME=false

# Runtime state
ELF_PATH=""
GLIBC_VERSION=""
ARCH=""
GLIBC_DIR=""
LIBC_PATH=""
LD_PATH=""
LOCAL_GLIBC_FILE=""
LOCAL_LD_FILE=""

# color
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
  echo -e "${RED}[ERROR]${RESET} $1" >&2
}

success() {
  echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

usage() {
  cat <<EOF
Usage: $0 [OPTION] <ELF_PATH> <GLIBC_VERSION>

Options:
  -h    Show help message.
  -v    Show verbose details.

Examples:
  $0 ./pwn 2.23
EOF
}

parse_args() {
  while getopts ":hv" opt; do
    case "$opt" in
      h)
        usage
        exit 0
        ;;
      v)
        VERBOSE=true
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

  ELF_PATH="$(realpath "$1")"
  GLIBC_VERSION="$2"
}

check() {
  local cmd
  for cmd in patchelf readelf realpath find; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      error "缺少依赖: $cmd"
      exit 1
    fi
  done

  if [[ ! -f "$ELF_PATH" ]]; then
    error "ELF 文件不存在: $ELF_PATH"
    exit 1
  fi

  if ! readelf -h "$ELF_PATH" >/dev/null 2>&1; then
    error "不是有效的 ELF 文件: $ELF_PATH"
    exit 1
  fi

  if [[ ! -d "$GLIBC_ALL_IN_ONE_PATH" ]]; then
    error "glibc-all-in-one 路径不存在: $GLIBC_ALL_IN_ONE_PATH"
    exit 1
  fi
}

is_elf_shared_object() {
  local f="$1"
  local type_field

  readelf -h "$f" >/dev/null 2>&1 || return 1
  type_field="$(readelf -h "$f" 2>/dev/null | awk -F: '/Type:/{gsub(/^[ \t]+/, "", $2); print $2}')"
  [[ "$type_field" == DYN* ]]
}

is_gnu_libc_file() {
  local f="$1"
  local b
  b="$(basename "$f")"

  [[ "$b" =~ ^libc\.so(\..*)?$ || "$b" =~ ^libc-[0-9].*\.so$ ]] || return 1
  is_elf_shared_object "$f" || return 1
  readelf -Ws "$f" 2>/dev/null | grep -q '__libc_start_main'
}

is_gnu_ld_file() {
  local f="$1"
  local b
  b="$(basename "$f")"

  [[ "$b" =~ ^ld-linux.*\.so(\..*)?$ || "$b" =~ ^ld-[0-9].*\.so$ ]] || return 1
  is_elf_shared_object "$f" || return 1
  readelf -Ws "$f" 2>/dev/null | grep -q '_dl_start'
}

checklibc() {
  local libc_path="$1"
  # TODO: 检查 GNU libc 版本
  if [[ "$VERBOSE" == "true" ]]; then
    info "checklibc 预留函数，待实现: $libc_path"
  fi
}

check_local() {
  local elf_path="$1"
  local elf_dir
  local file
  local libc_candidates=()
  local ld_candidates=()

  elf_dir="$(dirname "$elf_path")"
  IS_LOCAL_RUNTIME=false
  LOCAL_GLIBC_FILE=""
  LOCAL_LD_FILE=""

  while IFS= read -r -d '' file; do
    if is_gnu_libc_file "$file"; then
      libc_candidates+=("$file")
      continue
    fi

    if is_gnu_ld_file "$file"; then
      ld_candidates+=("$file")
    fi
  done < <(find "$elf_dir" -maxdepth 1 -type f -print0 2>/dev/null)

  if [[ ${#libc_candidates[@]} -gt 0 ]]; then
    LOCAL_GLIBC_FILE="${libc_candidates[0]}"
  fi

  if [[ ${#ld_candidates[@]} -gt 0 ]]; then
    LOCAL_LD_FILE="${ld_candidates[0]}"
  fi

  if [[ -n "$LOCAL_GLIBC_FILE" && -z "$LOCAL_LD_FILE" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
      info "检测到目录中存在 GNU libc 库: $(basename "$LOCAL_GLIBC_FILE")"
    fi
    checklibc "$LOCAL_GLIBC_FILE"
    return 0
  fi

  if [[ -n "$LOCAL_GLIBC_FILE" && -n "$LOCAL_LD_FILE" ]]; then
    IS_LOCAL_RUNTIME=true
    if [[ "$VERBOSE" == "true" ]]; then
      info "检测到目录中同时存在 GNU libc 库与动态链接器"
      info "  libc: $(basename "$LOCAL_GLIBC_FILE")"
      info "  ld:   $(basename "$LOCAL_LD_FILE")"
    fi
    return 0
  fi

  if [[ "$VERBOSE" == "true" ]]; then
    info "未在本目录中检查到 GNU libc 库或者动态链接器"
  fi
}

detect_arch() {
  local elf_path="$1"
  local machine

  machine="$(readelf -h "$elf_path" 2>/dev/null | awk -F: '/Machine:/{gsub(/^[ \t]+/, "", $2); print $2}')"

  case "$machine" in
    X86-64)
      ARCH=amd64
      [[ "$VERBOSE" == "true" ]] && info "该程序架构为: $machine"
      ;;
    80386)
      ARCH=i386
      [[ "$VERBOSE" == "true" ]] && info "该程序架构为: $machine"
      ;;
    *)
      error "不支持架构: $machine"
      exit 1
      ;;
  esac
}

find_glibc_dir() {
  local version="$1"
  local arch="$2"
  local libs_path="$GLIBC_ALL_IN_ONE_PATH/libs"
  local matches=()
  local dir

  if [[ ! -d "$libs_path" ]]; then
    error "glibc 库目录不存在: $libs_path"
    exit 1
  fi

  while IFS= read -r -d '' dir; do
    matches+=("$dir")
  done < <(find "$libs_path" -maxdepth 1 -type d -name "${version}*_${arch}" -print0 2>/dev/null)

  if [[ ${#matches[@]} -eq 0 ]]; then
    error "未找到版本 $version ($arch) 的 glibc"
    if [[ "$VERBOSE" == "true" ]]; then
      info "可用版本列表:"
      while IFS= read -r -d '' dir; do
        printf '  %s\n' "${dir##*/}" >&2
      done < <(find "$libs_path" -maxdepth 1 -type d -name "*_${arch}" -print0 2>/dev/null)
    fi
    exit 1
  fi

  if [[ ${#matches[@]} -gt 1 ]]; then
    warn "找到多个匹配版本，请选择:"
    local i
    for ((i = 0; i < ${#matches[@]}; i++)); do
      printf '  [%d] %s\n' $((i + 1)) "${matches[$i]##*/}"
    done

    local choice
    while true; do
      read -rp "请输入编号 (1-${#matches[@]}): " choice
      if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#matches[@]})); then
        GLIBC_DIR="${matches[$((choice - 1))]}"
        break
      fi
      warn "无效输入，请输入 1 到 ${#matches[@]} 之间的数字"
    done
  else
    GLIBC_DIR="${matches[0]}"
  fi

  LIBC_PATH="$GLIBC_DIR/libc-${version}.so"
  LD_PATH="$GLIBC_DIR/ld-${version}.so"

  if [[ ! -f "$LIBC_PATH" || ! -f "$LD_PATH" ]]; then
    error "目标 glibc 目录缺少 libc 或 ld 文件: $GLIBC_DIR"
    exit 1
  fi

  if [[ "$VERBOSE" == "true" ]]; then
    info "使用 glibc 目录: $GLIBC_DIR"
    info "要更换的动态库: $LIBC_PATH"
    info "要更换的链接器: $LD_PATH"
  fi
}

backup_elf() {
  local original_path="$1"
  local backup_path="${original_path}.bak"

  if [[ -f "$backup_path" ]]; then
    backup_path="${original_path}.bak.$(date +%Y%m%d%H%M%S)"
    warn "检测到已有备份，改用新备份文件: $backup_path"
  fi

  cp "$original_path" "$backup_path"

  if [[ ! -f "$backup_path" ]]; then
    error "备份失败"
    exit 1
  fi

  [[ "$VERBOSE" == "true" ]] && info "已备份到: $backup_path"
}

change_glibc() {
  if [[ "$VERBOSE" == "true" ]]; then
    info "正在更换动态库"
  fi

  if patchelf --replace-needed libc.so.6 "$LIBC_PATH" "$ELF_PATH"; then
    success "动态库更换成功"
  else
    error "动态库更换失败"
    exit 1
  fi

  if patchelf --set-interpreter "$LD_PATH" "$ELF_PATH"; then
    success "链接器更换成功"
  else
    error "链接器更换失败"
    exit 1
  fi
}

main() {
  parse_args "$@"
  check
  check_local "$ELF_PATH"

  if [[ "$IS_LOCAL_RUNTIME" == "true" ]]; then
    if [[ "$VERBOSE" == "true" ]]; then
      info "检测到本地运行时环境，当前版本默认不改写 ELF"
    fi
    exit 0
  fi

  detect_arch "$ELF_PATH"
  find_glibc_dir "$GLIBC_VERSION" "$ARCH"
  backup_elf "$ELF_PATH"
  change_glibc
}

main "$@"
