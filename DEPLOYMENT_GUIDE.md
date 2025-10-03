# Quick Deployment Guide

This guide covers deploying the fixes and 1Password integration to your VPS.

## Files Changed

### Maintenance Site

- `nginx/maintenance.conf` - Fixed invalid health check syntax

### Dashboard

- `ecosystem.config.js` - Updated to use 1Password wrapper script
- `start-with-1password.sh` - New wrapper script to load secrets from 1Password
- `1PASSWORD_SETUP.md` - Complete setup documentation

## Deployment Steps

### 1. Deploy Maintenance Site Nginx Fixes

From your local machine:

```bash
# Deploy the corrected nginx configurations
rsync -avz /home/debian/maintenance-site/nginx/dashboard.frynetworks.com user@your-vps:/var/www/maintenance-site/nginx/
rsync -avz /home/debian/maintenance-site/nginx/maintenance.frynetworks.com user@your-vps:/var/www/maintenance-site/nginx/

# Deploy the updated toggle script
rsync -avz /home/debian/maintenance-site/scripts/maintenance user@your-vps:/var/www/maintenance-site/scripts/

# Make sure the script is executable
ssh user@your-vps "chmod +x /var/www/maintenance-site/scripts/maintenance"
```

On your VPS, start the maintenance PM2 server (as your user, NOT sudo):

```bash
# Start maintenance server
pm2 start /var/www/maintenance-site/ecosystem.config.js --only maintenance
pm2 save

# Verify it's running
pm2 status
curl -I http://localhost:8080
```

Test the toggle (without --pm2 flag since PM2 should run as your user):

```bash
# Enable maintenance mode
sudo /var/www/maintenance-site/scripts/maintenance on

# Visit https://dashboard.frynetworks.com - should show maintenance page

# Disable maintenance mode
sudo /var/www/maintenance-site/scripts/maintenance off
```

### 2. Set Up 1Password (if not already done)

On your VPS:

```bash
# Install 1Password CLI (if not already installed)
curl -sSO https://downloads.1password.com/linux/tar/stable/x86_64/1password-cli-latest-linux-amd64.tar.gz
tar -xf 1password-cli-latest-linux-amd64.tar.gz
sudo mv op /usr/local/bin/
rm 1password-cli-latest-linux-amd64.tar.gz

# Verify installation
op --version
```

### 3. Create Secrets in 1Password

Using the 1Password web interface:

1. Go to your **Dashboard** vault
2. Create a new **Password** item named: `Dashboard Secrets`
3. Add these fields (all as password type):
   - `NEXTAUTH_SECRET`
   - `STAKE_MNEMONIC`
   - `STAKE_REKEY`
   - `REWARD_REKEY`
   - `REWARD_MNEMONIC`
   - `MONGO_URI`

### 4. Deploy Dashboard Changes

From your local machine:

```bash
# Deploy all dashboard files
rsync -avz /home/debian/dashboard/ecosystem.config.js user@your-vps:/home/debian/dashboard/
rsync -avz /home/debian/dashboard/start-with-1password.sh user@your-vps:/home/debian/dashboard/
rsync -avz /home/debian/dashboard/1PASSWORD_SETUP.md user@your-vps:/home/debian/dashboard/
```

### 5. Configure and Restart Dashboard

On your VPS:

```bash
# Make wrapper script executable
chmod +x /home/debian/dashboard/start-with-1password.sh

# Set your 1Password service account token
export OP_SERVICE_ACCOUNT_TOKEN="your-service-account-token-here"

# Restart dashboard with new configuration
pm2 restart dashboard --update-env

# Monitor logs to verify success
pm2 logs dashboard --lines 50
```

Look for:

```
Loading secrets from 1Password vault: Dashboard
Successfully loaded secrets from 1Password
Starting dashboard with npm start...
```

### 6. Save PM2 Configuration

```bash
# Save the PM2 config so it persists across reboots
pm2 save

# Optional: Set up PM2 to start on boot
pm2 startup
# Follow the instructions it provides
```

### 7. Test Everything

```bash
# Test maintenance toggle ON
sudo /var/www/maintenance-site/scripts/maintenance on --pm2
# Visit https://dashboard.frynetworks.com - should show maintenance page

# Test maintenance toggle OFF
sudo /var/www/maintenance-site/scripts/maintenance off --pm2
# Visit https://dashboard.frynetworks.com - should show dashboard

# Check dashboard logs for any errors
pm2 logs dashboard --lines 100
```

### 8. Clean Up Old Files

Once everything is confirmed working:

**Clean up old nginx backup files:**

```bash
# On VPS - remove the old incorrect config files
sudo rm /etc/nginx/sites-available/dashboard.conf
sudo rm /etc/nginx/sites-available/dashboard.conf.bak.*

# Verify only correct files remain
ls -la /etc/nginx/sites-available/
# Should show dashboard.frynetworks.com and future backups like dashboard.frynetworks.com.bak.*
```

**Clean up local maintenance-site folder:**

```bash
# On your local machine
cd /home/debian/maintenance-site/nginx

# Remove old configs (no longer needed)
rm dashboard.conf maintenance.conf

# Keep only the new ones
ls -la
# Should show: dashboard.frynetworks.com and maintenance.frynetworks.com
```

**Remove old dashboard .env file:**

```bash
# On VPS - backup and remove after confirming 1Password works
cd /var/www/dashboard
mv .env .env.backup.$(date +%Y%m%d)
```

**Managing future backups:**

The toggle script creates timestamped backups. Clean them periodically:

```bash
# On VPS - remove backups older than 30 days
find /etc/nginx/sites-available -name "*.bak.*" -mtime +30 -delete

# Or keep only the 5 most recent backups
ls -t /etc/nginx/sites-available/*.bak.* | tail -n +6 | xargs rm -f
```

## Troubleshooting

If the dashboard fails to start:

```bash
# Check PM2 logs
pm2 logs dashboard --err --lines 100

# Verify OP_SERVICE_ACCOUNT_TOKEN is set
echo $OP_SERVICE_ACCOUNT_TOKEN

# Test 1Password CLI access
op item get "Dashboard Secrets" --vault "Dashboard" --format json

# Verify script is executable
ls -la /var/www/dashboard/start-with-1password.sh
```

If maintenance toggle fails:

```bash
# Check nginx syntax
sudo nginx -t

# Check if maintenance server is running
pm2 status

# View toggle script logs
sudo /var/www/maintenance-site/scripts/maintenance on --pm2
```

## Security Note

The `OP_SERVICE_ACCOUNT_TOKEN` must be set in the environment before starting PM2. For persistence across reboots, consider adding it to:

1. PM2 startup script (recommended)
2. `/etc/environment` file
3. Your shell profile (less secure)

See `1PASSWORD_SETUP.md` for detailed instructions.

## Complete Setup Verification

Run these checks to ensure everything is working:

```bash
# 1. Check PM2 status
pm2 status

# 2. Test 1Password integration
export OP_SERVICE_ACCOUNT_TOKEN="your-token"
op item get "Dashboard Secrets" --vault "Dashboard" --fields "MONGO_URI"

# 3. Check nginx configuration
sudo nginx -t

# 4. Test maintenance toggle
sudo /var/www/maintenance-site/scripts/maintenance on --pm2
curl -I https://dashboard.frynetworks.com
sudo /var/www/maintenance-site/scripts/maintenance off --pm2

# 5. Verify dashboard logs
pm2 logs dashboard --lines 50
```

All systems should be operational! 🚀
