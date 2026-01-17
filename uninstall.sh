#!/bin/bash
###############################################################################
# sys32 Uninstaller
# Removes all sys32 agent files, configurations, and services
#
# Usage:
#   sudo bash uninstall.sh
#
# This will:
#   - Stop and disable sys32 service
#   - Remove systemd service file
#   - Delete installation directory
#   - Remove log files
#   - Clean up all traces of sys32 agent
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
INSTALL_DIR="/opt/sys32"
SERVICE_NAME="sys32"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
LOG_FILE="/var/log/sys32-install.log"

###############################################################################
# Helper Functions
###############################################################################

print_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║          sys32 Uninstaller                           ║"
    echo "║          Remove all agent files                       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

###############################################################################
# Root Check
###############################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then 
        error "This script must be run as root!"
        echo ""
        echo "Please run with sudo:"
        echo "  sudo bash uninstall.sh"
        echo ""
        exit 1
    fi
}

###############################################################################
# Confirmation
###############################################################################

confirm_uninstall() {
    echo ""
    warn "This will completely remove sys32 agent from this system!"
    echo ""
    echo "The following will be deleted:"
    echo "  - Systemd service: $SERVICE_FILE"
    echo "  - Installation directory: $INSTALL_DIR"
    echo "  - Log file: $LOG_FILE"
    echo "  - Virtual environment and all packages"
    echo ""
    
    read -p "Are you sure you want to continue? (yes/no): " -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi
}

###############################################################################
# Uninstallation Steps
###############################################################################

stop_service() {
    log "Stopping sys32 service..."
    
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl stop "$SERVICE_NAME"
        log "Service stopped"
    else
        warn "Service not running"
    fi
}

disable_service() {
    log "Disabling sys32 service..."
    
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SERVICE_NAME"
        log "Service disabled"
    else
        warn "Service not enabled"
    fi
}

remove_service_file() {
    log "Removing systemd service file..."
    
    if [ -f "$SERVICE_FILE" ]; then
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        log "Service file removed"
    else
        warn "Service file not found"
    fi
}

remove_installation_dir() {
    log "Removing installation directory..."
    
    if [ -d "$INSTALL_DIR" ]; then
        # Show what will be deleted
        echo "Deleting: $INSTALL_DIR"
        du -sh "$INSTALL_DIR" 2>/dev/null || true
        
        rm -rf "$INSTALL_DIR"
        log "Installation directory removed"
    else
        warn "Installation directory not found"
    fi
}

remove_log_file() {
    log "Removing log file..."
    
    if [ -f "$LOG_FILE" ]; then
        rm -f "$LOG_FILE"
        log "Log file removed"
    else
        warn "Log file not found"
    fi
}

cleanup_temp_files() {
    log "Cleaning up temporary files..."
    
    # Remove any temp directories that might be left over
    rm -rf /tmp/sys32-install-* 2>/dev/null || true
    
    log "Temporary files cleaned"
}

###############################################################################
# Main Uninstallation
###############################################################################

main() {
    print_banner
    
    # Check root
    check_root
    
    # Confirm
    confirm_uninstall
    
    echo ""
    log "Starting uninstallation..."
    echo ""
    
    # Step 1: Stop service
    stop_service
    
    # Step 2: Disable service
    disable_service
    
    # Step 3: Remove service file
    remove_service_file
    
    # Step 4: Remove installation directory
    remove_installation_dir
    
    # Step 5: Remove log file
    remove_log_file
    
    # Step 6: Cleanup temp files
    cleanup_temp_files
    
    # Success
    echo ""
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║        Uninstallation Completed Successfully!       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo ""
    success "sys32 agent has been completely removed from this system!"
    echo ""
    echo "Removed items:"
    echo "  ✓ Systemd service"
    echo "  ✓ Installation directory: $INSTALL_DIR"
    echo "  ✓ Virtual environment and packages"
    echo "  ✓ Log files"
    echo ""
    echo "Note: The agent record may still exist in the dashboard."
    echo "You can delete it from the dashboard UI if needed."
    echo ""
}

# Run uninstallation
main

exit 0
