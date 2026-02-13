# Project Fog Modernized - Changelog

## Version 2.0 (Complete Rewrite)

### Critical Bug Fixes

1. **Hardcoded source path** (projectfog_modern.sh line 19): Changed from hardcoded `/home/ubuntu/modern_fog/core_installer.sh` to dynamic `$(dirname "$0")/core_installer.sh`. The original would fail on any system where the script was not in that exact directory.

2. **Non-functional proxy** (proxy3.py): The `proxy_tunnel()` method was empty (`pass`), meaning the proxy accepted connections but never actually tunneled any traffic. Completely rewritten with full HTTP CONNECT tunnel support, direct HTTP forwarding, and bidirectional data relay.

3. **grep -P compatibility** (all scripts): Replaced `grep -oP` (Perl regex) with `awk` for OS detection. The `-P` flag requires PCRE support which is not available on all minimal Debian/Ubuntu installs.

4. **Missing service configurations**: Dropbear, Stunnel, Squid, Privoxy, Nginx, and OpenVPN were installed but never configured. Added complete configuration for all services.

5. **apt vs apt-get inconsistency**: Replaced all `apt` calls with `apt-get` in scripts. The `apt` command is designed for interactive use and should not be used in scripts.

6. **IP detection failure**: The original `curl || wget` fallback only triggered on non-zero exit, not on missing commands. Added proper command existence checks, multiple fallback services, and timeouts.

7. **GPG key handling**: Added `--batch --yes` flags for non-interactive GPG operations on Debian. The original could hang waiting for user input.

8. **Webmin download not validated**: Added file existence and size checks before executing the downloaded setup script.

9. **Uninstaller references non-existent services**: Added existence checks before stopping services. Added proper cleanup for all components.

### New Features

1. **Interactive menu system**: Full TUI menu with color-coded options for installation, management, and system info.

2. **Multiple installation modes**: Full, Core Only, VPN Only, Web Panel, and Custom installation options.

3. **User management**: Create, delete, list, lock, and unlock VPN users with expiry date support.

4. **OpenVPN full setup**: Complete PKI generation with Easy-RSA, TCP and UDP server configs, client config templates, and NAT rules.

5. **Stunnel SSL tunneling**: Full configuration with multiple SSL ports for SSH, Dropbear, and OpenVPN tunneling.

6. **Squid proxy configuration**: Complete config with dual ports (3128, 8080), privacy headers, and access controls.

7. **Privoxy configuration**: Full privacy proxy setup on port 8118.

8. **Nginx reverse proxy**: Web server with Project Fog landing page and Webmin reverse proxy.

9. **Firewall rules**: Automatic iptables configuration with NAT for VPN, persistent rules via iptables-persistent.

10. **Auto-start service**: Systemd service to restore iptables rules and IP forwarding on boot.

11. **Login banner/MOTD**: Professional login banner showing server info and menu command.

12. **Fail2Ban**: SSH and Dropbear brute-force protection.

13. **System information display**: Service status, port usage, and system resource overview.

14. **`menu` command**: Global shortcut command installed to `/usr/local/sbin/menu`.

### Compatibility Improvements

1. **OS detection**: Uses `awk` instead of `grep -P` for universal compatibility.

2. **OS validation**: Checks for supported OS versions with option to continue on unsupported systems.

3. **PHP version fallback**: Tries PHP 8.2, then 8.3, then 8.1, then default php-fpm.

4. **Squid package detection**: Automatically detects whether `squid` or `squid3` package is available.

5. **Debian codename fallback**: Maps version numbers to codenames for repository configuration.

6. **Safe package installation**: Retry logic with individual package fallback on batch failure.

7. **Pre-flight checks**: Internet connectivity, disk space, and tool availability verification.

8. **Error handling**: `set -euo pipefail` with trap for error reporting.

### Python Proxy Improvements

1. **Full HTTP CONNECT tunnel**: Properly handles CONNECT method for HTTPS/SSL tunneling.

2. **Direct HTTP forwarding**: Handles non-CONNECT HTTP requests.

3. **Bidirectional data relay**: Uses `select()` for efficient data tunneling.

4. **Graceful shutdown**: Signal handlers for SIGINT and SIGTERM.

5. **Logging**: File and console logging with configurable levels.

6. **Error responses**: Proper HTTP error codes (400, 502, 504) sent to clients.

7. **Increased backlog**: Changed from 5 to 256 for better connection handling.

8. **Systemd service**: Runs as a managed service with auto-restart.

### Uninstaller Improvements

1. **Confirmation prompt**: Requires typing "yes" before proceeding.

2. **Service existence checks**: Only stops services that are actually running.

3. **Complete cleanup**: Removes PHP packages, GPG keys, repository files, cron jobs, VPN users, iptables rules.

4. **Config restoration**: Restores backed-up SSH and Squid configurations.

5. **Reboot option**: Offers optional reboot after uninstallation.

## File Structure

```
Project-Fog-Modernized-Fixed/
├── projectfog_modern.sh    # Main entry point with interactive menu
├── core_installer.sh       # All installation and configuration functions
├── proxy3.py               # Fully functional HTTP tunneling proxy
├── uninstaller.sh          # Complete cleanup with confirmation
└── CHANGELOG_MODERN.md     # This file
```

## Port Reference

| Port  | Service           | Protocol |
|-------|-------------------|----------|
| 22    | OpenSSH           | TCP      |
| 80    | Nginx             | TCP      |
| 81    | Nginx (alt)       | TCP      |
| 109   | Dropbear          | TCP      |
| 143   | Dropbear          | TCP      |
| 443   | Stunnel (SSL-SSH) | TCP      |
| 442   | Stunnel (SSL-VPN) | TCP      |
| 445   | Stunnel (SSL)     | TCP      |
| 777   | Stunnel (SSL)     | TCP      |
| 990   | Stunnel (SSL-SSH) | TCP      |
| 1194  | OpenVPN TCP       | TCP      |
| 2200  | OpenVPN UDP       | UDP      |
| 2053  | 3X-UI Panel       | TCP      |
| 3128  | Squid Proxy       | TCP      |
| 8080  | Squid Proxy       | TCP      |
| 8118  | Privoxy           | TCP      |
| 8880  | Python Proxy      | TCP      |
| 10000 | Webmin            | TCP      |

## Supported Operating Systems

| OS           | Version | Codename  | Status     |
|--------------|---------|-----------|------------|
| Ubuntu       | 18.04   | bionic    | Supported  |
| Ubuntu       | 20.04   | focal     | Supported  |
| Ubuntu       | 22.04   | jammy     | Supported  |
| Ubuntu       | 24.04   | noble     | Supported  |
| Debian       | 9       | stretch   | Supported  |
| Debian       | 10      | buster    | Supported  |
| Debian       | 11      | bullseye  | Supported  |
| Debian       | 12      | bookworm  | Supported  |
