# -*- coding: utf-8 -*-
"""Service/Process metrics collector - Python 2/3 compatible"""
from __future__ import print_function
from __future__ import division
import psutil


class ServiceCollector(object):
    def collect(self, limit=50):
        """Collect running services/processes."""
        services = []
        
        try:
            for proc in psutil.process_iter(['pid', 'name', 'username', 'cpu_percent', 'memory_percent', 'memory_info', 'cmdline', 'status']):
                try:
                    pinfo = proc.info
                    
                    # Skip system idle process
                    if pinfo['pid'] == 0:
                        continue
                    
                    # Get memory in MB
                    memory_mb = pinfo['memory_info'].rss / 1024.0 / 1024.0 if pinfo.get('memory_info') else 0
                    
                    # Get I/O if available
                    disk_read_mb = 0
                    disk_write_mb = 0
                    try:
                        io_counters = proc.io_counters()
                        disk_read_mb = round(io_counters.read_bytes / 1024.0 / 1024.0, 2)
                        disk_write_mb = round(io_counters.write_bytes / 1024.0 / 1024.0, 2)
                    except (psutil.AccessDenied, AttributeError):
                        pass
                    
                    # Get status safely
                    status = pinfo.get('status', psutil.STATUS_RUNNING)
                    status_str = 'running' if status == psutil.STATUS_RUNNING else 'stopped'
                    
                    services.append({
                        'name': pinfo['name'] or 'unknown',
                        'pid': pinfo['pid'],
                        'status': status_str,
                        'cpu_percent': round(pinfo['cpu_percent'] or 0, 2),
                        'memory_percent': round(pinfo['memory_percent'] or 0, 2),
                        'memory_mb': round(memory_mb, 2),
                        'disk_read_mb': disk_read_mb,
                        'disk_write_mb': disk_write_mb,
                        'user': pinfo['username'] or 'unknown',
                        'command': ' '.join(pinfo['cmdline']) if pinfo.get('cmdline') else ''
                    })
                    
                except (psutil.NoSuchProcess, psutil.AccessDenied, psutil.ZombieProcess):
                    pass
            
            # Sort by CPU usage and limit
            services.sort(key=lambda x: x['cpu_percent'], reverse=True)
            return services[:limit]
            
        except Exception as e:
            print("Error collecting services: %s" % str(e))
            return []
