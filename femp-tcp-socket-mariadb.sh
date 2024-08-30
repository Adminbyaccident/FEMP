#!/bin/sh
# Instructions on how to use this script:
# chmod +x SCRIPTNAME.sh
# sudo ./SCRIPTNAME.sh
#
# SCRIPT: femp-tcp-socket-mariadb.sh
# AUTHOR: ALBERT VALBUENA
# DATE: 28-12-2022
# SET FOR: Beta
# (For Alpha, Beta, Dev, Test and Production)
#
# PLATFORM: FreeBSD 12/13
#
# PURPOSE: This script installs a full FEMP stack with NGINX + MySQL 8 + PHP-FPM configured to read from a TCP socket
#
# REV LIST:
# DATE: 28-12-2022
# BY: ALBERT VALBUENA
# MODIFICATION: 
#
#
# set -n # Uncomment to check your syntax, without execution.
# # NOTE: Do not forget to put the comment back in or
# # the shell script will not execute!

##########################################################
################ BEGINNING OF MAIN #######################
##########################################################

# Change the default pkg repository from quarterly to latest
sed -ip 's/quarterly/latest/g' /etc/pkg/FreeBSD.conf

# Update packages (it will first download the pkg repo from latest)
# secondly it will upgrade any installed packages.
pkg upgrade -y

# Install NGINX
pkg install -y nginx

# Enable NGINX at boot time
sysrc nginx_enable="YES"

# Generate self-signed TLS certificates
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /usr/local/etc/nginx/cert.key -out /usr/local/etc/nginx/cert.pem -subj "/C=US/ST=StateName/L=City/O=Adminbyaccident.com/CN=yoursite.com/emailAddress=somemail@gmail.com"

# Configure NGINX
pkg install -y git
mkdir /tmp/conf
git clone https://github.com/Adminbyaccident/FEMP.git /tmp/conf

rm /usr/local/etc/nginx/nginx.conf
touch /usr/local/etc/nginx/nginx.conf

cp /tmp/conf/base_nginx_tcp_socket.conf /usr/local/etc/nginx/nginx.conf

# Install PHP 8.2
pkg install -y php82 php82-extensions

# Configure PHP
cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini

# Avoid PHP's information (version, etc) being disclosed
sed -i -e '/expose_php/s/expose_php = On/expose_php = Off/' /usr/local/etc/php.ini

# Enable PHP-FPM at boot time
php_fpm_enable="YES"

# Install MariaDB 10.6 LTS
pkg install -y mariadb106-server mariadb106-client

# Add service to be fired up at boot time
sysrc mysql_enable="YES"
sysrc mysql_args="--bind-address=127.0.0.1"

# Install MySQL connector for PHP
pkg install -y php82-mysqli

# Install the 'old fashioned' Expect to automate the mysql_secure_installation part
pkg install -y expect

# Make the 'safe' install for MariaDB
echo "Performing MariaDB secure install"

SECURE_MARIADB=$(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Switch to unix_socket authentication\"
send \"n\r\"
expect \"Change the root password?\"
send \"n\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

echo "$SECURE_MARIADB"

# Start services
service nginx start
service php-fpm start
service mysql-server start

# Remove the content downloaded in /tmp/conf
rm -r /tmp/conf

# Execution end announcement
echo 'The FEMP stack has been installed on this box.'

# EOF
