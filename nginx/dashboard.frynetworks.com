server {

    server_name dashboard.frynetworks.com;

    # ACME challenge for Let's Encrypt
    location ^~ /.well-known/acme-challenge/ {
        root /var/www/html;
        try_files $uri =404;
    }

    # Reverse proxy to dashboard app
    location / {
        proxy_pass http://127.0.0.1:3007;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
    }

    include /etc/nginx/snippets/block-dotfiles.conf;

    listen [::]:443 ssl; # managed by Certbot
    listen 443 ssl; # managed by Certbot
    ssl_certificate /etc/letsencrypt/live/dashboard.frynetworks.com/fullchain.pem; # managed by Certbot
    ssl_certificate_key /etc/letsencrypt/live/dashboard.frynetworks.com/privkey.pem; # managed by Certbot
    include /etc/letsencrypt/options-ssl-nginx.conf; # managed by Certbot
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem; # managed by Certbot

}
server {
    if ($host = dashboard.frynetworks.com) {
        return 301 https://$host$request_uri;
    } # managed by Certbot


    listen 80;
    listen [::]:80;

    server_name dashboard.frynetworks.com;
    return 404; # managed by Certbot


}
