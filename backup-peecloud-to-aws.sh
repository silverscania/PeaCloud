#!/bin/bash

set -x

# Cron needs path setting
export PATH=$PATH:/sbin/:/usr/bin/:/bin:/usr/local/bin/

# Source config variables
source /usr/peacloud/settings.sh

# Set the names of the containers that the docker volumes are extracted from
DB_CONTAINER_NAME=docker_db_1
APP_CONTAINER_NAME=docker_app_1

BODY="Bi-weekly status report:\n----------------------------\n\n"

do_fsck () {
	#1st arg is partition name
	PARTITION=$1
	FSCK_RESULT="$(fsck -nv $PARTITION 2>&1)"
	if [ $? -ne 0 ]; then
		BODY="$BODY[ FAIL ] fsck of partition $PARTITION failed with code: $?\n"
		BODY="${BODY}${FSCK_RESULT}"
	else
		BODY="$BODY[ PASS ] fsck of partition $PARTITION was a-ok :)\n"
		#BODY=${BODY}${FSCK_RESULT}
	fi	
}

       
do_sync () {
	# Create a rule to move the non manifest and non signature files to glacier
	# after 30 days. The files are prefixed so that an AWS lifecycle rule can be created
	FOLDER=$1
	BUCKET=$2
	FULL=$3

	ulimit -n 2048
	TIMEOUT_RET_CODE=124 # Timeout function returns 124 in the event of a timeout

	#Timout default signal is fine, seems to be able to resume after sigterm
	timeout $UPLOAD_TIMEOUT duplicity --s3-use-new-style \
		--verbosity i --s3-use-ia \
		--s3-use-multiprocessing \
		--s3-use-server-side-encryption \
		--file-prefix-manifest manifest_ \
		--file-prefix-archive archive_ \
		--file-prefix-signature signature_ \
		--volsize=1000 \
		--progress \
		--progress-rate 60 \
		$FOLDER \
		$BUCKET \
		2>&1

	SYNC_RESULT=${PIPESTATUS[0]}

	if [ $SYNC_RESULT = $TIMEOUT_RET_CODE ]; then
		BODY="$BODY[ PASS ] duplicity upload timed out uploading to $BUCKET\n"
	elif [ $SYNC_RESULT = 0 ]; then
		BODY="$BODY[ PASS ] duplicity upload succeeded uploading to $BUCKET\n"
	else
		BODY="$BODY[ FAIL ] duplicity upload failed uploading to $BUCKET\n"
	fi

	echo "Bucket $BUCKET content after sync is"
	aws s3 ls --summarize --human-readable --recursive --region ap-south-1 ${BUCKET##*/} | tail -n 2
 
}

# Export docker volume
# This is the excerpt from the docker docs:
# 
# Backup, restore, or migrate data volumes
#
# Another useful function we can perform with volumes is use them for backups, restores or 
# migrations. You do this by using the --volumes-from flag to create a new container that 
# mounts that volume, like so:
# $ docker run --rm --volumes-from dbstore -v $(pwd):/backup ubuntu tar cvf /backup/backup.tar /dbdata
# Here you’ve launched a new container and mounted the volume from the dbstore container. 
# You’ve then mounted a local host directory as /backup. Finally, you’ve passed a command 
# that uses tar to backup the contents of the dbdata volume to a backup.tar file inside our 
# /backup directory. When the command completes and the container stops we’ll be left with 
# a backup of our dbdata volume.
# You could then restore it to the same container, or another that you’ve made elsewhere. Create a new container.
# $ docker run -v /dbdata --name dbstore2 ubuntu /bin/bash
#
# Then un-tar the backup file in the new container`s data volume.
# 
# $ docker run --rm --volumes-from dbstore2 -v $(pwd):/backup ubuntu bash -c "cd /dbdata && tar xvf /backup/backup.tar --strip 1"
# 
# You can use the techniques aboveh to automate backup, migration and restore testing using your preferred tools.
export_docker_volumes () {
	# Remove folder so files that are deleted don't get backed up
	DUMP_DEST_FOLDER=/tmp/backupdump
	rm -rf $DUMP_DEST_FOLDER

	# dump /var/lib/mysql from docker_db_1 container to /tmp/backupdump/mysql folder
	# to find where the volume is mounted do, look in the docker-compose yaml file
	# in the db container the docker volume is mounted to /var/lib/mysql so thats all we 
	# need to backup
	# --rm means that this container is deleted after running
	docker run --rm --volumes-from ${DB_CONTAINER_NAME} -v ${DUMP_DEST_FOLDER}:/backup ubuntu \
	cp -r /var/lib/mysql /backup/


	docker run --rm --volumes-from ${APP_CONTAINER_NAME} -v ${DUMP_DEST_FOLDER}:/backup ubuntu \
        cp -r /var/www/html /backup/

}

# Main function does the following things:
# 
# * Check health of disks
# * Check storage space remaining
# * Stops nextcloud container (docker-compose down)
# * Exports the database container
# * Restarts the nextcloud container
# * Uploads the database backup to aws
# * Uploads the data partition to aws (container doesn't need to be down for this because it's not a docker volume, just a filesystem)
#
# It has to sleep for 5 days rather than being scheduled by cron because an upload might take more
# than 5 days. Another way to do this would be by using a lock file.
#
# TODO: find a better way of reporting because email from a home IP is impossible. (Gets blocked by Google etc.)
#
main () {
	do_fsck /dev/mapper/ubuntu--peecloud--vg-storage
	do_fsck /dev/mapper/ubuntu--peecloud--vg-root
	df -Pkh

	do_db_dump
	do_duplicity_upload

	#DF="$(df -Pkh)"
	#BODY="${BODY}\n\n\nDisk usage:\n---------------------\n${DF}"
	#echo -e "$BODY" | mail -r "peecloud@peecloud.lan (Trump, Grand King Emporer of PeeCloud and the Holy Lands)" -s "Receieved intergalactic bi-weekly status report from deepspace network..." $EMAIL_RECIPIENTS

	echo "Finished upload, starting sleep: $(date)"
	sleep 5d
	echo "Finished sleep: $(date)"
}

do_duplicity_upload () {
	pkill -f "local/bin/duplicity"
	#Remove single process lock file, duplicity still keeps a set of previous
	#uploads and manifests in the same dir

	rm -f /root/.cache/duplicity/*/lockfile.lock
	
	do_sync /tmp/peacloud-sqlbkp.bak $AWS_DB_BUCKET
	do_sync /var/www/peecloud/config $AWS_CONFIG_BUCKET
	do_sync /storage $AWS_DATA_BUCKET 
}

# Call the function that does everything
#main

export_docker_volumes
