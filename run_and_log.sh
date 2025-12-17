#!/bin/bash

LOG_FILE="/tmp/calendarbar.log"

echo "Starting CalendarBarApp..." > "$LOG_FILE"
.build/debug/CalendarBarApp >> "$LOG_FILE" 2>&1 &
APP_PID=$!

echo "App running with PID: $APP_PID"
echo "Waiting 10 seconds for logs..."
sleep 10

echo ""
echo "=== Log Output ==="
cat "$LOG_FILE"

kill $APP_PID 2>/dev/null
