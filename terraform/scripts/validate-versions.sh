#!/bin/bash

# Module Version Validation Script
# Validates that version numbers are consistent across all version files and main.tf

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Change to terraform directory
cd "$(dirname "$0")/.."

print_info "============================================"
print_info "Module Version Validation"
print_info "============================================"

# Read version files
if [ -f "modules/azure/VERSION" ]; then
    AZURE_VERSION=$(cat modules/azure/VERSION | tr -d '\n')
else
    print_error "modules/azure/VERSION not found!"
    exit 1
fi

if [ -f "modules/em/VERSION" ]; then
    EM_VERSION=$(cat modules/em/VERSION | tr -d '\n')
else
    print_error "modules/em/VERSION not found!"
    exit 1
fi

# Extract versions from main.tf
if [ -f "main.tf" ]; then
    MAIN_AZURE=$(grep 'azure_modules_version.*=' main.tf | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')
    MAIN_EM=$(grep 'em_module_version.*=' main.tf | sed -E 's/.*"([0-9]+\.[0-9]+\.[0-9]+)".*/\1/')
else
    print_error "main.tf not found!"
    exit 1
fi

# Display versions
print_info ""
print_info "Current Module Versions:"
print_info "────────────────────────"
echo ""
echo "Azure Base Modules:"
echo "  📄 Version File: ${AZURE_VERSION}"
echo "  📝 main.tf:      ${MAIN_AZURE}"
echo ""
echo "EM Module:"
echo "  📄 Version File: ${EM_VERSION}"
echo "  📝 main.tf:      ${MAIN_EM}"
echo ""

# Validation
ERRORS=0

print_info "Validation Results:"
print_info "───────────────────"

# Check Azure modules version
if [ "$AZURE_VERSION" = "$MAIN_AZURE" ]; then
    print_success "✓ Azure modules version is consistent"
else
    print_error "✗ Azure modules version mismatch!"
    print_error "  Version file: $AZURE_VERSION"
    print_error "  main.tf:      $MAIN_AZURE"
    ERRORS=$((ERRORS + 1))
fi

# Check EM module version
if [ "$EM_VERSION" = "$MAIN_EM" ]; then
    print_success "✓ EM module version is consistent"
else
    print_error "✗ EM module version mismatch!"
    print_error "  Version file: $EM_VERSION"
    print_error "  main.tf:      $MAIN_EM"
    ERRORS=$((ERRORS + 1))
fi

# Check version format (semantic versioning)
validate_semver() {
    if [[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 0
    else
        return 1
    fi
}

if validate_semver "$AZURE_VERSION"; then
    print_success "✓ Azure modules version format is valid (semver)"
else
    print_error "✗ Azure modules version format is invalid: $AZURE_VERSION"
    ERRORS=$((ERRORS + 1))
fi

if validate_semver "$EM_VERSION"; then
    print_success "✓ EM module version format is valid (semver)"
else
    print_error "✗ EM module version format is invalid: $EM_VERSION"
    ERRORS=$((ERRORS + 1))
fi

# Check if CHANGELOG files exist
print_info ""
print_info "Changelog Validation:"
print_info "─────────────────────"

if [ -f "modules/azure/CHANGELOG.md" ]; then
    # Check if current version is documented
    if grep -q "\[$AZURE_VERSION\]" modules/azure/CHANGELOG.md; then
        print_success "✓ Azure modules CHANGELOG contains version $AZURE_VERSION"
    else
        print_warn "⚠ Azure modules CHANGELOG missing entry for version $AZURE_VERSION"
    fi
else
    print_error "✗ modules/azure/CHANGELOG.md not found!"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "modules/em/CHANGELOG.md" ]; then
    # Check if current version is documented
    if grep -q "\[$EM_VERSION\]" modules/em/CHANGELOG.md; then
        print_success "✓ EM module CHANGELOG contains version $EM_VERSION"
    else
        print_warn "⚠ EM module CHANGELOG missing entry for version $EM_VERSION"
    fi
else
    print_error "✗ modules/em/CHANGELOG.md not found!"
    ERRORS=$((ERRORS + 1))
fi

# Summary
print_info ""
print_info "============================================"
if [ $ERRORS -eq 0 ]; then
    print_success "All version validations passed! ✨"
    print_info "============================================"
    exit 0
else
    print_error "Version validation failed with $ERRORS error(s)"
    print_info "============================================"
    exit 1
fi
