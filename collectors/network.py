# -*- coding: utf-8 -*-
"""Network metrics collector - Python 2/3 compatible"""
from __future__ import division
import psutil
import time


class NetworkCollector(object):
    def __init__(self):
        self.last_stats = None
        self.last_time = None
    
    def collect(self):
        """Collect network metrics."""
        current_stats = psutil.net_io_counters()
        current_time = time.time()
        
        mbps = 0
        
        if self.last_stats and self.last_time:
            time_delta = current_time - self.last_time
            
            # Calculate bytes transferred in delta
            sent_delta = (current_stats.bytes_sent - self.last_stats.bytes_sent)
            recv_delta = (current_stats.bytes_recv - self.last_stats.bytes_recv)
            
            # Convert to Mbps
            total_bits = (sent_delta + recv_delta) * 8
            mbps = round(total_bits / time_delta / 1024.0 / 1024.0, 2)
        
        self.last_stats = current_stats
        self.last_time = current_time
        
        return {
            'bytes_sent': current_stats.bytes_sent,
            'bytes_recv': current_stats.bytes_recv,
            'packets_sent': current_stats.packets_sent,
            'packets_recv': current_stats.packets_recv,
            'total_mbps': mbps
        }
