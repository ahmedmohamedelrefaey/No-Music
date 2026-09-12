#!/bin/sh
set -e
mkdir -p /data/outputs
chown -R appuser:appuser /data
exec gosu appuser uvicorn app.main:app --host 0.0.0.0 --port 8000
