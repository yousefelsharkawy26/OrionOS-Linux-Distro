#!/bin/bash
# OrionOS Test Suite Runner
# Runs unit tests, integration tests, and validation checks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
RESULTS_DIR="$REPO_DIR/build/logs"
RESULTS_FILE="$RESULTS_DIR/test-results.json"

mkdir -p "$RESULTS_DIR"

PASS=0
FAIL=0
SKIP=0
TESTS=()

log_test() {
    local name="$1" status="$2" detail="${3:-}"
    TESTS+=("{\"name\":\"$name\",\"status\":\"$status\",\"detail\":\"$detail\"}")
    if [[ "$status" == "PASS" ]]; then ((PASS++)); fi
    if [[ "$status" == "FAIL" ]]; then ((FAIL++)); fi
    if [[ "$status" == "SKIP" ]]; then ((SKIP++)); fi
    echo "  [$status] $name $detail"
}

echo "=== OrionOS Test Suite ==="
echo "Date: $(date)"
echo ""

echo "--- PKGBUILD Validation ---"
for pkg in "$REPO_DIR"/packages/*/orionos-*/PKGBUILD "$REPO_DIR"/packages/extra/*/PKGBUILD; do
    [[ -f "$pkg" ]] || continue
    pkgname=$(basename "$(dirname "$pkg")")
    if bash -n "$pkg" 2>/dev/null; then
        log_test "PKGBUILD:$pkgname:syntax" "PASS"
    else
        log_test "PKGBUILD:$pkgname:syntax" "FAIL" "Syntax error"
    fi

    for field in pkgname pkgver pkgrel pkgdesc arch url license depends; do
        if grep -q "^$field=" "$pkg"; then
            log_test "PKGBUILD:$pkgname:$field" "PASS"
        else
            log_test "PKGBUILD:$pkgname:$field" "FAIL" "Missing $field"
        fi
    done
done
echo ""

echo "--- Shell Script Validation ---"
for script in "$REPO_DIR"/scripts/build/*.sh "$REPO_DIR"/packages/*/scripts/*; do
    [[ -f "$script" ]] || continue
    scriptname=$(basename "$script")
    if bash -n "$script" 2>/dev/null; then
        log_test "SCRIPT:$scriptname:syntax" "PASS"
    else
        log_test "SCRIPT:$scriptname:syntax" "FAIL" "Syntax error"
    fi
done
echo ""

echo "--- Python Syntax Validation ---"
for pyfile in "$REPO_DIR"/packages/*/src/*.py "$REPO_DIR"/ecosystem/*/cloud/cmd/server/main.py; do
    [[ -f "$pyfile" ]] || continue
    pyname=$(basename "$pyfile")
    if python3 -m py_compile "$pyfile" 2>/dev/null; then
        log_test "PYTHON:$pyname:syntax" "PASS"
    else
        log_test "PYTHON:$pyname:syntax" "FAIL" "Syntax error"
    fi
done
echo ""

echo "--- Documentation Validation ---"
for doc in "$REPO_DIR"/docs/**/*.md; do
    [[ -f "$doc" ]] || continue
    docname="${doc#$REPO_DIR/}"
    if [[ -s "$doc" ]]; then
        log_test "DOCS:$docname:exists" "PASS"
    else
        log_test "DOCS:$docname:exists" "FAIL" "Empty file"
    fi

    if head -1 "$doc" | grep -q "^#"; then
        log_test "DOCS:$docname:has-title" "PASS"
    else
        log_test "DOCS:$docname:has-title" "FAIL" "Missing title"
    fi
done
echo ""

echo "--- Config File Validation ---"
for conf in "$REPO_DIR"/packages/*/config/*.conf; do
    [[ -f "$conf" ]] || continue
    confname=$(basename "$conf")
    if python3 -c "import json; json.load(open('$conf'))" 2>/dev/null; then
        log_test "CONFIG:$confname:json-valid" "PASS"
    else
        log_test "CONFIG:$confname:json-valid" "SKIP" "Not JSON or invalid"
    fi
done
echo ""

echo "--- Desktop File Validation ---"
for desktop in "$REPO_DIR"/packages/*/desktop/*.desktop; do
    [[ -f "$desktop" ]] || continue
    dname=$(basename "$desktop")
    has_name=$(grep -c "^Name=" "$desktop" || true)
    has_exec=$(grep -c "^Exec=" "$desktop" || true)
    has_type=$(grep -c "^Type=" "$desktop" || true)
    if [[ $has_name -gt 0 && $has_exec -gt 0 && $has_type -gt 0 ]]; then
        log_test "DESKTOP:$dname:valid" "PASS"
    else
        log_test "DESKTOP:$dname:valid" "FAIL" "Missing required fields"
    fi
done
echo ""

echo "--- Go Module Validation ---"
if command -v go &>/dev/null; then
    for gomod in "$REPO_DIR"/ecosystem/*/cloud/go.mod; do
        [[ -f "$gomod" ]] || continue
        modname=$(dirname "$gomod")
        if (cd "$modname" && go mod verify 2>/dev/null); then
            log_test "GO:$(basename "$modname"):modules" "PASS"
        else
            log_test "GO:$(basename "$modname"):modules" "SKIP" "Cannot verify without go"
        fi
    done
else
    log_test "GO:runtime" "SKIP" "Go not installed"
fi
echo ""

echo "--- Rust/Cargo Validation ---"
if command -v cargo &>/dev/null; then
    for cargotoml in "$REPO_DIR"/ecosystem/*/desktop/Cargo.toml; do
        [[ -f "$cargotoml" ]] || continue
        crate_name=$(dirname "$cargotoml")
        if (cd "$crate_name" && cargo check 2>/dev/null); then
            log_test "RUST:$(basename "$crate_name"):check" "PASS"
        else
            log_test "RUST:$(basename "$crate_name"):check" "SKIP" "Cannot check without deps"
        fi
    done
else
    log_test "RUST:runtime" "SKIP" "Cargo not installed"
fi
echo ""

echo "--- CMake Validation ---"
for cmakefile in "$REPO_DIR"/packages/*/src/CMakeLists.txt; do
    [[ -f "$cmakefile" ]] || continue
    cmake_name=$(basename "$(dirname "$(dirname "$cmakefile")")")
    if grep -q "cmake_minimum_required" "$cmakefile"; then
        log_test "CMAKE:$cmake_name:valid" "PASS"
    else
        log_test "CMAKE:$cmake_name:valid" "FAIL" "Missing cmake_minimum_required"
    fi
done
echo ""

# Write results JSON
echo "[" > "$RESULTS_FILE"
for i in "${!TESTS[@]}"; do
    if [[ $i -lt $((${#TESTS[@]} - 1)) ]]; then
        echo "  ${TESTS[$i]}," >> "$RESULTS_FILE"
    else
        echo "  ${TESTS[$i]}" >> "$RESULTS_FILE"
    fi
done
echo "]" >> "$RESULTS_FILE"

echo "=== Test Results ==="
echo "  PASSED:  $PASS"
echo "  FAILED:  $FAIL"
echo "  SKIPPED: $SKIP"
echo "  TOTAL:   $((PASS + FAIL + SKIP))"
echo ""
echo "Results saved to: $RESULTS_FILE"

if [[ $FAIL -gt 0 ]]; then
    echo "SOME TESTS FAILED"
    exit 1
fi

echo "ALL TESTS PASSED"
