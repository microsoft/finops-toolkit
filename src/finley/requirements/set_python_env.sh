#!/usr/bin/env bash

# Ensure a Python environment name is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <python_env_name>"
    exit 1
fi

PYTHON_ENV=$1

# Update and install required packages
apt-get update && \
    apt-get install -y unixodbc && \
    apt-get autoremove -y && \
    apt-get clean

# Create a Python virtual environment
python3 -m venv /opt/$PYTHON_ENV && \
    export PATH=/opt/$PYTHON_ENV/bin:$PATH && \
    echo "source /opt/$PYTHON_ENV/bin/activate" >> ~/.bashrc

# Activate the virtual environment and install dependencies
source /opt/$PYTHON_ENV/bin/activate
pip3 install -r /requirements/requirements.txt