# CAAL - Distributed Deployment Guide

This guide describes how to deploy CAAL in a distributed architecture, separating the frontend development environment from the GPU-powered backend infrastructure. This setup is ideal for developers who want to work on the frontend from a lightweight machine (like a MacBook) while running the compute-intensive voice processing pipeline on a dedicated GPU server.

## Architecture Overview

```
┌─────────────────────────────────────────┐
│       Development Machine (MacBook)     │
│                                         │
│  ┌────────────────────────────────────┐ │
│  │  Frontend (Next.js)                │ │
│  │  - Hot reload development          │ │
│  │  - http://localhost:3000           │ │
│  └────────────────┬───────────────────┘ │
└───────────────────┼─────────────────────┘
                    │
                    │ WebRTC + WebSocket (wss://)
                    │ via Tailscale network
                    ▼
┌─────────────────────────────────────────┐
│         GPU Server (Backend)            │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │  nginx (TLS termination) :443    │   │
│  └──────────────┬───────────────────┘   │
│                 │                       │
│  ┌──────────────┼───────────────────┐   │
│  │  LiveKit Server :7880            │   │
│  │  Voice Agent :8889               │   │
│  │  Speaches (STT/GPU) :8000        │   │
│  │  Kokoro (TTS/GPU) :8880          │   │
│  │  Ollama (LLM/GPU) :11434         │   │
│  └──────────────────────────────────┘   │
│                 │                       │
│                 ▼                       │
│  ┌──────────────────────────────────┐   │
│  │  External: n8n (workflows)       │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

---

## Part 1: GPU Server Setup

### Prerequisites

#### Hardware
- NVIDIA GPU with 12GB+ VRAM (recommended)
- Sufficient RAM (16GB+ recommended)
- SSD storage for model caching

#### Software
- Linux distribution (Ubuntu 22.04/24.04 or Debian 12+ recommended)
- Docker Engine 24.0+
- Docker Compose v2.20+
- NVIDIA Container Toolkit
- Tailscale client installed and authenticated
- Git
- Ollama installed and configured

#### Network Ports (local only)
- 7880 (LiveKit WebSocket)
- 7881 (LiveKit WebRTC)
- 8000 (Speaches STT)
- 8880 (Kokoro TTS)
- 8889 (Agent webhooks)
- 11434 (Ollama API)
- 443 (nginx HTTPS)
- 50000-50100 (WebRTC UDP media)

### Step 1: Install NVIDIA Container Toolkit

```bash
# Add NVIDIA repository
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install NVIDIA Driver and Docker toolkit
sudo apt-get update
sudo apt install linux-headers-$(uname -r) build-essential dkms nvidia-detect
sudo apt install -y nvidia-driver
sudo reboot
```

After rebooting, confirm the driver is loaded and functioning:

```bash
nvidia-smi
```

If you encounter the error `NVIDIA-SMI has failed because it couldn't communicate with the NVIDIA driver`, this typically means the kernel module isn't loaded or wasn't built for your current kernel version. This commonly occurs after kernel updates or when using newer kernels from backports. To solve:

```bash
sudo dkms status
```

Look for output like:
- `nvidia-current/550.163.01, 6.1.0-18-amd64, x86_64: installed` – Module is ready (good)
- `nvidia-current/550.163.01: added` – Module needs building

The status shows whether your module is "added" (source registered), "built" (compiled), or "installed" (ready to use).

```bash
ls /usr/src/ | grep nvidia
```

If the module status shows "added" but not "installed", rebuild it using your version:

```bash
sudo dkms build nvidia-current/550.163.01
sudo dkms install nvidia-current/550.163.01
```

Replace `550.163.01` with your actual version number from the previous step.

```bash
sudo modprobe nvidia
nvidia-smi
```

If successful, `nvidia-smi` should now display your GPU information. If modprobe fails, check dmesg for specific error messages using `sudo dmesg | grep -i nvidia`.

Now install the container toolkit:

```bash
sudo apt-get install -y nvidia-container-toolkit

# Configure Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Verify
docker run --rm --gpus all nvidia/cuda:12.6.3-base-ubuntu22.04 nvidia-smi
```

### Step 2: Install and Configure Ollama

```bash
# Install Ollama
curl -fsSL https://ollama.com/install.sh | sh

# Configure Ollama to listen on all interfaces (required for Docker access)
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf << 'EOF'
[Service]
Environment="OLLAMA_HOST=0.0.0.0"
Environment="OLLAMA_KEEP_ALIVE=24h"
EOF

# Apply configuration and start Ollama
sudo systemctl daemon-reload
sudo systemctl restart ollama

# Verify Ollama is listening on all interfaces
ss -tlnp | grep 11434
# Should show: *:11434 (not 127.0.0.1:11434)

# Pull the LLM model
ollama pull ministral-3:14b

# Verify installation
curl http://localhost:11434/api/tags
```

### Step 3: Install and Configure Tailscale

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale status
tailscale ip -4  # Note your Tailscale IP
```

### Step 4: Clone and Configure CAAL

```bash
git clone https://github.com/CoreWorxLab/caal.git
cd caal
cp .env.example .env
```

### Step 5: Download OpenWakeWord Models

The voice agent requires OpenWakeWord models for wake word detection. These must be downloaded before building the Docker image:

```bash
# Download models using a temporary Docker container
docker run --rm -v "$(pwd)/models:/output" python:3.11-slim-bookworm bash -c '
pip install --quiet openwakeword
python3 << "PYEOF"
import shutil
from pathlib import Path
from openwakeword import utils

# Download models
utils.download_models()

# Copy required files
import openwakeword
pkg_path = Path(openwakeword.__file__).parent
models_path = pkg_path / "resources" / "models"

for f in ["melspectrogram.onnx", "embedding_model.onnx"]:
    src = models_path / f
    if src.exists():
        shutil.copy(str(src), f"/output/{f}")
        print(f"Copied {f}: {src.stat().st_size} bytes")
PYEOF
'
```

Verify the models were downloaded:

```bash
ls -la models/
# Should show:
# embedding_model.onnx  (~1.3 MB)
# melspectrogram.onnx   (~1.1 MB)
```

### Step 6: Generate LiveKit API Credentials

> [!important] LiveKit Credentials
> LiveKit uses API Key/Secret pairs for authentication. These are internal credentials that you generate yourself - not related to Tailscale or any external service.

```bash
docker run --rm livekit/livekit-server generate-keys
```

Example output:
```
API Key: API3F4xKZpWbzDk
API Secret: H8kxJ2mWvPqR7nTcYfLgA0sXeKdMbN9uQwZyVpIoEjHtCrSaFl
```

These credentials are used by:
- LiveKit server (to validate connections)
- Voice agent (to connect to LiveKit)
- Frontend (to generate room tokens)

### Step 7: Configure .env

```bash
# ===========================================
# Network Configuration
# ===========================================
CAAL_HOST_IP=100.x.x.x                              # tailscale ip -4
HTTPS_DOMAIN=gpu-server.tailnet-name.ts.net

# ===========================================
# LiveKit Configuration
# ===========================================
LIVEKIT_API_KEY=APIxxxxxxxxxx
LIVEKIT_API_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
LIVEKIT_URL=ws://localhost:7880

# ===========================================
# STT/TTS Configuration
# ===========================================
SPEACHES_URL=http://localhost:8000
KOKORO_URL=http://localhost:8880
WHISPER_MODEL=Systran/faster-whisper-medium
TTS_VOICE=am_puck

# ===========================================
# LLM Configuration (Ollama on localhost)
# ===========================================
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=ministral-3:14b
OLLAMA_THINK=false

# ===========================================
# n8n Integration (optional)
# ===========================================
N8N_MCP_URL=http://192.168.x.x:5678/mcp-server/http
N8N_MCP_TOKEN=your_n8n_mcp_token
```

### Step 8: Generate Tailscale TLS Certificates

```bash
sudo tailscale cert gpu-server.tailnet-name.ts.net

mkdir -p certs
sudo mv gpu-server.tailnet-name.ts.net.crt certs/server.crt
sudo mv gpu-server.tailnet-name.ts.net.key certs/server.key
sudo chown $USER:$USER certs/server.*
chmod 644 certs/server.*
```

### Step 9: Configure LiveKit for Tailscale

> [!warning] YAML Format
> The `livekit-tailscale.yaml` file must be **pure YAML** without any markdown formatting. Do not include markdown code fences (` ```yaml `) in the actual file - only raw YAML content.

Create `livekit-tailscale.yaml`:

```yaml
port: 7880
rtc:
  port_range_start: 50000
  port_range_end: 50100
  tcp_port: 7881
  use_external_ip: false
  node_ip: 100.x.x.x  # Your Tailscale IP

# Must match .env LIVEKIT_API_KEY and LIVEKIT_API_SECRET
keys:
  API3F4xKZpWbzDk: H8kxJ2mWvPqR7nTcYfLgA0sXeKdMbN9uQwZyVpIoEjHtCrSaFl

logging:
  level: info
```

### Step 10: Create Docker Compose Override

Create `docker-compose.distributed.yml`:

```yaml
services:
  frontend:
    profiles:
      - disabled

  livekit:
    volumes:
      - ./livekit-tailscale.yaml:/livekit.yaml:ro
    environment:
      - LIVEKIT_CONFIG=/livekit.yaml

  agent:
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      - OLLAMA_HOST=http://host.docker.internal:11434

  nginx:
    image: nginx:alpine
    profiles:
      - https
    ports:
      - "443:443"
    volumes:
      - ./certs:/etc/nginx/certs:ro
      - ./nginx-distributed.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - livekit
      - agent
    restart: unless-stopped
```

### Step 11: Create nginx Configuration

Create `nginx-distributed.conf`:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream livekit {
        server livekit:7880;
    }

    upstream agent_webhooks {
        server agent:8889;
    }

    server {
        listen 443 ssl;
        server_name _;

        ssl_certificate /etc/nginx/certs/server.crt;
        ssl_certificate_key /etc/nginx/certs/server.key;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        location / {
            proxy_pass http://livekit;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400;
            proxy_send_timeout 86400;
        }

        location /api/ {
            proxy_pass http://agent_webhooks/;
            proxy_http_version 1.1;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /health {
            proxy_pass http://agent_webhooks/health;
        }
    }
}
```

### Step 12: Start Backend Services

```bash
docker compose pull
docker compose -f docker-compose.yaml -f docker-compose.distributed.yml --profile https up -d
docker compose ps
docker compose logs -f agent
```

### Step 13: Verify Deployment

```bash
curl http://localhost:11434/api/tags  # Ollama
curl -v https://gpu-server.tailnet-name.ts.net/health  # nginx/agent
nvidia-smi  # GPU usage
```

---

## Part 2: macOS Frontend Setup

This section describes how to run the CAAL frontend on a macOS machine (e.g., MacBook) while connecting to the GPU backend server via Tailscale.

### Prerequisites

- macOS (Apple Silicon or Intel)
- Homebrew package manager
- Node.js 18+ and pnpm
- Tailscale installed and connected to the same tailnet as the GPU server

### Step 1: Install Dependencies

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Node.js and pnpm
brew install node pnpm

# Install Tailscale (if not already installed)
brew install tailscale
```

### Step 2: Connect to Tailscale

```bash
# Start Tailscale and authenticate
sudo tailscale up

# Verify connection
tailscale status
```

### Step 3: Verify Connectivity to GPU Server

Before configuring the frontend, verify you can reach the GPU server:

```bash
# Test network connectivity
ping gpu-server.tailnet-name.ts.net

# Test backend health endpoint
curl https://gpu-server.tailnet-name.ts.net/health
# Expected: {"status": "healthy", ...}

# Test LiveKit server (port 7443 via nginx)
curl https://gpu-server.tailnet-name.ts.net:7443/
# Expected: OK

# Test models API
curl https://gpu-server.tailnet-name.ts.net/api/models
# Expected: {"models": ["ministral-3:14b", ...]}
```

> [!important] Port Configuration
> The GPU server exposes LiveKit on port **7443** through nginx (not the default 7880). This provides TLS termination for secure WebSocket connections (wss://).

### Step 4: Clone Repository

```bash
git clone https://github.com/CoreWorxLab/caal.git
cd caal/frontend
```

### Step 5: Configure Environment Variables

Create `.env.local` in the `frontend` directory:

```bash
# LiveKit WebSocket URL (for token generation - server side)
LIVEKIT_URL=wss://gpu-server.tailnet-name.ts.net:7443

# LiveKit WebSocket URL (for browser connection - client side)
# When using an explicit wss:// URL, the frontend will use it directly
# even when running in HTTP mode (localhost development)
NEXT_PUBLIC_LIVEKIT_URL=wss://gpu-server.tailnet-name.ts.net:7443

# Backend webhook URL (for settings, models, voices APIs)
# Points to the agent service via nginx reverse proxy
WEBHOOK_URL=https://gpu-server.tailnet-name.ts.net/api

# LiveKit API credentials - MUST match GPU server values
LIVEKIT_API_KEY=API3F4xKZpWbzDk
LIVEKIT_API_SECRET=H8kxJ2mWvPqR7nTcYfLgA0sXeKdMbN9uQwZyVpIoEjHtCrSaFl

# Optional: Picovoice wake word detection (client-side)
# Get your access key from https://console.picovoice.ai/
NEXT_PUBLIC_PORCUPINE_ACCESS_KEY=your_picovoice_key
```

> [!warning] Credential Security
> The `.env.local` file contains sensitive API credentials. Ensure it is:
> - Never committed to git (already in `.gitignore`)
> - Only readable by your user account
> - Using credentials that match the GPU server configuration

### Step 6: Install Dependencies and Start

```bash
# Install Node.js dependencies
pnpm install

# Start development server
pnpm dev
```

The frontend will be available at `http://localhost:3000`.

### Step 7: Verify Connection

1. Open `http://localhost:3000` in your browser
2. Grant microphone permissions when prompted
3. Click "Start Session" or the microphone button
4. Check the Settings panel - you should see models loaded from the GPU server
5. Speak to the assistant and verify audio is processed

### Troubleshooting macOS Frontend

| Symptom | Cause | Solution |
|---------|-------|----------|
| "Failed to fetch" on connection | Wrong LiveKit URL or port | Verify `NEXT_PUBLIC_LIVEKIT_URL` includes `:7443` |
| Settings show wrong/no models | Missing `WEBHOOK_URL` | Add `WEBHOOK_URL=https://...` to `.env.local` |
| "LIVEKIT_URL is not defined" | Missing environment variable | Add `LIVEKIT_URL` (not just `NEXT_PUBLIC_*`) |
| WebSocket connection refused | Tailscale not connected | Run `tailscale status` and verify connectivity |
| SSL certificate error | First connection to server | Open `https://gpu-server:7443` in browser first to accept cert |
| Agent says wrong model | Model mismatch | Open Settings, select correct model from dropdown, save |
| No microphone access | Browser permissions | Check browser settings, use `localhost` (not IP) |

### Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `LIVEKIT_URL` | Yes | LiveKit server URL for token generation (server-side) |
| `NEXT_PUBLIC_LIVEKIT_URL` | Yes | LiveKit URL for browser WebSocket connection |
| `LIVEKIT_API_KEY` | Yes | LiveKit API key (must match GPU server) |
| `LIVEKIT_API_SECRET` | Yes | LiveKit API secret (must match GPU server) |
| `WEBHOOK_URL` | Yes | Backend API URL for settings/models/voices |
| `NEXT_PUBLIC_PORCUPINE_ACCESS_KEY` | No | Picovoice key for client-side wake word |

---

## Part 3: Certificate Management

### Auto-renewal Script

```bash
cat > ~/renew-tailscale-cert.sh << 'EOF'
#!/bin/bash
set -e
CAAL_DIR="/path/to/caal"
cd "$CAAL_DIR"

HOSTNAME=$(tailscale status --json | jq -r '.Self.DNSName' | sed 's/\.$//')
echo "Renewing certificate for: $HOSTNAME"

sudo tailscale cert "$HOSTNAME"
sudo mv "${HOSTNAME}.crt" certs/server.crt
sudo mv "${HOSTNAME}.key" certs/server.key
sudo chown $USER:$USER certs/server.*
chmod 644 certs/server.*

docker compose -f docker-compose.yaml -f docker-compose.distributed.yml restart nginx
echo "Certificate renewed at $(date)"
EOF

chmod +x ~/renew-tailscale-cert.sh
```

### Cron Job (monthly)

```bash
crontab -e
# Add:
0 3 1 * * /home/user/renew-tailscale-cert.sh >> /var/log/tailscale-cert-renewal.log 2>&1
```

---

## Quick Reference

### GPU Server

```bash
# Start
docker compose -f docker-compose.yaml -f docker-compose.distributed.yml --profile https up -d

# Stop
docker compose -f docker-compose.yaml -f docker-compose.distributed.yml --profile https down

# Logs
docker compose logs -f agent

# Ollama status
systemctl status ollama
```

### MacBook

```bash
cd frontend && pnpm dev
```

### Tailscale

```bash
tailscale status
tailscale ip -4
tailscale ping gpu-server
sudo tailscale cert hostname.tailnet.ts.net
```

### LiveKit

```bash
docker run --rm livekit/livekit-server generate-keys
```

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Agent build fails | Verify `models/` contains `melspectrogram.onnx` and `embedding_model.onnx` |
| LiveKit unhealthy | Check `livekit-tailscale.yaml` has no markdown fences, valid YAML syntax |
| WebSocket fails | `tailscale ping`, cert validity, nginx logs |
| No microphone | Access via `localhost:3000`, browser permissions |
| High latency | `tailscale ping --verbose`, `nvidia-smi`, `docker stats` |
| Auth errors | Credentials match across all config files |
| Agent not processing | `docker compose logs -f agent`, STT/TTS health |
| Ollama not reachable from agent | Verify `ss -tlnp \| grep 11434` shows `*:11434`, not `127.0.0.1:11434` |
