#!/bin/bash
set -euo pipefail

# ============================================================
# Blue-Green Deployment Script
# Usage: ./deploy.sh <image_tag>
#
# Prerequisite: Run setup_nginx.sh once before first deploy.
# ============================================================

TAG="${1:?Usage: deploy.sh <image_tag>}"

BLUE_CONTAINER="petclinic-blue"
GREEN_CONTAINER="petclinic-green"
NGINX_CONTAINER="nginx"
NETWORK="petclinic-net"

# Ensure Docker network exists
docker network create "${NETWORK}" 2>/dev/null || true

# ------------------------------------------------------------
# Determine current active container (blue or green)
# ------------------------------------------------------------
if docker ps --format '{{.Names}}' | grep -q "^${BLUE_CONTAINER}$"; then
    NEW_CONTAINER="${GREEN_CONTAINER}"
    OLD_CONTAINER="${BLUE_CONTAINER}"
elif docker ps --format '{{.Names}}' | grep -q "^${GREEN_CONTAINER}$"; then
    NEW_CONTAINER="${BLUE_CONTAINER}"
    OLD_CONTAINER="${GREEN_CONTAINER}"
else
    # First deployment: start with blue
    NEW_CONTAINER="${BLUE_CONTAINER}"
    OLD_CONTAINER=""
fi

echo "=========================================="
echo "  Blue-Green Deployment"
echo "  Image:  spring-petclinic:${TAG}"
echo "  New:    ${NEW_CONTAINER}"
echo "  Old:    ${OLD_CONTAINER:-none}"
echo "=========================================="

# ------------------------------------------------------------
# Step 1: Start new container (does NOT affect live traffic)
# ------------------------------------------------------------
echo "[1/4] Starting ${NEW_CONTAINER}..."
docker rm -f "${NEW_CONTAINER}" 2>/dev/null || true
docker run -d \
    --name "${NEW_CONTAINER}" \
    --network "${NETWORK}" \
    --restart=on-failure \
    "spring-petclinic:${TAG}"

# ------------------------------------------------------------
# Step 2: Health check - wait for new container to be ready
# ------------------------------------------------------------
echo "[2/4] Health check (max 60s)..."
HEALTHY=false
for i in $(seq 1 30); do
    if docker exec "${NGINX_CONTAINER}" wget -q -O /dev/null "http://${NEW_CONTAINER}:8080" 2>/dev/null; then
        HEALTHY=true
        break
    fi
    echo "  Waiting... (${i}/30)"
    sleep 2
done

if [ "${HEALTHY}" = false ]; then
    echo "  ❌ Health check failed! Rolling back..."
    docker rm -f "${NEW_CONTAINER}"
    exit 1
fi
echo "  ✅ ${NEW_CONTAINER} is healthy!"

# ------------------------------------------------------------
# Step 3: Switch Nginx to new container (zero downtime)
# ------------------------------------------------------------
echo "[3/4] Switching traffic to ${NEW_CONTAINER}..."

# Write Nginx config to a temp file in the Jenkins workspace,
# then docker cp into the Nginx container.
# (Cannot write to host /opt/nginx-conf directly because this script
#  runs inside the Jenkins container, not on the host.)
TMP_CONF=$(mktemp /tmp/nginx-default-XXXXXX.conf)
cat > "${TMP_CONF}" << 'NGINXEOF'
upstream petclinic_backend {
    server __CONTAINER__:8080;
}

server {
    listen 8081;

    location / {
        proxy_pass http://petclinic_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 5s;
        proxy_read_timeout 60s;
    }
}
NGINXEOF

# Replace placeholder with actual container name
sed -i "s/__CONTAINER__/${NEW_CONTAINER}/" "${TMP_CONF}"

# Copy config into Nginx container and reload
docker cp "${TMP_CONF}" "${NGINX_CONTAINER}:/etc/nginx/conf.d/default.conf"
rm -f "${TMP_CONF}"
docker exec "${NGINX_CONTAINER}" nginx -s reload
echo "  ✅ Traffic switched (zero downtime)!"

# ------------------------------------------------------------
# Step 4: Remove old container (traffic already on new one)
# ------------------------------------------------------------
if [ -n "${OLD_CONTAINER}" ]; then
    echo "[4/4] Removing old container: ${OLD_CONTAINER}..."
    docker rm -f "${OLD_CONTAINER}"
    echo "  ✅ Old container removed!"
else
    echo "[4/4] First deployment - no old container to remove."
fi

echo ""
echo "=========================================="
echo "  ✅ Deployment complete!"
echo "  App:    http://localhost:8081"
echo "  Active: ${NEW_CONTAINER}"
echo "=========================================="
