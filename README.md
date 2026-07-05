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

Lệnh mình hay dùng
```
cloudflared tunnel run --url http://localhost:8080 --no-chunked-encoding mac-ollama
```



> **Security notes:**
> - All traffic goes through Cloudflare's network (DDoS protection included)
> - API key is required for all requests (except `/health`)
> - Rate limiting is configured at 10 req/s per IP with burst of 20
> - Ollama only listens on 127.0.0.1 — never exposed directly

## Auto-start on Login

Chạy một lần để cài đặt auto-start, sau đó tunnel sẽ tự bật mỗi lần đăng nhập.

### macOS (LaunchAgent)

```bash
bash autostart/macos/install.sh
```

| Lệnh | Mô tả |
|------|---------|
| `launchctl list \| grep ollama-tunnel` | Xem trạng thái |
| `tail -f ~/.local/log/ollama-tunnel/tunnel.log` | Xem log |
| `launchctl stop com.kalix.ollama-tunnel` | Dừng |
| `launchctl start com.kalix.ollama-tunnel` | Khởi động lại |
| `bash autostart/macos/uninstall.sh` | Gỡ bỏ |

### Linux (systemd user service)

```bash
bash autostart/linux/install.sh
```

| Lệnh | Mô tả |
|------|---------|
| `systemctl --user status ollama-tunnel` | Xem trạng thái |
| `journalctl --user -u ollama-tunnel -f` | Xem log (systemd) |
| `tail -f ~/.local/log/ollama-tunnel/tunnel.log` | Xem log (file) |
| `systemctl --user stop ollama-tunnel` | Dừng |
| `systemctl --user start ollama-tunnel` | Khởi động lại |
| `bash autostart/linux/uninstall.sh` | Gỡ bỏ |

> **Headless server**: Chạy thêm `sudo loginctl enable-linger $USER` để service chạy không cần đăng nhập.

### Windows (Task Scheduler)

Mở PowerShell và chạy:

```powershell
.\autostart\windows\install.ps1
```

| Lệnh | Mô tả |
|------|---------|
| `Get-ScheduledTask -TaskPath '\Kalix\'` | Xem trạng thái |
| `Get-Content ~\.local\log\ollama-tunnel\tunnel.log -Tail 50 -Wait` | Xem log |
| `Stop-ScheduledTask -TaskPath '\Kalix\' -TaskName 'OllamaTunnel'` | Dừng |
| `Start-ScheduledTask -TaskPath '\Kalix\' -TaskName 'OllamaTunnel'` | Khởi động lại |
| `.\autostart\windows\uninstall.ps1` | Gỡ bỏ |

## File Structure

```
self-host-ai/
├── README.md
├── setup.sh                        # Setup script (macOS/Linux)
├── nginx/                          # Nginx config (shared across OS)
│   ├── nginx.conf                  # Reverse proxy config
│   ├── ollama-map.conf             # API key validation map
│   └── api-keys.conf               # Allowed API keys
├── ollama/
│   └── Modelfile.gemma4-32k        # Custom model (32k context)
└── autostart/                      # Auto-start scripts per OS
    ├── macos/                      # macOS → LaunchAgent
    │   ├── start-tunnel.sh         # Startup script
    │   ├── com.kalix.ollama-tunnel.plist  # LaunchAgent template
    │   ├── install.sh              # Install auto-start
    │   └── uninstall.sh            # Remove auto-start
    ├── linux/                      # Linux → systemd user service
    │   ├── start-tunnel.sh         # Startup script
    │   ├── ollama-tunnel.service    # systemd unit file template
    │   ├── install.sh              # Install auto-start
    │   └── uninstall.sh            # Remove auto-start
    └── windows/                    # Windows → Task Scheduler
        ├── start-tunnel.ps1        # Startup script (PowerShell)
        ├── install.ps1             # Install auto-start
        └── uninstall.ps1           # Remove auto-start
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
