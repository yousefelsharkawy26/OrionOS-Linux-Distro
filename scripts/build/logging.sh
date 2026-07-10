#!/bin/bash
# ==============================================================================
# OrionOS Build System - Logging Utilities
# Shared logging functions for all build scripts
# ==============================================================================

# Colors
readonly LOG_BLUE='\033[36m'
readonly LOG_GREEN='\033[32m'
readonly LOG_YELLOW='\033[33m'
readonly LOG_RED='\033[31m'
readonly LOG_RESET='\033[0m'
readonly LOG_BOLD='\033[1m'

# Log level
LOG_LEVEL="${ORIONOS_LOG_LEVEL:-INFO}"
LOG_FILE="${ORIONOS_LOG_FILE:-}"

# Level values
declare -A LOG_LEVELS=(
    [DEBUG]=0
    [INFO]=1
    [WARN]=2
    [ERROR]=3
    [FATAL]=4
)

# Initialize logging
log_init() {
    local log_dir="${1:-}"
    if [[ -n "$log_dir" ]]; then
        mkdir -p "$log_dir"
        LOG_FILE="$log_dir/build-$(date +%Y%m%d-%H%M%S).log"
        # Create log file with header
        {
            echo "OrionOS Build Log"
            echo "Started: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
            echo "PID: $$"
            echo "User: $(whoami)"
            echo "Host: $(hostname)"
            echo "============================================"
        } > "$LOG_FILE"
    fi
}

# Internal log function
_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    # Check log level
    local current_level="${LOG_LEVELS[$LOG_LEVEL]:-1}"
    local msg_level="${LOG_LEVELS[$level]:-1}"
    if [[ $msg_level -lt $current_level ]]; then
        return
    fi

    # Format based on level
    local prefix=""
    local color=""
    case "$level" in
        DEBUG)
            prefix="[DBG]"
            color="$LOG_BLUE"
            ;;
        INFO)
            prefix="[INF]"
            color="$LOG_GREEN"
            ;;
        WARN)
            prefix="[WRN]"
            color="$LOG_YELLOW"
            ;;
        ERROR)
            prefix="[ERR]"
            color="$LOG_RED"
            ;;
        FATAL)
            prefix="[FTL]"
            color="$LOG_RED$LOG_BOLD"
            ;;
    esac

    # Output to console
    echo -e "${color}  ${prefix} ${message}${LOG_RESET}"

    # Output to log file if configured
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        echo "[$timestamp] $prefix $message" >> "$LOG_FILE"
    fi
}

# Public logging functions
log_debug() { _log "DEBUG" "$1"; }
log_info() { _log "INFO" "$1"; }
log_warn() { _log "WARN" "$1"; }
log_error() { _log "ERROR" "$1"; }
log_fatal() { _log "FATAL" "$1"; }

# Section header
log_section() {
    local title="$1"
    echo ""
    echo -e "${LOG_BLUE}${LOG_BOLD}  ============================================${LOG_RESET}"
    echo -e "${LOG_BLUE}${LOG_BOLD}  $title${LOG_RESET}"
    echo -e "${LOG_BLUE}${LOG_BOLD}  ============================================${LOG_RESET}"
    if [[ -n "$LOG_FILE" && -f "$LOG_FILE" ]]; then
        echo "" >> "$LOG_FILE"
        echo "============================================" >> "$LOG_FILE"
        echo "$title" >> "$LOG_FILE"
        echo "============================================" >> "$LOG_FILE"
    fi
}

# Build step
log_step() {
    local step="$1"
    local current="${2:-}"
    local total="${3:-}"
    if [[ -n "$current" && -n "$total" ]]; then
        echo -e "${LOG_YELLOW}${LOG_BOLD}  [${current}/${total}] $step${LOG_RESET}"
    else
        echo -e "${LOG_YELLOW}${LOG_BOLD}  [*] $step${LOG_RESET}"
    fi
}

# Result
log_result() {
    local status="$1"
    if [[ "$status" == "success" || "$status" == "ok" || "$status" == "0" ]]; then
        echo -e "${LOG_GREEN}${LOG_BOLD}  [SUCCESS]${LOG_RESET}"
    else
        echo -e "${LOG_RED}${LOG_BOLD}  [FAILED]${LOG_RESET}"
    fi
}

# Progress bar
log_progress() {
    local current="$1"
    local total="$2"
    local width=40
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf '\r  ['
    printf '%0.s#' $(seq 1 $filled)
    printf '%0.s-' $(seq 1 $empty)
    printf '] %3d%% (%d/%d)' "$percentage" "$current" "$total"
}

# Timing
log_time() {
    local start_time="$1"
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    log_info "Elapsed time: ${minutes}m ${seconds}s"
}

# Error handler
log_on_error() {
    local lineno="$1"
    local msg="$2"
    log_fatal "Error at line $lineno: $msg"
    log_fatal "Build aborted"
}

# Set error trap
trap 'log_on_error "$LINENO" "$BASH_COMMAND"' ERR

# Export functions
export -f log_init log_debug log_info log_warn log_error log_fatal
export -f log_section log_step log_result log_progress log_time
export -f log_on_error
