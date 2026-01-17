# ShelterAgent - Python Monitoring Agent

Python-based system monitor that collects and reports metrics to the ShelterAgent dashboard.

## 🎯 Features

- **Auto-Registration**: Automatically registers with the server on first run
- **System Metrics**: CPU, Memory, Disk, Network, I/O monitoring
- **Process Monitoring**: Tracks top 50 processes by resource usage
- **Buffered Sending**: Collects every 5s, sends batch every 30s
- **Heartbeat**: Keeps server updated with agent status
- **Error Handling**: Robust error handling with retry logic
- **Logging**: Comprehensive logging to file and console

## 🔧 Requirements

- **Python**: 3.7 or higher
- **Permissions**: Run as root/administrator for full system access
- **Network**: HTTP access to Laravel dashboard server

## 📦 Installation

```bash
# Install dependencies
pip install -r requirements.txt

# or manually:
pip install psutil requests python-dotenv schedule
```

## ⚙️ Configuration

Create `.env` file from template:

```bash
cp .env.example .env
```

Edit `.env`:

```env
# Laravel server URL
SERVER_URL=http://localhost:8000/api

# API token (auto-filled after first registration)
API_TOKEN=

# Agent identification (optional, defaults to hostname)
AGENT_HOSTNAME=

# Collection intervals (in seconds)
COLLECTION_INTERVAL=5    # How often to collect metrics
SEND_INTERVAL=30        # How often to send batch to server
SERVICE_INTERVAL=60     # How often to update service list
```

## 🚀 Usage

### First Run (Registration)

```bash
# Run agent (will auto-register)
python agent.py
```

On first run:
1. Agent collects system information
2. Registers with server via POST `/api/agent/register`
3. Receives and saves API token
4. Begins normal operation

### Normal Operation

```bash
# Run agent
python agent.py

# Run in background (Linux/Mac)
nohup python agent.py > /dev/null 2>&1 &

# Run as service (recommended for production)
# See systemd example below
```

### Stop Agent

Press `Ctrl+C` to gracefully stop the agent. It will send remaining buffered metrics before exiting.

## 📊 Metrics Collected

### CPU
- Overall CPU usage percentage
- Per-core CPU usage
- Load average (Linux/Mac)

### Memory
- Total, used, free, available memory
- Memory usage percentage
- Swap usage

### Disk
- Total, used, free disk space
- Disk usage percentage
- I/O read/write rate (MB/s)

### Network
- Bytes sent/received (cumulative)
- Packets sent/received
- Bandwidth usage (Mbps)

### Services/Processes
- Top 50 processes by CPU usage
- Process name, PID, status
- CPU and memory usage per process
- Disk I/O per process
- User running the process
- Command line

## 🔄 Operation Flow

```
┌─────────────────┐
│  Start Agent    │
└────────┬────────┘
         │
         ├─► No API Token? ──► Register ──► Save Token
         │
         ▼
  ┌──────────────────┐
  │ Collection Loop   │
  └──────────────────┘
         │
         ├─► Every 5s:  Collect metrics ──► Buffer
         ├─► Every 30s: Send buffered metrics
         ├─► Every 60s: Collect & send services
         └─► Every 10s: Send heartbeat
```

## 🛠️ Running as Service (Linux)

Create `/etc/systemd/system/shelteragent.service`:

```ini
[Unit]
Description=ShelterAgent Monitoring Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/python-agent
ExecStart=/usr/bin/python3 /path/to/python-agent/agent.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable shelteragent
sudo systemctl start shelteragent

# Check status
sudo systemctl status shelteragent

# View logs
sudo journalctl -u shelteragent -f
```

## 📁 Project Structure

```
python-agent/
├── agent.py              # Main agent script
├── collectors/           # Metric collectors
│   ├── __init__.py
│   ├── cpu.py           # CPU metrics
│   ├── memory.py        # Memory metrics
│   ├── disk.py          # Disk metrics
│   ├── network.py       # Network metrics
│   └── services.py      # Process monitoring
├── requirements.txt      # Python dependencies
├── .env.example         # Configuration template
├── .env                 # Configuration (created by you)
└── agent.log            # Log file (created automatically)
```

## 🐛 Troubleshooting

### Agent won't register
- Check `SERVER_URL` is correct
- Ensure Laravel server is running
- Check network connectivity: `curl http://your-server/api/health`

### Permission errors
- Run as root/administrator
- On Linux: `sudo python agent.py`
- On Windows: Run terminal as Administrator

### High CPU usage
- Increase `COLLECTION_INTERVAL` (default: 5s)
- Reduce service monitoring frequency (increase `SERVICE_INTERVAL`)

### Missing metrics
- Some metrics require root privileges
- Check `agent.log` for errors
- Verify psutil is properly installed

## 📝 Logs

Logs are written to:
- `agent.log` in the agent directory
- Console output (stdout)

Log format:
```
2026-01-17 15:30:45 - __main__ - INFO - ✓ Sent 120 metrics successfully
2026-01-17 15:31:00 - __main__ - INFO - ✓ Sent 50 services
```

## 🔐 Security Notes

- API tokens are stored in `.env` file
- Ensure `.env` has appropriate permissions (600)
- Use HTTPS for SERVER_URL in production
- Keep the agent updated

## 🚀 Performance

- **Memory footprint**: ~30-50 MB
- **CPU usage**: < 1%
- **Network bandwidth**: ~1 KB per metrics batch (30s interval)
- **Disk I/O**: Minimal (only for logging)

## 📄 License

Part of the ShelterAgent monitoring system. Open source.
