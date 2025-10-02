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

Deploy to VPS with PM2 (recommended)
-----------------------------------

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

Nginx snippet — swap upstream to maintenance
-------------------------------------------

This example assumes you have an nginx server block for `dashboard.frynetworks.com` which proxies to your normal upstream (dashboard app). Create a separate upstream for the maintenance server and then switch `proxy_pass` to that upstream while in maintenance window.

```nginx
upstream dashboard_app {
	server 127.0.0.1:3000; # your normal dashboard backend
}

upstream maintenance_app {
	server 127.0.0.1:8080; # maintenance server
}

server {
	server_name dashboard.frynetworks.com;

	location / {
		# Point to maintenance_app during maintenance, otherwise dashboard_app
		proxy_pass http://maintenance_app;
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
	}

	# Keep static health check or admin routes proxied to dashboard_app if needed
}
```

To switch back after maintenance: update the `proxy_pass` back to `http://dashboard_app` and reload nginx (`sudo nginx -s reload` or `systemctl reload nginx`).

Optional: Return 503 for API clients
-----------------------------------

If you want API clients to get a 503 rather than the HTML, I can add a small rule in `server.js` to detect paths starting with `/api/` and return 503 + `Retry-After` header. Tell me if you want that behavior and I'll add it.

If you want, I can also add a small systemd service unit example for servers not using PM2.

Quick toggle script (optional)
-----------------------------

If you prefer a single command to switch nginx between dashboard and maintenance, copy the `scripts/maintenance` file to your VPS (and make it executable). Usage:

```bash
# on VPS (run as user with sudo privileges)
sudo chmod +x /var/www/maintenance-site/scripts/maintenance
sudo /var/www/maintenance-site/scripts/maintenance on   # enable maintenance
sudo /var/www/maintenance-site/scripts/maintenance off  # disable maintenance
```

There is also a PowerShell version `scripts/maintenance.ps1` if you prefer invoking via PowerShell remoting.

Safer toggle usage (new)
------------------------

The provided toggle scripts now create a timestamped backup of the existing `/etc/nginx/sites-available/dashboard.conf` before swapping, validate `nginx -t`, and optionally start/stop the PM2 process using a flag.

Examples (on the VPS, user with sudo privileges):

```bash
# enable maintenance and start the maintenance pm2 process (if you used the ecosystem file)
sudo /var/www/maintenance-site/scripts/maintenance on --pm2

# disable maintenance and stop the maintenance pm2 process
sudo /var/www/maintenance-site/scripts/maintenance off --pm2
```

PowerShell example:

```powershell
# enable
. /var/www/maintenance-site/scripts/maintenance.ps1 -Mode on -PM2
# disable
. /var/www/maintenance-site/scripts/maintenance.ps1 -Mode off -PM2
```

Health checks & rollback
------------------------

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
