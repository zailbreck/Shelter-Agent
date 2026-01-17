#!/bin/bash
###############################################################################
# sys32 Quick Installer
# Zero-configuration installation from GitHub
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/YOUR-USERNAME/YOUR-REPO/main/install.sh | sudo bash
#
# No configuration needed - everything is pre-configured in config.yml
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration - UPDATE THESE BEFORE DEPLOYMENT
GITHUB_USER="zailbreck"           # TODO: Change to your GitHub username
GITHUB_REPO="Shelter-Agent"               # TODO: Change to your repo name
GITHUB_BRANCH="master"                  # Branch to download from
AGENT_ZIP_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/archive/refs/heads/${GITHUB_BRANCH}.zip"

# Installation settings
INSTALL_DIR="/opt/sys32"
SERVICE_NAME="sys32"
LOG_FILE="/var/log/sys32-install.log"
TEMP_DIR="/tmp/sys32-install-$$"

###############################################################################
# Helper Functions
###############################################################################

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                Quick Installer v2.0                  ║"
    echo "║           Zero-Configuration Installation            ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE" 2>/dev/null || true
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> "$LOG_FILE" 2>/dev/null || true
}

error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE" 2>/dev/null || true
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

###############################################################################
# Validation
###############################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "This script must be run as root!"
        echo ""
        echo "Please run with sudo or as root:"
        echo "  curl -sSL https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/install.sh | sudo bash"
        echo ""
        exit 1
    fi
}

###############################################################################
# System Detection
###############################################################################

detect_os() {
    log "Detecting operating system..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VER=$VERSION_ID
        OS_NAME=$PRETTY_NAME
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        VER=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
        OS_NAME="RedHat/CentOS $VER"
    else
        error "Unsupported operating system"
        exit 1
    fi
    
    # Validate supported OS
    case "$OS" in
        ubuntu|debian|almalinux|rhel|centos|rocky)
            log "Detected: $OS_NAME"
            ;;
        *)
            error "Unsupported OS: $OS"
            echo "Supported: Ubuntu, Debian, AlmaLinux, RHEL, Rocky Linux"
            exit 1
            ;;
    esac
}

###############################################################################
# Dependency Management
###############################################################################

install_zip_tools() {
    log "Checking for zip/unzip utilities..."
    
    NEED_INSTALL=0
    
    if ! command -v zip &> /dev/null; then
        warn "zip not found"
        NEED_INSTALL=1
    fi
    
    if ! command -v unzip &> /dev/null; then
        warn "unzip not found"
        NEED_INSTALL=1
    fi
    
    if [ $NEED_INSTALL -eq 0 ]; then
        log "zip/unzip already installed"
        return 0
    fi
    
    log "Installing zip/unzip..."
    
    case "$OS" in
        ubuntu|debian)
            apt-get update -qq > /dev/null 2>&1
            apt-get install -y zip unzip > /dev/null 2>&1
            ;;
        almalinux|rhel|centos|rocky)
            yum install -y zip unzip > /dev/null 2>&1 || dnf install -y zip unzip > /dev/null 2>&1
            ;;
    esac
    
    log "zip/unzip installed"
}

detect_python() {
    log "Detecting Python installation..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        PIP_CMD="pip3"
        PYTHON_VER=$(python3 --version 2>&1 | awk '{print $2}')
        log "Found Python 3: $PYTHON_VER"
        return 0
    fi
    
    if command -v python2 &> /dev/null; then
        PYTHON_CMD="python2"
        PIP_CMD="pip2"
        PYTHON_VER=$(python2 --version 2>&1 | awk '{print $2}')
        warn "Found Python 2: $PYTHON_VER (Python 3 recommended)"
        return 0
    fi
    
    if command -v python &> /dev/null; then
        PYTHON_CMD="python"
        PIP_CMD="pip"
        PYTHON_VER=$(python --version 2>&1 | awk '{print $2}')
        log "Found Python: $PYTHON_VER"
        return 0
    fi
    
    return 1
}

install_python() {
    log "Installing Python..."
    
    case "$OS" in
        ubuntu|debian)
            apt-get update -qq > /dev/null 2>&1
            apt-get install -y python3 python3-pip python3-dev build-essential curl wget > /dev/null 2>&1
            PYTHON_CMD="python3"
            PIP_CMD="pip3"
            ;;
        almalinux|rhel|centos|rocky)
            # Check version for package manager
            if command -v dnf &> /dev/null; then
                dnf install -y python3 python3-pip python3-devel gcc curl wget > /dev/null 2>&1
            else
                yum install -y python3 python3-pip python3-devel gcc curl wget > /dev/null 2>&1
            fi
            PYTHON_CMD="python3"
            PIP_CMD="pip3"
            ;;
    esac
    
    log "Python installed successfully"
}

install_python_packages() {
    log "Installing Python packages..."
    
    # Upgrade pip silently
    $PYTHON_CMD -m pip install --upgrade pip > /dev/null 2>&1 || true
    
    # Install required packages
    $PYTHON_CMD -m pip install psutil PyYAML > /dev/null 2>&1
    
    log "Python packages installed (psutil, PyYAML)"
}

###############################################################################
# Download & Extract
###############################################################################

download_agent() {
    log "Downloading sys32 from GitHub..."
    log "URL: $AGENT_ZIP_URL"
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    cd "$TEMP_DIR"
    
    # Download ZIP from GitHub
    if command -v wget &> /dev/null; then
        log "Using wget to download..."
        wget -O agent.zip "$AGENT_ZIP_URL" 2>&1 | tail -5
        DOWNLOAD_RESULT=$?
    elif command -v curl &> /dev/null; then
        log "Using curl to download..."
        curl -sSL -o agent.zip "$AGENT_ZIP_URL"
        DOWNLOAD_RESULT=$?
    else
        error "Neither wget nor curl found!"
        exit 1
    fi
    
    if [ $DOWNLOAD_RESULT -ne 0 ]; then
        error "Download failed with exit code: $DOWNLOAD_RESULT"
        echo "URL: $AGENT_ZIP_URL"
        exit 1
    fi
    
    if [ ! -f agent.zip ]; then
        error "Failed to download agent from GitHub"
        echo "URL: $AGENT_ZIP_URL"
        echo "Check if repository is public and branch name is correct"
        exit 1
    fi
    
    # Check file size
    FILE_SIZE=$(stat -f%z agent.zip 2>/dev/null || stat -c%s agent.zip 2>/dev/null)
    if [ "$FILE_SIZE" -lt 1000 ]; then
        error "Downloaded file is too small ($FILE_SIZE bytes)"
        echo "Content:"
        cat agent.zip
        exit 1
    fi
    
    log "Download complete ($FILE_SIZE bytes)"
}

extract_agent() {
    log "Extracting agent files..."
    
    cd "$TEMP_DIR"
    
    # Extract ZIP
    log "Unzipping archive..."
    if ! unzip -q agent.zip; then
        error "Failed to extract ZIP file"
        echo "Trying to see ZIP contents:"
        unzip -l agent.zip | head -20
        exit 1
    fi
    
    # Find extracted directory (GitHub creates repo-branch format)
    log "Looking for extracted directory..."
    ls -la
    
    EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "*${GITHUB_USER}*" -o -name "${GITHUB_REPO}*" | grep -v "^\.$" | head -1)
    
    if [ -z "$EXTRACTED_DIR" ]; then
        error "Failed to find extracted directory"
        echo "Expected directory pattern: ${GITHUB_REPO}-*"
        echo "Found directories:"
        ls -la
        exit 1
    fi
    
    log "Found extracted directory: $EXTRACTED_DIR"
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Check for python-agent subdirectory
    if [ -d "$EXTRACTED_DIR/python-agent" ]; then
        log "Copying from python-agent/ subdirectory..."
        cp -rv "$EXTRACTED_DIR/python-agent/"* "$INSTALL_DIR/" 2>&1 | head -10
    else
        log "No python-agent/ subdirectory, copying all files..."
        echo "Available directories in $EXTRACTED_DIR:"
        ls -la "$EXTRACTED_DIR"
        cp -rv "$EXTRACTED_DIR/"* "$INSTALL_DIR/" 2>&1 | head -10
    fi
    
    # Verify critical files exist
    if [ ! -f "$INSTALL_DIR/agent.py" ]; then
        error "agent.py not found after extraction!"
        echo "Contents of $INSTALL_DIR:"
        ls -la "$INSTALL_DIR"
        exit 1
    fi
    
    if [ ! -f "$INSTALL_DIR/config.yml" ]; then
        error "config.yml not found after extraction!"
        echo "Contents of $INSTALL_DIR:"
        ls -la "$INSTALL_DIR"
        exit 1
    fi
    
    # Set permissions
    chmod +x "$INSTALL_DIR/agent.py"
    chmod 600 "$INSTALL_DIR/config.yml"
    
    log "Agent files installed to $INSTALL_DIR"
    log "Installed files:"
    ls -lh "$INSTALL_DIR" | head -10
}

validate_config() {
    log "Validating configuration..."
    
    if [ ! -f "$INSTALL_DIR/config.yml" ]; then
        error "config.yml not found!"
        exit 1
    fi
    
    # Check if SERVER_URL is configured
    SERVER_URL=$(grep "url:" "$INSTALL_DIR/config.yml" | head -1 | awk '{print $2}' | tr -d '"')
    
    if [[ "$SERVER_URL" == *"YOUR-SERVER-URL-HERE"* ]]; then
        error "Server URL not configured!"
        echo ""
        echo "Please update config.yml in your GitHub repository:"
        echo "  server:"
        echo "    url: \"https://your-actual-server.com/api\""
        echo ""
        exit 1
    fi
    
    if [[ ! "$SERVER_URL" =~ ^https:// ]]; then
        error "Server URL must use HTTPS!"
        echo "Current: $SERVER_URL"
        exit 1
    fi
    
    log "Server URL: $SERVER_URL"
    log "Configuration validated"
}

###############################################################################
# Service Setup
###############################################################################

create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=sys32 Monitoring Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=$PYTHON_CMD $INSTALL_DIR/agent.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security
NoNewPrivileges=false
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    
    log "Systemd service created"
}

start_service() {
    log "Starting sys32 service..."
    
    systemctl enable "$SERVICE_NAME" > /dev/null 2>&1
    systemctl start "$SERVICE_NAME"
    
    sleep 3
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "sys32 service is running!"
        return 0
    else
        error "Failed to start service"
        echo ""
        echo "Check logs with:"
        echo "  journalctl -u $SERVICE_NAME -xe"
        echo ""
        return 1
    fi
}

###############################################################################
# Cleanup
###############################################################################

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

###############################################################################
# Main Installation
###############################################################################

main() {
    print_banner
    
    # Initialize log
    touch "$LOG_FILE" 2>/dev/null || true
    chmod 644 "$LOG_FILE" 2>/dev/null || true
    
    log "Installation started"
    echo ""
    
    # Step 1: Root check
    check_root
    
    # Step 2: Detect OS
    detect_os
    
    # Step 3: Install zip/unzip
    install_zip_tools
    
    # Step 4: Python
    if ! detect_python; then
        install_python
    fi
    
    # Step 5: Python packages
    install_python_packages
    
    # Step 6: Download from GitHub
    download_agent
    
    # Step 7: Extract
    extract_agent
    
    # Step 8: Validate config
    validate_config
    
    # Step 9: Create service
    create_systemd_service
    
    # Step 10: Start service
    if start_service; then
        echo ""
        echo "╔══════════════════════════════════════════════════════╗"
        echo "║      Installation Completed Successfully!           ║"
        echo "╚══════════════════════════════════════════════════════╝"
        echo ""
        success "sys32 is now monitoring this server!"
        echo ""
        echo "Installation Details:"
        echo "  OS:            $OS_NAME"
        echo "  Python:        $PYTHON_VER"
        echo "  Install Dir:   $INSTALL_DIR"
        echo "  Service:       $SERVICE_NAME"
        echo "  Server URL:    $SERVER_URL"
        echo ""
        echo "Useful Commands:"
        echo "  Status:   systemctl status $SERVICE_NAME"
        echo "  Logs:     journalctl -u $SERVICE_NAME -f"
        echo "  Restart:  systemctl restart $SERVICE_NAME"
        echo "  Stop:     systemctl stop $SERVICE_NAME"
        echo ""
        echo "The agent will auto-register with the dashboard within 30 seconds."
        echo ""
    else
        exit 1
    fi
    
    log "Installation complete"
}

# Run installation
main

exit 0
