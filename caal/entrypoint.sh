#!/bin/bash
# CAAL Agent Entrypoint
# Creates config files from defaults if they don't exist, then runs as agent user

set -e

CONFIG_DIR="/app/config"

# Ensure config directory exists and is writable by agent
mkdir -p "$CONFIG_DIR"
chown agent:agent "$CONFIG_DIR"

# settings.json - copy default if missing
if [ ! -f "$CONFIG_DIR/settings.json" ]; then
    echo "Creating settings.json from defaults..."
    cp /app/settings.default.json "$CONFIG_DIR/settings.json"
    chown agent:agent "$CONFIG_DIR/settings.json"
fi

# mcp_servers.json - copy default if missing
if [ ! -f "$CONFIG_DIR/mcp_servers.json" ]; then
    echo "Creating mcp_servers.json from defaults..."
    cp /app/mcp_servers.default.json "$CONFIG_DIR/mcp_servers.json"
    chown agent:agent "$CONFIG_DIR/mcp_servers.json"
fi

# Create symlinks from /app to config files (for code that expects them in /app)
ln -sf "$CONFIG_DIR/settings.json" /app/settings.json
ln -sf "$CONFIG_DIR/mcp_servers.json" /app/mcp_servers.json

# Drop privileges and execute the main command as agent user
exec gosu agent "$@"
