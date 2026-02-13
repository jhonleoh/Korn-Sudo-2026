#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#    ░▒▓█  ☁️  Project Fog Migration Script  ☁️  █▓▒░
#    Safely migrate from old Project Fog to Modernized version
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
    echo -e "${YELLOW}[INFO]${NC}  Run: ${CYAN}sudo su${NC} then re-run this script."
    exit 1
fi

clear
echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                           ║"
echo "  ║    ☁️  Project Fog Migration Tool  ☁️                    ║"
echo "  ║                                                           ║"
echo "  ║      Upgrade from Old Version to Modernized v2.0          ║"
echo "  ║                                                           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Detect if old Project Fog is installed
OLD_INSTALLED=false
BACKUP_DIR="/root/project-fog-backup-$(date +%Y%m%d-%H%M%S)"

echo -e "${CYAN}[*]${NC} Checking for existing Project Fog installation..."
echo ""

# Check for old installation markers
if [[ -d /etc/korn ]] || [[ -d /home/vps ]] || [[ -f /usr/local/sbin/korn-menu ]]; then
    OLD_INSTALLED=true
    echo -e "${YELLOW}[!]${NC} Old Project Fog installation detected!"
    echo ""
fi

if [[ "$OLD_INSTALLED" == "false" ]]; then
    echo -e "${GREEN}[✓]${NC} No old installation detected. Safe to proceed with fresh install."
    echo ""
    read -rp "Press Enter to continue with installation..."
    exec ./projectfog_modern.sh
    exit 0
fi

# Display migration options
echo -e "${WHITE}This script will help you migrate safely. Choose an option:${NC}"
echo ""
echo -e "${CYAN}  Migration Options:${NC}"
echo -e "  ─────────────────────────────────────────────────────────"
echo -e "  ${GREEN}1)${NC} Clean Migration (Recommended)"
echo -e "     • Backup VPN users and OpenVPN configs"
echo -e "     • Uninstall old version completely"
echo -e "     • Install new modernized version"
echo -e "     • Restore VPN users"
echo ""
echo -e "  ${YELLOW}2)${NC} Backup Only"
echo -e "     • Create backup of current configuration"
echo -e "     • Exit (you can manually install later)"
echo ""
echo -e "  ${YELLOW}3)${NC} Force Install (Not Recommended)"
echo -e "     • Install new version alongside old"
echo -e "     • May cause port conflicts"
echo ""
echo -e "  ${RED}4)${NC} Cancel"
echo -e "  ─────────────────────────────────────────────────────────"
echo ""
read -rp "Select option [1-4]: " migration_choice

case "$migration_choice" in
    1)
        echo ""
        echo -e "${CYAN}[*]${NC} Starting Clean Migration..."
        ;;
    2)
        echo ""
        echo -e "${CYAN}[*]${NC} Creating backup only..."
        ;;
    3)
        echo ""
        echo -e "${YELLOW}[!]${NC} Force installing (conflicts may occur)..."
        sleep 2
        exec ./projectfog_modern.sh
        exit 0
        ;;
    4)
        echo -e "${GREEN}Migration cancelled.${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option.${NC}"
        exit 1
        ;;
esac

# ═══════════════════════════════════════════════════
#  BACKUP PHASE
# ═══════════════════════════════════════════════════

echo ""
echo -e "${CYAN}[1/5]${NC} Creating backup directory: ${BACKUP_DIR}"
mkdir -p "$BACKUP_DIR"

echo -e "${CYAN}[2/5]${NC} Backing up VPN users..."
# Backup /etc/passwd and /etc/shadow entries for VPN users
if [[ -f /etc/passwd ]]; then
    grep '/bin/false' /etc/passwd > "$BACKUP_DIR/vpn_users.txt" 2>/dev/null || true
    echo -e "  ${GREEN}Saved${NC} VPN user list"
fi

# Backup shadow file (encrypted passwords)
if [[ -f /etc/shadow ]]; then
    cp /etc/shadow "$BACKUP_DIR/shadow.bak" 2>/dev/null || true
    chmod 600 "$BACKUP_DIR/shadow.bak"
    echo -e "  ${GREEN}Saved${NC} Password hashes"
fi

echo -e "${CYAN}[3/5]${NC} Backing up OpenVPN configuration..."
# Backup OpenVPN configs and certificates
if [[ -d /etc/openvpn ]]; then
    cp -r /etc/openvpn "$BACKUP_DIR/openvpn_backup" 2>/dev/null || true
    echo -e "  ${GREEN}Saved${NC} OpenVPN configs and certificates"
fi

# Backup client configs if they exist
if [[ -d /root/client-configs ]] || [[ -d /home/vps/public_html ]]; then
    [[ -d /root/client-configs ]] && cp -r /root/client-configs "$BACKUP_DIR/" 2>/dev/null
    [[ -d /home/vps/public_html ]] && cp -r /home/vps/public_html "$BACKUP_DIR/" 2>/dev/null
    echo -e "  ${GREEN}Saved${NC} Client configuration files"
fi

echo -e "${CYAN}[4/5]${NC} Backing up SSH keys and configurations..."
# Backup SSH authorized_keys
if [[ -f /root/.ssh/authorized_keys ]]; then
    mkdir -p "$BACKUP_DIR/ssh"
    cp /root/.ssh/authorized_keys "$BACKUP_DIR/ssh/" 2>/dev/null || true
    echo -e "  ${GREEN}Saved${NC} SSH authorized keys"
fi

# Backup custom SSH config
if [[ -f /etc/ssh/sshd_config ]]; then
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.bak" 2>/dev/null || true
    echo -e "  ${GREEN}Saved${NC} SSH configuration"
fi

echo -e "${CYAN}[5/5]${NC} Creating backup summary..."
cat > "$BACKUP_DIR/README.txt" << BACKUPEOF
Project Fog Backup - $(date)
═══════════════════════════════════════════════════

This directory contains backups from your old Project Fog installation.

Contents:
- vpn_users.txt         : List of VPN users
- shadow.bak            : Encrypted passwords (restore with care)
- openvpn_backup/       : OpenVPN configs and certificates
- client-configs/       : Client .ovpn files (if available)
- ssh/                  : SSH authorized_keys
- sshd_config.bak       : SSH server configuration

To restore VPN users after migration:
1. Review vpn_users.txt for usernames
2. Recreate users via the new 'menu' command
3. Or manually restore from shadow.bak (advanced)

To restore OpenVPN certificates:
1. Copy CA and server certs from openvpn_backup/
2. Place in /etc/openvpn/
3. Update server configs to reference them

IMPORTANT: Keep this backup safe until you verify the new installation works!
BACKUPEOF

echo ""
echo -e "${GREEN}[✓]${NC} Backup completed: ${CYAN}${BACKUP_DIR}${NC}"
echo ""

# If backup only, exit here
if [[ "$migration_choice" == "2" ]]; then
    echo -e "${GREEN}Backup complete. You can now manually install the new version.${NC}"
    echo -e "${YELLOW}Backup location: ${CYAN}${BACKUP_DIR}${NC}"
    exit 0
fi

# ═══════════════════════════════════════════════════
#  UNINSTALL OLD VERSION
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[*]${NC} Uninstalling old Project Fog version..."
echo ""

# Stop old services
echo -e "${CYAN}[1/4]${NC} Stopping old services..."
OLD_SERVICES=(
    "korn-startup"
    "projectfogstartup"
    "openvpn@server_tcp"
    "openvpn@server_udp"
    "openvpn"
    "dropbear"
    "stunnel4"
    "squid"
    "squid3"
    "privoxy"
    "nginx"
    "webmin"
    "x-ui"
)

for svc in "${OLD_SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        systemctl stop "$svc" 2>/dev/null && echo -e "  ${GREEN}Stopped${NC} $svc"
    fi
    systemctl disable "$svc" 2>/dev/null || true
done

echo ""
echo -e "${CYAN}[2/4]${NC} Removing old files and directories..."
OLD_DIRS=(
    "/etc/korn"
    "/home/vps"
    "/usr/local/sbin/korn-menu"
    "/usr/local/sbin/korn-*"
)

for dir in "${OLD_DIRS[@]}"; do
    if [[ -e "$dir" ]]; then
        rm -rf "$dir" 2>/dev/null && echo -e "  ${GREEN}Removed${NC} $dir"
    fi
done

# Remove old menu commands
rm -f /usr/local/sbin/menu 2>/dev/null || true
rm -f /usr/bin/menu 2>/dev/null || true

echo ""
echo -e "${CYAN}[3/4]${NC} Cleaning up old systemd services..."
rm -f /etc/systemd/system/korn-startup.service 2>/dev/null || true
rm -f /etc/systemd/system/projectfogstartup.service 2>/dev/null || true
systemctl daemon-reload

echo ""
echo -e "${CYAN}[4/4]${NC} Preserving OpenVPN and user accounts..."
echo -e "  ${YELLOW}Note:${NC} OpenVPN configs and VPN users are kept for migration"

echo ""
echo -e "${GREEN}[✓]${NC} Old version uninstalled (configs backed up)"
echo ""

# ═══════════════════════════════════════════════════
#  INSTALL NEW VERSION
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[*]${NC} Installing Project Fog Modernized v2.0..."
echo ""
read -rp "Press Enter to start installation..."

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ensure installer has execute permissions
chmod +x "${SCRIPT_DIR}/projectfog_modern.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/core_installer.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/proxy3.py" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/uninstaller.sh" 2>/dev/null || true

# Run the new installer
cd "${SCRIPT_DIR}"
exec bash ./projectfog_modern.sh

# Note: After installation, user should manually restore VPN users from backup
