# -*- coding: utf-8 -*-
"""Memory metrics collector - Python 2/3 compatible"""
from __future__ import division
import psutil


class MemoryCollector(object):
    def collect(self):
        """Collect memory metrics."""
        mem = psutil.virtual_memory()
        swap = psutil.swap_memory()
        
        return {
            'total': mem.total,
            'available': mem.available,
            'used': mem.used,
            'free': mem.free,
            'percent': round(mem.percent, 2),
            'swap_total': swap.total,
            'swap_used': swap.used,
            'swap_percent': round(swap.percent, 2)
        }
