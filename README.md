# Self-Host AI — Ollama + Nginx API Proxy

Self-hosted Ollama with nginx reverse proxy, API key authentication, and Cloudflare-ready configuration.

## Architecture

```
Internet → Cloudflare Tunnel → Nginx (:8080) → Ollama (:11434)
                                  ↑
                          API Key validation
```

## Quick Start

```bash
# Run the setup script (as root/sudo)
sudo bash setup.sh
```

This will:
1. Create an Ollama model `gemma4-32k` with 32k context window
2. Generate a secure API key
3. Configure and start Nginx as reverse proxy
4. Test the setup

## Manual Setup

### 1. Create Ollama model with 32k context

```bash
ollama create gemma4-32k -f ollama/Modelfile.gemma4-32k
```

Verify it works:
```bash
ollama run gemma4-32k "Hello, how are you?"
```

### 2. Configure Nginx

```bash
# Copy the map config (http context)
sudo cp nginx/ollama-map.conf /etc/nginx/conf.d/

# Copy API keys file
sudo cp nginx/api-keys.conf /etc/nginx/api-keys.conf

# Add your API key (generate one first)
API_KEY="sk-$(openssl rand -hex 32)"
echo "\"Bearer $API_KEY\" 1;" | sudo tee -a /etc/nginx/api-keys.conf

# Install site config
sudo cp nginx/nginx.conf /etc/nginx/sites-available/ollama-proxy
sudo ln -sf /etc/nginx/sites-available/ollama-proxy /etc/nginx/sites-enabled/

# Test & reload
sudo nginx -t
sudo systemctl reload nginx
```

### 3. Test

```bash
# Should return 401
curl http://localhost:8080/api/tags

# Should return 200 with model list
curl http://localhost:8080/api/tags \
  -H "Authorization: Bearer $API_KEY"

# Chat request
curl http://localhost:8080/api/chat \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model": "gemma4-32k", "messages": [{"role": "user", "content": "Hello!"}]}'
```

## API Key Management

### Add a new key
```bash
NEW_KEY="sk-$(openssl rand -hex 32)"
echo "\"Bearer $NEW_KEY\" 1;" | sudo tee -a /etc/nginx/api-keys.conf
sudo nginx -s reload
```

### Revoke a key
Remove the corresponding line from `/etc/nginx/api-keys.conf`, then:
```bash
sudo nginx -s reload
```

## Cloudflare Tunnel

When ready to expose to the internet:

```bash
# Install cloudflared
# https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/

# Quick tunnel (temporary URL)
cloudflared tunnel --url http://localhost:8080

# Named tunnel (persistent, custom domain)
cloudflared tunnel create ollama-api
cloudflared tunnel route dns ollama-api api.yourdomain.com
cloudflared tunnel run ollama-api
```

> **Security notes:**
> - All traffic goes through Cloudflare's network (DDoS protection included)
> - API key is required for all requests (except `/health`)
> - Rate limiting is configured at 10 req/s per IP with burst of 20
> - Ollama only listens on 127.0.0.1 — never exposed directly

## File Structure

```
self-host-ai/
├── README.md
├── setup.sh              # Automated setup script
├── ollama/
│   └── Modelfile.gemma4-32k   # Ollama model with 32k context
└── nginx/
    ├── nginx.conf         # Nginx site config (reverse proxy)
    ├── ollama-map.conf    # Map block for API key validation
    └── api-keys.conf      # API keys (Bearer tokens)
```

## Configuration

| Setting | Value | File |
|---------|-------|------|
| Nginx listen port | 8080 | `nginx/nginx.conf` |
| Ollama backend | 127.0.0.1:11434 | `nginx/nginx.conf` |
| Context window | 32768 tokens | `ollama/Modelfile.gemma4-32k` |
| Rate limit | 10 req/s (burst 20) | `nginx/nginx.conf` |
| Request timeout | 600s | `nginx/nginx.conf` |
| Max body size | 50MB | `nginx/nginx.conf` |
