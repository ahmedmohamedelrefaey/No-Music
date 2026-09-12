#!/bin/sh
set -e
mkdir -p /data/outputs /data/model-cache
chown -R appuser:appuser /data
export TORCH_HOME=/data/model-cache
exec gosu appuser uvicorn app.main:app --host 0.0.0.0 --port 8000
