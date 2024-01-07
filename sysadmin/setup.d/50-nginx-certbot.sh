#!/bin/bash

set -Eeuxo pipefail

curdir="$(dirname "${BASH_SOURCE[0]}")"
#rootdir="$curdir/../.."

# shellcheck source=./.helpers.bash
source "$curdir/.helpers.bash"

###############
# NGINX SETUP #
###############

# Blast away all of the Ubuntu-ey goodness.
rm -rf /etc/nginx

# Make a blank directory for our configuration.
mkdir -p /etc/nginx
pushd /etc/nginx/

# Copied from openSUSE.
cat >mime.types <<EOF
types {
    text/html                                        html htm shtml;
    text/css                                         css;
    text/xml                                         xml;
    image/gif                                        gif;
    image/jpeg                                       jpeg jpg;
    application/javascript                           js;
    application/atom+xml                             atom;
    application/rss+xml                              rss;

    text/mathml                                      mml;
    text/plain                                       txt;
    text/vnd.sun.j2me.app-descriptor                 jad;
    text/vnd.wap.wml                                 wml;
    text/x-component                                 htc;

    image/avif                                       avif;
    image/png                                        png;
    image/svg+xml                                    svg svgz;
    image/tiff                                       tif tiff;
    image/vnd.wap.wbmp                               wbmp;
    image/webp                                       webp;
    image/x-icon                                     ico;
    image/x-jng                                      jng;
    image/x-ms-bmp                                   bmp;

    font/woff                                        woff;
    font/woff2                                       woff2;

    application/java-archive                         jar war ear;
    application/json                                 json;
    application/mac-binhex40                         hqx;
    application/msword                               doc;
    application/pdf                                  pdf;
    application/postscript                           ps eps ai;
    application/rtf                                  rtf;
    application/vnd.apple.mpegurl                    m3u8;
    application/vnd.google-earth.kml+xml             kml;
    application/vnd.google-earth.kmz                 kmz;
    application/vnd.ms-excel                         xls;
    application/vnd.ms-fontobject                    eot;
    application/vnd.ms-powerpoint                    ppt;
    application/vnd.oasis.opendocument.graphics      odg;
    application/vnd.oasis.opendocument.presentation  odp;
    application/vnd.oasis.opendocument.spreadsheet   ods;
    application/vnd.oasis.opendocument.text          odt;
    application/vnd.openxmlformats-officedocument.presentationml.presentation
                                                     pptx;
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
                                                     xlsx;
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
                                                     docx;
    application/vnd.wap.wmlc                         wmlc;
    application/wasm                                 wasm;
    application/x-7z-compressed                      7z;
    application/x-cocoa                              cco;
    application/x-java-archive-diff                  jardiff;
    application/x-java-jnlp-file                     jnlp;
    application/x-makeself                           run;
    application/x-perl                               pl pm;
    application/x-pilot                              prc pdb;
    application/x-rar-compressed                     rar;
    application/x-redhat-package-manager             rpm;
    application/x-sea                                sea;
    application/x-shockwave-flash                    swf;
    application/x-stuffit                            sit;
    application/x-tcl                                tcl tk;
    application/x-x509-ca-cert                       der pem crt;
    application/x-xpinstall                          xpi;
    application/xhtml+xml                            xhtml;
    application/xspf+xml                             xspf;
    application/zip                                  zip;

    application/octet-stream                         bin exe dll;
    application/octet-stream                         deb;
    application/octet-stream                         dmg;
    application/octet-stream                         iso img;
    application/octet-stream                         msi msp msm;

    audio/midi                                       mid midi kar;
    audio/mpeg                                       mp3;
    audio/ogg                                        ogg;
    audio/x-m4a                                      m4a;
    audio/x-realaudio                                ra;

    video/3gpp                                       3gpp 3gp;
    video/mp2t                                       ts;
    video/mp4                                        mp4;
    video/mpeg                                       mpeg mpg;
    video/quicktime                                  mov;
    video/webm                                       webm;
    video/x-flv                                      flv;
    video/x-m4v                                      m4v;
    video/x-mng                                      mng;
    video/x-ms-asf                                   asx asf;
    video/x-ms-wmv                                   wmv;
    video/x-msvideo                                  avi;
}
EOF

# Configure NGINX. This configuration is very loosely hacked on top of
# <https://github.com/cyphar/cyphar.com/tree/main/srv/overlay/_host/etc/nginx>.
cat >nginx.conf <<"EOF"
user www-data;
worker_processes 4;

error_log  /var/log/nginx/error.log;

events {
	worker_connections 1024;
	use epoll;
}

http {
	include       mime.types;
	default_type  application/octet-stream;

	log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
	access_log /var/log/nginx/access.log main;

	sendfile on;
	tcp_nopush on;

	# Don't embed the nginx version in the Server: header.
	server_tokens off;

	# Redirect everything to SSL, and provide acme-challenge support.
	server {
		listen 80 default_server;
		listen [::]:80 default_server;
		server_name .ncss.life;

		location / {
			return 302 https://$host$request_uri;
		}

		# Needed for http-01 ACME validation (which is the only trivial way of
		# getting a certificate without storing credentials for DNS zone
		# configuration on your edge node).
		location /.well-known/acme-challenge/ {
			root /srv/wkd;
		}
	}

	include conf.d/coffee.conf;
}
EOF

# We have to have a working NGINX configuration when using certbot, before we
# can configure the TLS stuff for the actual site. So we first use empty files
# for the TLS-related config and then update them after certbot gets us a
# certificate.
mkdir -p conf.d
pushd conf.d

touch coffee.conf # dummy file until we get the certificate

cat >coffee.conf.actual.template <<"EOF"
# Serve up coffee. Get it while it's hot!
server {
	listen 443 ssl http2;
	listen [::]:443 ssl http2;
	# NOTE: THIS FIELD SHOULD BE REPLACED BY host_server_setup.py.
	server_name {{DOMAIN}};

	ssl_certificate /etc/letsencrypt/live/{{DOMAIN}}/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/{{DOMAIN}}/privkey.pem;

	# Semi-reasonable and secure TLS configuration, based on
	#   <https://wiki.mozilla.org/Security/Server_Side_TLS> and
	#   <https://github.com/ssllabs/research/wiki/SSL-and-TLS-Deployment-Best-Practices>.

	gzip off;

	# Only support TLSv1.[23].
	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_ciphers "ECDHE+CHACHA20 ECDHE+AESGCM DHE+CHACHA20 DHE+AESGCM ECDHE+ECDSA+AESGCM";
	# All of the ciphers are safe, Mozilla recommends disabling
	# server-preferred ciphers. IIRC this might also make TLSv1.3 not
	# require 2-RTT but don't quote me on that.
	#ssl_prefer_server_ciphers on;

	# ffdhe4096 (RFC 7919) is recommended by Mozilla over randomly-generated DH
	# parameters.
	ssl_dhparam /srv/run/ffdhe4096.pem;

	# x25519 is more generally trusted but less supported. And contrary to the
	# naming, secp521r1 is not recommended by NIST and instead we should just use
	# prime256v1 and secp384r1.
	ssl_ecdh_curve X448:X25519:secp384r1:prime256v1;

	# Make SSL session resumption window short to make it harder to track users.
	ssl_session_cache shared:SSL:10m;
	ssl_session_timeout 1m;
	ssl_session_tickets off;

	# OSCP stapling.
	ssl_stapling on;
	ssl_stapling_verify on;

	# For OSCP stapling.
	resolver 1.1.1.1 1.0.0.1 valid=300s;
	resolver_timeout 5s;

	# Tunnel to LXC.
	location / {
		# Some additional headers just to be safe.
		add_header X-Download-Options "noopen" always;
		add_header X-Permitted-Cross-Domain-Policies "none" always;

		# Some applications need to be told they're being reverse-proxied.
		proxy_set_header Host $host;
		proxy_set_header X-Real-IP $remote_addr;
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header X-Forwarded-Proto $scheme;
		proxy_set_header X-Forwarded-Host $http_host;

		# Pass to Docker.
		proxy_pass http://127.0.0.1:{{PORT}}/;
	}
}
EOF

# Replace variables in the template.
sed "s|{{DOMAIN}}|$DOMAIN|g;s|{{PORT}}|$HOST_PORT|g" coffee.conf.actual.template >coffee.conf.actual

popd # conf.d
popd # /etc/nginx

# Yes this looks a bit dodgy, trust me this is actually ffdhe4096.
cat >/srv/run/ffdhe4096.pem <<EOF
-----BEGIN DH PARAMETERS-----
MIICCAKCAgEA//////////+t+FRYortKmq/cViAnPTzx2LnFg84tNpWp4TZBFGQz
+8yTnc4kmz75fS/jY2MMddj2gbICrsRhetPfHtXV/WVhJDP1H18GbtCFY2VVPe0a
87VXE15/V8k1mE8McODmi3fipona8+/och3xWKE2rec1MKzKT0g6eXq8CrGCsyT7
YdEIqUuyyOP7uWrat2DX9GgdT0Kj3jlN9K5W7edjcrsZCwenyO4KbXCeAvzhzffi
7MA0BM0oNC9hkXL+nOmFg/+OTxIy7vKBg8P+OxtMb61zO7X8vC7CIAXFjvGDfRaD
ssbzSibBsu/6iGtCOGEfz9zeNVs7ZRkDW7w09N75nAI4YbRvydbmyQd62R0mkff3
7lmMsPrBhtkcrv4TCYUTknC0EwyTvEN5RPT9RFLi103TZPLiHnH1S/9croKrnJ32
nuhtK8UiNjoNq8Uhl5sN6todv5pC1cRITgq80Gv6U93vPBsg7j/VnXwl5B0rZp4e
8W5vUsMWTfT7eTDp5OWIV7asfV9C1p9tGHdjzx1VA0AEh/VbpX4xzHpxNciG77Qx
iu1qHgEtnmgyqQdgCpGBMMRtx3j5ca0AOAkpmaMzy4t6Gh25PXFAADwqTs6p+Y0K
zAqCkc3OyX3Pjsm1Wn+IpGtNtahR9EGC4caKAH5eZV9q//////////8CAQI=
-----END DH PARAMETERS-----
EOF

# Make sure nginx is running.
systemctl restart nginx

#################
# CERTBOT SETUP #
#################

# NOTE: THIS WILL NOT WORK IF THE OLD ACCOUNT WAS NOT DEACTIVATED FIRST.
certbot register --email "ncsscoffeerun@gmail.com" --agree-tos --no-eff-email

# Register our cert.
certbot certonly --non-interactive --webroot --domain "$DOMAIN" --webroot-path /srv/wkd

# We now have a certificate -- switch over nginx config!
mv /etc/nginx/conf.d/coffee.conf{.actual,}
systemctl restart nginx

# Make sure we regularly renew certificates.
cat >/etc/systemd/system/certbot-renew.service <<EOF
[Unit]
Description=ACME Certificate Renewal

[Service]
ExecStart=/usr/bin/certbot renew
ExecStartPost=/usr/bin/systemctl reload nginx
EOF

cat >/etc/systemd/system/certbot-renew.timer <<EOF
[Unit]
Description=Timer for ACME Certificate Renewal

[Timer]
OnCalendar=weekly
RandomizedDelaySec=2hour

[Install]
WantedBy=multi-user.target
EOF

# Start the clock!
systemctl daemon-reload
systemctl enable certbot-renew.timer
systemctl start certbot-renew.timer
