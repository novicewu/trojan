#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: CentOS 6+/Debian 6+/Ubuntu 18.04+
#	Description: Install the Trojan server
#	Version: 0.0.1
#	Author: novice
#=================================================


# Modify System Variables
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# Install Trojan
apt --fix-broken -y install python-pycurl python-apt
add-apt-repository -y ppa:greaterfire/trojan
apt update
apt -y install trojan

# Create Certificate
apt -y install gnutls-bin gnutls-doc
echo && read -e -p "请输入服务器IP地址: " IP
echo -e "cn = \"$IP\"
organization = \"Trojan\"
serial = 1
expiration_days = 3650
ca
signing_key
cert_signing_key
crl_signing_key" >/etc/ca-certificates/ca.tmpl

# Creat CA Key
cd /etc/ca-certificates
certtool --generate-privkey --outfile ca-key.pem

# Create CA Certificate
certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem

# Create Server Certificate Template
echo -e "cn = \"$IP\"
organization = \"Trojan\"
expiration_days = 3650
signing_key
encryption_key
tls_www_server" >/etc/ca-certificates/server.tmpl

# Create Sever Key
certtool --generate-privkey --outfile server-key.pem

# Create Server Certificate
certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem

# Server Config
echo && read -e -p "请设置密码: " passwd
echo -e "{
    \"run_type\": \"server\",
    \"local_addr\": \"0.0.0.0\",
    \"local_port\": 443,
    \"remote_addr\": \"127.0.0.1\",
    \"remote_port\": 80,
    \"password\": [
        \"$passwd\"
    ],
    \"log_level\": 1,
    \"ssl\": {
        \"cert\": \"/etc/ca-certificates/server-cert.pem\",
        \"key\": \"/etc/ca-certificates/server-key.pem\",
        \"key_password\": \"\",
        \"cipher\": \"ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256\",
        \"prefer_server_cipher\": true,
        \"alpn\": [
            \"http/1.1\"
        ],
        \"reuse_session\": true,
         \"session_timeout\": 300,
         \"curves\": \"\",
         \"sigalgs\": \"\",
        \"dhparam\": \"\"
       }
}" > /etc/trojan/config.json

#Create Trojan Service
echo -e "[Unit]
After=network.target 

[Service]
ExecStart=/usr/bin/trojan /etc/trojan/config.json
Restart=always

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/trojan.service

#Start Trojan Service
systemctl start trojan
echo -e "Trojan Installation Complete!"

