# -*- coding: utf-8 -*-
"""Disk metrics collector - Python 2/3 compatible"""
from __future__ import division
import psutil
import time


class DiskCollector(object):
    def __init__(self):
        self.last_io = None
        self.last_time = None
    
    def collect(self):
        """Collect disk metrics."""
        # Get disk usage
        partitions = psutil.disk_partitions(all=False)
        total_used = 0
        total_size = 0
        
        for partition in partitions:
            try:
                usage = psutil.disk_usage(partition.mountpoint)
                total_used += usage.used
                total_size += usage.total
            except (PermissionError, OSError):
                continue
        
        percent = round((total_used / total_size * 100) if total_size > 0 else 0, 2)
        
        # Get I/O stats
        io_mb_per_sec = 0
        try:
            current_io = psutil.disk_io_counters()
            current_time = time.time()
            
            if self.last_io and self.last_time:
                time_delta = current_time - self.last_time
                read_delta = (current_io.read_bytes - self.last_io.read_bytes) / 1024.0 / 1024.0
                write_delta = (current_io.write_bytes - self.last_io.write_bytes) / 1024.0 / 1024.0
                io_mb_per_sec = round((read_delta + write_delta) / time_delta, 2)
            
            self.last_io = current_io
            self.last_time = current_time
        except:
            pass
        
        return {
            'total': total_size,
            'used': total_used,
            'free': total_size - total_used,
            'percent': percent,
            'io_mb_per_sec': io_mb_per_sec
        }
