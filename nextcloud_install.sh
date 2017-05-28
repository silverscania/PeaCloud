#!/bin/sh

# Install ubuntu server 16.04 with LVM paritions. 10GB root partition and remaining
# space mounted on /storage

set -e
set -x

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

#Dependencies
apt-get install apache2 mariadb-server libapache2-mod-php7.0
apt-get install php7.0-gd php7.0-json php7.0-mysql php7.0-curl php7.0-mbstring
apt-get install php7.0-intl php7.0-mcrypt php-imagick php7.0-xml php7.0-zip
apt-get install git python-pip mailutils

#Additional Apache config
a2enmod rewrite
a2enmod headers
a2enmod env
a2enmod dir
a2enmod mime
a2enmod ssl

#Apache site config
cp default-ssl.conf peecloud.conf /etc/apache2/sites-available
rm /etc/apache2/sites-enabled/* 

#Enable sites (make symlinks)
a2ensite default-ssl
a2ensite peecloud

#Checkout repo
cd /var/www
if [ ! -d "peecloud" ]; then
	git clone https://github.com/nextcloud/server.git peecloud 
fi
cd peecloud
git checkout stable11
cd 3rdparty
git submodule update --init

#Set ower for files
cd ..
chmod -R www-data:www-data .

#Start stuff
service apache2 restart

#Setup DNS
apt-get install bind9 dnsutils
cd $SCRIPT_DIR
cp named.conf.local /etc/bind/
cp db.peecloud.lan /etc/bind/
systemctl restart bind9.service

#Ignore lid switch
printf "\nHandleLidSwitch=ignore\n" >> /etc/systemd/logind.conf
service systemd-logind restart

#Setup duplicity
cd $SCRIPT_DIR
tar -xvf duplicity-0.7.12.tar.gz
cd duplicity-0.7.12/
apt-get install rsync librsync-dev python-urllib3 
pip install lockfile
pip install boto
python setup.py install

#Install PeaCloud
cd $SCRIPT_DIR
mkdir /usr/peacloud
echo "You must fill in the settings in /usr/peacloud/settings.sh"
cp *.sh /usr/peacloud
 
#Setup cronjobs
add_cronjob () {
	JOB=$1
	(crontab -l 2>/dev/null; printf "$JOB\n") | crontab -
}
#Don't restart because you need to decrypt the disk
#add_cronjob "#Reboot at 11pm every month\n0 23 1 * * reboot +10"
add_cronjob "#Resume upload at 12am every night\n0 0 2-14,16-31 * * /usr/peacloud/run-and-log.sh /usr/peacloud/weekly-report.sh resume"
add_cronjob "#Full upload at 12am every two weeks\n 0 0 1 * * /usr/peacloud/run-and-log.sh /usr/peacloud/weekly-report.sh force"
add_cronjob "#Full upload at 12am every two weeks\n 0 0 15 * * /usr/peacloud/run-and-log.sh /usr/peacloud/weekly-report.sh force"


#Not using aws sync because it doesn't encrypt filenames
##setup aws cli
#pip install awscli
#aws configure 
## manually enter keys from console
## region: ap-southeast-1

