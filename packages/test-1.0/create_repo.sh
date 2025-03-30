#!/bin/sh
# Script to generate the repository metadata for pfSense packages

set -e

REPO_DIR="repo"

# Run pkg repo to generate the repository metadata
pkg repo "${REPO_DIR}"

echo "✅ Repository metadata generated in ${REPO_DIR}"

