# ShelterAgent - Quick Installation Guide

## For Server Administrators (Installing Agent)

### One-Command Installation

```bash
curl -sSL https://your-domain.com/install.sh | sudo bash -s -- https://your-server.com/api
```

**Replace:**
- `https://your-domain.com/install.sh` - URL where installer is hosted
- `https://your-server.com/api` - Your ShelterAgent dashboard API URL

### What Happens?

The installer will automatically:
1. ✅ Check for root privileges
2. ✅ Detect OS (CentOS, Ubuntu, Debian, etc.)
3. ✅ Install Python (if not present)
4. ✅ Install dependencies (psutil, PyYAML)
5. ✅ Download agent files
6. ✅ Create configuration with your server URL
7. ✅ Setup systemd service
8. ✅ Start monitoring immediately

**Total time:** ~30-60 seconds

### Examples

**Basic installation:**
```bash
curl -sSL https://monitor.company.com/install.sh | sudo bash -s -- https://monitor.company.com/api
```

**With self-signed certificate:**
```bash
export VERIFY_SSL=false
curl -sSL https://monitor.company.com/install.sh | sudo bash -s -- https://monitor.company.com/api
```

**Pre-configured:**
```bash
export SERVER_URL=https://monitor.company.com/api
curl -sSL https://monitor.company.com/install.sh | sudo bash
```

### Verify Installation

```bash
# Check service
systemctl status shelteragent

# View logs
journalctl -u shelteragent -f

# Check agent appeared in dashboard
# Visit: https://your-server.com
```

---

## For Dashboard Administrators (Hosting Installer)

### Option 1: Host on Laravel Server (Easiest)

```bash
# Copy installer to public directory
cp python-agent/quick-install.sh agent-dashboard/public/install.sh

# Installer is now available at:
# https://your-server.com/install.sh
```

Share with users:
```bash
curl -sSL https://your-server.com/install.sh | sudo bash -s -- https://your-server.com/api
```

### Option 2: Host on GitHub

1. Create repository
2. Upload `quick-install.sh` as `install.sh`
3. Get raw URL

Share with users:
```bash
curl -sSL https://raw.githubusercontent.com/username/repo/main/install.sh | sudo bash -s -- https://your-server.com/api
```

### Option 3: Nginx/Apache Static Hosting

```bash
# Copy to web root
cp quick-install.sh /var/www/html/install.sh

# Make sure it's served with correct MIME type
# Nginx: add to config
location /install.sh {
    default_type text/plain;
}
```

---

## Multi-Server Deployment

### Install on multiple servers at once:

```bash
# List of servers
SERVERS="server1.com server2.com server3.com"
SERVER_URL="https://monitor.company.com/api"

for server in $SERVERS; do
    echo "Installing on $server..."
    ssh root@$server "curl -sSL https://monitor.company.com/install.sh | bash -s -- $SERVER_URL"
done
```

### Using Ansible:

```yaml
---
- hosts: all
  become: yes
  vars:
    dashboard_url: "https://monitor.company.com/api"
  tasks:
    - name: Install ShelterAgent
      shell: curl -sSL https://monitor.company.com/install.sh | bash -s -- {{ dashboard_url }}
```

---

## Commands After Installation

```bash
# Check status
systemctl status shelteragent

# View real-time logs
journalctl -u shelteragent -f

# Restart agent
systemctl restart shelteragent

# Stop agent
systemctl stop shelteragent

# View configuration
cat /opt/shelteragent/config.yml

# Check agent ID
grep agent_id /opt/shelteragent/config.yml
```

---

## Uninstallation

```bash
# Stop and remove service
sudo systemctl stop shelteragent
sudo systemctl disable shelteragent
sudo rm /etc/systemd/system/shelteragent.service
sudo systemctl daemon-reload

# Remove agent files
sudo rm -rf /opt/shelteragent

# (Optional) Remove from dashboard
# Delete agent via dashboard UI
```

---

## Troubleshooting

### Error: "Must be run as root"
**Solution:** Add `sudo`
```bash
curl -sSL https://url/install.sh | sudo bash -s -- https://server/api
```

### Error: "SERVER_URL must use HTTPS"
**Solution:** Use https:// not http://
```bash
# Correct
https://monitor.company.com/api

# Wrong
http://monitor.company.com/api
```

### Service won't start
**Check logs:**
```bash
journalctl -u shelteragent -xe
```

**Common fixes:**
```bash
# Fix permissions
sudo chmod 600 /opt/shelteragent/config.yml

# Reinstall Python packages
sudo pip3 install psutil PyYAML

# Restart service
sudo systemctl restart shelteragent
```

### Agent not appearing in dashboard
**Check:**
1. Server URL is correct: `cat /opt/shelteragent/config.yml`
2. Dashboard is accessible: `curl https://your-server.com/api/health`
3. Agent is running: `systemctl status shelteragent`
4. Check agent logs: `journalctl -u shelteragent -f`

---

## FAQs

**Q: Is it safe to curl | bash?**
A: Review the installer first:
```bash
curl -sSL https://url/install.sh > install.sh
less install.sh  # Review
sudo bash install.sh https://server/api
```

**Q: Can I use HTTP instead of HTTPS?**
A: No, HTTPS is enforced for security.

**Q: How do I update the agent?**
A: Re-run the installer. It will update existing installation.

**Q: Does it preserve config on update?**
A: Yes, API token and agent_id are preserved.

**Q: What if I have Python 2?**
A: Installer supports both Python 2.7+ and Python 3.x

**Q: How much resources does it use?**
A: ~30-50MB RAM, <1% CPU

---

## Security Notes

- ✅ Installer validates root privileges
- ✅ HTTPS-only communication
- ✅ Self-generated API tokens
- ✅ HWID-based authentication
- ✅ Config file has 600 permissions
- ✅ Systemd service isolation

---

## Quick Reference

**Installation:**
```bash
curl -sSL INSTALLER_URL | sudo bash -s -- SERVER_API_URL
```

**Status:**
```bash
systemctl status shelteragent
```

**Logs:**
```bash
journalctl -u shelteragent -f
```

**Config:**
```bash
cat /opt/shelteragent/config.yml
```

**Uninstall:**
```bash
sudo systemctl stop shelteragent && sudo systemctl disable shelteragent && sudo rm -rf /opt/shelteragent /etc/systemd/system/shelteragent.service
```

---

For detailed documentation, see:
- [DEPLOYMENT.md](../DEPLOYMENT.md) - Full deployment guide
- [INSTALL.md](INSTALL.md) - Manual installation
- [COMPATIBILITY.md](COMPATIBILITY.md) - Python 2/3 compatibility

For support: Check `/var/log/shelteragent-install.log`
