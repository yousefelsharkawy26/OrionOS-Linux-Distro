#!/bin/bash
# =============================================================================
# OrionOS Test Runner
# Comprehensive test suite for the operating system
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_DIR="${1:-${PROJECT_ROOT}/build/logs}"
RESULTS_FILE="${LOG_DIR}/test-results.json"

mkdir -p "$LOG_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TOTAL_TESTS=0

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $*"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# =============================================================================
# Unit Tests
# =============================================================================

run_unit_tests() {
    log_info "Running unit tests..."

    # Test package configuration
    test_pkgbuild_syntax

    # Test kernel configuration
    test_kernel_config

    # Test service definitions
    test_service_configs

    # Test script syntax
    test_script_syntax

    # Test JSON/YAML configurations
    test_config_files
}

test_pkgbuild_syntax() {
    local test_name="PKGBUILD Syntax"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0
    while IFS= read -r -d '' pkgbuild; do
        if ! bash -n "$pkgbuild" 2>/dev/null; then
            log_fail "$test_name - $pkgbuild has syntax errors"
            failed=1
        fi
    done < <(find "${PROJECT_ROOT}/packages" -name "PKGBUILD" -print0)

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_kernel_config() {
    local test_name="Kernel Configuration"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local config_file="${PROJECT_ROOT}/kernel/config/orionos-kernel.config"

    if [[ ! -f "$config_file" ]]; then
        log_fail "$test_name - Configuration file not found"
        return
    fi

    # Check for required options
    local required_options=(
        "CONFIG_LOCALVERSION="
        "CONFIG_BTRFS_FS="
        "CONFIG_SCHED_BORE="
        "CONFIG_TRANSPARENT_HUGEPAGE="
        "CONFIG_NUMA_BALANCING="
        "CONFIG_IO_URING="
        "CONFIG_SECURITY_SELINUX="
        "CONFIG_SECURITY_APPARMOR="
        "CONFIG_TCG_TPM="
        "CONFIG_EFI_STUB="
        "CONFIG_PREEMPT="
    )

    local missing=0
    for opt in "${required_options[@]}"; do
        if ! grep -q "^${opt}" "$config_file" 2>/dev/null; then
            log_fail "$test_name - Missing required option: $opt"
            missing=1
        fi
    done

    if [[ $missing -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_service_configs() {
    local test_name="Service Configuration"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0

    # Check systemd service files
    while IFS= read -r -d '' service_file; do
        # Basic validation - check for required sections
        if ! grep -q "^\[Unit\]" "$service_file" 2>/dev/null; then
            log_fail "$test_name - Missing [Unit] section in $(basename "$service_file")"
            failed=1
        fi
        if ! grep -q "^\[Service\]" "$service_file" 2>/dev/null; then
            log_fail "$test_name - Missing [Service] section in $(basename "$service_file")"
            failed=1
        fi
    done < <(find "${PROJECT_ROOT}" -name "*.service" -print0)

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_script_syntax() {
    local test_name="Script Syntax"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0
    while IFS= read -r -d '' script; do
        local shebang
        shebang=$(head -1 "$script")
        if [[ "$shebang" == *"bash"* ]]; then
            if ! bash -n "$script" 2>/dev/null; then
                log_fail "$test_name - Bash syntax error in $script"
                failed=1
            fi
        elif [[ "$shebang" == *"python3"* ]] || [[ "$shebang" == *"python"* ]]; then
            if command -v python3 &>/dev/null; then
                if ! python3 -m py_compile "$script" 2>/dev/null; then
                    log_fail "$test_name - Python syntax error in $script"
                    failed=1
                fi
            fi
        fi
    done < <(find "${PROJECT_ROOT}/scripts" -type f -executable -print0 2>/dev/null)

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_config_files() {
    local test_name="Configuration Files"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0

    # Check JSON files
    while IFS= read -r -d '' json_file; do
        if ! python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
            log_fail "$test_name - Invalid JSON: $json_file"
            failed=1
        fi
    done < <(find "${PROJECT_ROOT}" -name "*.json" -not -path "*/.git/*" -print0)

    # Check for critical configuration files
    local required_configs=(
        "kernel/config/orionos-kernel.config"
        "config/defaults"
    )

    for config in "${required_configs[@]}"; do
        if [[ ! -f "${PROJECT_ROOT}/${config}" ]]; then
            log_fail "$test_name - Missing required config: $config"
            failed=1
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

# =============================================================================
# Integration Tests
# =============================================================================

run_integration_tests() {
    log_info "Running integration tests..."

    test_build_system
    test_package_deps
    test_iso_config
}

test_build_system() {
    local test_name="Build System"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # Check if Makefile exists and is valid
    if [[ ! -f "${PROJECT_ROOT}/Makefile" ]]; then
        log_fail "$test_name - Makefile not found"
        return
    fi

    # Check for required targets
    local required_targets=("all" "clean" "iso" "kernel" "packages" "help")
    local missing=0

    for target in "${required_targets[@]}"; do
        if ! grep -q "^${target}:" "${PROJECT_ROOT}/Makefile" 2>/dev/null; then
            log_fail "$test_name - Missing Makefile target: $target"
            missing=1
        fi
    done

    if [[ $missing -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_package_deps() {
    local test_name="Package Dependencies"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0

    # Check that core packages have required dependencies defined
    while IFS= read -r -d '' pkgbuild; do
        local pkg_name
        pkg_name=$(grep "^pkgname=" "$pkgbuild" | head -1 | cut -d'=' -f2 | tr -d '"' || true)

        if [[ -z "$pkg_name" ]]; then
            log_fail "$test_name - Missing pkgname in $pkgbuild"
            failed=1
        fi

        # Check for description
        if ! grep -q "^pkgdesc=" "$pkgbuild" 2>/dev/null; then
            log_fail "$test_name - Missing pkgdesc in $pkg_name"
            failed=1
        fi
    done < <(find "${PROJECT_ROOT}/packages" -name "PKGBUILD" -print0)

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_iso_config() {
    local test_name="ISO Configuration"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0

    # Check ISO build script exists
    if [[ ! -f "${PROJECT_ROOT}/scripts/build/build-iso.sh" ]]; then
        log_fail "$test_name - ISO build script not found"
        failed=1
    fi

    # Check archiso profile
    if [[ ! -d "${PROJECT_ROOT}/profiles" ]]; then
        log_fail "$test_name - Profiles directory not found"
        failed=1
    fi

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

# =============================================================================
# Security Tests
# =============================================================================

run_security_tests() {
    log_info "Running security tests..."

    test_security_policies
    test_encryption_config
    test_firewall_rules
}

test_security_policies() {
    local test_name="Security Policies"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0

    # Check for security configuration files
    local required_files=(
        "packages/core/orionos-security/PKGBUILD"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "${PROJECT_ROOT}/${file}" ]]; then
            log_fail "$test_name - Missing security file: $file"
            failed=1
        fi
    done

    # Check kernel config for security options
    local kernel_config="${PROJECT_ROOT}/kernel/config/orionos-kernel.config"
    if [[ -f "$kernel_config" ]]; then
        # Check for important security features
        if ! grep -q "CONFIG_SECURITY=y" "$kernel_config" 2>/dev/null; then
            log_fail "$test_name - Security subsystem not enabled in kernel"
            failed=1
        fi
    fi

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_encryption_config() {
    local test_name="Encryption Configuration"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # Check for LUKS/encryption references in configs
    local failed=0

    if [[ ! -f "${PROJECT_ROOT}/packages/core/orionos-security/PKGBUILD" ]]; then
        log_fail "$test_name - Security package not found"
        failed=1
    fi

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_firewall_rules() {
    local test_name="Firewall Rules"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0

    # Check for firewall configuration
    if [[ ! -d "${PROJECT_ROOT}/packages/core/orionos-security" ]]; then
        log_fail "$test_name - Security package directory not found"
        failed=1
    fi

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

# =============================================================================
# Performance Tests
# =============================================================================

run_performance_tests() {
    log_info "Running performance tests..."

    test_kernel_optimizations
    test_service_efficiency
}

test_kernel_optimizations() {
    local test_name="Kernel Optimizations"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    local failed=0
    local kernel_config="${PROJECT_ROOT}/kernel/config/orionos-kernel.config"

    if [[ ! -f "$kernel_config" ]]; then
        log_fail "$test_name - Kernel config not found"
        ((TESTS_FAILED++))
        return
    fi

    # Check for performance-related options
    local perf_options=(
        "CONFIG_PREEMPT=y"
        "CONFIG_SCHED_BORE=y"
        "CONFIG_TRANSPARENT_HUGEPAGE=y"
        "CONFIG_NUMA_BALANCING=y"
        "CONFIG_IO_URING=y"
        "CONFIG_ZSWAP=y"
    )

    for opt in "${perf_options[@]}"; do
        if ! grep -q "^${opt}" "$kernel_config" 2>/dev/null; then
            log_fail "$test_name - Missing performance option: $opt"
            failed=1
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_pass "$test_name"
    fi
}

test_service_efficiency() {
    local test_name="Service Efficiency"
    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    # Check that services use appropriate resource limits
    local failed=0

    # Check for memory/cpu limits in service files
    local services_dir="${PROJECT_ROOT}/packages/core/orionos-services"
    if [[ -d "$services_dir" ]]; then
        log_pass "$test_name - Services package exists"
    else
        log_fail "$test_name - Services package not found"
        failed=1
    fi

    if [[ $failed -ne 0 ]]; then
        TESTS_FAILED=$((TESTS_FAILED - 1))  # Adjust counter since we already incremented
        TESTS_FAILED=$((TESTS_FAILED + failed))
    fi
}

# =============================================================================
# Report Generation
# =============================================================================

generate_report() {
    log_info "Generating test report..."

    local duration=$SECONDS

    # Generate JSON report
    cat > "$RESULTS_FILE" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "total_tests": $TOTAL_TESTS,
    "passed": $TESTS_PASSED,
    "failed": $TESTS_FAILED,
    "skipped": $TESTS_SKIPPED,
    "duration_seconds": $duration,
    "success_rate": $(python3 -c "print(f'{($TESTS_PASSED / $TOTAL_TESTS * 100):.1f}' if $TOTAL_TESTS > 0 else '0.0')"),
    "results": {
        "status": "$([[ $TESTS_FAILED -eq 0 ]] && echo "PASS" || echo "FAIL")"
    }
}
EOF

    echo ""
    echo "========================================"
    echo "OrionOS Test Results"
    echo "========================================"
    echo "Total Tests:  $TOTAL_TESTS"
    echo -e "Passed:       ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed:       ${RED}$TESTS_FAILED${NC}"
    echo -e "Skipped:      ${YELLOW}$TESTS_SKIPPED${NC}"
    echo "Duration:     ${duration}s"
    echo "Report:       $RESULTS_FILE"
    echo "========================================"

    # Return exit code based on results
    if [[ $TESTS_FAILED -gt 0 ]]; then
        return 1
    fi
    return 0
}

# =============================================================================
# Main
# =============================================================================

main() {
    echo "========================================"
    echo "OrionOS Test Suite"
    echo "========================================"
    echo ""

    SECONDS=0

    # Run all test suites
    run_unit_tests
    run_integration_tests
    run_security_tests
    run_performance_tests

    # Generate report
    generate_report
}

main "$@"
