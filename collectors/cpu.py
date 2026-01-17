# -*- coding: utf-8 -*-
"""CPU metrics collector - Python 2/3 compatible"""
from __future__ import division
import psutil


class CPUCollector(object):
    def __init__(self):
        # Initialize baseline
        psutil.cpu_percent(interval=None)
    
    def collect(self):
        """Collect CPU metrics."""
        try:
            load_avg = psutil.getloadavg() if hasattr(psutil, 'getloadavg') else (0, 0, 0)
        except (AttributeError, OSError):
            load_avg = (0, 0, 0)
        
        return {
            'usage': round(psutil.cpu_percent(interval=1), 2),
            'per_cpu': [round(x, 2) for x in psutil.cpu_percent(percpu=True)],
            'load_avg': list(load_avg)
        }
