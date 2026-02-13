#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#    ░▒▓█  ☁️  Project Fog Universal Modernized  ☁️  █▓▒░
#              Compatible with Ubuntu & Debian
#              Ubuntu: 18.04, 20.04, 22.04, 24.04
#              Debian: 9, 10, 11, 12
# ═══════════════════════════════════════════════════════════════════

# ----- Strict Mode & Error Handling -----
set -euo pipefail
trap 'echo -e "\n\e[1;31m[ERROR]\e[0m An error occurred at line $LINENO. Exiting."; exit 1' ERR

# ----- Color Definitions -----
RED='\e[1;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
MAGENTA='\e[1;35m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'
NC='\e[0m'

# ----- Script Directory Detection -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ----- Root Check -----
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} This script must be run as root."
    echo -e "${YELLOW}[INFO]${NC}  Run: ${CYAN}sudo su${NC} then re-run this script."
    exit 1
fi

# ----- OS Detection (compatible with all Debian/Ubuntu) -----
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        echo -e "${RED}[ERROR]${NC} Cannot detect OS. /etc/os-release not found."
        exit 1
    fi

    # Use awk instead of grep -P for maximum compatibility
    OS_NAME=$(awk -F= '/^ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_VER=$(awk -F= '/^VERSION_ID=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_CODENAME=$(awk -F= '/^VERSION_CODENAME=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_PRETTY=$(awk -F= '/^PRETTY_NAME=/{gsub(/"/, "", $2); print $2}' /etc/os-release)
    OS_VER_MAJOR="${OS_VER%%.*}"

    export OS_NAME OS_VER OS_CODENAME OS_PRETTY OS_VER_MAJOR
}

# ----- OS Validation -----
validate_os() {
    local supported=false

    case "$OS_NAME" in
        ubuntu)
            case "$OS_VER_MAJOR" in
                18|20|22|24) supported=true ;;
            esac
            ;;
        debian)
            case "$OS_VER_MAJOR" in
                9|10|11|12) supported=true ;;
            esac
            ;;
    esac

    if [[ "$supported" != "true" ]]; then
        echo -e "${RED}[ERROR]${NC} Unsupported OS: ${OS_PRETTY:-$OS_NAME $OS_VER}"
        echo -e "${YELLOW}[INFO]${NC}  Supported: Ubuntu 18/20/22/24, Debian 9/10/11/12"
        echo ""
        read -rp "Continue anyway? (y/N): " choice
        if [[ ! "$choice" =~ ^[Yy]$ ]]; then
            exit 1
        fi
        echo -e "${YELLOW}[WARN]${NC} Proceeding on unsupported OS. Some features may not work."
    fi
}

# ----- Pre-flight Checks -----
preflight_checks() {
    echo -e "${CYAN}[*]${NC} Running pre-flight checks..."

    # Check internet connectivity
    local has_internet=false
    for test_host in "google.com" "cloudflare.com" "github.com"; do
        if ping -c 1 -W 3 "$test_host" &>/dev/null; then
            has_internet=true
            break
        fi
    done

    if [[ "$has_internet" != "true" ]]; then
        echo -e "${RED}[ERROR]${NC} No internet connectivity detected."
        exit 1
    fi
    echo -e "${GREEN}[✓]${NC} Internet connectivity OK"

    # Ensure basic tools exist (wget or curl needed)
    if ! command -v wget &>/dev/null && ! command -v curl &>/dev/null; then
        echo -e "${YELLOW}[WARN]${NC} Neither wget nor curl found. Installing curl..."
        apt-get update -qq && apt-get install -y -qq curl
    fi

    # Detect public IP with multiple fallbacks and timeout
    IPADDR=""
    local ip_services=("https://api.ipify.org" "https://ifconfig.me" "https://icanhazip.com" "https://ipecho.net/plain")
    for svc in "${ip_services[@]}"; do
        if command -v curl &>/dev/null; then
            IPADDR=$(curl -s --max-time 5 "$svc" 2>/dev/null) && break
        elif command -v wget &>/dev/null; then
            IPADDR=$(wget -qO- --timeout=5 "$svc" 2>/dev/null) && break
        fi
    done

    if [[ -z "$IPADDR" ]]; then
        echo -e "${YELLOW}[WARN]${NC} Could not detect public IP. Some features may not work."
        IPADDR="UNKNOWN"
    fi
    export IPADDR
    echo -e "${GREEN}[✓]${NC} Public IP: ${CYAN}${IPADDR}${NC}"

    # Check available disk space (need at least 1GB)
    local avail_mb
    avail_mb=$(df / --output=avail -BM | tail -1 | tr -d 'M ')
    if [[ "$avail_mb" -lt 1024 ]]; then
        echo -e "${YELLOW}[WARN]${NC} Low disk space: ${avail_mb}MB available (recommended: 1GB+)"
    else
        echo -e "${GREEN}[✓]${NC} Disk space: ${avail_mb}MB available"
    fi

    echo -e "${GREEN}[✓]${NC} Pre-flight checks passed"
    echo ""
}

# ----- Banner -----
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "  ╔═══════════════════════════════════════════════════════════╗"
    echo "  ║                                                           ║"
    echo "  ║       ░▒▓█  ☁️  Project Fog Modernized  ☁️  █▓▒░        ║"
    echo "  ║                                                           ║"
    echo "  ║          Universal VPS AutoScript Installer               ║"
    echo "  ║                                                           ║"
    echo "  ╠═══════════════════════════════════════════════════════════╣"
    echo -e "  ║  ${WHITE}OS      : ${GREEN}${OS_PRETTY:-$OS_NAME $OS_VER}${CYAN}"
    printf "  %-60s║\n" ""
    echo -e "  ║  ${WHITE}IP      : ${GREEN}${IPADDR}${CYAN}"
    printf "  %-60s║\n" ""
    echo -e "  ║  ${WHITE}Kernel  : ${GREEN}$(uname -r)${CYAN}"
    printf "  %-60s║\n" ""
    echo -e "  ║  ${WHITE}RAM     : ${GREEN}$(free -m | awk '/Mem:/{print $2}')MB${CYAN}"
    printf "  %-60s║\n" ""
    echo -e "  ${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ----- Main Menu -----
show_menu() {
    echo -e "${WHITE}  ┌─────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │${CYAN}         INSTALLATION OPTIONS                 ${WHITE}│${NC}"
    echo -e "${WHITE}  ├─────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │  ${GREEN}1)${NC} Full Installation (All Services)        ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}2)${NC} Core Only (SSH + Dropbear + Stunnel)    ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}3)${NC} VPN Only (OpenVPN + Proxy)              ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}4)${NC} Web Panel (Webmin + 3X-UI)              ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}5)${NC} Custom Installation                     ${WHITE}│${NC}"
    echo -e "${WHITE}  ├─────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │  ${YELLOW}6)${NC} System Information                      ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${YELLOW}7)${NC} User Management                         ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${RED}8)${NC} Uninstall Project Fog                   ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${RED}0)${NC} Exit                                    ${WHITE}│${NC}"
    echo -e "${WHITE}  └─────────────────────────────────────────────┘${NC}"
    echo ""
}

# ----- Custom Installation Menu -----
show_custom_menu() {
    echo -e "${WHITE}  ┌─────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │${CYAN}         CUSTOM INSTALLATION                  ${WHITE}│${NC}"
    echo -e "${WHITE}  ├─────────────────────────────────────────────┤${NC}"
    echo -e "${WHITE}  │  ${GREEN}1)${NC} System Updates & Dependencies            ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}2)${NC} SSH & Dropbear                           ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}3)${NC} Stunnel (SSL Tunnel)                     ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}4)${NC} OpenVPN (TCP + UDP)                      ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}5)${NC} Squid Proxy                              ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}6)${NC} Privoxy                                  ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}7)${NC} Nginx Reverse Proxy                      ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}8)${NC} PHP (8.x)                                ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}9)${NC} Webmin                                   ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}10)${NC} 3X-UI Panel                             ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}11)${NC} Python Proxy                            ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}12)${NC} Fail2Ban (Security)                     ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${GREEN}13)${NC} Firewall (iptables rules)               ${WHITE}│${NC}"
    echo -e "${WHITE}  │  ${RED}0)${NC}  Back to Main Menu                       ${WHITE}│${NC}"
    echo -e "${WHITE}  └─────────────────────────────────────────────┘${NC}"
    echo ""
}

# ----- System Info -----
show_sysinfo() {
    echo -e "\n${CYAN}═══════════ System Information ═══════════${NC}"
    echo -e "${WHITE}OS          :${NC} ${OS_PRETTY:-$OS_NAME $OS_VER}"
    echo -e "${WHITE}Kernel      :${NC} $(uname -r)"
    echo -e "${WHITE}Architecture:${NC} $(uname -m)"
    echo -e "${WHITE}Hostname    :${NC} $(hostname)"
    echo -e "${WHITE}Public IP   :${NC} ${IPADDR}"
    echo -e "${WHITE}Total RAM   :${NC} $(free -m | awk '/Mem:/{print $2}')MB"
    echo -e "${WHITE}Used RAM    :${NC} $(free -m | awk '/Mem:/{print $3}')MB"
    echo -e "${WHITE}Disk Used   :${NC} $(df -h / | awk 'NR==2{print $3 "/" $2 " (" $5 ")"}')"
    echo -e "${WHITE}Uptime      :${NC} $(uptime -p 2>/dev/null || uptime)"
    echo -e "${WHITE}CPU Cores   :${NC} $(nproc)"
    echo -e "${WHITE}Load Avg    :${NC} $(cat /proc/loadavg | awk '{print $1, $2, $3}')"
    echo ""

    echo -e "${CYAN}═══════════ Service Status ═══════════${NC}"
    local services=("sshd:SSH" "dropbear:Dropbear" "stunnel4:Stunnel" "openvpn:OpenVPN" "squid:Squid" "privoxy:Privoxy" "nginx:Nginx" "webmin:Webmin" "x-ui:3X-UI" "fail2ban:Fail2Ban")
    for svc_pair in "${services[@]}"; do
        local svc_name="${svc_pair%%:*}"
        local svc_label="${svc_pair##*:}"
        if systemctl is-active --quiet "$svc_name" 2>/dev/null; then
            printf "  ${GREEN}●${NC} %-15s ${GREEN}Running${NC}\n" "$svc_label"
        elif systemctl is-enabled --quiet "$svc_name" 2>/dev/null; then
            printf "  ${YELLOW}●${NC} %-15s ${YELLOW}Stopped${NC}\n" "$svc_label"
        else
            printf "  ${RED}●${NC} %-15s ${RED}Not Installed${NC}\n" "$svc_label"
        fi
    done
    echo ""

    echo -e "${CYAN}═══════════ Port Usage ═══════════${NC}"
    echo -e "${WHITE}  Port    Service${NC}"
    echo -e "  ─────────────────────"
    echo -e "  22      OpenSSH"
    echo -e "  109     Dropbear"
    echo -e "  143     Dropbear"
    echo -e "  443     Stunnel (SSL)"
    echo -e "  445     Stunnel (SSL)"
    echo -e "  777     Stunnel (SSL)"
    echo -e "  1194    OpenVPN TCP"
    echo -e "  2200    OpenVPN UDP"
    echo -e "  3128    Squid Proxy"
    echo -e "  8080    Squid Proxy"
    echo -e "  8118    Privoxy"
    echo -e "  80      Nginx"
    echo -e "  8880    Python Proxy"
    echo -e "  10000   Webmin"
    echo -e "  2053    3X-UI Panel"
    echo ""
}

# ----- Source Core Installer -----
source_core() {
    local core_file="${SCRIPT_DIR}/core_installer.sh"
    if [[ ! -f "$core_file" ]]; then
        echo -e "${RED}[ERROR]${NC} Core installer not found: ${core_file}"
        echo -e "${YELLOW}[INFO]${NC}  Ensure core_installer.sh is in the same directory as this script."
        exit 1
    fi
    # shellcheck source=core_installer.sh
    source "$core_file"
}

# ----- User Management -----
user_management_menu() {
    while true; do
        echo -e "\n${CYAN}═══════════ User Management ═══════════${NC}"
        echo -e "  ${GREEN}1)${NC} Create VPN User"
        echo -e "  ${GREEN}2)${NC} Delete VPN User"
        echo -e "  ${GREEN}3)${NC} List VPN Users"
        echo -e "  ${GREEN}4)${NC} Lock VPN User"
        echo -e "  ${GREEN}5)${NC} Unlock VPN User"
        echo -e "  ${RED}0)${NC} Back"
        echo ""
        read -rp "  Select option: " uchoice
        case "$uchoice" in
            1) create_vpn_user ;;
            2) delete_vpn_user ;;
            3) list_vpn_users ;;
            4) lock_vpn_user ;;
            5) unlock_vpn_user ;;
            0) return ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
    done
}

# ----- Full Installation -----
full_install() {
    echo -e "\n${CYAN}[*]${NC} Starting Full Installation..."
    echo -e "${YELLOW}[!]${NC} This will install ALL services. Continue? (y/N)"
    read -rp "  > " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}[*]${NC} Installation cancelled."
        return
    fi

    local start_time
    start_time=$(date +%s)

    InstUpdates
    InstSSH
    InstDropbear
    InstStunnel
    InstOpenVPN
    InstSquid
    InstPrivoxy
    InstNginx
    InstPHP
    InstWebmin
    Inst3XUI
    InstPythonProxy
    InstFail2Ban
    SetupFirewall
    SetupAutoStart
    InstBanner

    local end_time elapsed
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  ☁️  Project Fog Installation Complete!  ☁️${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════${NC}"
    echo -e "  ${WHITE}Time elapsed: ${CYAN}$((elapsed / 60))m $((elapsed % 60))s${NC}"
    echo -e "  ${WHITE}Server IP   : ${CYAN}${IPADDR}${NC}"
    echo ""
    echo -e "  ${WHITE}Access Menu : ${CYAN}menu${NC} (or run this script again)"
    echo ""
    show_sysinfo
}

# ----- Core Only Installation -----
core_install() {
    echo -e "\n${CYAN}[*]${NC} Starting Core Installation (SSH + Dropbear + Stunnel)..."
    InstUpdates
    InstSSH
    InstDropbear
    InstStunnel
    InstFail2Ban
    SetupFirewall
    SetupAutoStart
    InstBanner
    echo -e "${GREEN}[✓]${NC} Core installation complete!"
}

# ----- VPN Only Installation -----
vpn_install() {
    echo -e "\n${CYAN}[*]${NC} Starting VPN Installation (OpenVPN + Proxy)..."
    InstUpdates
    InstOpenVPN
    InstSquid
    InstPrivoxy
    InstPythonProxy
    SetupFirewall
    SetupAutoStart
    echo -e "${GREEN}[✓]${NC} VPN installation complete!"
}

# ----- Web Panel Installation -----
panel_install() {
    echo -e "\n${CYAN}[*]${NC} Starting Web Panel Installation (Webmin + 3X-UI)..."
    InstUpdates
    InstNginx
    InstPHP
    InstWebmin
    Inst3XUI
    echo -e "${GREEN}[✓]${NC} Web Panel installation complete!"
}

# ----- Custom Installation Handler -----
custom_install() {
    while true; do
        show_custom_menu
        read -rp "  Select option: " cchoice
        case "$cchoice" in
            1)  InstUpdates ;;
            2)  InstSSH; InstDropbear ;;
            3)  InstStunnel ;;
            4)  InstOpenVPN ;;
            5)  InstSquid ;;
            6)  InstPrivoxy ;;
            7)  InstNginx ;;
            8)  InstPHP ;;
            9)  InstWebmin ;;
            10) Inst3XUI ;;
            11) InstPythonProxy ;;
            12) InstFail2Ban ;;
            13) SetupFirewall ;;
            0)  return ;;
            *)  echo -e "${RED}Invalid option${NC}" ;;
        esac
        echo ""
        echo -e "${GREEN}[✓]${NC} Done. Press Enter to continue..."
        read -r
    done
}

# ----- Uninstall -----
run_uninstall() {
    local uninstall_file="${SCRIPT_DIR}/uninstaller.sh"
    if [[ -f "$uninstall_file" ]]; then
        bash "$uninstall_file"
    else
        echo -e "${RED}[ERROR]${NC} Uninstaller not found: ${uninstall_file}"
    fi
}

# ═══════════════════════════════════════════════════
#                    MAIN EXECUTION
# ═══════════════════════════════════════════════════

detect_os
validate_os
source_core
preflight_checks
show_banner

# Install 'menu' command globally
MENU_CMD="/usr/local/sbin/menu"
if [[ ! -f "$MENU_CMD" ]] || ! grep -q "Project Fog" "$MENU_CMD" 2>/dev/null; then
    cat > "$MENU_CMD" << MENUEOF
#!/bin/bash
# Project Fog Menu Shortcut
bash "${SCRIPT_DIR}/projectfog_modern.sh"
MENUEOF
    chmod +x "$MENU_CMD"
fi

# Main Loop
while true; do
    show_menu
    read -rp "  Select option: " choice
    case "$choice" in
        1) full_install ;;
        2) core_install ;;
        3) vpn_install ;;
        4) panel_install ;;
        5) custom_install ;;
        6) show_sysinfo ;;
        7) user_management_menu ;;
        8) run_uninstall ;;
        0)
            echo -e "\n${GREEN}Thank you for using Project Fog!${NC}"
            echo -e "${CYAN}Run '${WHITE}menu${CYAN}' anytime to return.${NC}\n"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac

    echo ""
    read -rp "  Press Enter to continue..."
    show_banner
done
