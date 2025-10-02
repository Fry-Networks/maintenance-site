param(
  [Parameter(Mandatory=$true)] [ValidateSet('on','off')] [string]$Mode,
  [switch]$PM2
)

$root = '/var/www/maintenance-site'
$nginxAvailable = '/etc/nginx/sites-available'
$nginxEnabled = '/etc/nginx/sites-enabled'
$target = 'dashboard.conf'

function Timestamp { Get-Date -Format yyyyMMddTHHmmssZ }

Write-Output "Root dir: $root"
if (-not (Test-Path -Path $root -PathType Container)) {
  Write-Error "Error: $root does not exist. Copy your maintenance site to that path on the server."
  exit 3
}

$srcOn = "$root/nginx/maintenance.conf"
$srcOff = "$root/nginx/dashboard.conf"
$dest = "$nginxAvailable/$target"

if (Test-Path -Path $dest -PathType Leaf) {
  $backup = "$dest.bak.$(Timestamp)"
  Write-Output "Backing up existing $dest -> $backup"
  sudo cp $dest $backup
}

if ($Mode -eq 'on') {
  Write-Output "Enabling maintenance mode..."
  sudo cp $srcOn $dest
} else {
  Write-Output "Disabling maintenance mode..."
  sudo cp $srcOff $dest
}

Write-Output "Updating symlink in sites-enabled (atomic)"
sudo ln -sf $dest "$nginxEnabled/$target"

Write-Output "Testing nginx configuration..."
if (-not (sudo nginx -t)) {
  Write-Error "nginx -t failed, attempting rollback..."
  if ($backup -and (Test-Path -Path $backup)) {
    sudo cp $backup $dest
    sudo ln -sf $dest "$nginxEnabled/$target"
    if (-not (sudo nginx -t)) {
      Write-Error "Rollback: nginx -t still failing; manual intervention required"
    }
  }
  exit 4
}

Write-Output "Reloading nginx"
sudo systemctl reload nginx

if ($PM2) {
  if ($Mode -eq 'on') {
    Write-Output "Starting maintenance server via PM2"
    sudo -E pm2 start /var/www/maintenance-site/ecosystem.config.js --only maintenance | Out-Null
  } else {
    Write-Output "Stopping maintenance server via PM2"
    sudo -E pm2 stop maintenance | Out-Null
  }
}

Write-Output "Done. Nginx reloaded with mode=$Mode"