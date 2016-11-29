#!/bin/bash

echo "Install Ansible"

#Steps to Install Ansible & Run Playbook

echo "1. Add the repository in the server:"

    sudo apt-add-repository ppa:ansible/ansible -y

echo "2. Install the package"

    sudo apt-get update && sudo apt-get install ansible -y

echo "3. Delete all the entry inside /etc/ansible/ folder"

cd /etc/
rm -rf ansible

echo "Install git"
apt-get install git

echo "clone the repository"
git clone https://github.com/KeerthigaKrishnan/ansible_lamp_playbook.git /tmp

echo "Copy ansible folder /tmp"
cp -pr /tmp/ansible /etc

database_name="test"
mysql_password="MYPASSWORD123"
cat /etc/mysql/debian.cnf  | grep password | awk 'NR==1{print $3};' > /var/mysql/dump.passwrord

echo "Installing Apache2,PHP,Mysql"
echo "Installation through ansible playbook"
echo "Playbook Installs LAMP"

ansible-playbook /etc/ansible/lamp.yml

if [$? -ne 0 ]; then
echo "Rolling back to Previous Versions/ Mention the Previous Version"
apt-get install apache2 apache2-doc apache2-mpm-prefork apache2-utils -y
apt-get install libapache2-mod-php5.5 php5.5 php5.5-common php5.5-curl php5.5-dev php5.5-gd php5.5-idn php-pear php5.5-imagick php5.5-mcrypt php5.5-mysql -y

#The following commands set the MySQL root password to MYPASSWORD123 when you install the mysql-server package.
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password $mysql_password'
sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password $mysql_password'
sudo apt-get -y install mysql-server
fi

echo "Downloads Git repository and clone the repository and create drupal database"
ansible-playbook /etc/ansible/drupal.yml

echo -e "\n"

service apache2 restart && service mysql restart > /dev/null

echo "cloning the database from git repository"
git clone https://github.com/KeerthigaKrishnan/ansible_lamp_playbook.git /var/mysql/

echo "Importing drupal Database"
mysql -u debian-sys-maint -h localhost -p'`cat /var/mysql/dump.passwrord`' drupal < /var/mysql/newdatabase.sql

echo "Mysql Replication Setup"
echo "Configure Mysql master server the my.cnf configuration"

echo "Append this line under mysqld"
sed -i '/\[mysqld\]/a server-id = 1' /etc/mysql/my.cnf
sed -i  '/\[mysqld\]/a log_bin = /var/log/mysql/mysql-bin.log' /etc/mysql/my.cnf
sed -i '/\[mysqld\]/a binlog_do_db=test' /etc/mysql/my.cnf

echo "RESTART THE MYSQL SERVICE"

sudo service mysql restart

echo "Grant Privilege to slave"

mysql -u debian-sys-maint -h localhost -p`cat /var/mysql/dump.passwrord` -e "GRANT REPLICATION SLAVE ON *.* TO 'slave_user'@'%' IDENTIFIED BY 'password'; FLUSH PRIVILEGES";

echo "Master Status"

mysql -u debian-sys-maint -h localhost -p`cat /var/mysql/dump.passwrord` -e " use newdatabase; FLUSH TABLES WITH READ LOCK;SHOW MASTER STATUS;"

echo "Dump the Database"
mysqldump -u root -p --opt newdatabase > /var/mysql/newdatabase.sql

mysql -u debian-sys-maint -h localhost -p`cat /var/mysql/dump.passwrord` -e "use newdatabase;UNLOCK TABLES;"


echo "copy the master database dump to all slave server"

for i in `cat /root/slave_ip_servers`
do
scp root@$i:/var/mysql/newdatabase.sql /var
done

echo "Configure Slave Server"

servers=`cat /root/slave_ip_servers`

for j in `cat /root/slave_ip_servers`
do
ssh root@$j "mysql -u debian-sys-maint -h localhost -p`cat /var/mysql/dump.passwrord` -e "create database newdatabase";echo "Restore the dump" ; mysql -u root -p newdatabase < /var/newdatabase.sql"

ssh root@$servers "sudo sed -i '/\[mysqld\]/a server-id = 2' /etc/mysql/my.cnf;sudo sed -i  '/\[mysqld\]/a log_bin = /var/log/mysql/mysql-bin.log' /etc/mysql/my.cnf;sudo sed -i '/\[mysqld\]/a binlog_do_db=test' /etc/mysql/my.cnf; sudo service mysqld restart;"
done

echo "Slave replication Configuration"

ansible-playbook /etc/ansible/master-slave.yml












