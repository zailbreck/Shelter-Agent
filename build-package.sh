#!/bin/bash
###############################################################################
# ShelterAgent Package Builder
# Creates distributable packages (.tar.gz, .rpm, .deb)
#
# Usage: bash build-package.sh
###############################################################################

set -e

VERSION="1.0.0"
PACKAGE_NAME="shelteragent"
BUILD_DIR="build"
DIST_DIR="dist"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║         ShelterAgent Package Builder                 ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Clean previous builds
echo "[1/5] Cleaning previous builds..."
rm -rf "$BUILD_DIR" "$DIST_DIR" *.egg-info
echo "✓ Clean complete"

# Build source distribution
echo ""
echo "[2/5] Building source distribution..."
python setup.py sdist
echo "✓ Source distribution created"

# Build wheel (if possible)
echo ""
echo "[3/5] Building wheel package..."
if command -v python3 &> /dev/null; then
    python3 setup.py bdist_wheel 2>/dev/null || echo "  (Skipped - wheel not available)"
else
    echo "  (Skipped - Python 3 not available)"
fi

# Create installation tarball with installer
echo ""
echo "[4/5] Creating installation package..."
INSTALL_PKG="${PACKAGE_NAME}-${VERSION}-installer.tar.gz"

tar -czf "$DIST_DIR/$INSTALL_PKG" \
    agent.py \
    collectors/ \
    requirements.txt \
    .env.example \
    install.sh \
    README.md \
    --transform "s,^,${PACKAGE_NAME}-${VERSION}/,"

echo "✓ Installation package created: $DIST_DIR/$INSTALL_PKG"

# Display results
echo ""
echo "[5/5] Package build complete!"
echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║              Build Results                            ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
ls -lh "$DIST_DIR"
echo ""
echo "Installation Instructions:"
echo ""
echo "1. Copy package to target server:"
echo "   scp $DIST_DIR/$INSTALL_PKG user@server:/tmp/"
echo ""
echo "2. Extract and install:"
echo "   tar -xzf /tmp/$INSTALL_PKG"
echo "   cd ${PACKAGE_NAME}-${VERSION}"
echo "   sudo bash install.sh"
echo ""
echo "Or use Python package:"
echo "   pip install $DIST_DIR/${PACKAGE_NAME}-${VERSION}.tar.gz"
echo ""
