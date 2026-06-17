```
curl http://localhost:8080/v1/chat/completions \
  -H "Authorization: Bearer sk-7d...." \
  -H "Content-Type: application/json" \
  -d '{"model": "gemma4-32k", "messages": [{"role": "user", "content": "Xin chào!"}]}'
```

cloudflared tunnel create mac-ollama

cloudflared tunnel route dns mac-ollama ollama.kalix.vn

cloudflared tunnel run --url http://localhost:8080 mac-ollama