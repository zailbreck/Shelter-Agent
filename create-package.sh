#!/bin/bash
###############################################################################
# Create ShelterAgent Distribution Package
# Generates a tarball that can be hosted for quick-install.sh
###############################################################################

VERSION="1.0.0"
PACKAGE_NAME="shelteragent"
OUTPUT_DIR="dist"

echo "Creating ShelterAgent distribution package..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Create temporary directory for packaging
TMP_DIR=$(mktemp -d)
AGENT_DIR="$TMP_DIR/$PACKAGE_NAME"

mkdir -p "$AGENT_DIR"
mkdir -p "$AGENT_DIR/collectors"

echo "Copying agent files..."

# Copy main agent files
cp agent.py "$AGENT_DIR/"
cp requirements.txt "$AGENT_DIR/"

# Copy collectors
cp collectors/__init__.py "$AGENT_DIR/collectors/"
cp collectors/cpu.py "$AGENT_DIR/collectors/"
cp collectors/memory.py "$AGENT_DIR/collectors/"
cp collectors/disk.py "$AGENT_DIR/collectors/"
cp collectors/network.py "$AGENT_DIR/collectors/"
cp collectors/services.py "$AGENT_DIR/collectors/"

# Create tarball
echo "Creating tarball..."
cd "$TMP_DIR"
tar -czf "$PACKAGE_NAME-${VERSION}.tar.gz" "$PACKAGE_NAME"

# Move to output directory
mv "$PACKAGE_NAME-${VERSION}.tar.gz" "$OLDPWD/$OUTPUT_DIR/"

# Cleanup
rm -rf "$TMP_DIR"

# Calculate checksum
cd "$OLDPWD/$OUTPUT_DIR"
SHA256=$(sha256sum "$PACKAGE_NAME-${VERSION}.tar.gz" | awk '{print $1}')

echo ""
echo "✓ Package created: $OUTPUT_DIR/$PACKAGE_NAME-${VERSION}.tar.gz"
echo "✓ SHA256: $SHA256"
echo ""
echo "Upload this file to your server and update quick-install.sh with:"
echo "  DOWNLOAD_URL=\"https://your-server.com/path/to/$PACKAGE_NAME-${VERSION}.tar.gz\""
echo "  EXPECTED_SHA256=\"$SHA256\""
echo ""
