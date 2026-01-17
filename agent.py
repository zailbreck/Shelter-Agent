#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
ShelterAgent - System Monitoring Agent
Compatible with Python 2.7+ and Python 3.x
Uses HWID-based authentication
"""

from __future__ import print_function
from __future__ import division
from __future__ import absolute_import

import os
import sys
import time
import logging
import socket
import platform
import hashlib
import uuid

# Python 2/3 compatibility
if sys.version_info[0] >= 3:
    import urllib.request as urllib2
    import urllib.parse as urlparse
else:
    import urllib2
    import urlparse

try:
    import yaml
except ImportError:
    print("ERROR: PyYAML is required. Install with: pip install pyyaml")
    sys.exit(1)

# Import collectors
from collectors.cpu import CPUCollector
from collectors.memory import MemoryCollector
from collectors.disk import DiskCollector
from collectors.network import NetworkCollector
from collectors.services import ServiceCollector

# Configure logging (will be updated from config)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('agent.log'),
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)


class ShelterAgent(object):
    def __init__(self, config_file='config.yml'):
        """Initialize agent with YAML configuration."""
        self.config = self.load_config(config_file)
        self.config_file = config_file
        
        # Server settings
        self.server_url = self.config['server']['url']
        if not self.server_url.startswith('https://'):
            logger.error("Server URL must use HTTPS!")
            logger.error("Please update config.yml with https:// URL")
            sys.exit(1)
        
        self.verify_ssl = self.config['server'].get('verify_ssl', True)
        
        # Agent identity (HWID-hostname)
        self.hwid = self.config['agent'].get('hwid') or self.generate_hwid()
        self.hostname = self.config['agent'].get('hostname') or socket.gethostname()
        self.agent_id = "%s-%s" % (self.hwid, self.hostname)
        
        # API Token (self-generated)
        self.api_token = self.config['agent'].get('api_token', '')
        
        # Intervals
        intervals = self.config.get('intervals', {})
        self.collection_interval = intervals.get('collection', 5)
        self.send_interval = intervals.get('send', 30)
        self.service_interval = intervals.get('services', 60)
        self.heartbeat_interval = intervals.get('heartbeat', 10)
        
        # Initialize collectors
        self.cpu_collector = CPUCollector()
        self.memory_collector = MemoryCollector()
        self.disk_collector = DiskCollector()
        self.network_collector = NetworkCollector()
        self.service_collector = ServiceCollector()
        
        # Metrics buffer
        self.metrics_buffer = []
        self.last_send_time = time.time()
        self.last_service_update = time.time()
        self.last_heartbeat = time.time()
        
        logger.info("Initialized ShelterAgent")
        logger.info("Agent ID: %s" % self.agent_id)
        logger.info("Server URL: %s" % self.server_url)

    def load_config(self, config_file):
        """Load configuration from YAML file."""
        if not os.path.exists(config_file):
            logger.error("Config file not found: %s" % config_file)
            logger.error("Please create config.yml from template")
            sys.exit(1)
        
        try:
            with open(config_file, 'r') as f:
                config = yaml.safe_load(f)
            return config
        except Exception as e:
            logger.error("Failed to load config: %s" % str(e))
            sys.exit(1)

    def save_config(self):
        """Save configuration to YAML file."""
        try:
            with open(self.config_file, 'w') as f:
                yaml.dump(self.config, f, default_flow_style=False)
            logger.info("Configuration saved")
        except Exception as e:
            logger.error("Failed to save config: %s" % str(e))

    def generate_hwid(self):
        """Generate hardware ID based on system characteristics."""
        try:
            # Get MAC address
            mac = ':'.join(['{:02x}'.format((uuid.getnode() >> i) & 0xff) 
                           for i in range(0, 8*6, 8)][::-1])
            
            # Get machine ID (Linux)
            machine_id = ""
            if os.path.exists('/etc/machine-id'):
                with open('/etc/machine-id', 'r') as f:
                    machine_id = f.read().strip()
            elif os.path.exists('/var/lib/dbus/machine-id'):
                with open('/var/lib/dbus/machine-id', 'r') as f:
                    machine_id = f.read().strip()
            
            # Combine and hash
            unique_str = "%s-%s-%s" % (mac, machine_id, platform.machine())
            hwid = hashlib.sha256(unique_str.encode('utf-8')).hexdigest()[:16]
            
            return hwid
        except Exception as e:
            logger.warning("Failed to generate HWID: %s" % str(e))
            # Fallback to MAC-based ID
            mac = uuid.getnode()
            return hashlib.sha256(str(mac).encode('utf-8')).hexdigest()[:16]

    def generate_api_token(self):
        """Generate unique API token for this agent."""
        # Combine HWID, hostname, and random component
        random_component = os.urandom(32).hex() if sys.version_info[0] >= 3 else os.urandom(32).encode('hex')
        token_source = "%s-%s-%s" % (self.hwid, self.hostname, random_component)
        api_token = hashlib.sha256(token_source.encode('utf-8')).hexdigest()
        return api_token

    def register(self):
        """Register this agent with the server."""
        if self.api_token:
            logger.info("Agent already has API token, validating...")
            # Try to send heartbeat to validate token
            if self.send_heartbeat():
                logger.info("API token is valid")
                return True
            else:
                logger.warning("API token invalid, re-registering...")
        
        logger.info("Registering agent with server...")
        
        try:
            import psutil
            
            # Generate new API token
            new_api_token = self.generate_api_token()
            
            # Get total disk size
            total_disk = 0
            for part in psutil.disk_partitions(all=False):
                try:
                    usage = psutil.disk_usage(part.mountpoint)
                    total_disk += usage.total
                except (PermissionError, OSError):
                    pass
            
            data = {
                'agent_id': self.agent_id,
                'hwid': self.hwid,
                'hostname': self.hostname,
                'ip_address': self.get_ip_address(),
                'os_type': platform.system(),
                'os_version': platform.platform(),
                'cpu_cores': psutil.cpu_count(logical=True),
                'total_memory': psutil.virtual_memory().total,
                'total_disk': total_disk,
                'api_token': new_api_token,
            }
            
            response = self.http_post(
                self.server_url + '/agent/register',
                data
            )
            
            if response and response.get('success'):
                self.api_token = new_api_token
                
                # Update config
                self.config['agent']['hwid'] = self.hwid
                self.config['agent']['hostname'] = self.hostname
                self.config['agent']['api_token'] = self.api_token
                self.save_config()
                
                logger.info("Successfully registered! Agent ID: %s" % self.agent_id)
                logger.info("API Token: %s..." % self.api_token[:10])
                return True
            else:
                logger.error("Registration failed: %s" % (response.get('message', 'Unknown error') if response else 'No response'))
                return False
                
        except Exception as e:
            logger.error("Registration error: %s" % str(e))
            import traceback
            traceback.print_exc()
            return False

    def get_ip_address(self):
        """Get local IP address."""
        try:
            s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            s.connect(("8.8.8.8", 80))
            ip = s.getsockname()[0]
            s.close()
            return ip
        except:
            return '127.0.0.1'

    def http_post(self, url, data, headers=None):
        """HTTP POST request with HTTPS support and SSL verification."""
        import json
        import ssl
        
        if headers is None:
            headers = {}
        
        headers['Content-Type'] = 'application/json'
        
        json_data = json.dumps(data)
        
        if sys.version_info[0] >= 3:
            json_data = json_data.encode('utf-8')
        
        try:
            req = urllib2.Request(url, json_data, headers)
            
            # SSL context
            if sys.version_info[0] >= 3:
                if self.verify_ssl:
                    context = ssl.create_default_context()
                else:
                    context = ssl._create_unverified_context()
                response = urllib2.urlopen(req, timeout=10, context=context)
            else:
                # Python 2
                if self.verify_ssl:
                    response = urllib2.urlopen(req, timeout=10)
                else:
                    context = ssl._create_unverified_context()
                    response = urllib2.urlopen(req, timeout=10, context=context)
            
            response_data = response.read()
            
            if sys.version_info[0] >= 3:
                response_data = response_data.decode('utf-8')
            
            return json.loads(response_data)
        except Exception as e:
            logger.error("HTTP POST error to %s: %s" % (url, str(e)))
            return None

    def send_heartbeat(self):
        """Send heartbeat to server."""
        try:
            headers = {'Authorization': 'Bearer %s' % self.api_token}
            data = {'agent_id': self.agent_id}
            
            response = self.http_post(
                self.server_url + '/agent/heartbeat',
                data,
                headers
            )
            
            if response and response.get('success'):
                logger.debug("Heartbeat sent successfully")
                return True
            else:
                logger.warning("Heartbeat failed: %s" % (response.get('message', '') if response else 'No response'))
                return False
                
        except Exception as e:
            logger.error("Heartbeat error: %s" % str(e))
            return False

    def collect_metrics(self):
        """Collect all system metrics."""
        metrics = []
        
        try:
            # CPU metrics
            cpu_data = self.cpu_collector.collect()
            metrics.append({
                'metric_type': 'cpu',
                'value': cpu_data['usage'],
                'unit': '%'
            })
            
            # Memory metrics
            memory_data = self.memory_collector.collect()
            metrics.append({
                'metric_type': 'memory',
                'value': memory_data['percent'],
                'unit': '%'
            })
            
            # Disk metrics
            disk_data = self.disk_collector.collect()
            metrics.append({
                'metric_type': 'disk',
                'value': disk_data['percent'],
                'unit': '%'
            })
            
            # Network metrics
            network_data = self.network_collector.collect()
            metrics.append({
                'metric_type': 'network',
                'value': network_data['total_mbps'],
                'unit': 'Mbps'
            })
            
            # I/O metrics
            metrics.append({
                'metric_type': 'io',
                'value': disk_data['io_mb_per_sec'],
                'unit': 'MB/s'
            })
            
            return metrics
            
        except Exception as e:
            logger.error("Error collecting metrics: %s" % str(e))
            return []

    def send_metrics(self):
        """Send buffered metrics to server."""
        if not self.metrics_buffer:
            return True
        
        try:
            headers = {'Authorization': 'Bearer %s' % self.api_token}
            data = {
                'agent_id': self.agent_id,
                'metrics': self.metrics_buffer
            }
            
            response = self.http_post(
                self.server_url + '/metrics',
                data,
                headers
            )
            
            if response and response.get('success'):
                count = len(self.metrics_buffer)
                self.metrics_buffer = []
                logger.info("Sent %d metrics successfully" % count)
                return True
            else:
                logger.warning("Failed to send metrics")
                return False
                
        except Exception as e:
            logger.error("Error sending metrics: %s" % str(e))
            return False

    def send_services(self):
        """Collect and send services data."""
        try:
            services = self.service_collector.collect()
            
            if not services:
                logger.info("No services to send")
                return True
            
            headers = {'Authorization': 'Bearer %s' % self.api_token}
            data = {
                'agent_id': self.agent_id,
                'services': services
            }
            
            response = self.http_post(
                self.server_url + '/services',
                data,
                headers
            )
            
            if response and response.get('success'):
                logger.info("Sent %d services" % len(services))
                return True
            else:
                error_msg = response.get('message', 'Unknown error') if response else 'No response from server'
                logger.warning("Failed to send services: %s" % error_msg)
                if response and 'errors' in response:
                    logger.error("Validation errors: %s" % str(response['errors']))
                return False
                
        except Exception as e:
            logger.error("Error sending services: %s" % str(e))
            import traceback
            traceback.print_exc()
            return False

    def run(self):
        """Main agent loop."""
        logger.info("Starting ShelterAgent...")
        logger.info("Agent ID: %s" % self.agent_id)
        
        # Register if needed
        if not self.api_token:
            if not self.register():
                logger.error("Failed to register. Exiting...")
                sys.exit(1)
        else:
            # Validate existing token
            if not self.register():
                logger.error("Failed to validate token. Exiting...")
                sys.exit(1)
        
        logger.info("Agent running. Press Ctrl+C to stop.")
        
        try:
            while True:
                current_time = time.time()
                
                # Collect metrics
                metrics = self.collect_metrics()
                self.metrics_buffer.extend(metrics)
                
                # Send metrics if interval elapsed
                if current_time - self.last_send_time >= self.send_interval:
                    self.send_metrics()
                    self.last_send_time = current_time
                
                # Send services if interval elapsed
                if current_time - self.last_service_update >= self.service_interval:
                    self.send_services()
                    self.last_service_update = current_time
                
                # Send heartbeat
                if current_time - self.last_heartbeat >= self.heartbeat_interval:
                    self.send_heartbeat()
                    self.last_heartbeat = current_time
                
                # Sleep until next collection
                time.sleep(self.collection_interval)
                
        except KeyboardInterrupt:
            logger.info("\nShutting down ShelterAgent...")
            # Send remaining metrics
            if self.metrics_buffer:
                self.send_metrics()
            logger.info("Agent stopped")


if __name__ == '__main__':
    agent = ShelterAgent()
    agent.run()
