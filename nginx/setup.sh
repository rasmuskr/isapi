#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

apt-get install -y nginx-full uwsgi

mkdir -p /run/uwsgi/app/apiis/
chown www-data:www-data /run/uwsgi/app/apiis/

cat << EOF > /etc/nginx/sites-available/isapi.conf
server {
        listen          80;
        server_name     isapi.rasmuskr.dk 10.0.*;
        access_log /var/log/nginx/apiis.access.log;
        error_log /var/log/nginx/apiis.error.log;

        location / {
            include         uwsgi_params;
            uwsgi_pass      unix:/run/uwsgi/app/apiis/apiis.socket;
        }
}
EOF

ln -s /etc/nginx/sites-available/isapi.conf /etc/nginx/sites-enabled/isapi.conf


cat << EOF > /etc/uwsgi/apps-available/isapi.ini
[uwsgi]
vhost = true
socket = /run/uwsgi/app/apiis/apiis.socket
venv = ${DIR}/bin/isapi_venv/
chdir = ${DIR}/isapi
module = isapi
callable = app
EOF

ln -s /etc/uwsgi/apps-available/isapi.ini /etc/uwsgi/apps-enabled/isapi.ini

service uwsgi reload
service nginx reload