#!/bin/bash

echo Auto EaglerXBungee - Colbster937 2025

echo Installing required packages
if command -v "apt" > /dev/null 2>&1; then
    apt install curl wget unzip docker.io docker-compose jq yq -y
elif command -v "brew" > /dev/null 2>&1; then
    PKGS="curl wget unzip docker docker-compose jq yq"
    for PKG in $PKGS; do
        if ! brew list "$PKG" &>/dev/null; then
            brew install "$PKG"
        fi
    done
fi

echo Creating main directory
mkdir -p bungee
cd bungee

echo Downloading bungeecord
LATESTV=$(curl -s https://api.papermc.io/v2/projects/waterfall | jq -r '.versions[-1]')
LATESTB=$(curl -s https://api.papermc.io/v2/projects/waterfall/versions/$LATESTV/builds | jq -r '.builds[-1].build')
FILE=$(curl -s https://api.papermc.io/v2/projects/waterfall/versions/$LATESTV/builds/$LATESTB | jq -r '.downloads.application.name')
WATERFALL_DL="https://api.papermc.io/v2/projects/waterfall/versions/$LATESTV/builds/$LATESTB/downloads/$FILE"
wget -q -O server.jar "$WATERFALL_DL" &> /dev/null

echo Creating plugin directory
mkdir -p plugins
cd plugins

echo Downloading EaglerXBungee
wget -q -O EaglerXBungee.jar "https://git.eaglercraft.rip/eaglercraft/eaglercraft-builds/raw/branch/main/EaglercraftX_1.8_EaglerXBungee.jar" &> /dev/null

cd ..
echo Creating Docker file
cat <<EOF > docker-compose.yml
services:
  bungee:
    image: eclipse-temurin:21-jdk
    container_name: eaglerxbungee
    working_dir: /app
    ports:
      - 25565:25565
    volumes:
      - ./:/app
    command: ["java", "-jar", "server.jar"]
    restart: always
    networks:
      - eagler-network
  nginx:
    image: nginx:alpine
    container_name: eaglerxbungee_nginx
    volumes:
        - ./nginx.conf:/etc/nginx/nginx.conf:ro
    ports:
        - "8081:8081"
    networks:
        - eagler-network
networks:
  eagler-network:
    driver: bridge
EOF

echo Creating start script
cat <<EOF > start
screen docker-compose up
EOF
chmod +x start

cat <<EOF > nginx.conf
events {}

http {
    server {
        listen 8081;

        location / {
            proxy_pass http://bungee:8081;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_read_timeout 86400;
        }
    }
}
EOF

echo Starting the container \(this may take a while\)
docker-compose up -d &>/dev/null
while ! docker inspect -f '{{.State.Running}}' "eaglerxbungee" | grep -q "true"; do
    sleep 1
done
sleep 5

echo Stopping the container
docker-compose down &>/dev/null

if [ ! -f "backend.txt" ]; then
    echo "What is your PaperMC server IP (including port)?"
    read -p '> ' BACKEND_IP
    echo "$BACKEND_IP" > backend.txt
else
    BACKEND_IP=$(cat backend.txt)
fi

yq -i ".servers.lobby.address = \"$BACKEND_IP\"" config.yml

echo Configuring bungeecord
yq -i '.online_mode = false' config.yml
yq -i '.listeners[0].host = "0.0.0.0:25565"' config.yml
yq -i '.listeners[0].query_port = 25565' config.yml
yq -i '.listeners[0].ping_passthrough = true' config.yml
yq -i '.listeners[0].force_default_server = true' config.yml
yq -i '.ip_forward = true' config.yml

echo Configuring EaglerXBungee
cd plugins/EaglercraftXBungee
yq -i '.listener_01.forward_ip = true' listeners.yml
yq -i '.listener_01.http_server.enabled = true' listeners.yml

echo Downloading EaglercraftX web
wget -q -O web.zip "https://git.eaglercraft.rip/eaglercraft/eaglercraft-builds/raw/branch/main/EaglercraftX_1.8_Web.zip" &> /dev/null

echo Extracting EaglercraftX web
unzip -o web.zip -d web &>/dev/null

echo -e "\n"
echo -e "\033[32mDone! Run the server with \"./start\" in bungee folder\033[0m"
echo -e "\033[1;31mMake sure your backend server is configured for bungeecord and has the proper authentication and/or security measures\033[0m"
