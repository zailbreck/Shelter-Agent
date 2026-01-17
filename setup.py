#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Setup script for ShelterAgent
Compatible with Python 2.7+ and Python 3.x
"""

from __future__ import print_function
import sys
import os

try:
    from setuptools import setup, find_packages
except ImportError:
    print("Error: setuptools is required. Please install it first:")
    print("  pip install setuptools")
    sys.exit(1)

# Read README
def read_file(filename):
    filepath = os.path.join(os.path.dirname(__file__), filename)
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            return f.read()
    return ''

# Read requirements
def read_requirements():
    filepath = os.path.join(os.path.dirname(__file__), 'requirements.txt')
    if os.path.exists(filepath):
        with open(filepath, 'r') as f:
            return [line.strip() for line in f if line.strip() and not line.startswith('#')]
    return ['psutil>=5.0.0']

setup(
    name='shelteragent',
    version='1.0.0',
    description='ShelterAgent - Multi-Agent Server Monitoring Client',
    long_description=read_file('README.md'),
    long_description_content_type='text/markdown',
    author='ShelterAgent Team',
    author_email='admin@shelteragent.local',
    url='https://github.com/shelteragent/agent',
    license='MIT',
    
    packages=find_packages(),
    py_modules=['agent'],
    
    install_requires=read_requirements(),
    
    python_requires='>=2.7, !=3.0.*, !=3.1.*, !=3.2.*, !=3.3.*, !=3.4.*',
    
    classifiers=[
        'Development Status :: 5 - Production/Stable',
        'Intended Audience :: System Administrators',
        'License :: OSI Approved :: MIT License',
        'Operating System :: POSIX :: Linux',
        'Programming Language :: Python',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.5',
        'Programming Language :: Python :: 3.6',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: 3.9',
        'Programming Language :: Python :: 3.10',
        'Topic :: System :: Monitoring',
    ],
    
    entry_points={
        'console_scripts': [
            'shelteragent=agent:main' if hasattr(sys.modules.get('agent', object()), 'main') else None,
        ],
    },
    
    include_package_data=True,
    zip_safe=False,
)
