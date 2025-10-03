Maintenance site (standalone)

This folder is a minimal, dependency-free static maintenance page you can deploy as a temporary site for dashboard.frynetworks.com. It intentionally has no JS or API calls.

Files:

- index.html — the maintenance page. It expects `Logo.png` and `background.png` to be present in the same folder.
- server.js — a tiny Node static server that serves files in this folder (no external deps).
- package.json — start script to run the server with `node server.js`.

Quick local test (PowerShell):

1. Copy `Logo.png` and `background.png` into this folder.
2. Start a simple static server. Option A: using Python 3 (if installed):

Maintenance site (standalone)

This folder is a minimal, dependency-free static maintenance page you can deploy as a temporary site for dashboard.frynetworks.com. It intentionally has no JS or API calls.

Files:

- index.html — the maintenance page. It expects `Logo.png` and `background.png` to be present in the same folder.
- server.js — a tiny Node static server that serves files in this folder (no external deps).
- package.json — start script to run the server with `node server.js`.
- ecosystem.config.js — PM2 ecosystem to start the server with a single command.

Quick local test (PowerShell):

1. Copy `Logo.png` and `background.png` into this folder.
2. Start a simple static server. Option A: using Python 3 (if installed):

```powershell
# from the maintenance-site folder
python -m http.server 8000
# then open http://localhost:8000 in your browser
```

Option B: using Node.js server included here:

```powershell
# from the maintenance-site folder
node server.js
# then open http://localhost:8080
```

## Deploy to VPS with PM2 (recommended)

1. SCP or rsync the folder to your VPS, e.g.:

```bash
# from your local machine
rsync -avz maintenance-site/ user@vps:/var/www/maintenance-site/
```

2. SSH to the VPS and start with PM2 (ecosystem file):

```bash
ssh user@vps
cd /var/www/maintenance-site
# install pm2 if missing
npm install -g pm2
# start the app using the ecosystem file
pm2 start ecosystem.config.js
# or directly: pm2 start server.js --name maintenance
```

3. Verify it's running:

```bash
pm2 status
curl -I http://localhost:8080
```

## Nginx Configuration

This setup includes two nginx configuration files in the `nginx/` directory:

- `dashboard.conf` - Routes traffic to your dashboard (port 3000)
- `maintenance.conf` - Routes traffic to the maintenance page (port 8080)

The toggle script automatically swaps between these configurations.

**Important:** The configurations are designed to be copied to `/etc/nginx/sites-available/dashboard.conf` and symlinked to `/etc/nginx/sites-enabled/`. The toggle script handles this automatically.

## Optional: Return 503 for API clients

If you want API clients to get a 503 rather than the HTML, I can add a small rule in `server.js` to detect paths starting with `/api/` and return 503 + `Retry-After` header. Tell me if you want that behavior and I'll add it.

If you want, I can also add a small systemd service unit example for servers not using PM2.

## Quick toggle script (optional)

If you prefer a single command to switch nginx between dashboard and maintenance, copy the `scripts/maintenance` file to your VPS (and make it executable). Usage:

```bash
# on VPS (run as user with sudo privileges)
sudo chmod +x /var/www/maintenance-site/scripts/maintenance
sudo /var/www/maintenance-site/scripts/maintenance on   # enable maintenance
sudo /var/www/maintenance-site/scripts/maintenance off  # disable maintenance
```

There is also a PowerShell version `scripts/maintenance.ps1` if you prefer invoking via PowerShell remoting.

## Toggling Between Dashboard and Maintenance Mode

The maintenance site includes automated toggle scripts to easily switch between normal dashboard operation and maintenance mode.

### Commands

**Enable Maintenance Mode** (shows maintenance page to users):

```bash
sudo /var/www/maintenance-site/scripts/maintenance on --pm2
```

**Disable Maintenance Mode** (restores dashboard):

```bash
sudo /var/www/maintenance-site/scripts/maintenance off --pm2
```

### What the Toggle Does

The script automatically:

1. Creates a timestamped backup of your current nginx configuration
2. Swaps the nginx configuration to point to the appropriate backend
3. Validates the nginx configuration with `nginx -t`
4. Reloads nginx if validation passes
5. Starts/stops the maintenance PM2 process (when using `--pm2` flag)
6. Rolls back automatically if validation fails

### Additional Examples

Without PM2 process management:

```bash
sudo /var/www/maintenance-site/scripts/maintenance on   # enable maintenance
sudo /var/www/maintenance-site/scripts/maintenance off  # disable maintenance
```

PowerShell example:

```powershell
# enable
. /var/www/maintenance-site/scripts/maintenance.ps1 -Mode on -PM2
# disable
. /var/www/maintenance-site/scripts/maintenance.ps1 -Mode off -PM2
```

## Health checks & rollback

1. After running `maintenance on`, confirm nginx is healthy:

```bash
sudo nginx -t
curl -I https://dashboard.frynetworks.com
```

2. If `nginx -t` fails, the toggle script will attempt to restore the timestamped backup and warn you. If the problem persists, inspect `/var/log/nginx/error.log` and the backed-up file (e.g. `/etc/nginx/sites-available/dashboard.conf.bak.20251002T123456Z`).

3. Manual rollback (if needed):

```bash
sudo cp /etc/nginx/sites-available/dashboard.conf.bak.20251002T123456Z /etc/nginx/sites-available/dashboard.conf
sudo ln -sf /etc/nginx/sites-available/dashboard.conf /etc/nginx/sites-enabled/dashboard.conf
sudo nginx -t && sudo systemctl reload nginx
```

If you want, I can also add a health-check script that polls the site after the swap and auto-rolls back on repeated failures.
