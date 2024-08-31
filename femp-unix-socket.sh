#!/bin/sh
# Instructions on how to use this script:
# chmod +x SCRIPTNAME.sh
# sudo ./SCRIPTNAME.sh
#
# SCRIPT: femp-unix-socket.sh
# AUTHOR: ALBERT VALBUENA
# DATE: 25-12-2022
# SET FOR: Beta
# (For Alpha, Beta, Dev, Test and Production)
#
# PLATFORM: FreeBSD 12/13
#
# PURPOSE: This script installs a full FEMP stack with NGINX + MySQL 8 + PHP-FPM configured to read from a UNIX socket
#
# REV LIST:
# DATE: 25-12-2022
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

cp /tmp/conf/base_nginx.conf /usr/local/etc/nginx/nginx.conf

# Install PHP 8.2
pkg install -y php82 php82-extensions

# Configure PHP
cp /usr/local/etc/php.ini-production /usr/local/etc/php.ini

# Avoid PHP's information (version, etc) being disclosed
sed -i -e '/expose_php/s/expose_php = On/expose_php = Off/' /usr/local/etc/php.ini

# Configure PHP-FPM
sed -i -e '/9000/s/127.0.0.1:9000/\/var\/run\/php-fpm.sock/' /usr/local/etc/php-fpm.d/www.conf
sed -i -e '/listen.owner/s/;listen.owner/listen.owner/' /usr/local/etc/php-fpm.d/www.conf
sed -i -e '/listen.group/s/;listen.group/listen.group/' /usr/local/etc/php-fpm.d/www.conf
sed -i -e '/listen.mode/s/;listen.mode/listen.mode/' /usr/local/etc/php-fpm.d/www.conf

# Enable PHP-FPM at boot time
sysrc php_fpm_enable="YES"
service php-fpm start

# Install MySQL 8.0
pkg install -y mysql80-server

# Add service to be fired up at boot time
sysrc mysql_enable="YES"
sysrc mysql_args="--bind-address=127.0.0.1"

# Install MySQL connector for PHP
pkg install -y php82-mysqli

# Install the 'old fashioned' Expect to automate the mysql_secure_installation part
pkg install -y expect

# Make the hideous 'safe' install for MySQL
pkg install -y pwgen

# Start MySQL service, otherwise the mysql_secure_installation will fail
service mysql-server start

DB_ROOT_PASSWORD=$(pwgen 32 --secure --numerals --capitalize) && export DB_ROOT_PASSWORD && echo $DB_ROOT_PASSWORD >> /root/db_root_pwd.txt

SECURE_MYSQL=$(expect -c "
set timeout 10
set DB_ROOT_PASSWORD "$DB_ROOT_PASSWORD"
spawn mysql_secure_installation
expect \"Press y|Y for Yes, any other key for No:\"
send \"y\r\"
expect \"Please enter 0 = LOW, 1 = MEDIUM and 2 = STRONG:\"
send \"0\r\"
expect \"New password:\"
send \"$DB_ROOT_PASSWORD\r\"
expect \"Re-enter new password:\"
send \"$DB_ROOT_PASSWORD\r\"
expect \"Do you wish to continue with the password provided?(Press y|Y for Yes, any other key for No) :\"
send \"Y\r\"
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

echo "$SECURE_MYSQL"

# Display the location of the generated root password for MySQL
echo "Your DB_ROOT_PASSWORD is written on this file /root/db_root_pwd.txt"

# No one but root can read this file. Read only permission.
chmod 400 /root/db_root_pwd.txt

# Start services
service nginx start
service php-fpm start
service mysql-server restart

# Remove the content downloaded in /tmp/conf
rm -r /tmp/conf

# Execution end announcement
echo 'The FEMP stack has been installed on this box.'

# EOF
