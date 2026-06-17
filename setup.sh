#!/usr/bin/env bash
set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Setup Script for Ollama + Nginx API Proxy
# ═══════════════════════════════════════════════════════════════
#
# This script:
#   1. Creates the Ollama model with 32k context window
#   2. Generates an API key
#   3. Installs and configures Nginx
#   4. Tests the setup
#
# Usage: sudo bash setup.sh
# ═══════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GENERATED_KEY=""

print_header() {
    echo ""
    echo "══════════════════════════════════════════════"
    echo "  $1"
    echo "══════════════════════════════════════════════"
}

# ── Step 1: Create Ollama model with 32k context ──
setup_ollama_model() {
    print_header "Step 1: Creating Ollama model with 32k context"

    if ! command -v ollama &>/dev/null; then
        echo "❌ Ollama not found. Please install it first:"
        echo "   curl -fsSL https://ollama.ai/install.sh | sh"
        exit 1
    fi

    echo "📦 Creating custom model gemma4-32k from Modelfile..."
    ollama create gemma4-32k -f "$SCRIPT_DIR/ollama/Modelfile.gemma4-32k"
    echo "✅ Model gemma4-32k created successfully!"
    echo ""
    echo "💡 Test it with: ollama run gemma4-32k"
}

# ── Step 2: Generate API key ──
generate_api_key() {
    print_header "Step 2: Generating API Key"

    GENERATED_KEY="sk-$(openssl rand -hex 32)"
    echo "🔑 Generated API key: $GENERATED_KEY"
    echo ""
    echo "⚠️  Save this key! It will be added to the nginx config."
}

# ── Step 3: Install and configure Nginx ──
setup_nginx() {
    print_header "Step 3: Setting up Nginx"

    # Install nginx if not present
    if ! command -v nginx &>/dev/null; then
        echo "📦 Installing nginx..."
        if command -v apt-get &>/dev/null; then
            apt-get update && apt-get install -y nginx
        elif command -v brew &>/dev/null; then
            brew install nginx
        else
            echo "❌ Cannot install nginx automatically. Please install manually."
            exit 1
        fi
    fi

    echo "📝 Configuring nginx..."

    # Determine nginx config paths
    if [ -d /etc/nginx ]; then
        NGINX_DIR="/etc/nginx"
    elif [ -d /usr/local/etc/nginx ]; then
        NGINX_DIR="/usr/local/etc/nginx"  # macOS Homebrew
    elif [ -d /opt/homebrew/etc/nginx ]; then
        NGINX_DIR="/opt/homebrew/etc/nginx"  # macOS Apple Silicon Homebrew
    else
        echo "❌ Cannot find nginx config directory."
        exit 1
    fi

    echo "   Nginx config dir: $NGINX_DIR"

    # Create necessary directories
    mkdir -p "$NGINX_DIR/sites-available"
    mkdir -p "$NGINX_DIR/sites-enabled"
    mkdir -p "$NGINX_DIR/conf.d"

    # Copy map config (http context)
    cp "$SCRIPT_DIR/nginx/ollama-map.conf" "$NGINX_DIR/conf.d/ollama-map.conf"
    echo "   ✅ Copied ollama-map.conf → $NGINX_DIR/conf.d/"

    # Copy and configure API keys
    cp "$SCRIPT_DIR/nginx/api-keys.conf" "$NGINX_DIR/api-keys.conf"
    # Add the generated key
    echo "\"Bearer $GENERATED_KEY\" 1;" >> "$NGINX_DIR/api-keys.conf"
    echo "   ✅ API key added to $NGINX_DIR/api-keys.conf"

    # Copy site config
    cp "$SCRIPT_DIR/nginx/nginx.conf" "$NGINX_DIR/sites-available/ollama-proxy"
    ln -sf "$NGINX_DIR/sites-available/ollama-proxy" "$NGINX_DIR/sites-enabled/ollama-proxy"
    echo "   ✅ Site config installed and enabled"

    # Ensure sites-enabled is included in main nginx.conf
    if ! grep -q "sites-enabled" "$NGINX_DIR/nginx.conf" 2>/dev/null; then
        echo ""
        echo "⚠️  You may need to add this line to your $NGINX_DIR/nginx.conf"
        echo "   inside the http {} block:"
        echo ""
        echo "   include $NGINX_DIR/sites-enabled/*;"
        echo ""
    fi

    # Test nginx config
    echo "🔍 Testing nginx configuration..."
    if nginx -t 2>&1; then
        echo "✅ Nginx config is valid!"
    else
        echo "❌ Nginx config has errors. Please check the output above."
        exit 1
    fi

    # Reload nginx
    echo "🔄 Reloading nginx..."
    if command -v systemctl &>/dev/null; then
        systemctl reload nginx || systemctl start nginx
    elif command -v brew &>/dev/null; then
        brew services restart nginx
    else
        nginx -s reload 2>/dev/null || nginx
    fi
    echo "✅ Nginx is running!"
}

# ── Step 4: Test the setup ──
test_setup() {
    print_header "Step 4: Testing the Setup"

    echo "🔍 Testing health endpoint (no auth)..."
    HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "000")
    if [ "$HEALTH" = "200" ]; then
        echo "   ✅ Health check passed"
    else
        echo "   ⚠️  Health check returned $HEALTH (Ollama might not be running)"
    fi

    echo ""
    echo "🔍 Testing without API key (should fail)..."
    NO_AUTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/tags 2>/dev/null || echo "000")
    if [ "$NO_AUTH" = "401" ]; then
        echo "   ✅ Correctly rejected (401 Unauthorized)"
    else
        echo "   ⚠️  Got $NO_AUTH instead of 401"
    fi

    echo ""
    echo "🔍 Testing with API key (should succeed)..."
    WITH_AUTH=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Authorization: Bearer $GENERATED_KEY" \
        http://localhost:8080/api/tags 2>/dev/null || echo "000")
    if [ "$WITH_AUTH" = "200" ]; then
        echo "   ✅ Authenticated request passed (200 OK)"
    else
        echo "   ⚠️  Got $WITH_AUTH instead of 200"
    fi
}

# ── Print summary ──
print_summary() {
    print_header "Setup Complete! 🎉"

    echo ""
    echo "📋 Summary:"
    echo "   • Ollama model: gemma4-32k (32768 token context)"
    echo "   • Nginx proxy:  http://localhost:8080"
    echo "   • Ollama API:   http://localhost:11434 (direct, local only)"
    echo ""
    echo "🔑 Your API Key:"
    echo "   $GENERATED_KEY"
    echo ""
    echo "📝 Usage examples:"
    echo ""
    echo "   # List models"
    echo "   curl http://localhost:8080/api/tags \\"
    echo "     -H 'Authorization: Bearer $GENERATED_KEY'"
    echo ""
    echo "   # Chat (streaming)"
    echo "   curl http://localhost:8080/api/chat \\"
    echo "     -H 'Authorization: Bearer $GENERATED_KEY' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"model\": \"gemma4-32k\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
    echo ""
    echo "   # OpenAI-compatible endpoint"
    echo "   curl http://localhost:8080/v1/chat/completions \\"
    echo "     -H 'Authorization: Bearer $GENERATED_KEY' \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"model\": \"gemma4-32k\", \"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
    echo ""
    echo "🌐 Cloudflare Tunnel (when ready):"
    echo "   cloudflared tunnel --url http://localhost:8080"
    echo ""
    echo "🔒 To add more API keys:"
    echo "   1. Generate: openssl rand -hex 32"
    echo "   2. Add to: /etc/nginx/api-keys.conf"
    echo "      Format: \"Bearer sk-<your-key>\" 1;"
    echo "   3. Reload: sudo nginx -s reload"
}

# ── Main ──
main() {
    echo ""
    echo "🚀 Ollama + Nginx API Proxy Setup"
    echo "   Self-hosted AI with API key authentication"
    echo ""

    setup_ollama_model
    generate_api_key
    setup_nginx
    test_setup
    print_summary
}

main "$@"
