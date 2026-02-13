#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#    ░▒▓█  ☁️  Project Fog - Fix Broken Installation  ☁️  █▓▒░
#    Repairs interrupted installations and package conflicts
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

clear
echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════════════════════════╗"
echo "  ║                                                           ║"
echo "  ║       ☁️  Fix Broken Installation  ☁️                    ║"
echo "  ║                                                           ║"
echo "  ║     Repairs interrupted Project Fog installations         ║"
echo "  ║                                                           ║"
echo "  ╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${YELLOW}This script will fix common installation issues:${NC}"
echo -e "  • Broken package dependencies"
echo -e "  • Failed PHP installation"
echo -e "  • Interrupted apt operations"
echo -e "  • Locked dpkg database"
echo ""
read -rp "Press Enter to start repair process..."
echo ""

# ═══════════════════════════════════════════════════
#  STEP 1: Kill any hanging processes
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[1/8]${NC} Stopping any hanging processes..."

# Kill any hanging apt/dpkg processes
pkill -9 apt 2>/dev/null || true
pkill -9 apt-get 2>/dev/null || true
pkill -9 dpkg 2>/dev/null || true
pkill -9 unattended-upgrade 2>/dev/null || true

# Kill problematic PHP processes
pkill -9 lsphp 2>/dev/null || true
pkill -9 php-fpm 2>/dev/null || true

sleep 2
echo -e "  ${GREEN}Done${NC}"

# ═══════════════════════════════════════════════════
#  STEP 2: Remove lock files
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[2/8]${NC} Removing lock files..."

rm -f /var/lib/dpkg/lock 2>/dev/null || true
rm -f /var/lib/dpkg/lock-frontend 2>/dev/null || true
rm -f /var/lib/apt/lists/lock 2>/dev/null || true
rm -f /var/cache/apt/archives/lock 2>/dev/null || true

echo -e "  ${GREEN}Done${NC}"

# ═══════════════════════════════════════════════════
#  STEP 3: Configure pending packages
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[3/8]${NC} Configuring pending packages..."

dpkg --configure -a 2>&1 | tee /tmp/dpkg-configure.log

if grep -q "error" /tmp/dpkg-configure.log; then
    echo -e "  ${YELLOW}Some errors detected, will fix in next steps${NC}"
else
    echo -e "  ${GREEN}Done${NC}"
fi

# ═══════════════════════════════════════════════════
#  STEP 4: Remove problematic PHP packages
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[4/8]${NC} Removing problematic PHP packages..."

# Remove php-litespeed (this is the culprit - not needed for Project Fog)
DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y \
    php7.4-litespeed \
    php-all-dev \
    php-ssh2-all-dev \
    2>/dev/null || true

# Remove any broken PHP packages
DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y \
    'php7.4-*litespeed*' \
    2>/dev/null || true

echo -e "  ${GREEN}Done${NC}"

# ═══════════════════════════════════════════════════
#  STEP 5: Fix broken dependencies
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[5/8]${NC} Fixing broken dependencies..."

DEBIAN_FRONTEND=noninteractive apt-get -f install -y 2>&1 | tee /tmp/apt-fix.log

echo -e "  ${GREEN}Done${NC}"

# ═══════════════════════════════════════════════════
#  STEP 6: Clean package cache
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[6/8]${NC} Cleaning package cache..."

apt-get clean
apt-get autoclean
apt-get autoremove -y

echo -e "  ${GREEN}Done${NC}"

# ═══════════════════════════════════════════════════
#  STEP 7: Update package lists
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[7/8]${NC} Updating package lists..."

apt-get update -qq 2>&1 | tee /tmp/apt-update.log

echo -e "  ${GREEN}Done${NC}"

# ═══════════════════════════════════════════════════
#  STEP 8: Verify system health
# ═══════════════════════════════════════════════════

echo -e "${CYAN}[8/8]${NC} Verifying system health..."

# Check for any remaining broken packages
BROKEN_COUNT=$(dpkg -l | grep -c "^iU\|^iF" 2>/dev/null || echo "0")

if [[ "$BROKEN_COUNT" -gt 0 ]]; then
    echo -e "  ${YELLOW}Warning: $BROKEN_COUNT broken packages still detected${NC}"
    echo -e "  ${YELLOW}Running additional cleanup...${NC}"
    
    # Try to remove all broken packages
    dpkg -l | grep "^iU\|^iF" | awk '{print $2}' | xargs -r apt-get remove --purge -y 2>/dev/null || true
    dpkg --configure -a 2>/dev/null || true
    apt-get -f install -y 2>/dev/null || true
fi

echo -e "  ${GREEN}Done${NC}"

# ═══════════════════════════════════════════════════
#  FINAL STATUS
# ═══════════════════════════════════════════════════

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ☁️  Repair Process Complete  ☁️${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if system is healthy now
if dpkg -l | grep -q "^iU\|^iF"; then
    echo -e "${YELLOW}[!]${NC} Some package issues may remain. Check logs:"
    echo -e "    ${CYAN}cat /tmp/dpkg-configure.log${NC}"
    echo -e "    ${CYAN}cat /tmp/apt-fix.log${NC}"
    echo ""
    echo -e "${YELLOW}[!]${NC} You may need to manually remove problematic packages:"
    echo -e "    ${CYAN}dpkg -l | grep '^iU\\|^iF'${NC}"
    echo ""
else
    echo -e "${GREEN}[✓]${NC} System is healthy! All package issues resolved."
    echo ""
fi

echo -e "${WHITE}Next Steps:${NC}"
echo ""
echo -e "  ${CYAN}1)${NC} Re-run Project Fog installer:"
echo -e "     ${CYAN}./projectfog_modern.sh${NC}"
echo ""
echo -e "  ${CYAN}2)${NC} If you want to skip PHP installation this time:"
echo -e "     ${CYAN}./projectfog_modern.sh${NC}"
echo -e "     Then choose: ${YELLOW}5) Custom Installation${NC}"
echo -e "     And skip option 8 (PHP)"
echo ""
echo -e "  ${CYAN}3)${NC} Or install PHP manually later:"
echo -e "     ${CYAN}menu → 5) Custom Installation → 8) PHP${NC}"
echo ""

echo -e "${YELLOW}Note:${NC} The PHP-LiteSpeed package caused the issue. Project Fog"
echo -e "      will now install standard PHP-FPM instead, which is more reliable."
echo ""
