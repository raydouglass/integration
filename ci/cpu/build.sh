#!/bin/bash
# Copyright (c) 2020, NVIDIA CORPORATION.
###############################################################
# rapids/rapids-xgboost meta pkg conda build script for gpuCI #
#                                                             #
# config set in `ci/axis/*.yml`                               #
###############################################################
set -e

# Set paths
export PATH=/conda/bin:$PATH
export HOME=$WORKSPACE

# Save original build offset
export ORIG_OFFSET=$RAPIDS_OFFSET

# Activate conda env
source activate gdf

# Print current env vars
env

# Install gpuCI tools
curl -s https://raw.githubusercontent.com/rapidsai/gpuci-tools/master/install.sh | bash
source ~/.bashrc
cd ~

# Print diagnostic information
gpuci_logger "Print conda info..."
conda info
conda config --show-sources
conda list --show-channel-urls

function build_pkg {
  # Build pkg
  gpuci_logger "Start conda build for '${1}'..."
  conda build -c ${CONDA_USERNAME:-rapidsai-nightly} -c nvidia -c conda-forge --python=${PYTHON_VERSION} ${1}
}

function build_default_pkg {
  # Build default version if current version matches DEFAULT_CUDA_VERSION
  if [ "$CUDA_VERSION" == "$DEFAULT_CUDA_VERSION" ] ; then
    gpuci_logger "Current CUDA_VERSION '$CUDA_VERSION' is the DEFAULT_CUDA_VERSION, building package again with incremented build number..."
    gpuci_logger "Previous build number '$RAPIDS_OFFSET'"
    export RAPIDS_OFFSET=$((RAPIDS_OFFSET+1))
    gpuci_logger "New build number '$RAPIDS_OFFSET'"
    build_pkg $1
    # Reset offset
    export RAPIDS_OFFSET=$ORIG_OFFSET
    gpuci_logger "Reset build number after default build '$RAPIDS_OFFSET'"
  else
    gpuci_logger "Current CUDA_VERSION '$CUDA_VERSION' is not DEFAULT_CUDA_VERSION, skipping default build..."
  fi
}

function run_builds {
  # Kick off main pkg b
  build_pkg $1
  # Check and build default pkgs
  build_default_pkg $1
}

function upload_builds {
  # Check for upload key
  if [ -z "$MY_UPLOAD_KEY" ]; then
    gpuci_logger "No upload key found, env var MY_UPLOAD_KEY not set, skipping upload..."
  else
    gpuci_logger "Upload key found, starting upload..."
    gpuci_logger "Files to upload..."
    ls /conda/conda-bld/linux-64/rapids*.tar.bz2

    gpuci_logger "Starting upload..."
    ls /conda/conda-bld/linux-64/rapids*.tar.bz2 | xargs gpuci_retry \
      anaconda -t ${MY_UPLOAD_KEY} upload -u ${CONDA_USERNAME:-rapidsai-nightly} --label main --force
  fi
}

# Run builds
run_builds $CONDA_XGBOOST_RECIPE
run_builds $CONDA_RAPIDS_RECIPE
run_builds $CONDA_RAPIDS_BUILD_RECIPE
run_builds $CONDA_RAPIDS_NOTEBOOK_RECIPE
run_builds $CONDA_RAPIDS_DOC_RECIPE

# Upload builds
upload_builds
