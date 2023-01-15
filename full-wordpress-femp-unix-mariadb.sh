#!/bin/sh
# Instructions on how to use this script:
# chmod +x SCRIPTNAME.sh
# sudo ./SCRIPTNAME.sh
#
# SCRIPT: full-wordpress-femp-unix-mariadb.sh
# AUTHOR: ALBERT VALBUENA
# DATE: 28-12-2022
# SET FOR: Beta
# (For Alpha, Beta, Dev, Test and Production)
#
# PLATFORM: FreeBSD 12/13
#
# PURPOSE: This script installs a full FEMP stack with NGINX + MySQL 8 + PHP-FPM configured to read from a UNIX socket
#
# REV LIST:
# DATE: 28-12-2022
# BY: ALBERT VALBUENA
# MODIFICATION: 28-12-2022
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

# Install MariaDB 10.6 LTS
pkg install -y mariadb106-server mariadb106-client

# Add service to be fired up at boot time
sysrc mysql_enable="YES"
sysrc mysql_args="--bind-address=127.0.0.1"

# Start MariaDB
service mysql-server start

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

# Remove the content downloaded in /tmp/conf
rm -r /tmp/conf

# Execution end announcement
echo 'The FEMP stack has been installed on this box.'
echo 'WordPress install begins now'

# Create the database and user. Mind this is MariaDB.
pkg install -y pwgen

touch /root/new_db_name.txt
touch /root/new_db_user_name.txt
touch /root/newdb_pwd.txt

echo "Generating new database, username and passoword for the WordPress install"

NEW_DB_NAME=$(pwgen 8 --secure --numerals --capitalize) && export NEW_DB_NAME && echo $NEW_DB_NAME >> /root/new_db_name.txt

NEW_DB_USER_NAME=$(pwgen 10 --secure --numerals --capitalize) && export NEW_DB_USER_NAME && echo $NEW_DB_USER_NAME >> /root/new_db_user_name.txt

NEW_DB_PASSWORD=$(pwgen 32 --secure --numerals --capitalize) && export NEW_DB_PASSWORD && echo $NEW_DB_PASSWORD >> /root/newdb_pwd.txt

NEW_DATABASE=$(expect -c "
set timeout 10
spawn mysql -u root -p
expect \"Enter password:\"
send \"\r\"
expect \"root@localhost \[(none)\]>\"
send \"CREATE DATABASE $NEW_DB_NAME;\r\"
expect \"root@localhost \[(none)\]>\"
send \"CREATE USER '$NEW_DB_USER_NAME'@'localhost' IDENTIFIED BY '$NEW_DB_PASSWORD';\r\"
expect \"root@localhost \[(none)\]>\"
send \"GRANT ALL PRIVILEGES ON $NEW_DB_NAME.* TO '$NEW_DB_USER_NAME'@'localhost';\r\"
expect \"root@localhost \[(none)\]>\"
send \"FLUSH PRIVILEGES;\r\"
expect \"root@localhost \[(none)\]>\"
send \"exit\r\"
expect eof
")

echo "$NEW_DATABASE"

# Install PHP packages for Wordpress
pkg install -y	php82\
		php82-bcmath\
		php82-bz2\
		php82-ctype\
		php82-curl\
		php82-dom\
		php82-exif\
		php82-extensions\
		php82-fileinfo\
		php82-filter\
		php82-ftp\
		php82-gd\
		php82-iconv\
		php82-intl\
		php82-mbstring\
		php82-mysqli\
		php82-opcache\
		php82-pdo\
		php82-pdo_mysql\
		php82-pdo_sqlite\
		php82-pecl-mcrypt\
		php82-phar\
		php82-posix\
		php82-session\
		php82-simplexml\
		php82-soap\
		php82-sockets\
		php82-sqlite3\
		php82-tokenizer\
		php82-xml\
		php82-xmlreader\
		php82-xmlwriter\
		php82-zip\
		php82-zlib

# Reload PHP-FPM so it acknowledges the recently installed PHP packages
service php-fpm reload

# Fetch Wordpress from the official site
fetch -o /root https://wordpress.org/latest.tar.gz

# Unpack Wordpress
tar -zxf /root/latest.tar.gz -C /root

# Create the main config file from the sample
cp /root/wordpress/wp-config-sample.php /root/wordpress/wp-config.php

# Add the database name into the wp-config.php file
NEW_DB=$(cat /root/new_db_name.txt) && export NEW_DB
sed -i -e 's/database_name_here/'"$NEW_DB"'/g' /root/wordpress/wp-config.php

# Add the username into the wp-config.php file
USER_NAME=$(cat /root/new_db_user_name.txt) && export USER_NAME
sed -i -e 's/username_here/'"$USER_NAME"'/g' /root/wordpress/wp-config.php

# Add the db password into the wp-config.php file
PASSWORD=$(cat /root/newdb_pwd.txt) && export PASSWORD
sed -i -e 's/password_here/'"$PASSWORD"'/g' /root/wordpress/wp-config.php

# Add the socket where MariaDB is running
sed -i -e 's/localhost/localhost:\/var\/run\/mysql\/mysql.sock/g' /root/wordpress/wp-config.php

# Create a directory for the WordPress site
mkdir /usr/local/www/sites

# Move the content of the wordpress file into the DocumentRoot path
cp -r /root/wordpress/* /usr/local/www/sites/

# Change the ownership of the DocumentRoot path content from root to the Apache HTTP user (named www)
chown -R www:www /usr/local/www/sites/

# No one but root can read these files. Read only permissions.
chmod 400 /root/db_root_pwd.txt
chmod 400 /root/new_db_name.txt
chmod 400 /root/new_db_user_name.txt
chmod 400 /root/newdb_pwd.txt

# Display the new database, username and password generated on MySQL to accomodate WordPress
echo "Your NEW_DB_NAME is written on this file /root/new_db_name.txt"
echo "Your NEW_DB_USER_NAME is written on this file /root/new_db_user_name.txt"
echo "Your NEW_DB_PASSWORD is written on this file /root/newdb_pwd.txt"

# Actions on the CLI are now finished.
echo 'Actions on the CLI are now finished. Please visit the ip/domain of the site with a browser and proceed with the final install steps.'

echo 'Remember to add random keys in wp-config.php using this link to create them: https://api.wordpress.org/secret-key/1.1/salt/'

# EOF
