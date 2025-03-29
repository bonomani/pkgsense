#!/bin/sh
# Build script for test FreeRADIUS pkg

set -e

PKGNAME=test
PKGVERSION=1.0
PKGDIR=${PKGNAME}-${PKGVERSION}
REPO_DIR=repo

# Cleanup
rm -rf ${REPO_DIR}
mkdir -p ${REPO_DIR}

# Package it
pkg create -r ${PKGDIR} -m ${PKGDIR} -p /dev/null -o ${REPO_DIR}
pkg repo ${REPO_DIR}

echo "✅ Paquet généré : ${REPO_DIR}/${PKGNAME}-${PKGVERSION}.txz"

