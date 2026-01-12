# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 0.1.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in CAAL, please report it responsibly.

**Do NOT open a public issue for security vulnerabilities.**

### How to Report

Email: **cmac@coreworxlab.com**

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Any suggested fixes (optional)

### What to Expect

- **Acknowledgment**: Within 48 hours
- **Initial assessment**: Within 7 days
- **Resolution timeline**: Depends on severity, typically 30-90 days

### Scope

This policy applies to:
- Python voice agent (`voice_agent.py`, `src/caal/`)
- Next.js frontend (`frontend/`)
- Flutter mobile app (`mobile/`)
- Docker configurations
- n8n workflow examples

### Out of Scope

- Third-party dependencies (report to respective projects)
- Self-hosted infrastructure misconfigurations
- Social engineering attacks

## Security Best Practices

When deploying CAAL:

1. **Generate unique LiveKit keys** for production
2. **Use HTTPS** for any non-localhost deployment
3. **Secure your n8n instance** with authentication
4. **Keep Ollama** on a trusted network
5. **Review n8n workflows** before enabling MCP access

Thank you for helping keep CAAL secure.
