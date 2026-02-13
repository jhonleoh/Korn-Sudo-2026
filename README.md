# ☁️ Project Fog Modernized - VPS AutoScript ☁️

**Version:** 2.0  
**Author:** Modernized by Leo
**License:** Unlicense (Public Domain)

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [System Requirements](#system-requirements)
- [Installation Guide](#installation-guide)
- [Post-Installation](#post-installation)
- [Service Details](#service-details)
- [Port Reference](#port-reference)
- [User Management](#user-management)
- [Uninstallation](#uninstallation)
- [Troubleshooting](#troubleshooting)
- [Security Recommendations](#security-recommendations)
- [Changelog](#changelog)
- [Credits](#credits)

---

## 🌟 Overview

**Project Fog Modernized** is a comprehensive, production-ready VPS autoscript designed for Ubuntu and Debian systems. It automates the installation and configuration of essential tunneling, proxy, and VPN services, transforming a fresh VPS into a fully functional, secure server in minutes.

This modernized version has been completely rewritten from the ground up to fix critical bugs, ensure cross-version compatibility, and add professional-grade features including an interactive menu system, user management, and comprehensive security configurations.

### What Makes This Version Different?

- ✅ **Fully Functional** - All services are properly configured (not just installed)
- ✅ **Cross-Compatible** - Works on Debian 9-12 and Ubuntu 18.04-24.04
- ✅ **Interactive Menu** - User-friendly TUI for installation and management
- ✅ **Production Ready** - Includes error handling, logging, and security hardening
- ✅ **Well Documented** - Complete guides and inline documentation

---

## 🚀 Features

### Core Services

| Service | Description | Ports |
|---------|-------------|-------|
| **OpenSSH** | Secure Shell access with optimized configuration | 22 |
| **Dropbear** | Lightweight SSH server for tunneling | 109, 143 |
| **Stunnel** | SSL/TLS tunnel for encrypted connections | 443, 445, 777, 990, 442 |
| **OpenVPN** | Full VPN server (TCP + UDP) with Easy-RSA PKI | 1194 (TCP), 2200 (UDP) |
| **Squid** | High-performance HTTP/HTTPS proxy | 3128, 8080 |
| **Privoxy** | Privacy-focused web proxy | 8118 |
| **Nginx** | Reverse proxy and web server | 80, 81 |
| **Webmin** | Web-based system administration panel | 10000 |
| **3X-UI** | Modern V2Ray/Xray management panel | 2053 |
| **Python Proxy** | Custom HTTP tunneling proxy with CONNECT support | 8880 |
| **Fail2Ban** | Intrusion prevention system | N/A |

### Additional Features

- 🎨 **Interactive Menu System** - Color-coded TUI for easy navigation
- 👥 **User Management** - Create, delete, lock/unlock VPN users with expiry dates
- 🔒 **Automatic Firewall** - Pre-configured iptables rules with persistence
- 📊 **System Information** - Real-time service status and resource monitoring
- 🔐 **SSL Certificates** - Auto-generated self-signed certificates for all SSL services
- 🌐 **IP Forwarding** - Automatic NAT configuration for VPN traffic
- 📝 **Login Banner** - Professional MOTD with server information
- ⚡ **Auto-Start Service** - Ensures all configurations persist across reboots

---

## 💻 System Requirements

### Supported Operating Systems

| OS | Versions | Status |
|----|----------|--------|
| **Ubuntu** | 18.04, 20.04, 22.04, 24.04 | ✅ Fully Supported |
| **Debian** | 9, 10, 11, 12 | ✅ Fully Supported |

### Minimum Hardware Requirements

- **CPU:** 1 core (2+ cores recommended)
- **RAM:** 512 MB (1 GB+ recommended)
- **Disk:** 2 GB free space (5 GB+ recommended)
- **Network:** Public IPv4 address with internet access

### Prerequisites

- **Root Access:** The script must be run as root or with `sudo`
- **Fresh VPS:** Recommended to use a clean installation (not required but safer)
- **Open Ports:** All TCP/UDP ports should be accessible (no firewall blocking)

---

## ⚠️ Important: Upgrading from Old Version?

**If you already have the old Project Fog installed**, do NOT follow the installation guide below. Instead, use the migration script:

```bash
cd Project-Fog-Modernized-Fixed
./migrate.sh
```

See **[MIGRATION.md](MIGRATION.md)** for detailed upgrade instructions.

---

## 📥 Installation Guide (Fresh Install Only)

### Method 1: Direct Download and Run (Recommended)

```bash
# Switch to root user
sudo su

# Download the script
wget https://github.com/YOUR-REPO/Project-Fog-Modernized/archive/main.zip

# Extract the archive
unzip main.zip
cd Project-Fog-Modernized-main

# Make scripts executable (if needed)
chmod +x projectfog_modern.sh core_installer.sh proxy3.py uninstaller.sh

# Run the installer
./projectfog_modern.sh
```

### Method 2: Git Clone

```bash
# Switch to root user
sudo su

# Clone the repository
git clone https://github.com/jhonleoh/Korn-Sudo-2026.git
cd Project-Fog-Modernized

# Run the installer
./projectfog_modern.sh
```

### Method 3: Manual Upload

1. Download the `Project-Fog-Modernized-Fixed.zip` file to your computer
2. Upload it to your VPS using SCP, SFTP, or your hosting panel
3. Extract and run:

```bash
sudo su
unzip Project-Fog-Modernized-Fixed.zip
cd Project-Fog-Modernized-Fixed
./projectfog_modern.sh
```

---

## 🎯 Post-Installation

### Accessing the Menu

After installation, you can access the Project Fog management panel at any time by running:

```bash
menu
```

This command is available system-wide and provides access to all management functions.

### Installation Options

When you run the script, you'll be presented with several installation options:

1. **Full Installation** - Installs all services (recommended for most users)
2. **Core Only** - SSH + Dropbear + Stunnel (minimal tunneling setup)
3. **VPN Only** - OpenVPN + Proxy services
4. **Web Panel** - Webmin + 3X-UI management panels
5. **Custom Installation** - Pick and choose individual components

### First Steps After Installation

1. **Check Service Status:**
   ```bash
   menu
   # Select option 6: System Information
   ```

2. **Create VPN Users:**
   ```bash
   menu
   # Select option 7: User Management
   # Then select 1: Create VPN User
   ```

3. **Download OpenVPN Client Configs:**
   ```bash
   # Client configs are located at:
   /etc/project-fog/openvpn-clients/client_tcp.ovpn
   /etc/project-fog/openvpn-clients/client_udp.ovpn
   ```

4. **Access Web Panels:**
   - **Webmin:** `http://YOUR_SERVER_IP:10000`
   - **3X-UI:** `http://YOUR_SERVER_IP:2053`
   - **Nginx Landing Page:** `http://YOUR_SERVER_IP:81`

---

## 🔧 Service Details

### OpenVPN Configuration

Project Fog sets up two OpenVPN instances:

- **TCP Server** (Port 1194) - Better for restrictive networks
- **UDP Server** (Port 2200) - Better performance for general use

**Features:**
- AES-256-GCM encryption
- TLS authentication
- DNS push (Google DNS + Cloudflare)
- Full tunnel mode (all traffic through VPN)
- Supports up to 50 concurrent clients per instance

**Client Configuration:**
- Download `.ovpn` files from `/etc/project-fog/openvpn-clients/`
- Import into OpenVPN client (OpenVPN GUI, Tunnelblick, etc.)
- Use your VPN username and password created via User Management

### Stunnel SSL Tunneling

Stunnel wraps various services in SSL/TLS encryption:

| Port | Target Service | Purpose |
|------|----------------|---------|
| 443 | Dropbear (109) | SSL-wrapped SSH |
| 445 | Dropbear (109) | SSL-wrapped SSH (alternate) |
| 777 | Dropbear (143) | SSL-wrapped SSH (alternate port) |
| 990 | OpenSSH (22) | SSL-wrapped SSH |
| 442 | OpenVPN (1194) | SSL-wrapped VPN |

**Use Case:** Bypass DPI (Deep Packet Inspection) and firewall restrictions by tunneling SSH/VPN through SSL.

### Squid Proxy

High-performance HTTP/HTTPS proxy server.

**Configuration:**
- Ports: 3128, 8080
- Access: Allows localhost and private networks
- Privacy: Removes forwarding headers
- Logging: `/var/log/squid/`

**Usage Example:**
```bash
# Set proxy in your application or browser
HTTP Proxy: YOUR_SERVER_IP:3128
HTTPS Proxy: YOUR_SERVER_IP:3128
```

### Python Proxy

Custom-built HTTP tunneling proxy with full CONNECT method support.

**Features:**
- HTTP and HTTPS tunneling
- Non-blocking I/O with `select()`
- Automatic logging
- Systemd service integration
- Configurable status message

**Service Management:**
```bash
systemctl status fog-proxy
systemctl restart fog-proxy
systemctl stop fog-proxy
```

### Dropbear SSH

Lightweight SSH server optimized for tunneling.

**Advantages over OpenSSH:**
- Smaller memory footprint
- Faster startup time
- Ideal for SSH tunneling and port forwarding

**Ports:** 109, 143

**Usage:**
```bash
ssh -p 109 username@YOUR_SERVER_IP
ssh -p 143 username@YOUR_SERVER_IP
```

---

## 🔌 Port Reference

### Complete Port Map

| Port | Protocol | Service | Description |
|------|----------|---------|-------------|
| 22 | TCP | OpenSSH | Standard SSH access |
| 80 | TCP | Nginx | HTTP web server |
| 81 | TCP | Nginx | Alternate HTTP (Project Fog landing page) |
| 109 | TCP | Dropbear | Lightweight SSH server |
| 143 | TCP | Dropbear | Lightweight SSH server (alternate) |
| 443 | TCP | Stunnel | SSL tunnel → Dropbear 109 |
| 442 | TCP | Stunnel | SSL tunnel → OpenVPN 1194 |
| 445 | TCP | Stunnel | SSL tunnel → Dropbear 109 |
| 777 | TCP | Stunnel | SSL tunnel → Dropbear 143 |
| 990 | TCP | Stunnel | SSL tunnel → OpenSSH 22 |
| 1194 | TCP | OpenVPN | VPN server (TCP mode) |
| 2200 | UDP | OpenVPN | VPN server (UDP mode) |
| 2053 | TCP | 3X-UI | V2Ray/Xray management panel |
| 3128 | TCP | Squid | HTTP/HTTPS proxy |
| 8080 | TCP | Squid | HTTP/HTTPS proxy (alternate) |
| 8118 | TCP | Privoxy | Privacy-focused web proxy |
| 8880 | TCP | Python Proxy | Custom HTTP tunneling proxy |
| 10000 | TCP | Webmin | Web-based system administration |

### Firewall Configuration

All necessary ports are automatically opened by the installation script. The firewall rules are saved and restored on boot via the `projectfogstartup` systemd service.

**Manual Firewall Management:**
```bash
# View current rules
iptables -L -n -v

# Save rules manually
iptables-save > /etc/iptables/rules.v4

# Restore rules manually
iptables-restore < /etc/iptables/rules.v4
```

---

## 👥 User Management

### Creating VPN Users

1. Run the menu: `menu`
2. Select **7) User Management**
3. Select **1) Create VPN User**
4. Enter username and password
5. Set expiry days (0 = never expires)

**Command Line Alternative:**
```bash
# Create user with no shell access
useradd -s /bin/false -M username
echo "username:password" | chpasswd

# Set expiry date (optional)
chage -E 2026-12-31 username
```

### Listing VPN Users

From the User Management menu, select **3) List VPN Users** to see:
- Username
- Status (Active/Locked)
- Expiry date

### Locking/Unlocking Users

**Lock a user:**
```bash
passwd -l username
```

**Unlock a user:**
```bash
passwd -u username
```

### Deleting VPN Users

From the User Management menu, select **2) Delete VPN User**, or:

```bash
userdel -f username
```

---

## 🗑️ Uninstallation

To completely remove Project Fog and all its components:

```bash
cd /path/to/Project-Fog-Modernized-Fixed
./uninstaller.sh
```

The uninstaller will:
1. Ask for confirmation (type `yes` to proceed)
2. Stop all running services
3. Remove all installed packages
4. Delete all configuration files
5. Remove VPN user accounts
6. Clean up iptables rules
7. Restore backed-up configurations
8. Offer to reboot the system

**Warning:** This action cannot be undone. All VPN users, configurations, and certificates will be permanently deleted.

---

## 🔍 Troubleshooting

### Common Issues

#### 1. Script Fails with "Permission Denied"

**Solution:**
```bash
sudo su
chmod +x projectfog_modern.sh
./projectfog_modern.sh
```

#### 2. Services Not Starting

**Check service status:**
```bash
systemctl status dropbear
systemctl status stunnel4
systemctl status openvpn@server_tcp
systemctl status squid
```

**View logs:**
```bash
journalctl -u dropbear -n 50
journalctl -u openvpn@server_tcp -n 50
tail -f /var/log/project-fog/install.log
```

#### 3. Cannot Connect to VPN

**Checklist:**
- Ensure firewall allows UDP 2200 and TCP 1194
- Verify OpenVPN service is running: `systemctl status openvpn@server_tcp`
- Check client config has correct server IP
- Verify VPN user credentials are correct
- Check logs: `tail -f /var/log/openvpn/openvpn_tcp.log`

#### 4. Webmin Not Accessible

**Solution:**
```bash
# Restart Webmin
systemctl restart webmin

# Check if it's listening
netstat -tulpn | grep 10000

# Access via: http://YOUR_IP:10000
```

#### 5. PHP Installation Fails

The script will automatically try PHP 8.2, 8.3, and 8.1 in order. If all fail:

```bash
# Manually add repository
sudo add-apt-repository ppa:ondrej/php -y  # Ubuntu
# OR for Debian, check /etc/apt/sources.list.d/php-sury.list

# Update and retry
apt-get update
apt-get install php8.2-fpm
```

### Getting Help

If you encounter issues not covered here:

1. Check the logs: `/var/log/project-fog/install.log`
2. Review service-specific logs in `/var/log/`
3. Run system diagnostics from the menu (option 6)
4. Ensure your VPS meets the minimum requirements

---

## 🔐 Security Recommendations

### Essential Security Practices

1. **Change Default SSH Port** (after installation):
   ```bash
   nano /etc/ssh/sshd_config
   # Change Port 22 to something else (e.g., 2222)
   systemctl restart sshd
   ```

2. **Use Strong Passwords:**
   - Generate strong passwords for VPN users
   - Use a password manager
   - Enable SSH key authentication

3. **Enable SSH Key Authentication:**
   ```bash
   # On your local machine
   ssh-keygen -t ed25519
   ssh-copy-id root@YOUR_SERVER_IP
   
   # On server, disable password auth
   nano /etc/ssh/sshd_config
   # Set: PasswordAuthentication no
   systemctl restart sshd
   ```

4. **Keep System Updated:**
   ```bash
   apt-get update && apt-get upgrade -y
   ```

5. **Monitor Fail2Ban:**
   ```bash
   fail2ban-client status
   fail2ban-client status sshd
   ```

6. **Regular Backups:**
   - Backup `/etc/project-fog/`
   - Backup `/etc/openvpn/`
   - Backup VPN user list

7. **Use SSL Certificates:**
   - For production, replace self-signed certificates with Let's Encrypt
   - Install certbot: `apt-get install certbot`

### Hardening Checklist

- [ ] Change default SSH port
- [ ] Disable root password login (use SSH keys)
- [ ] Set up automatic security updates
- [ ] Configure Fail2Ban for all services
- [ ] Implement rate limiting on proxies
- [ ] Regular log monitoring
- [ ] Periodic VPN user audits
- [ ] Firewall rule review

---

## 📜 Changelog

### Version 2.0 (Current)

**Major Rewrite:**
- Complete overhaul of all scripts
- Fixed 35+ critical bugs
- Added interactive menu system
- Implemented full service configurations
- Enhanced cross-version compatibility

**Key Improvements:**
- Functional Python proxy with CONNECT support
- Dynamic script directory detection
- Comprehensive error handling
- User management system
- System information dashboard
- Fail2Ban integration
- Automatic firewall configuration

For detailed changes, see `CHANGELOG_MODERN.md`.

---

## 🙏 Credits

**Original Project:** Project Fog by korn-sudo  
**Modernization:** Manus AI (2026)  
**License:** Unlicense (Public Domain)

### Third-Party Software

This project integrates and configures the following open-source software:

- [OpenVPN](https://openvpn.net/) - VPN server
- [Stunnel](https://www.stunnel.org/) - SSL tunnel
- [Squid](http://www.squid-cache.org/) - HTTP proxy
- [Dropbear](https://matt.ucc.asn.au/dropbear/dropbear.html) - SSH server
- [Nginx](https://nginx.org/) - Web server
- [Webmin](https://www.webmin.com/) - System administration
- [3X-UI](https://github.com/mhsanaei/3x-ui) - V2Ray/Xray panel
- [Fail2Ban](https://www.fail2ban.org/) - Intrusion prevention

### Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

---

## 📄 License

This project is released into the **Public Domain** under the [Unlicense](https://unlicense.org/).

You are free to use, modify, and distribute this software for any purpose, commercial or non-commercial, without any restrictions.

---

**Made with ☁️ by the Project Fog community**
