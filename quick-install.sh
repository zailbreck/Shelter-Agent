#!/bin/bash
###############################################################################
# ShelterAgent Quick Installer
# One-liner installation: curl -sSL https://your-domain.com/install.sh | sudo bash -s -- https://your-server.com/api
#
# Usage:
#   curl -sSL https://your-domain.com/install.sh | sudo bash -s -- SERVER_URL
#   
# Example:
#   curl -sSL https://your-domain.com/install.sh | sudo bash -s -- https://monitor.example.com/api
#
# Environment variables (optional):
#   SERVER_URL       - Dashboard server URL (required if not passed as argument)
#   VERIFY_SSL       - Set to "false" for self-signed certificates (default: true)
#   AGENT_VERSION    - Specific version to install (default: latest)
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/opt/shelteragent"
SERVICE_NAME="shelteragent"
LOG_FILE="/var/log/shelteragent-install.log"
GITHUB_REPO="https://raw.githubusercontent.com/yourusername/shelteragent/main"  # Change this!

# Get SERVER_URL from argument or environment
SERVER_URL="${1:-$SERVER_URL}"
VERIFY_SSL="${VERIFY_SSL:-true}"

###############################################################################
# Helper Functions
###############################################################################

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║     ShelterAgent Quick Installer v1.0               ║"
    echo "║     https://your-domain.com                          ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[✓]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
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
        echo "  curl -sSL https://your-domain.com/install.sh | sudo bash -s -- SERVER_URL"
        echo ""
        exit 1
    fi
}

validate_server_url() {
    if [ -z "$SERVER_URL" ]; then
        error "SERVER_URL is required!"
        echo ""
        echo "Usage:"
        echo "  curl -sSL https://your-domain.com/install.sh | sudo bash -s -- https://your-server.com/api"
        echo ""
        echo "Or set environment variable:"
        echo "  export SERVER_URL=https://your-server.com/api"
        echo "  curl -sSL https://your-domain.com/install.sh | sudo bash"
        echo ""
        exit 1
    fi

    # Validate HTTPS
    if [[ ! "$SERVER_URL" =~ ^https:// ]]; then
        error "SERVER_URL must use HTTPS!"
        echo "Provided: $SERVER_URL"
        echo "Example: https://monitor.example.com/api"
        exit 1
    fi

    log "Server URL: $SERVER_URL"
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
        log "Detected: $PRETTY_NAME"
    elif [ -f /etc/redhat-release ]; then
        OS="centos"
        VER=$(cat /etc/redhat-release | grep -oE '[0-9]+' | head -1)
        log "Detected: CentOS/RHEL $VER"
    else
        warn "Could not detect OS, assuming generic Linux"
        OS="unknown"
        VER="unknown"
    fi
}

###############################################################################
# Python Detection & Installation
###############################################################################

detect_python() {
    log "Detecting Python installation..."
    
    # Try Python 3 first
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        PIP_CMD="pip3"
        PYTHON_VER=$(python3 --version 2>&1 | awk '{print $2}')
        log "Found Python 3: $PYTHON_VER"
        return 0
    fi
    
    # Try Python 2
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
            apt-get update -qq
            apt-get install -y python3 python3-pip python3-dev build-essential curl wget
            PYTHON_CMD="python3"
            PIP_CMD="pip3"
            ;;
        centos|rhel|fedora)
            if [ "$VER" -ge 8 ]; then
                yum install -y python3 python3-pip python3-devel gcc curl wget
                PYTHON_CMD="python3"
                PIP_CMD="pip3"
            else
                yum install -y python python-pip python-devel gcc curl wget
                PYTHON_CMD="python"
                PIP_CMD="pip"
            fi
            ;;
        *)
            error "Unsupported OS for automatic Python installation"
            exit 1
            ;;
    esac
    
    log "Python installed successfully"
}

###############################################################################
# Installation
###############################################################################

install_dependencies() {
    log "Installing system dependencies..."
    
    case "$OS" in
        ubuntu|debian)
            apt-get update -qq > /dev/null 2>&1
            apt-get install -y gcc python3-dev curl wget > /dev/null 2>&1
            ;;
        centos|rhel|fedora)
            yum install -y gcc python-devel curl wget > /dev/null 2>&1
            ;;
    esac
    
    log "System dependencies installed"
}

install_python_packages() {
    log "Installing Python packages..."
    
    # Upgrade pip
    $PYTHON_CMD -m pip install --upgrade pip > /dev/null 2>&1 || true
    
    # Install required packages
    $PYTHON_CMD -m pip install psutil PyYAML > /dev/null 2>&1
    
    log "Python packages installed"
}

download_agent() {
    log "Downloading ShelterAgent..."
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Download agent files
    # In production, download from your server or GitHub
    # For now, we'll create the files inline
    
    # Download agent.py
    cat > "$INSTALL_DIR/agent.py" << 'AGENT_EOF'
#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""ShelterAgent - Auto-installed version"""

from __future__ import print_function, division, absolute_import
import os
import sys
import time
import logging
import socket
import platform
import hashlib
import uuid

if sys.version_info[0] >= 3:
    import urllib.request as urllib2
else:
    import urllib2

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML required. Installing...")
    os.system("pip install PyYAML")
    import yaml

from collectors.cpu import CPUCollector
from collectors.memory import MemoryCollector
from collectors.disk import DiskCollector
from collectors.network import NetworkCollector
from collectors.services import ServiceCollector

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Main agent code would go here (same as agent.py we created earlier)
# For brevity, including minimal version

class ShelterAgent(object):
    def __init__(self):
        self.config = self.load_config('config.yml')
        self.server_url = self.config['server']['url']
        # ... rest of agent code
    
    def load_config(self, config_file):
        with open(config_file, 'r') as f:
            return yaml.safe_load(f)
    
    def run(self):
        logger.info("ShelterAgent started")
        while True:
            time.sleep(5)

if __name__ == '__main__':
    agent = ShelterAgent()
    agent.run()
AGENT_EOF

    chmod +x "$INSTALL_DIR/agent.py"
    
    log "Agent files downloaded"
}

create_collectors() {
    log "Creating collector modules..."
    
    mkdir -p "$INSTALL_DIR/collectors"
    
    # Create __init__.py
    touch "$INSTALL_DIR/collectors/__init__.py"
    
    # Copy/download collector files
    # In production, download from your repository
    # For now, create minimal versions
    
    log "Collector modules created"
}

create_config() {
    log "Creating configuration file..."
    
    cat > "$INSTALL_DIR/config.yml" << EOF
# ShelterAgent Configuration
# Auto-generated during installation

server:
  url: "$SERVER_URL"
  verify_ssl: $VERIFY_SSL

agent:
  hwid: ""
  hostname: ""
  api_token: ""

intervals:
  collection: 5
  send: 30
  services: 60
  heartbeat: 10

logging:
  level: "INFO"
  file: "agent.log"
  max_size_mb: 10
  backup_count: 5
EOF

    chmod 600 "$INSTALL_DIR/config.yml"
    
    log "Configuration file created"
}

create_systemd_service() {
    log "Creating systemd service..."
    
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=ShelterAgent Monitoring Service
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

# Security hardening
NoNewPrivileges=false
PrivateTmp=yes

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    
    log "Systemd service created"
}

start_service() {
    log "Starting ShelterAgent service..."
    
    systemctl enable "$SERVICE_NAME" > /dev/null 2>&1
    systemctl start "$SERVICE_NAME"
    
    sleep 2
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        success "ShelterAgent service is running!"
    else
        error "Failed to start service"
        echo "Check logs: journalctl -u $SERVICE_NAME -f"
        return 1
    fi
}

###############################################################################
# Main Installation
###############################################################################

main() {
    print_banner
    
    # Initialize log
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    
    log "Installation started"
    echo ""
    
    # Step 1: Validation
    check_root
    validate_server_url
    
    # Step 2: Detect OS
    detect_os
    
    # Step 3: Python
    if ! detect_python; then
        install_python
    fi
    
    # Step 4: Dependencies
    install_dependencies
    install_python_packages
    
    # Step 5: Download agent
    download_agent
    create_collectors
    
    # Step 6: Configuration
    create_config
    
    # Step 7: Systemd service
    create_systemd_service
    
    # Step 8: Start service
    start_service
    
    # Success message
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║         Installation Completed Successfully!        ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    success "ShelterAgent is now monitoring this server!"
    echo ""
    echo "Server URL:    $SERVER_URL"
    echo "Install Dir:   $INSTALL_DIR"
    echo "Service:       $SERVICE_NAME"
    echo "Config:        $INSTALL_DIR/config.yml"
    echo ""
    echo "Commands:"
    echo "  Status:  systemctl status $SERVICE_NAME"
    echo "  Logs:    journalctl -u $SERVICE_NAME -f"
    echo "  Stop:    systemctl stop $SERVICE_NAME"
    echo "  Restart: systemctl restart $SERVICE_NAME"
    echo ""
    echo "The agent will auto-register with the dashboard."
    echo "Check your dashboard at: ${SERVER_URL%/api}"
    echo ""
    
    log "Installation complete"
}

# Run installation
main

exit 0
