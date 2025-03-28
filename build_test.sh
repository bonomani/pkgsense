#!/bin/sh
# Build script for test FreeRADIUS pkg
# Save as: build.sh

set -e

PKGNAME=test
PKGVERSION=1.0
PKGDIR=${PKGNAME}-${PKGVERSION}

# Create the pkg dir layout
mkdir -p ${PKGDIR}/usr/local/etc/test
mkdir -p ${PKGDIR}/+COMPACT_MANIFEST

# Add your test script
cat > ${PKGDIR}/usr/local/etc/test/test.txt <<'EOF'
This is a test package file.
EOF

# Create manifest
cat > ${PKGDIR}/+MANIFEST <<EOF
{
  "name": "${PKGNAME}",
  "version": "${PKGVERSION}",
  "comment": "Test package for pfSense custom repo",
  "maintainer": "you@example.com",
  "origin": "custom/test",
  "www": "https://github.com/bonomani/pfsense-custom",
  "prefix": "/usr/local",
  "licenselogic": "single",
  "licenses": ["BSD"],
  "flatsize": 1024,
  "desc": "Simple test package to validate custom pfSense repo"
}
EOF

# Package it
pkg create -r ${PKGDIR} -m ${PKGDIR} -p /dev/null -o repo

# Generate packagesite.yaml for repo
pkg repo repo

echo "✅ Test package created: repo/${PKGNAME}-${PKGVERSION}.txz"
echo "📦 packagesite.yaml generated in repo/"

