##!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd ${DIR}

apt-get install -y wget

wget -O - http://packages.elasticsearch.org/GPG-KEY-elasticsearch | apt-key add -

echo "deb http://packages.elasticsearch.org/elasticsearch/1.1/debian stable main" | sudo tee /etc/apt/sources.list.d/elasticsearch.list

apt-get update
apt-get install elasticsearch
update-rc.d elasticsearch defaults 95 10


mkdir -p ${DIR}/../data/elasticsearch/
sudo chmod 777 ${DIR}/../data/elasticsearch/

cat << EOF > /etc/elasticsearch/elasticsearch.yml
cluster.name: rasmuskrdk_logging
network.host: 127.0.0.1
# path.data: ${DIR}/../data/elasticsearch/
EOF

apt-get install -y openjdk-7-jdk

service elasticsearch start

mkdir -p ${DIR}/../bin/

apt-get install -y git npm nodejs

cd ${DIR}/../bin/
git clone https://github.com/fangli/kibana-authentication-proxy
cd kibana-authentication-proxy/
git submodule init
git submodule update
npm install


cd kibana
git checkout master
git pull
cd ..


cat << EOF > /etc/init.d/kibana
#!/bin/sh
### BEGIN INIT INFO
# Provides:          
# Required-Start:    \$remote_fs \$syslog
# Required-Stop:     \$remote_fs \$syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO

dir="${DIR}/../bin/kibana-authentication-proxy/"
user="root"
cmd="nodejs app.js"

name=\`basename \$0\`
pid_file="/var/run/\$name.pid"
stdout_log="/var/log/\$name.log"
stderr_log="/var/log/\$name.err"

get_pid() {
    cat "\$pid_file"    
}

is_running() {
    [ -f "\$pid_file" ] && ps \`get_pid\` > /dev/null 2>&1
}

case "\$1" in
    start)
    if is_running; then
        echo "Already started"
    else
        echo "Starting \$name"
        cd "\$dir"
        sudo -u "\$user" \$cmd >> "\$stdout_log" 2>> "\$stderr_log" &
        echo \$! > "\$pid_file"
        if ! is_running; then
            echo "Unable to start, see \$stdout_log and \$stderr_log"
            exit 1
        fi
    fi
    ;;
    stop)
    if is_running; then
        echo -n "Stopping \$name.."
        kill \`get_pid\`
        for i in {1..10}
        do
            if ! is_running; then
                break
            fi
            
            echo -n "."
            sleep 1
        done
        echo
        
        if is_running; then
            echo "Not stopped; may still be shutting down or shutdown may have failed"
            exit 1
        else
            echo "Stopped"
            if [ -f "\$pid_file" ]; then
                rm "\$pid_file"
            fi
        fi
    else
        echo "Not running"
    fi
    ;;
    restart)
    \$0 stop
    if is_running; then
        echo "Unable to stop, will not attempt to start"
        exit 1
    fi
    \$0 start
    ;;
    status)
    if is_running; then
        echo "Running"
    else
        echo "Stopped"
        exit 1
    fi
    ;;
    *)
    echo "Usage: \$0 {start|stop|restart|status}"
    exit 1
    ;;
esac

exit 0
EOF

chmod +x /etc/init.d/kibana

cat << EOF > ${DIR}/../bin/kibana-authentication-proxy/config.js
module.exports =  {

    ////////////////////////////////////
    // ElasticSearch Backend Settings
    ////////////////////////////////////
    "es_host": "127.0.0.1",  // The host of Elastic Search
    "es_port": 9200,  // The port of Elastic Search
    "es_using_ssl": false,  // If the ES is using SSL(https)?
    "es_username":  "",  // The basic authentication user of ES server, leave it blank if no basic auth applied
    "es_password":  "",  // The password of basic authentication of ES server, leave it blank if no basic auth applied.


    ////////////////////////////////////
    // Proxy server configurations
    ////////////////////////////////////
    // Which port listen to
    "listen_port": 9201,
    // Control HTTP max-Age header. Whether the browser cache static kibana files or not?
    // 0 for no-cache, unit in millisecond, default to 0
    // We strongly recommand you set to a larger number such as 2592000000(a month) to get a better loading speed
    "brower_cache_maxage": 0,
    // Enable SSL protocol
    "enable_ssl_port": false,
        // The following settings are valid only when enable_ssl_port is true
        "listen_port_ssl": 4443,
        // Use absolute path for the key file
        "ssl_key_file": "POINT_TO_YOUR_SSL_KEY",
        // Use absolute path for the certification file
        "ssl_cert_file": "POINT_TO_YOUR_SSL_CERT",

    // The ES index for saving kibana dashboards
    // default to "kibana-int"
    // With the default configuration, all users will use the same index for kibana dashboards settings,
    // But we support using different kibana settings for each user.
    // If you want to use different kibana indices for individual users, use %user% instead of the real username
    // Since we support multiple authentication types(google, cas or basic), you must decide which one you gonna use.

    // Bad English:D
    // For example:
    // Config "kibana_es_index": "kibana-int-for-%user%", "which_auth_type_for_kibana_index": "basic"
    // will use kibana index settings like "kibana-int-for-demo1", "kibana-int-for-demo2" for user demo1 and demo2.
    // in this case, if you enabled both Google Oauth2 and BasicAuth, and the username of BasicAuth is the boss.
    "kibana_es_index": "kibana-int", // "kibana-int-%user%"
    "which_auth_type_for_kibana_index": "cas", // google, cas or basic

    ////////////////////////////////////
    // Security Configurations
    ////////////////////////////////////
    // Cookies secret
    // Please change the following secret randomly for security.
    "cookie_secret": "AS1234asdfnndfoertj12ASDFASD",


    ////////////////////////////////////
    // Kibana3 Authentication Settings
    // Currently we support 3 different auth methods: Google OAuth2, Basic Auth and CAS SSO.
    // You can use one of them or both
    ////////////////////////////////////


    // =================================
    // Google OAuth2 settings
    // Enable? true or false
    // When set to false, google OAuth will not be applied.
    "enable_google_oauth": false,
        // We use the following redirect URI:
        // http://YOUR-KIBANA-SITE:[listen_port]/auth/google/callback
        // Please add it in the google developers console first.
        // The client ID of Google OAuth2
        "client_id": "",
        "client_secret": "",  // The client secret of Google OAuth2
        "allowed_emails": ["rasmuskr@gmail.com"],  // An emails list for the authorized users


    // =================================
    // Basic Authentication Settings
    // The following config is different from the previous basic auth settings.
    // It will be applied on the client who access kibana3.
    // Enable? true or false
    "enable_basic_auth": true,
        // Multiple user/passwd supported
        // The User&Passwd list for basic auth
        "basic_auth_users": [
            {"user": "loguser", "password": "logpass"},
            // {"user": "demo1", "password": "pwd2"},
        ],


    // =================================
    // CAS SSO Login
    // Enable? true or false
    "enable_cas_auth": false,
        // Point to the CAS authentication URL
        "cas_server_url": "https://point-to-the-cas-server/cas",
        // CAS protocol version, one of 1.0 or 2.0
        "cas_protocol_version": 1.0,
};
EOF

update-rc.d kibana defaults 95 10

service kibana start


#####################################################################################

# Grant access so logstash can read the folder
chmod 755 /var/log/nginx/
chmod chmod o+r /var/log/nginx/*

usermod -aG adm logstash

echo "deb http://packages.elasticsearch.org/logstash/1.3/debian stable main" | sudo tee /etc/apt/sources.list.d/logstash.list

apt-get update

apt-get install -y logstash


sed -i '/START=no/c\START=yes' /etc/default/logstash


cat << EOF > /etc/logstash/conf.d/90_elasticsearch_out.conf
output {
  elasticsearch_http {
    host => "127.0.0.1"
  }
}
EOF


cat << EOF > /etc/logstash/conf.d/20_nginx_api_acess.conf
input {
 file {
   type => "nginx_api_access"
   path => ["/var/log/nginx/*.log"]
   exclude => ["*.gz", "error.*"]
   discover_interval => 10
   start_position => "beginning"
 }
}

filter {
 grok {
   match => [ "message", "%{COMBINEDAPACHELOG}(?: %{DATA:request_time})(:? %{DATA:upstream_response_time})(:? %{DATA:pipe})(:? %{WORD:upstream_cache_status})" ]
 }
 geoip {
   add_tag => [ "geoip" ]
   source => "clientip"
 }
 date {
      match => [ "timestamp", "dd/MMM/yyyy:HH:mm:ss Z" ]
      add_tag => [ "tsmatch" ]
 }
}
EOF


update-rc.d logstash defaults 95 10

service logstash start





