# 🔄 Migration Guide - Upgrading from Old Project Fog

If you have the **old Project Fog** already installed on your VPS, follow this guide to safely upgrade to the **Modernized v2.0** without conflicts.

---

## ⚠️ Important: Do NOT Install Directly

**DO NOT** run `projectfog_modern.sh` directly if you have the old version installed. This will cause:

- ❌ Port conflicts (multiple services trying to use the same ports)
- ❌ Configuration conflicts (old and new configs interfering)
- ❌ Service failures (services won't start properly)
- ❌ Potential data loss (VPN users may be overwritten)

---

## ✅ Safe Migration Process

### Option 1: Automated Migration (Recommended)

We've created a migration script that handles everything automatically:

```bash
# 1. Upload and extract the new Project Fog Modernized
cd /root
unzip Project-Fog-Modernized-Fixed.zip
cd Project-Fog-Modernized-Fixed

# 2. Run the migration script (NOT the installer!)
chmod +x migrate.sh
./migrate.sh
```

**What the migration script does:**

1. ✅ Detects if old Project Fog is installed
2. ✅ Creates a timestamped backup of:
   - VPN user accounts and passwords
   - OpenVPN certificates and configs
   - SSH keys and configuration
   - Client .ovpn files
3. ✅ Safely uninstalls the old version
4. ✅ Preserves your VPN users and OpenVPN setup
5. ✅ Launches the new installer
6. ✅ Provides instructions to restore users

### Option 2: Manual Migration

If you prefer to do it manually:

#### Step 1: Backup Your Data

```bash
# Create backup directory
mkdir -p /root/fog-backup

# Backup VPN users
grep '/bin/false' /etc/passwd > /root/fog-backup/vpn_users.txt

# Backup OpenVPN
cp -r /etc/openvpn /root/fog-backup/

# Backup SSH keys
cp /root/.ssh/authorized_keys /root/fog-backup/ 2>/dev/null || true

# Backup client configs (if they exist)
cp -r /root/client-configs /root/fog-backup/ 2>/dev/null || true
cp -r /home/vps/public_html /root/fog-backup/ 2>/dev/null || true
```

#### Step 2: Uninstall Old Version

```bash
# Stop all services
systemctl stop openvpn@server_tcp openvpn@server_udp
systemctl stop dropbear stunnel4 squid privoxy nginx webmin

# Remove old Project Fog files
rm -rf /etc/korn
rm -rf /home/vps
rm -f /usr/local/sbin/korn-*
rm -f /usr/local/sbin/menu

# Clean up old systemd services
rm -f /etc/systemd/system/korn-startup.service
rm -f /etc/systemd/system/projectfogstartup.service
systemctl daemon-reload
```

#### Step 3: Install New Version

```bash
cd /root/Project-Fog-Modernized-Fixed
./projectfog_modern.sh
```

#### Step 4: Restore VPN Users

After installation, recreate your VPN users:

```bash
# View backed up users
cat /root/fog-backup/vpn_users.txt

# For each user, run:
menu
# Select: 7) User Management
# Select: 1) Create VPN User
# Enter the username and new password
```

---

## 🔍 What Gets Preserved vs. Recreated

| Component | Status | Notes |
|-----------|--------|-------|
| **VPN Users** | 🟡 Backed up | Must be manually recreated (usernames preserved) |
| **OpenVPN Certs** | 🟢 Preserved | Can be reused or regenerated |
| **SSH Keys** | 🟢 Preserved | Backed up and can be restored |
| **Service Configs** | 🔴 Replaced | New, improved configs installed |
| **Ports** | 🟢 Same | All services use the same ports |
| **Client .ovpn files** | 🟡 Backed up | May need regeneration with new certs |

---

## 🆘 Troubleshooting Migration

### Issue: "Port already in use" errors

**Cause:** Old services are still running

**Solution:**
```bash
# Check what's using the port (example: port 443)
netstat -tulpn | grep :443

# Kill the process
killall stunnel4

# Or stop all old services
systemctl stop dropbear stunnel4 squid openvpn nginx
```

### Issue: VPN users can't connect after migration

**Cause:** Users need to be recreated in the new system

**Solution:**
```bash
# Check your backup for usernames
cat /root/fog-backup/vpn_users.txt

# Recreate each user via menu
menu → 7) User Management → 1) Create VPN User
```

### Issue: Old menu command still appears

**Cause:** Old menu script cached in shell

**Solution:**
```bash
# Clear shell hash table
hash -r

# Or logout and login again
exit
# Then SSH back in
```

### Issue: Services won't start after migration

**Cause:** Configuration conflicts

**Solution:**
```bash
# Check service status
systemctl status dropbear
systemctl status stunnel4

# View logs
journalctl -u dropbear -n 50

# If needed, reinstall specific component via menu
menu → 5) Custom Installation
```

---

## 📋 Pre-Migration Checklist

Before running the migration, ensure:

- [ ] You have root access to the server
- [ ] You've noted down all VPN usernames
- [ ] You have at least 2GB free disk space
- [ ] You have a backup of important data
- [ ] You're prepared for 5-10 minutes of downtime
- [ ] You have alternative access to the server (in case SSH config changes)

---

## 🎯 Post-Migration Checklist

After migration completes:

- [ ] Run `menu` to verify it works
- [ ] Check system info (menu option 6)
- [ ] Recreate VPN users (menu option 7)
- [ ] Test VPN connection with a client
- [ ] Test SSH access on all ports (22, 109, 143)
- [ ] Test Stunnel SSL tunnels (443, 445, 777)
- [ ] Access Webmin (http://YOUR_IP:10000)
- [ ] Verify all services are running
- [ ] Keep the backup for at least 7 days

---

## 💾 Backup Location

The migration script creates backups at:

```
/root/project-fog-backup-YYYYMMDD-HHMMSS/
```

**Contents:**
- `vpn_users.txt` - List of VPN usernames
- `shadow.bak` - Encrypted passwords
- `openvpn_backup/` - OpenVPN configs and certificates
- `ssh/` - SSH authorized_keys
- `README.txt` - Detailed backup information

**Keep this backup for at least 7-14 days** until you're sure the new installation is working perfectly.

---

## 🚨 Emergency Rollback

If something goes wrong and you need to rollback:

1. **Restore OpenVPN:**
   ```bash
   cp -r /root/project-fog-backup-*/openvpn_backup/* /etc/openvpn/
   systemctl restart openvpn@server_tcp openvpn@server_udp
   ```

2. **Restore SSH keys:**
   ```bash
   cp /root/project-fog-backup-*/ssh/authorized_keys /root/.ssh/
   chmod 600 /root/.ssh/authorized_keys
   ```

3. **Restore VPN users** (advanced):
   ```bash
   # This requires manually editing /etc/shadow
   # Only do this if you know what you're doing
   # Or recreate users manually via the menu
   ```

---

## ❓ Need Help?

If you encounter issues during migration:

1. Check the backup directory for your data
2. Review the migration logs
3. Try the manual migration steps
4. Check the main README.md troubleshooting section

---

**Remember:** The migration script is designed to be safe and preserve your data. Always keep backups!
