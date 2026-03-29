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

  INPUT_ELF_PATH=$1
  GLIBC_VERSION=$2
}

main() {
  parse_args "$@"
}

main "$@"
