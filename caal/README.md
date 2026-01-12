# CAAL

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![LiveKit](https://img.shields.io/badge/LiveKit-Agents-purple.svg)](https://docs.livekit.io/agents/)

> **Local voice assistant that learns new abilities via auto-discovered n8n workflows exposed as tools via MCP**

Built on [LiveKit Agents](https://docs.livekit.io/agents/) with fully local STT/TTS/LLM using [Speaches](https://github.com/speaches-ai/speaches), [Kokoro](https://github.com/remsky/Kokoro-FastAPI), and [Ollama](https://ollama.ai/).

![CAAL Voice Assistant](frontend/.github/assets/readme-hero.webp)

## Features

- **Local Voice Pipeline** - Speaches (Faster-Whisper STT) + Kokoro (TTS) + Ollama LLM
- **Wake Word Detection** - "Hey Cal" activation via Picovoice Porcupine
- **n8n Integrations** - Home Assistant, APIs, databases - anything n8n can connect to
- **Web Search** - DuckDuckGo integration for real-time information
- **Webhook API** - External triggers for announcements and tool reload
- **Mobile App** - Flutter client for Android and iOS

## Quick Start

Choose your deployment mode:

| Mode | Hardware | Command | Documentation |
|------|----------|---------|---------------|
| **NVIDIA GPU** | Linux + NVIDIA GPU | `docker compose up -d` | [Below](#nvidia-gpu-linux) |
| **Apple Silicon** | M1/M2/M3/M4 Mac | `./start-apple.sh` | [docs/APPLE-SILICON.md](docs/APPLE-SILICON.md) |
| **Distributed** | GPU Server + macOS | See docs | [docs/DISTRIBUTED-DEPLOYMENT.md](docs/DISTRIBUTED-DEPLOYMENT.md) |

---

## NVIDIA GPU (Linux)

### Requirements

- Docker with [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [Ollama](https://ollama.ai/) running on your network
- [n8n](https://n8n.io/) with MCP enabled (Settings > MCP Access)
- 12GB+ VRAM recommended

### Installation

```bash
# Clone and configure
git clone https://github.com/CoreWorxLab/caal.git
cd caal
cp .env.example .env
nano .env  # Set CAAL_HOST_IP, OLLAMA_HOST, N8N_MCP_URL, N8N_MCP_TOKEN

# Deploy
docker compose up -d
```

Open `http://YOUR_SERVER_IP:3000` from any device on your network.

---

## Apple Silicon (macOS)

CAAL runs on Apple Silicon Macs using [mlx-audio](https://github.com/Blaizzy/mlx-audio) for Metal-accelerated STT/TTS.

```bash
./start-apple.sh
```

**See [docs/APPLE-SILICON.md](docs/APPLE-SILICON.md) for full setup instructions.**

---

## Distributed Deployment

Run the GPU-intensive backend on a Linux server while using the frontend on a Mac or another device.

**See [docs/DISTRIBUTED-DEPLOYMENT.md](docs/DISTRIBUTED-DEPLOYMENT.md) for full setup instructions.**

---

## Network Modes

CAAL supports three network configurations:

| Mode | Voice From | Access URL | Command |
|------|------------|------------|---------|
| **LAN HTTP** | Host machine only | `http://localhost:3000` | `docker compose up -d` |
| **LAN HTTPS** | Any LAN device | `https://192.168.1.100` | `docker compose --profile https up -d` |
| **Tailscale** | Anywhere | `https://your-machine.tailnet.ts.net` | `docker compose --profile https up -d` |

> **Why?** Browsers block microphone access on HTTP except from localhost. HTTPS is required for voice from other devices.

### LAN HTTP (Default)

```bash
CAAL_HOST_IP=192.168.1.100  # Set in .env
docker compose up -d
```

### LAN HTTPS (mkcert)

```bash
# Generate certificates
mkcert -install
mkcert 192.168.1.100
mkdir -p certs && mv 192.168.1.100.pem certs/server.crt && mv 192.168.1.100-key.pem certs/server.key
chmod 644 certs/server.key

# Configure .env
CAAL_HOST_IP=192.168.1.100
HTTPS_DOMAIN=192.168.1.100

# Build and start
docker compose --profile https build frontend
docker compose --profile https up -d
```

### Tailscale (Remote Access)

```bash
# Generate Tailscale certs
tailscale cert your-machine.tailnet.ts.net
mkdir -p certs && mv your-machine.tailnet.ts.net.crt certs/server.crt && mv your-machine.tailnet.ts.net.key certs/server.key

# Configure .env
CAAL_HOST_IP=100.x.x.x                         # tailscale ip -4
HTTPS_DOMAIN=your-machine.tailnet.ts.net

# Build and start
docker compose --profile https build frontend
docker compose --profile https up -d
```

---

## Configuration

### Essential Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `CAAL_HOST_IP` | Your server's LAN/Tailscale IP | Yes |
| `OLLAMA_HOST` | Ollama server URL | Yes |
| `N8N_MCP_URL` | n8n MCP endpoint | Yes |
| `N8N_MCP_TOKEN` | n8n access token | Yes |
| `OLLAMA_MODEL` | LLM model (default: `ministral-3:8b`) | No |
| `TTS_VOICE` | Kokoro voice (default: `am_puck`) | No |
| `PORCUPINE_ACCESS_KEY` | Picovoice key for wake word | No |

See `.env.example` for full configuration options.

---

## Integrations

### n8n Workflows

CAAL discovers tools from n8n workflows via MCP. Each workflow with a webhook trigger becomes a voice command.

```bash
cd n8n-workflows
cp config.env.example config.env
nano config.env  # Set your n8n IP and API key
python setup.py  # Creates all workflows
```

**Setup n8n:**
1. Enable MCP: **Settings > MCP Access > Enable MCP**
2. Set connection method to **Access Token** and copy the token
3. Set `N8N_MCP_URL` in `.env`

See `n8n-workflows/README.md` for included workflows.

### Wake Word Detection

1. Get a free access key from [Picovoice Console](https://console.picovoice.ai/)
2. Train "Hey Cal" wake word, download **Web (WASM)** model
3. Place `hey_cal.ppn` in `frontend/public/`
4. Set `PORCUPINE_ACCESS_KEY` in `.env`
5. Rebuild: `docker compose build frontend && docker compose up -d`

---

## Webhook API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/announce` | POST | Make CAAL speak a message |
| `/wake` | POST | Trigger wake word greeting |
| `/reload-tools` | POST | Refresh MCP tool cache |
| `/health` | GET | Health check |

```bash
curl -X POST http://localhost:8889/announce \
  -H "Content-Type: application/json" \
  -d '{"message": "Package delivered"}'
```

---

## Mobile App

Flutter client for Android and iOS in `mobile/`.

```bash
cd mobile
flutter pub get
flutter run
```

See [mobile/README.md](mobile/README.md) for full documentation.

---

## Development

```bash
# Install dependencies
uv sync

# Start infrastructure
docker compose up -d livekit speaches kokoro

# Run agent locally
uv run voice_agent.py dev

# Run frontend locally
cd frontend && pnpm install && pnpm dev
```

**Commands:**
```bash
uv run ruff check src/   # Lint
uv run mypy src/         # Type check
uv run pytest            # Test
```

---

## Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│  Docker Compose Stack                                                 │
│                                                                       │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │  Frontend  │  │  LiveKit   │  │  Speaches  │  │   Kokoro   │       │
│  │  (Next.js) │  │   Server   │  │ (STT, GPU) │  │ (TTS, GPU) │       │
│  │   :3000    │  │   :7880    │  │   :8000    │  │   :8880    │       │
│  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘  └─────┬──────┘       │
│        │               │               │               │              │
│        │               └───────────────┼───────────────┘              │
│        └───────────────────────┐       │                              │
│                                │       │                              │
│                          ┌─────┴───────┴─────┐                        │
│                          │       Agent       │                        │
│                          │  (Voice Pipeline) │                        │
│                          │  :8889 (webhooks) │                        │
│                          └─────────┬─────────┘                        │
│                                    │                                  │
└────────────────────────────────────┼──────────────────────────────────┘
                                     │
                   ┌─────────────────┼─────────────────┐
                   │                 │                 │
             ┌─────┴─────┐     ┌─────┴─────┐     ┌─────┴─────┐
             │  Ollama   │     │    n8n    │     │   Your    │
             │   (LLM)   │     │ Workflows │     │   APIs    │
             └───────────┘     └───────────┘     └───────────┘
                    External Services (on your network)
```

---

## Troubleshooting

### WebRTC Not Connecting

1. Check `CAAL_HOST_IP` matches your network mode
2. Verify firewall ports: 3000, 7880, 7881, 50000-50100 (UDP)
3. Check logs: `docker compose logs livekit | grep -i "ice\|error"`

### Ollama Connection Failed

```bash
# Ensure Ollama binds to network
OLLAMA_HOST=0.0.0.0 ollama serve

# From Docker, use host.docker.internal
OLLAMA_HOST=http://host.docker.internal:11434
```

### First Start Is Slow

Normal - models download on first run (~2-5 minutes):
```bash
docker compose logs -f speaches kokoro
```

---

## Related Projects

- [LiveKit Agents](https://github.com/livekit/agents) - Voice agent framework
- [Speaches](https://github.com/speaches-ai/speaches) - Faster-Whisper STT server
- [Kokoro-FastAPI](https://github.com/remsky/Kokoro-FastAPI) - Kokoro TTS server
- [mlx-audio](https://github.com/Blaizzy/mlx-audio) - STT/TTS for Apple Silicon
- [Ollama](https://ollama.ai/) - Local LLM server
- [n8n](https://n8n.io/) - Workflow automation

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.
