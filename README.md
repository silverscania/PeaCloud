To Build
==================================
$ cd docker
$ cp peacloud_aws_backup/settings.sh peacloud_aws_backup/mysettings.sh
* Fill out 'mysettings.sh'
* Remove source (.) line from end of mysettings.sh
$ docker-compose build


To Run
=================================

$ ./unencryptDisk.sh
Enter sudo password
Enter disk de-encryption password
$ cd docker
$ docker-compose up -d


To Stop
=================================
$ cd docker
$ docker-compose down -t 600


To Update
=================================
See https://hub.docker.com/_/nextcloud/

$ docker-compose pull app db
$ docker-compose up -d


To Run a Backup Now
=================================
$ cd docker
  Make sure current backup script isn't running
$ docker stop docker_peacloud_aws_backup_1 
  Run backup script in the backup container with the flag to backup now
$ docker-compose run peacloud_aws_backup /backup-peecloud-to-aws.sh --immediate-backup


Troubleshooting
=================================

Error:
	apache2: Could not reliably determine the server's fully qualified domain name

Resolution:
	$ docker exec -it docker_app_1 bash
	$ mkdir /var/httpd
	$ service apache2 restart


Install Crontab as root
================================

$ sudo su
$ crontab -e 

Add these lines:

0 12 * * * {path-to-peacloud}/wondershape-night
0 7  * * * {path-to-peacloud}/wondershape-day  
