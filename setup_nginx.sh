#!/bin/bash
set -euo pipefail

# ============================================================
# Nginx Reverse Proxy Setup (run once in WSL2)
#
# This script creates:
#   1. A Docker network for Nginx <-> backend containers
#   2. An Nginx container as the fixed entry point (port 8081)
#   3. An initial "maintenance mode" config
#
# After running this, trigger a Jenkins build to deploy
# the actual application behind Nginx.
# ============================================================

NETWORK="petclinic-net"
NGINX_CONTAINER="nginx"
CONF_DIR="/opt/nginx-conf"

echo "=== Nginx Reverse Proxy Setup ==="
echo ""

# 1. Create Docker network
docker network create "${NETWORK}" 2>/dev/null || true
echo "✅ Docker network '${NETWORK}' ready"

# 2. Create config directory and initial config (maintenance mode)
mkdir -p "${CONF_DIR}"
cat > "${CONF_DIR}/default.conf" << 'EOF'
server {
    listen 8081;
    location / {
        return 503 'Service not yet deployed. Trigger a Jenkins build first.';
    }
}
EOF
echo "✅ Initial Nginx config created (maintenance mode)"

# 3. Remove old Nginx container if exists
docker rm -f "${NGINX_CONTAINER}" 2>/dev/null || true

# 4. Stop old app container if it occupies port 8081
docker rm -f spring-petclinic 2>/dev/null || true

# 5. Start Nginx container
docker run -d \
    --name "${NGINX_CONTAINER}" \
    --network "${NETWORK}" \
    -p 8081:8081 \
    --restart=on-failure \
    -v "${CONF_DIR}/default.conf:/etc/nginx/conf.d/default.conf" \
    nginx:alpine

echo "✅ Nginx running on port 8081"
echo ""
echo "=========================================="
echo "  Setup complete!"
echo ""
echo "  Nginx:    http://localhost:8081"
echo "  Network:  ${NETWORK}"
echo "  Config:   ${CONF_DIR}/default.conf"
echo ""
echo "  Next step:"
echo "    1. Push Jenkinsfile + deploy.sh to GitHub"
echo "    2. Trigger a Jenkins build"
echo "    3. Click '部署' when pipeline pauses"
echo "    4. App will be live at http://localhost:8081"
echo "=========================================="
