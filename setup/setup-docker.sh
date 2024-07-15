#!/bin/sh

apt-get install -y ca-certificates curl

if ! [ -f /etc/apt/keyrings/docker.asc ]; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
fi

if ! [ -f /etc/apt/sources.list.d/docker.list ]; then
  echo   "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
fi

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

if ! [ -f /etc/docker/daemon.json ]; then
  echo '{ "log-driver": "journald" }' > /etc/docker/daemon.json
fi

service docker restart

echo ""
echo "Docker setup complete!"
echo ""
