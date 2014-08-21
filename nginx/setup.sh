#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

apt-get install -y nginx-full uwsgi uwsgi-plugin-python

mkdir -p /run/uwsgi/app/isapi/
chown www-data:www-data /run/uwsgi/app/isapi/

cat << EOF > /etc/nginx/sites-available/isapi.conf

log_format isapi_log_format '\$remote_addr - \$remote_user [\$time_local] '
        '"\$request" \$status \$body_bytes_sent '
        '"\$http_referer" "\$http_user_agent" '
        '\$request_time \$upstream_response_time \$pipe \$upstream_cache_status';

uwsgi_cache_path /tmp/ngx-cache-isapi/ keys_zone=isapizone:10m;

server {
        listen          80;
        server_name     isapi.rasmuskr.dk localhost;
        access_log /var/log/nginx/isapi.access.log isapi_log_format;
        error_log /var/log/nginx/isapi.error.log;

        gzip              on;
        gzip_buffers      16 8k;
        gzip_comp_level   4;
        gzip_http_version 1.0;
        gzip_min_length   1280;
        gzip_types        *;
        gzip_vary         on;

        uwsgi_cache isapizone;
        uwsgi_cache_lock on;
        uwsgi_ignore_headers Set-Cookie;
        uwsgi_hide_header Set-Cookie;
        uwsgi_cache_use_stale error timeout invalid_header updating;

        location / {
            include         uwsgi_params;
            uwsgi_pass      unix:/run/uwsgi/app/isapi/isapi.socket;
        }
}
EOF

ln -s /etc/nginx/sites-available/isapi.conf /etc/nginx/sites-enabled/isapi.conf

BASEDIR="${DIR}/.."

cat << EOF > /etc/uwsgi/apps-available/isapi.ini
[uwsgi]
plugins = python
vhost = true
socket = /run/uwsgi/app/isapi/isapi.socket
venv = ${BASEDIR}/bin/isapi_venv/
chdir = ${BASEDIR}/isapi/
module = isapi
callable = app
EOF

ln -s /etc/uwsgi/apps-available/isapi.ini /etc/uwsgi/apps-enabled/isapi.ini

service uwsgi restart
service nginx reload


echo "RUN: sudo rm /etc/nginx/sites-enabled/default"
echo "AND RUN: sudo service nginx reload"
echo "to disable the default nginx site"