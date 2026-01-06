#!/bin/bash
set -e

echo "Starting tinyproxy..."

# Start tinyproxy in the background
tinyproxy -c /home/tinyproxy/tinyproxy.conf -d &
TINYPROXY_PID=$!

echo "Tinyproxy started with PID $TINYPROXY_PID"
echo "Monitoring allowlist for changes..."

# Monitor allowlist for changes and reload tinyproxy
while true; do
    inotifywait -e modify,create,delete /home/tinyproxy/allowlist.txt 2>/dev/null
    echo "$(date -Iseconds) Allowlist changed, reloading tinyproxy..."
    kill -USR1 $TINYPROXY_PID || {
        echo "Tinyproxy process died, exiting"
        exit 1
    }
    echo "$(date -Iseconds) Tinyproxy reloaded"
done &
INOTIFY_PID=$!

# Handle shutdown signals
# If we don't do this the container will not exit until the container engine
# gets desperate and send SIGKILL
shutdown() {
    echo "Received shutdown signal, stopping tinyproxy..."
    kill $TINYPROXY_PID 2>/dev/null || true
    kill $INOTIFY_PID 2>/dev/null || true
    exit 0
}

trap shutdown SIGTERM SIGINT

# Wait for tinyproxy to exit
wait $TINYPROXY_PID
