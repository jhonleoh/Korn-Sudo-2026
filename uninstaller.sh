#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#    ░▒▓█  ☁️  Project Fog Modernized Uninstaller  ☁️  █▓▒░
#    Complete removal of all Project Fog components
# ═══════════════════════════════════════════════════════════════════

# Colors
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
NC='\e[0m'

# Root check
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root."
    exit 1
fi

echo ""
echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
echo -e "${RED}       ☁️  Project Fog Uninstaller  ☁️${NC}"
echo -e "${RED}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}This will remove ALL Project Fog components including:${NC}"
echo -e "  - Dropbear, Stunnel, OpenVPN"
echo -e "  - Squid, Privoxy, Nginx"
echo -e "  - Webmin, 3X-UI Panel"
echo -e "  - Python Proxy, Fail2Ban rules"
echo -e "  - All configuration files and certificates"
echo -e "  - All VPN user accounts"
echo ""
echo -e "${RED}WARNING: This action cannot be undone!${NC}"
echo ""
read -rp "Are you sure you want to continue? (yes/N): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo -e "${GREEN}Uninstallation cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}[1/7]${NC} Stopping services..."

# Stop all services safely (check if they exist first)
services_to_stop=(
    "dropbear"
    "stunnel4"
    "openvpn@server_tcp"
    "openvpn@server_udp"
    "openvpn"
    "squid"
    "squid3"
    "privoxy"
    "nginx"
    "webmin"
    "x-ui"
    "fog-proxy"
    "projectfogstartup"
    "fail2ban"
)

for svc in "${services_to_stop[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        systemctl stop "$svc" 2>/dev/null && echo -e "  ${GREEN}Stopped${NC} $svc" || echo -e "  ${YELLOW}Could not stop${NC} $svc"
    fi
    systemctl disable "$svc" 2>/dev/null || true
done

echo ""
echo -e "${CYAN}[2/7]${NC} Removing packages..."

# Remove packages
packages_to_remove=(
    "dropbear"
    "stunnel4"
    "openvpn"
    "easy-rsa"
    "squid"
    "squid3"
    "privoxy"
    "webmin"
)

for pkg in "${packages_to_remove[@]}"; do
    if dpkg -l "$pkg" &>/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get purge -y "$pkg" 2>/dev/null && \
            echo -e "  ${GREEN}Removed${NC} $pkg" || echo -e "  ${YELLOW}Could not remove${NC} $pkg"
    fi
done

# Remove 3X-UI if installed
if command -v x-ui &>/dev/null || [[ -f /usr/bin/x-ui ]]; then
    echo -e "  Removing 3X-UI..."
    x-ui uninstall 2>/dev/null || true
    rm -f /usr/bin/x-ui /usr/local/x-ui 2>/dev/null || true
fi

echo ""
echo -e "${CYAN}[3/7]${NC} Removing PHP packages..."

# Remove PHP packages
for ver in "8.1" "8.2" "8.3"; do
    if dpkg -l "php${ver}-fpm" &>/dev/null 2>&1; then
        DEBIAN_FRONTEND=noninteractive apt-get purge -y "php${ver}-*" 2>/dev/null || true
        echo -e "  ${GREEN}Removed${NC} PHP ${ver}"
    fi
done

echo ""
echo -e "${CYAN}[4/7]${NC} Cleaning up configuration files..."

# Remove configuration directories
dirs_to_remove=(
    "/etc/project-fog"
    "/etc/openvpn"
    "/etc/dropbear"
    "/etc/stunnel"
    "/var/log/project-fog"
    "/var/log/openvpn"
)

for dir in "${dirs_to_remove[@]}"; do
    if [[ -d "$dir" ]]; then
        rm -rf "$dir"
        echo -e "  ${GREEN}Removed${NC} $dir"
    fi
done

# Remove specific files
files_to_remove=(
    "/usr/local/bin/fog-proxy"
    "/usr/local/sbin/menu"
    "/etc/systemd/system/fog-proxy.service"
    "/etc/systemd/system/projectfogstartup.service"
    "/etc/profile.d/projectfog.sh"
    "/etc/nginx/conf.d/projectfog.conf"
    "/etc/fail2ban/jail.local"
    "/etc/apt/sources.list.d/php-sury.list"
    "/usr/share/keyrings/php-archive-keyring.gpg"
)

for f in "${files_to_remove[@]}"; do
    if [[ -f "$f" ]]; then
        rm -f "$f"
        echo -e "  ${GREEN}Removed${NC} $f"
    fi
done

echo ""
echo -e "${CYAN}[5/7]${NC} Removing VPN user accounts..."

# Remove VPN users (users with /bin/false shell and UID >= 1000)
while IFS=: read -r username _ uid _ _ _ shell; do
    if [[ "$uid" -ge 1000 && "$shell" == "/bin/false" ]]; then
        userdel -f "$username" 2>/dev/null
        echo -e "  ${GREEN}Removed user${NC} $username"
    fi
done < /etc/passwd

echo ""
echo -e "${CYAN}[6/7]${NC} Cleaning up system..."

# Clean up iptables rules for VPN
iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -j MASQUERADE 2>/dev/null || true
iptables -t nat -D POSTROUTING -s 10.9.0.0/24 -j MASQUERADE 2>/dev/null || true

# Remove saved iptables rules
rm -f /etc/iptables/rules.v4 2>/dev/null || true

# Auto-remove orphaned packages
apt-get autoremove -y 2>/dev/null || true
apt-get autoclean -y 2>/dev/null || true

# Reload systemd
systemctl daemon-reload 2>/dev/null || true

echo ""
echo -e "${CYAN}[7/7]${NC} Restoring defaults..."

# Restore SSH config if backup exists
if [[ -f /etc/ssh/sshd_config.bak.fog ]]; then
    cp /etc/ssh/sshd_config.bak.fog /etc/ssh/sshd_config
    systemctl restart sshd 2>/dev/null || true
    echo -e "  ${GREEN}Restored${NC} SSH configuration"
fi

# Restore Squid config if backup exists
for conf in /etc/squid/squid.conf.bak.fog /etc/squid3/squid.conf.bak.fog; do
    if [[ -f "$conf" ]]; then
        cp "$conf" "${conf%.bak.fog}"
        echo -e "  ${GREEN}Restored${NC} Squid configuration"
    fi
done

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ☁️  Project Fog has been completely uninstalled  ☁️${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Offer reboot
read -rp "Reboot now to complete cleanup? (y/N): " reboot_choice
if [[ "$reboot_choice" =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}Rebooting in 5 seconds...${NC}"
    sleep 5
    reboot
fi
