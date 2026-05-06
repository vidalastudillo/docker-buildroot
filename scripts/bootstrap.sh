#!/bin/bash
# -----------------------------------------------------------------------------
# bootstrap.sh - Clone or update the Buildroot source
# Copyright (c) 2025-2026, VIDAL & ASTUDILLO Ltda and contributors.
# www.vidalastudillo.com
#
# Reads BUILDROOT_VERSION from the project root and clones or updates
# buildroot/ to the tip of the configured branch.
#
# Usage: ./scripts/bootstrap.sh
# Must be called from the docker-buildroot root directory.
# -----------------------------------------------------------------------------

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/BUILDROOT_VERSION"
BUILDROOT_DIR="$PROJECT_ROOT/buildroot"

log()   { echo -e "\033[1;32m[bootstrap]\033[0m $1"; }
error() { echo -e "\033[1;31m[error]\033[0m $1"; exit 1; }

[ -f "$VERSION_FILE" ] || error "BUILDROOT_VERSION not found at $VERSION_FILE"

# shellcheck source=../BUILDROOT_VERSION
source "$VERSION_FILE"

[ -n "$BUILDROOT_REPO"   ] || error "BUILDROOT_REPO is not set in BUILDROOT_VERSION"
[ -n "$BUILDROOT_BRANCH" ] || error "BUILDROOT_BRANCH is not set in BUILDROOT_VERSION"

if [ ! -d "$BUILDROOT_DIR/.git" ]; then
    log "Cloning $BUILDROOT_REPO (branch: $BUILDROOT_BRANCH)..."
    git clone --branch "$BUILDROOT_BRANCH" "$BUILDROOT_REPO" "$BUILDROOT_DIR"
else
    CURRENT_REMOTE=$(git -C "$BUILDROOT_DIR" remote get-url origin 2>/dev/null || echo "")
    if [ "$CURRENT_REMOTE" != "$BUILDROOT_REPO" ]; then
        error "buildroot/ points to '$CURRENT_REMOTE', expected '$BUILDROOT_REPO'. Fix manually."
    fi
    log "Updating buildroot/ to latest tip of $BUILDROOT_BRANCH..."
    git -C "$BUILDROOT_DIR" fetch origin
    git -C "$BUILDROOT_DIR" checkout "$BUILDROOT_BRANCH"
    git -C "$BUILDROOT_DIR" pull origin "$BUILDROOT_BRANCH"
fi

COMMIT=$(git -C "$BUILDROOT_DIR" log --oneline -1)
log "buildroot/ is ready: $COMMIT"
