#!/bin/bash
# =============================================================================
# OrionOS Build Logging Utilities
# Standardized logging for all build scripts
# =============================================================================

# Colors
readonly C_BLUE='\033[0;34m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_RED='\033[0;31m'
readonly C_CYAN='\033[0;36m'
readonly C_RESET='\033[0m'

# Prefixes
readonly P_INFO="${C_BLUE}[INFO]${C_RESET}"
readonly P_SUCCESS="${C_GREEN}[OK]${C_RESET}"
readonly P_WARN="${C_YELLOW}[WARN]${C_RESET}"
readonly P_ERROR="${C_RED}[ERROR]${C_RESET}"
readonly P_DEBUG="${C_CYAN}[DEBUG]${C_RESET}"

# Log file
LOG_FILE="${BUILD_DIR:-./build}/logs/build-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log_info() {
    echo -e "${P_INFO} $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_success() {
    echo -e "${P_SUCCESS} $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [OK] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_warn() {
    echo -e "${P_WARN} $*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "${P_ERROR} $*" >&2
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${P_DEBUG} $*"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

log_section() {
    echo -e "\n${C_BLUE}═══════════════════════════════════════════════════════════${C_RESET}"
    echo -e "${C_BLUE}  $*${C_RESET}"
    echo -e "${C_BLUE}═══════════════════════════════════════════════════════════${C_RESET}\n"
    echo "" >> "$LOG_FILE" 2>/dev/null || true
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SECTION] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log_fatal() {
    log_error "$*"
    exit 1
}
