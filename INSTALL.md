# ShelterAgent - Python Agent Installation Guide

## Quick Installation (Automated)

### Method 1: Using Installer Script (Recommended)

**Requirements**: Root/sudo access

```bash
# Download or copy the agent files to server
cd /tmp
# ... copy files here ...

# Run installer (will auto-detect Python 2/3)
sudo bash install.sh
```

The installer will:
- ✅ Check for root privileges (required)
- ✅ Detect OS (CentOS 6/7/8, Ubuntu 14.04+, Debian 7+)
- ✅ Detect or install Python (2.7+ or 3.x)
- ✅ Install system dependencies
- ✅ Install Python packages (psutil, etc.)
- ✅ Copy agent to `/opt/shelteragent`
- ✅ Configure systemd service
- ✅ Start and enable auto-start
- ✅ Auto-register with dashboard on first run

### Method 2: Using Pre-built Package

```bash
# Extract package
tar -xzf shelteragent-1.0.0-installer.tar.gz
cd shelteragent-1.0.0

# Run installer
sudo bash install.sh
```

### Method 3: Python Package Installation

```bash
# Install from source
pip install shelteragent-1.0.0.tar.gz

# Or install from directory
cd python-agent
sudo pip install .
```

---

## Compatibility

### Python Versions
- ✅ Python 2.7
- ✅ Python 3.5+
- ✅ Python 3.10+

### Supported Linux Distributions

| Distribution | Version | Status |
|-------------|---------|--------|
| CentOS | 6.x | ✅ Supported |
| CentOS | 7.x | ✅ Supported |
| CentOS | 8.x | ✅ Supported |
| RHEL | 6.x - 8.x | ✅ Supported |
| Ubuntu | 14.04+ | ✅ Supported |
| Debian | 7+ | ✅ Supported |
| Fedora | 20+ | ✅ Supported |

---

## Manual Installation

If automated installer fails, follow these steps:

### 1. Install Python (if needed)

**CentOS/RHEL 6/7:**
```bash
sudo yum install -y python python-pip python-devel gcc
```

**CentOS/RHEL 8:**
```bash
sudo yum install -y python3 python3-pip python3-devel gcc
```

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-dev build-essential
```

### 2. Install Python Dependencies

```bash
# Python 3
sudo pip3 install psutil python-dotenv

# Python 2
sudo pip install psutil python-dotenv
```

### 3. Copy Agent Files

```bash
sudo mkdir -p /opt/shelteragent
sudo cp -r agent.py collectors/ requirements.txt .env.example /opt/shelteragent/
```

### 4. Configure Agent

```bash
cd /opt/shelteragent
sudo cp .env.example .env
sudo nano .env
```

Set `SERVER_URL` to your dashboard URL:
```env
SERVER_URL=http://your-server-ip:8000/api
```

### 5. Create Systemd Service

```bash
sudo nano /etc/systemd/system/shelteragent.service
```

Content:
```ini
[Unit]
Description=ShelterAgent Monitoring Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/shelteragent
ExecStart=/usr/bin/python3 /opt/shelteragent/agent.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

**Note**: Change `/usr/bin/python3` to `/usr/bin/python` or `/usr/bin/python2` if using Python 2.

### 6. Start Service

```bash
sudo systemctl daemon-reload
sudo systemctl enable shelteragent
sudo systemctl start shelteragent
```

---

## Building Packages

To create distributable packages:

```bash
cd python-agent

# Build packages
bash build-package.sh
```

This creates:
- `dist/shelteragent-1.0.0.tar.gz` - Python package
- `dist/shelteragent-1.0.0-installer.tar.gz` - Complete installer package

---

## Verification

### Check Service Status

```bash
sudo systemctl status shelteragent
```

### View Logs

```bash
# Systemd logs
sudo journalctl -u shelteragent -f

# Agent log file
sudo tail -f /opt/shelteragent/agent.log
```

### Check Registration

After starting, the agent should automatically register with the dashboard. Check:

1. Dashboard UI: http://your-server:8000
2. Agent log for "Successfully registered" message
3. `.env` file should contain `API_TOKEN`

---

## Troubleshooting

### Installer Fails: "Must be run as root"

**Solution**: Use sudo
```bash
sudo bash install.sh
```

### Python Not Found

**Solution**: Install Python manually for your OS (see Manual Installation section)

### Service Won't Start

**Check logs**:
```bash
sudo journalctl -u shelteragent -xe
```

**Common issues**:
- Wrong Python path in service file
- Missing dependencies
- Network connectivity to dashboard
- Permissions on `/opt/shelteragent`

### Registration Fails

**Check**:
1. Server URL is correct in `.env`
2. Dashboard is running and accessible
3. Network connectivity: `curl http://your-server:8000/api/health`

### "No module named psutil"

**Solution**:
```bash
# Python 3
sudo pip3 install psutil

# Python 2
sudo pip install psutil
```

---

## Uninstallation

```bash
# Stop and disable service
sudosystemctl stop shelteragent
sudo systemctl disable shelteragent

# Remove service file
sudo rm /etc/systemd/system/shelteragent.service
sudo systemctl daemon-reload

# Remove agent files
sudo rm -rf /opt/shelteragent

# (Optional) Remove from dashboard
# Delete agent via dashboard UI or API
```

---

## Security Notes

- Agent runs as root for full system access
- API token is stored in `/opt/shelteragent/.env`
- Ensure `.env` has proper permissions (600)
- Use HTTPS for `SERVER_URL` in production
- Firewall: Agent needs outbound HTTP/HTTPS access

---

## Additional Commands

```bash
# Restart agent
sudo systemctl restart shelteragent

# Stop agent
sudo systemctl stop shelteragent

# Reconfigure
sudo nano /opt/shelteragent/.env
sudo systemctl restart shelteragent

# Manual run (for testing)
cd /opt/shelteragent
sudo python3 agent.py

# Update agent
# Copy new files and restart
sudo systemctl restart shelteragent
```

---

## Next Steps

1. ✅ Verify agent appears in dashboard
2. ✅ Check metrics are being collected
3. ✅ Monitor service status
4. ✅ Set up monitoring/alerting for agent health

---

For support or issues, check:
- Agent logs: `/opt/shelteragent/agent.log`
- Service logs: `journalctl -u shelteragent`
- Dashboard API: `http://your-server:8000/api/agents`
