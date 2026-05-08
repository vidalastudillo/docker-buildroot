#!/bin/bash
# -----------------------------------------------------------------------------
# run_template.sh - Template for BR2_EXTERNAL run scripts
# Project: docker-buildroot
# -----------------------------------------------------------------------------
#
# INSTRUCTIONS: Copy this file into your BR2_EXTERNAL directory (e.g.
# externals/my_project/run_my_target.sh) and fill in the "Configuration"
# section below.
#
# IMPORTANT: This script MUST always be called from the docker-buildroot
# root directory. Example:
#   ./externals/my_project/run_my_target.sh make my_defconfig
#   ./externals/my_project/run_my_target.sh make all
#
# SHARED RESOURCES (managed by this infrastructure, do not change):
#   Downloads:  /workspace/dl       — shared across all externals
#   CCache:     /workspace/ccache   — shared across all externals
#   Buildroot:  /root/buildroot     — bind-mounted from ./buildroot/
#   Externals:  /buildroot_externals — bind-mounted from ./externals/
#
# IMAGE NAME: defaults to 'va_buildroot'. Override per session with:
#   export BUILDROOT_IMAGE=my_custom_image
# -----------------------------------------------------------------------------

set -e

# Ensure the shared workspace volume exists
docker volume inspect buildroot_workspace >/dev/null 2>&1 || docker volume create buildroot_workspace


# -----------------------------------------------------------------------------
# Configuration — fill these in for your external
# -----------------------------------------------------------------------------

# Docker image produced by this repo's Dockerfile.
# Override with: export BUILDROOT_IMAGE=my_image
BUILDROOT_IMAGE=${BUILDROOT_IMAGE:-va_buildroot}

# Internal container paths — do not change
BUILDROOT_DIR=/root/buildroot
EXTERNAL_TREES_DIR=/buildroot_externals

# Subfolder name used to isolate this target's outputs on the host.
# Results will be written to: ./images/<OUTPUT_NAME>/, ./target/<OUTPUT_NAME>/,
# and ./graphs/<OUTPUT_NAME>/
OUTPUT_NAME=my_project/my_target   # e.g. "pi_swupdate/cm4" or "kivy/rpi2"

# Path to your external tree inside the container.
# For a single external: ${EXTERNAL_TREES_DIR}/my_project
# For multiple externals: ${EXTERNAL_TREES_DIR}/first:${EXTERNAL_TREES_DIR}/second
MY_EXTERNAL=${EXTERNAL_TREES_DIR}/my_project

# CCache size limit
CCACHE_LIMIT="50G"

# Output directory inside the container workspace (derived, do not change)
OUTPUT_DIR=/workspace/outputs/${OUTPUT_NAME}


# -----------------------------------------------------------------------------
# Docker run command
# -----------------------------------------------------------------------------

# Detect if we are in an interactive terminal
[ -t 0 ] && TTY_FLAGS="-ti" || TTY_FLAGS=""

# At least on macOS, exposing the full OUTPUT_DIR to the host negatively
# impacts build speed and causes frequent errors building libraries.
# Only images, target and graphs are bind-mounted to the host.
DOCKER_RUN="docker run
    --rm
    $TTY_FLAGS
    -v buildroot_workspace:/workspace
    -e OUTPUT_DIR=$OUTPUT_DIR
    -e BR2_CCACHE_DIR=/workspace/ccache
    -e BR2_DL_DIR=/workspace/dl
    -e CCACHE_MAXSIZE=$CCACHE_LIMIT
    -e CCACHE_BASEDIR=/workspace
    -e CCACHE_COMPILERCHECK=content
    -v $(pwd)/buildroot:$BUILDROOT_DIR:ro
    -v $(pwd)/externals:$EXTERNAL_TREES_DIR
    -v $(pwd)/images/${OUTPUT_NAME}:$OUTPUT_DIR/images
    -v $(pwd)/target/${OUTPUT_NAME}:$OUTPUT_DIR/target
    -v $(pwd)/graphs/${OUTPUT_NAME}:$OUTPUT_DIR/graphs
    $BUILDROOT_IMAGE"

# Builds the make invocation string.
# BR2_DL_DIR on the command line takes highest precedence, overriding any
# value that .config may set, ensuring downloads always go to the shared
# workspace volume.
make() {
    echo "make BR2_EXTERNAL=${MY_EXTERNAL} O=$OUTPUT_DIR BR2_DL_DIR=/workspace/dl"
}

if [ "$1" == "make" ]; then
    eval $DOCKER_RUN $(make) ${@:2}
else
    eval $DOCKER_RUN $@
fi
