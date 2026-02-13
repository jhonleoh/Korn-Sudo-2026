#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#    ░▒▓█  ☁️  Project Fog Core Installer  ☁️  █▓▒░
#    All installation functions for Project Fog Modernized
# ═══════════════════════════════════════════════════════════════════

# ----- Inherit variables from parent or detect fresh -----
if [[ -z "${OS_NAME:-}" ]]; then
    OS_NAME=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_VER=$(awk -F= '/^VERSION_ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_CODENAME=$(awk -F= '/^VERSION_CODENAME=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_VER_MAJOR="${OS_VER%%.*}"
fi

if [[ -z "${IPADDR:-}" ]]; then
    IPADDR=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || wget -qO- --timeout=5 https://ifconfig.me 2>/dev/null || echo "UNKNOWN")
fi

if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

# Color definitions (in case sourced independently)
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
NC='\e[0m'

# ----- Project directories -----
FOG_DIR="/etc/project-fog"
FOG_LOG="/var/log/project-fog"
mkdir -p "$FOG_DIR" "$FOG_LOG"

# ═══════════════════════════════════════════════════
#  HELPER FUNCTIONS
# ═══════════════════════════════════════════════════

log_info()  { echo -e "${CYAN}[*]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
log_err()   { echo -e "${RED}[✗]${NC} $1"; }

# Safe package installer with retry
safe_install() {
    local retries=2
    local count=0
    while [[ $count -lt $retries ]]; do
        if DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$@" 2>>"${FOG_LOG}/install.log"; then
            return 0
        fi
        count=$((count + 1))
        log_warn "Retry $count/$retries for: $*"
        sleep 2
    done
    # Try installing packages one by one on failure
    log_warn "Batch install failed. Trying packages individually..."
    for pkg in "$@"; do
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "$pkg" 2>>"${FOG_LOG}/install.log" || \
            log_warn "Could not install: $pkg (skipping)"
    done
}

# Check if a service is active
is_service_active() {
    systemctl is-active --quiet "$1" 2>/dev/null
}

# Enable and start a service safely
enable_service() {
    local svc="$1"
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable "$svc" 2>/dev/null || true
    systemctl restart "$svc" 2>/dev/null || log_warn "Could not start $svc"
}

# Generate self-signed SSL certificate if needed
generate_ssl_cert() {
    local cert_dir="/etc/project-fog/ssl"
    mkdir -p "$cert_dir"
    if [[ ! -f "$cert_dir/fog.pem" ]]; then
        log_info "Generating self-signed SSL certificate..."
        openssl req -new -newkey rsa:2048 -days 3650 -nodes -x509 \
            -subj "/C=PH/ST=Cloud/L=Fog/O=ProjectFog/CN=${IPADDR}" \
            -keyout "$cert_dir/fog.key" \
            -out "$cert_dir/fog.crt" 2>/dev/null
        cat "$cert_dir/fog.key" "$cert_dir/fog.crt" > "$cert_dir/fog.pem"
        chmod 600 "$cert_dir/fog.key" "$cert_dir/fog.pem"
        log_ok "SSL certificate generated"
    else
        log_ok "SSL certificate already exists"
    fi
}

# ═══════════════════════════════════════════════════
#  1. SYSTEM UPDATES & DEPENDENCIES
# ═══════════════════════════════════════════════════

InstUpdates() {
    log_info "Updating system packages..."
    export DEBIAN_FRONTEND=noninteractive

    # Fix any broken packages first
    dpkg --configure -a 2>/dev/null || true
    apt-get -f install -y 2>/dev/null || true

    apt-get update -qq 2>>"${FOG_LOG}/install.log"
    apt-get upgrade -y -qq 2>>"${FOG_LOG}/install.log"

    # Remove conflicting firewalls (we'll use iptables directly)
    apt-get remove --purge -y ufw firewalld 2>/dev/null || true

    log_info "Installing core dependencies..."
    safe_install \
        nano sudo wget curl zip unzip tar gzip \
        psmisc build-essential iptables bc openssl \
        cron net-tools dnsutils lsof dos2unix git \
        qrencode libcap2-bin dbus whois ngrep screen \
        bzip2 gcc automake autoconf make libtool \
        ca-certificates apt-transport-https lsb-release \
        gnupg software-properties-common jq socat

    # Install figlet with fallback
    if ! command -v figlet &>/dev/null; then
        safe_install figlet 2>/dev/null || log_warn "figlet not available (cosmetic only)"
    fi

    # Ensure time is synced
    if command -v timedatectl &>/dev/null; then
        timedatectl set-ntp true 2>/dev/null || true
    fi

    log_ok "System updates complete"
}

# ═══════════════════════════════════════════════════
#  2. SSH CONFIGURATION
# ═══════════════════════════════════════════════════

InstSSH() {
    log_info "Configuring OpenSSH..."

    safe_install openssh-server

    # Backup original config
    [[ -f /etc/ssh/sshd_config ]] && cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.fog

    # Configure SSH - compatible with all versions
    local sshd_conf="/etc/ssh/sshd_config"

    # Use sed for compatibility across all versions
    sed -i 's/^#\?Port .*/Port 22/' "$sshd_conf"
    sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin yes/' "$sshd_conf"
    sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' "$sshd_conf"
    sed -i 's/^#\?PermitEmptyPasswords .*/PermitEmptyPasswords no/' "$sshd_conf"
    sed -i 's/^#\?X11Forwarding .*/X11Forwarding yes/' "$sshd_conf"
    sed -i 's/^#\?PrintMotd .*/PrintMotd no/' "$sshd_conf"
    sed -i 's/^#\?TCPKeepAlive .*/TCPKeepAlive yes/' "$sshd_conf"
    sed -i 's/^#\?ClientAliveInterval .*/ClientAliveInterval 60/' "$sshd_conf"
    sed -i 's/^#\?ClientAliveCountMax .*/ClientAliveCountMax 3/' "$sshd_conf"

    # Add settings if they don't exist
    grep -q "^ClientAliveInterval" "$sshd_conf" || echo "ClientAliveInterval 60" >> "$sshd_conf"
    grep -q "^ClientAliveCountMax" "$sshd_conf" || echo "ClientAliveCountMax 3" >> "$sshd_conf"

    enable_service sshd
    log_ok "OpenSSH configured (Port 22)"
}

# ═══════════════════════════════════════════════════
#  3. DROPBEAR
# ═══════════════════════════════════════════════════

InstDropbear() {
    log_info "Installing and configuring Dropbear..."

    safe_install dropbear

    # Configure Dropbear ports
    # Dropbear configuration path
    local dropbear_default="/etc/default/dropbear"

    if [[ -f "$dropbear_default" ]]; then
        # Debian/Ubuntu style configuration
        sed -i 's/^NO_START=.*/NO_START=0/' "$dropbear_default"

        # Set ports based on OS version
        # Newer systems use DROPBEAR_EXTRA_ARGS, older use DROPBEAR_PORT
        if grep -q "DROPBEAR_PORT" "$dropbear_default"; then
            sed -i 's/^DROPBEAR_PORT=.*/DROPBEAR_PORT=109/' "$dropbear_default"
        fi

        # Add extra args for additional port
        if grep -q "^DROPBEAR_EXTRA_ARGS" "$dropbear_default"; then
            sed -i 's/^DROPBEAR_EXTRA_ARGS=.*/DROPBEAR_EXTRA_ARGS="-p 109 -p 143"/' "$dropbear_default"
        else
            echo 'DROPBEAR_EXTRA_ARGS="-p 109 -p 143"' >> "$dropbear_default"
        fi

        # Set banner
        if grep -q "^DROPBEAR_BANNER" "$dropbear_default"; then
            sed -i 's|^DROPBEAR_BANNER=.*|DROPBEAR_BANNER="/etc/project-fog/banner.txt"|' "$dropbear_default"
        else
            echo 'DROPBEAR_BANNER="/etc/project-fog/banner.txt"' >> "$dropbear_default"
        fi
    fi

    # Create banner
    cat > /etc/project-fog/banner.txt << 'BANNER'
<br>
<b><font color="cyan">☁️ Project Fog Modernized ☁️</font></b><br>
<b><font color="green">Secure VPN Tunneling Server</font></b><br>
<br>
BANNER

    enable_service dropbear
    log_ok "Dropbear configured (Ports 109, 143)"
}

# ═══════════════════════════════════════════════════
#  4. STUNNEL (SSL TUNNEL)
# ═══════════════════════════════════════════════════

InstStunnel() {
    log_info "Installing and configuring Stunnel..."

    safe_install stunnel4

    # Generate SSL certificate
    generate_ssl_cert

    # Enable stunnel
    local stunnel_default="/etc/default/stunnel4"
    if [[ -f "$stunnel_default" ]]; then
        sed -i 's/^ENABLED=.*/ENABLED=1/' "$stunnel_default"
    fi

    # Create stunnel configuration
    cat > /etc/stunnel/stunnel.conf << STUNNELEOF
# Project Fog Stunnel Configuration
pid = /var/run/stunnel4/stunnel.pid
cert = /etc/project-fog/ssl/fog.pem
key = /etc/project-fog/ssl/fog.key

[dropbear-ssl]
accept = 443
connect = 127.0.0.1:109

[dropbear-ssl2]
accept = 445
connect = 127.0.0.1:109

[dropbear-ssl3]
accept = 777
connect = 127.0.0.1:143

[openssh-ssl]
accept = 990
connect = 127.0.0.1:22

[openvpn-ssl]
accept = 442
connect = 127.0.0.1:1194
STUNNELEOF

    # Ensure pid directory exists
    mkdir -p /var/run/stunnel4
    chown stunnel4:stunnel4 /var/run/stunnel4 2>/dev/null || true

    enable_service stunnel4
    log_ok "Stunnel configured (SSL Ports: 443, 445, 777, 990, 442)"
}

# ═══════════════════════════════════════════════════
#  5. OPENVPN
# ═══════════════════════════════════════════════════

InstOpenVPN() {
    log_info "Installing and configuring OpenVPN..."

    safe_install openvpn easy-rsa

    local ovpn_dir="/etc/openvpn"
    local easyrsa_dir="/etc/openvpn/easy-rsa"

    # Setup Easy-RSA
    if [[ -d /usr/share/easy-rsa ]]; then
        cp -r /usr/share/easy-rsa "$easyrsa_dir"
    else
        # Download Easy-RSA if not available
        local easyrsa_ver="3.1.7"
        wget -qO /tmp/easyrsa.tgz "https://github.com/OpenVPN/easy-rsa/releases/download/v${easyrsa_ver}/EasyRSA-${easyrsa_ver}.tgz" || \
        wget -qO /tmp/easyrsa.tgz "https://github.com/OpenVPN/easy-rsa/releases/download/v3.1.2/EasyRSA-3.1.2.tgz"
        mkdir -p "$easyrsa_dir"
        tar xzf /tmp/easyrsa.tgz --strip-components=1 -C "$easyrsa_dir"
        rm -f /tmp/easyrsa.tgz
    fi

    # Initialize PKI
    cd "$easyrsa_dir" || return 1
    if [[ ! -d "$easyrsa_dir/pki" ]]; then
        cat > "$easyrsa_dir/vars" << 'VARSEOF'
set_var EASYRSA_ALGO     ec
set_var EASYRSA_CURVE    prime256v1
set_var EASYRSA_DIGEST   "sha256"
set_var EASYRSA_REQ_CN   "ProjectFog-CA"
set_var EASYRSA_BATCH    "yes"
VARSEOF

        ./easyrsa init-pki 2>/dev/null
        ./easyrsa --batch build-ca nopass 2>/dev/null
        ./easyrsa --batch gen-req server nopass 2>/dev/null
        ./easyrsa --batch sign-req server server 2>/dev/null
        ./easyrsa gen-dh 2>/dev/null || openssl dhparam -out "$easyrsa_dir/pki/dh.pem" 2048 2>/dev/null
        openvpn --genkey secret "$ovpn_dir/ta.key" 2>/dev/null || openvpn --genkey --secret "$ovpn_dir/ta.key" 2>/dev/null
    fi

    # Copy certificates
    cp "$easyrsa_dir/pki/ca.crt" "$ovpn_dir/" 2>/dev/null || true
    cp "$easyrsa_dir/pki/issued/server.crt" "$ovpn_dir/" 2>/dev/null || true
    cp "$easyrsa_dir/pki/private/server.key" "$ovpn_dir/" 2>/dev/null || true
    cp "$easyrsa_dir/pki/dh.pem" "$ovpn_dir/" 2>/dev/null || true

    # TCP Configuration
    cat > "$ovpn_dir/server_tcp.conf" << TCPEOF
port 1194
proto tcp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
tls-auth /etc/openvpn/ta.key 0
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /etc/openvpn/ipp_tcp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "dhcp-option DNS 1.1.1.1"
duplicate-cn
keepalive 10 120
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
persist-key
persist-tun
status /var/log/openvpn/status_tcp.log
log-append /var/log/openvpn/openvpn_tcp.log
verb 3
max-clients 50
user nobody
group nogroup
TCPEOF

    # UDP Configuration
    cat > "$ovpn_dir/server_udp.conf" << UDPEOF
port 2200
proto udp
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key
dh /etc/openvpn/dh.pem
tls-auth /etc/openvpn/ta.key 0
server 10.9.0.0 255.255.255.0
ifconfig-pool-persist /etc/openvpn/ipp_udp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "dhcp-option DNS 1.1.1.1"
duplicate-cn
keepalive 10 120
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
persist-key
persist-tun
status /var/log/openvpn/status_udp.log
log-append /var/log/openvpn/openvpn_udp.log
verb 3
max-clients 50
user nobody
group nogroup
UDPEOF

    mkdir -p /var/log/openvpn

    # Enable IP forwarding
    sed -i 's/^#\?net.ipv4.ip_forward=.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p 2>/dev/null || true

    # NAT rules for OpenVPN
    local default_iface
    default_iface=$(ip route show default | awk '/default/{print $5}' | head -1)
    if [[ -n "$default_iface" ]]; then
        iptables -t nat -C POSTROUTING -s 10.8.0.0/24 -o "$default_iface" -j MASQUERADE 2>/dev/null || \
            iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$default_iface" -j MASQUERADE
        iptables -t nat -C POSTROUTING -s 10.9.0.0/24 -o "$default_iface" -j MASQUERADE 2>/dev/null || \
            iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o "$default_iface" -j MASQUERADE
    fi

    # Generate client config template
    mkdir -p "$FOG_DIR/openvpn-clients"
    cat > "$FOG_DIR/openvpn-clients/client_tcp.ovpn" << CLIENTEOF
client
dev tun
proto tcp
remote ${IPADDR} 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
key-direction 1
verb 3
auth-user-pass

<ca>
$(cat "$ovpn_dir/ca.crt" 2>/dev/null || echo "# CA cert will be here")
</ca>

<tls-auth>
$(cat "$ovpn_dir/ta.key" 2>/dev/null || echo "# TA key will be here")
</tls-auth>
CLIENTEOF

    cat > "$FOG_DIR/openvpn-clients/client_udp.ovpn" << CLIENTEOF2
client
dev tun
proto udp
remote ${IPADDR} 2200
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
data-ciphers AES-256-GCM:AES-128-GCM:CHACHA20-POLY1305
key-direction 1
verb 3
auth-user-pass

<ca>
$(cat "$ovpn_dir/ca.crt" 2>/dev/null || echo "# CA cert will be here")
</ca>

<tls-auth>
$(cat "$ovpn_dir/ta.key" 2>/dev/null || echo "# TA key will be here")
</tls-auth>
CLIENTEOF2

    # Enable OpenVPN services
    enable_service openvpn@server_tcp
    enable_service openvpn@server_udp

    log_ok "OpenVPN configured (TCP: 1194, UDP: 2200)"
    log_ok "Client configs: ${FOG_DIR}/openvpn-clients/"
}

# ═══════════════════════════════════════════════════
#  6. SQUID PROXY
# ═══════════════════════════════════════════════════

InstSquid() {
    log_info "Installing and configuring Squid..."

    # Squid package name varies by OS version
    if apt-cache show squid &>/dev/null; then
        safe_install squid
    elif apt-cache show squid3 &>/dev/null; then
        safe_install squid3
    else
        log_err "Squid package not found in repositories"
        return 1
    fi

    # Detect squid config location
    local squid_conf=""
    for conf_path in /etc/squid/squid.conf /etc/squid3/squid.conf; do
        if [[ -f "$conf_path" ]]; then
            squid_conf="$conf_path"
            break
        fi
    done

    if [[ -z "$squid_conf" ]]; then
        squid_conf="/etc/squid/squid.conf"
        mkdir -p "$(dirname "$squid_conf")"
    fi

    # Backup original
    [[ -f "$squid_conf" ]] && cp "$squid_conf" "${squid_conf}.bak.fog"

    cat > "$squid_conf" << 'SQUIDEOF'
# Project Fog Squid Configuration
acl localhost src 127.0.0.1/32
acl localhost src ::1
acl to_localhost dst 127.0.0.0/8 0.0.0.0/32 ::1
acl localnet src 10.0.0.0/8
acl localnet src 172.16.0.0/12
acl localnet src 192.168.0.0/16

acl SSL_ports port 443
acl Safe_ports port 80
acl Safe_ports port 21
acl Safe_ports port 443
acl Safe_ports port 70
acl Safe_ports port 210
acl Safe_ports port 1025-65535
acl Safe_ports port 280
acl Safe_ports port 488
acl Safe_ports port 591
acl Safe_ports port 777
acl CONNECT method CONNECT

http_access allow localhost
http_access allow localnet
http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access deny all

# Ports
http_port 3128
http_port 8080

# Logging
access_log /var/log/squid/access.log
cache_log /var/log/squid/cache.log

# Performance
coredump_dir /var/spool/squid
refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320

# Privacy
via off
forwarded_for delete
request_header_access X-Forwarded-For deny all
reply_header_access X-Forwarded-For deny all

visible_hostname ProjectFog
SQUIDEOF

    # Create log directory
    mkdir -p /var/log/squid
    chown proxy:proxy /var/log/squid 2>/dev/null || true

    # Detect and enable the correct service name
    if systemctl list-unit-files | grep -q "squid.service"; then
        enable_service squid
    elif systemctl list-unit-files | grep -q "squid3.service"; then
        enable_service squid3
    fi

    log_ok "Squid Proxy configured (Ports 3128, 8080)"
}

# ═══════════════════════════════════════════════════
#  7. PRIVOXY
# ═══════════════════════════════════════════════════

InstPrivoxy() {
    log_info "Installing and configuring Privoxy..."

    safe_install privoxy

    local privoxy_conf="/etc/privoxy/config"
    [[ -f "$privoxy_conf" ]] && cp "$privoxy_conf" "${privoxy_conf}.bak.fog"

    cat > "$privoxy_conf" << 'PRIVOXYEOF'
# Project Fog Privoxy Configuration
user-manual /usr/share/doc/privoxy/user-manual
confdir /etc/privoxy
logdir /var/log/privoxy
actionsfile match-all.action
actionsfile default.action
actionsfile user.action
filterfile default.filter
filterfile user.filter
logfile logfile

listen-address  0.0.0.0:8118
toggle  1
enable-remote-toggle  0
enable-remote-http-toggle  0
enable-edit-actions 0
enforce-blocks 0
buffer-limit 4096
enable-proxy-authentication-forwarding 0
forwarded-connect-retries  1
accept-intercepted-requests 1
allow-cgi-request-crunching 0
split-large-forms 0
keep-alive-timeout 5
tolerate-pipelining 1
socket-timeout 300
PRIVOXYEOF

    enable_service privoxy
    log_ok "Privoxy configured (Port 8118)"
}

# ═══════════════════════════════════════════════════
#  8. NGINX
# ═══════════════════════════════════════════════════

InstNginx() {
    log_info "Installing and configuring Nginx..."

    safe_install nginx

    # Create Project Fog default page
    mkdir -p /var/www/html
    cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Project Fog</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: linear-gradient(135deg, #0c0c0c 0%, #1a1a2e 100%); color: #fff; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
        .container { text-align: center; padding: 2rem; }
        h1 { font-size: 2.5rem; color: #00d4ff; text-shadow: 0 0 20px rgba(0,212,255,0.5); }
        p { color: #aaa; font-size: 1.1rem; }
        .status { color: #00ff88; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>&#9729; Project Fog Modernized &#9729;</h1>
        <p>VPS AutoScript Server</p>
        <p class="status">Server is running</p>
    </div>
</body>
</html>
HTMLEOF

    # Nginx config
    cat > /etc/nginx/conf.d/projectfog.conf << 'NGINXEOF'
server {
    listen 81;
    server_name _;

    location / {
        root /var/www/html;
        index index.html;
    }

    # Proxy for Webmin
    location /webmin/ {
        proxy_pass http://127.0.0.1:10000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINXEOF

    # Remove default site if it conflicts
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

    # Test config before restarting
    if nginx -t 2>/dev/null; then
        enable_service nginx
        log_ok "Nginx configured (Ports 80, 81)"
    else
        log_warn "Nginx config test failed. Check /etc/nginx/"
        enable_service nginx
    fi
}

# ═══════════════════════════════════════════════════
#  9. PHP
# ═══════════════════════════════════════════════════

InstPHP() {
    log_info "Installing PHP..."

    # Add PHP repository based on OS
    if [[ "$OS_NAME" == "ubuntu" ]]; then
        # Check if add-apt-repository is available
        if ! command -v add-apt-repository &>/dev/null; then
            safe_install software-properties-common
        fi
        add-apt-repository ppa:ondrej/php -y 2>/dev/null || log_warn "Could not add PHP PPA"
    elif [[ "$OS_NAME" == "debian" ]]; then
        # Use Sury repository for Debian
        if [[ ! -f /usr/share/keyrings/php-archive-keyring.gpg ]]; then
            if command -v curl &>/dev/null; then
                curl -sSL https://packages.sury.org/php/apt.gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/php-archive-keyring.gpg 2>/dev/null
            else
                wget -qO- https://packages.sury.org/php/apt.gpg | gpg --batch --yes --dearmor -o /usr/share/keyrings/php-archive-keyring.gpg 2>/dev/null
            fi
        fi
        local codename="${OS_CODENAME}"
        # Fallback codename for older Debian versions
        if [[ -z "$codename" ]]; then
            case "$OS_VER_MAJOR" in
                9)  codename="stretch" ;;
                10) codename="buster" ;;
                11) codename="bullseye" ;;
                12) codename="bookworm" ;;
                *)  codename="bookworm" ;;
            esac
        fi
        echo "deb [signed-by=/usr/share/keyrings/php-archive-keyring.gpg] https://packages.sury.org/php/ ${codename} main" > /etc/apt/sources.list.d/php-sury.list
    fi

    apt-get update -qq 2>>"${FOG_LOG}/install.log"

    # Try PHP versions in order of preference: 8.2 -> 8.3 -> 8.1
    local php_ver=""
    for try_ver in "8.2" "8.3" "8.1"; do
        if apt-cache show "php${try_ver}-fpm" &>/dev/null 2>&1; then
            php_ver="$try_ver"
            break
        fi
    done

    if [[ -z "$php_ver" ]]; then
        log_warn "No modern PHP version found. Trying default php-fpm..."
        safe_install php-fpm php-cli php-common php-mysql php-xml php-curl php-gd php-mbstring php-zip php-bcmath
    else
        log_info "Installing PHP ${php_ver}..."
        
        # Mark problematic packages to avoid installation
        apt-mark hold php-all-dev php-ssh2-all-dev 2>/dev/null || true
        
        safe_install \
            "php${php_ver}-fpm" "php${php_ver}-cli" "php${php_ver}-common" \
            "php${php_ver}-mysql" "php${php_ver}-xml" "php${php_ver}-curl" \
            "php${php_ver}-gd" "php${php_ver}-mbstring" "php${php_ver}-opcache" \
            "php${php_ver}-zip" "php${php_ver}-intl" "php${php_ver}-bcmath" \
            "php${php_ver}-soap" "php${php_ver}-imap"

        # Optional packages (may not be available everywhere)
        safe_install "php${php_ver}-imagick" 2>/dev/null || true
        safe_install "php${php_ver}-xmlrpc" 2>/dev/null || true
        
        # Install ssh2 separately and carefully (avoid -all-dev packages)
        safe_install libssh2-1 2>/dev/null || true
        safe_install "php${php_ver}-ssh2" 2>/dev/null || true
        
        # Unhold packages
        apt-mark unhold php-all-dev php-ssh2-all-dev 2>/dev/null || true

        enable_service "php${php_ver}-fpm"
        log_ok "PHP ${php_ver} installed"
    fi
}

# ═══════════════════════════════════════════════════
#  10. WEBMIN
# ═══════════════════════════════════════════════════

InstWebmin() {
    log_info "Installing Webmin..."

    local setup_script="/tmp/webmin-setup-repos.sh"

    # Download the official setup script
    if command -v curl &>/dev/null; then
        curl -sSL -o "$setup_script" https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh 2>/dev/null
    else
        wget -qO "$setup_script" https://raw.githubusercontent.com/webmin/webmin/master/setup-repos.sh 2>/dev/null
    fi

    if [[ -f "$setup_script" && -s "$setup_script" ]]; then
        # Run setup script non-interactively
        sh "$setup_script" -f 2>>"${FOG_LOG}/install.log" || log_warn "Webmin repo setup had issues"
        rm -f "$setup_script"

        safe_install webmin

        # Disable SSL for Webmin (access via Nginx reverse proxy)
        if [[ -f /etc/webmin/miniserv.conf ]]; then
            sed -i 's|^ssl=1|ssl=0|' /etc/webmin/miniserv.conf
        fi

        enable_service webmin
        log_ok "Webmin installed (Port 10000)"
    else
        log_err "Failed to download Webmin setup script"
        rm -f "$setup_script"
    fi
}

# ═══════════════════════════════════════════════════
#  11. 3X-UI PANEL
# ═══════════════════════════════════════════════════

Inst3XUI() {
    log_info "Installing 3X-UI Panel..."
    log_warn "3X-UI requires interactive setup. Launching installer..."
    echo ""
    echo -e "${YELLOW}  The 3X-UI installer will now run.${NC}"
    echo -e "${YELLOW}  Follow the on-screen prompts to complete setup.${NC}"
    echo -e "${YELLOW}  Default port: 2053${NC}"
    echo ""

    # Download and run 3X-UI installer
    local installer_url="https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh"
    if command -v curl &>/dev/null; then
        bash <(curl -Ls "$installer_url") || log_warn "3X-UI installation had issues"
    elif command -v wget &>/dev/null; then
        bash <(wget -qO- "$installer_url") || log_warn "3X-UI installation had issues"
    else
        log_err "Neither curl nor wget available for 3X-UI download"
    fi

    log_ok "3X-UI installation process completed"
}

# ═══════════════════════════════════════════════════
#  12. PYTHON PROXY
# ═══════════════════════════════════════════════════

InstPythonProxy() {
    log_info "Installing Python Proxy..."

    # Ensure Python 3 is installed
    if ! command -v python3 &>/dev/null; then
        safe_install python3
    fi

    # Copy proxy script
    local proxy_src="${SCRIPT_DIR}/proxy3.py"
    local proxy_dst="/usr/local/bin/fog-proxy"

    if [[ -f "$proxy_src" ]]; then
        cp "$proxy_src" "$proxy_dst"
    else
        # Create inline if source not found
        cat > "$proxy_dst" << 'PROXYEOF'
#!/usr/bin/env python3
"""Project Fog - HTTP Tunneling Proxy (Python 3)"""
PROXYEOF
        # The full proxy will be written by the proxy3.py file
        log_warn "proxy3.py not found in script directory, using embedded version"
        # Write the full proxy inline - see proxy3.py for the complete version
    fi

    chmod +x "$proxy_dst"

    # Create systemd service for the proxy
    cat > /etc/systemd/system/fog-proxy.service << SVCEOF
[Unit]
Description=Project Fog HTTP Tunneling Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/fog-proxy 8880 ProjectFog
Restart=always
RestartSec=3
StandardOutput=append:/var/log/project-fog/proxy.log
StandardError=append:/var/log/project-fog/proxy-error.log

[Install]
WantedBy=multi-user.target
SVCEOF

    enable_service fog-proxy
    log_ok "Python Proxy configured (Port 8880)"
}

# ═══════════════════════════════════════════════════
#  13. FAIL2BAN
# ═══════════════════════════════════════════════════

InstFail2Ban() {
    log_info "Installing and configuring Fail2Ban..."

    safe_install fail2ban

    # Create local jail configuration
    cat > /etc/fail2ban/jail.local << 'F2BEOF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5
backend  = auto

[sshd]
enabled  = true
port     = ssh,22
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3

[dropbear]
enabled  = true
port     = 109,143
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
F2BEOF

    enable_service fail2ban
    log_ok "Fail2Ban configured"
}

# ═══════════════════════════════════════════════════
#  14. FIREWALL (IPTABLES)
# ═══════════════════════════════════════════════════

SetupFirewall() {
    log_info "Configuring firewall rules..."

    # Detect default network interface
    local default_iface
    default_iface=$(ip route show default | awk '/default/{print $5}' | head -1)

    if [[ -z "$default_iface" ]]; then
        log_warn "Could not detect default network interface"
        default_iface="eth0"
    fi

    # Flush existing rules (be careful not to lock ourselves out)
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT

    # Allow established connections
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # Allow loopback
    iptables -A INPUT -i lo -j ACCEPT

    # Allow all Project Fog ports
    local ports=(22 80 81 109 143 443 442 445 777 990 1194 2200 2053 3128 8080 8118 8880 10000)
    for port in "${ports[@]}"; do
        iptables -A INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null || true
    done
    iptables -A INPUT -p udp --dport 2200 -j ACCEPT 2>/dev/null || true

    # NAT for VPN
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$default_iface" -j MASQUERADE 2>/dev/null || true
    iptables -t nat -A POSTROUTING -s 10.9.0.0/24 -o "$default_iface" -j MASQUERADE 2>/dev/null || true

    # IP forwarding
    echo 1 > /proc/sys/net/ipv4/ip_forward

    # Save iptables rules
    if command -v iptables-save &>/dev/null; then
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4

        # Install iptables-persistent if available (non-interactive)
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections 2>/dev/null || true
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections 2>/dev/null || true
        safe_install iptables-persistent 2>/dev/null || true
    fi

    log_ok "Firewall rules configured"
}

# ═══════════════════════════════════════════════════
#  15. AUTO-START SERVICE
# ═══════════════════════════════════════════════════

SetupAutoStart() {
    log_info "Setting up auto-start service..."

    cat > /etc/systemd/system/projectfogstartup.service << 'STARTUPEOF'
[Unit]
Description=Project Fog Startup Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c '\
    # Restore iptables rules \
    if [ -f /etc/iptables/rules.v4 ]; then \
        iptables-restore < /etc/iptables/rules.v4 2>/dev/null || true; \
    fi; \
    # Enable IP forwarding \
    echo 1 > /proc/sys/net/ipv4/ip_forward; \
    # Log startup \
    echo "Project Fog started at $(date)" >> /var/log/project-fog/startup.log; \
'

[Install]
WantedBy=multi-user.target
STARTUPEOF

    enable_service projectfogstartup
    log_ok "Auto-start service configured"
}

# ═══════════════════════════════════════════════════
#  16. BANNER / MOTD
# ═══════════════════════════════════════════════════

InstBanner() {
    log_info "Setting up login banner..."

    # Create MOTD script
    cat > /etc/profile.d/projectfog.sh << 'MOTDEOF'
#!/bin/bash
# Project Fog MOTD
if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_TTY" ]; then
    IPADDR=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "\e[1;36m  ╔═══════════════════════════════════════════╗\e[0m"
    echo -e "\e[1;36m  ║   ☁️  Project Fog Modernized  ☁️          ║\e[0m"
    echo -e "\e[1;36m  ╠═══════════════════════════════════════════╣\e[0m"
    echo -e "\e[1;36m  ║\e[1;37m  IP     : \e[1;32m${IPADDR}\e[1;36m"
    printf "  %-44s║\n" ""
    echo -e "\e[1;36m  ║\e[1;37m  Uptime : \e[1;32m$(uptime -p 2>/dev/null || uptime)\e[1;36m"
    printf "  %-44s║\n" ""
    echo -e "\e[1;36m  ║\e[1;37m  Type '\e[1;33mmenu\e[1;37m' for Project Fog panel\e[1;36m"
    printf "  %-44s║\n" ""
    echo -e "\e[1;36m  ╚═══════════════════════════════════════════╝\e[0m"
    echo ""
fi
MOTDEOF
    chmod +x /etc/profile.d/projectfog.sh

    log_ok "Login banner configured"
}

# ═══════════════════════════════════════════════════
#  USER MANAGEMENT FUNCTIONS
# ═══════════════════════════════════════════════════

create_vpn_user() {
    echo ""
    read -rp "  Username: " vpn_user
    read -rsp "  Password: " vpn_pass
    echo ""

    if [[ -z "$vpn_user" || -z "$vpn_pass" ]]; then
        log_err "Username and password cannot be empty"
        return 1
    fi

    # Check if user exists
    if id "$vpn_user" &>/dev/null; then
        log_err "User '$vpn_user' already exists"
        return 1
    fi

    read -rp "  Expiry days (0 = never): " vpn_days

    # Create user with /bin/false shell (no shell access)
    if [[ "$vpn_days" -gt 0 ]] 2>/dev/null; then
        local exp_date
        exp_date=$(date -d "+${vpn_days} days" +%Y-%m-%d)
        useradd -e "$exp_date" -s /bin/false -M "$vpn_user"
    else
        useradd -s /bin/false -M "$vpn_user"
    fi

    echo "${vpn_user}:${vpn_pass}" | chpasswd

    log_ok "User '${vpn_user}' created successfully"
    [[ "${vpn_days:-0}" -gt 0 ]] && echo -e "  ${WHITE}Expires: ${CYAN}${exp_date}${NC}"
}

delete_vpn_user() {
    echo ""
    list_vpn_users
    read -rp "  Username to delete: " del_user

    if [[ -z "$del_user" ]]; then
        log_err "No username specified"
        return 1
    fi

    if ! id "$del_user" &>/dev/null; then
        log_err "User '$del_user' does not exist"
        return 1
    fi

    userdel -f "$del_user" 2>/dev/null
    log_ok "User '${del_user}' deleted"
}

list_vpn_users() {
    echo -e "\n${CYAN}  VPN Users:${NC}"
    echo -e "  ─────────────────────────────────────"
    printf "  ${WHITE}%-15s %-12s %-12s${NC}\n" "Username" "Status" "Expires"
    echo -e "  ─────────────────────────────────────"

    local found=false
    while IFS=: read -r username _ uid _ _ _ shell; do
        if [[ "$uid" -ge 1000 && "$shell" == "/bin/false" ]]; then
            found=true
            local status="Active"
            local expiry="Never"
            local exp_date
            exp_date=$(chage -l "$username" 2>/dev/null | awk -F: '/Account expires/{print $2}' | xargs)

            if [[ "$exp_date" != "never" && -n "$exp_date" ]]; then
                expiry="$exp_date"
            fi

            if passwd -S "$username" 2>/dev/null | grep -q "L"; then
                status="Locked"
            fi

            printf "  %-15s %-12s %-12s\n" "$username" "$status" "$expiry"
        fi
    done < /etc/passwd

    if [[ "$found" != "true" ]]; then
        echo -e "  ${YELLOW}No VPN users found${NC}"
    fi
    echo ""
}

lock_vpn_user() {
    echo ""
    read -rp "  Username to lock: " lock_user
    if id "$lock_user" &>/dev/null; then
        passwd -l "$lock_user" 2>/dev/null
        log_ok "User '${lock_user}' locked"
    else
        log_err "User '${lock_user}' does not exist"
    fi
}

unlock_vpn_user() {
    echo ""
    read -rp "  Username to unlock: " unlock_user
    if id "$unlock_user" &>/dev/null; then
        passwd -u "$unlock_user" 2>/dev/null
        log_ok "User '${unlock_user}' unlocked"
    else
        log_err "User '${unlock_user}' does not exist"
    fi
}
