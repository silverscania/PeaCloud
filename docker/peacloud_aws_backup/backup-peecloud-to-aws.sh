#!/bin/bash

set -x

# Cron needs path setting
export PATH=$PATH:/sbin/:/usr/bin/:/bin:/usr/local/bin/

# Source config variables
source ./settings.sh

# Set the names of the volumes that persist everything in peacloud
DB_CONTAINER_VOLUME=/mnt/db_volume
APP_CONTAINER_VOLUME=/mnt/app_volume

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

	ulimit -n 2048
	
	duplicity --s3-use-new-style \
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

	SYNC_RESULT=$?

	if [ $SYNC_RESULT = 0 ]; then
		BODY="$BODY[ PASS ] duplicity upload succeeded uploading to $BUCKET\n"
	else
		BODY="$BODY[ FAIL ] duplicity upload failed uploading to $BUCKET\n"
	fi

	echo "Bucket $BUCKET content after sync is"
	#aws s3 ls --summarize --human-readable --recursive --region ap-south-1 ${BUCKET##*/} | tail -n 2
 
}

do_restore () {
       
	BUCKET=$1
	FOLDER=$2

        ulimit -n 2048

	echo "restore"
	exit 0
        duplicity restore --s3-use-new-style \
                --verbosity i --s3-use-ia \
                --s3-use-multiprocessing \
                --s3-use-server-side-encryption \
                --file-prefix-manifest manifest_ \
                --file-prefix-archive archive_ \
                --file-prefix-signature signature_ \
                --progress \
                --progress-rate 60 \
                $BUCKET \
                $FOLDER \
                2>&1

        SYNC_RESULT=$?
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
	#do_fsck /dev/mapper/ubuntu--peecloud--vg-storage
	#do_fsck /dev/mapper/ubuntu--peecloud--vg-root
	#df -Pkh
	
	case "$1" in
  		"--immediate-backup")
    		do_duplicity_upload
    		;;

		"--restore")
		restore_all
    		;;

		"--weekly-backup")
		while [ 1 ]
		do
			echo "Starting sleep: $(date)"
			sleep 7d
			echo "Finished sleep: $(date)"
			do_duplicity_upload
		done
    		;;

		*)
    		echo "You have failed to specify what to do correctly."
    		exit 1
    		;;
	esac

	#DF="$(df -Pkh)"
	#BODY="${BODY}\n\n\nDisk usage:\n---------------------\n${DF}"
	#echo -e "$BODY" | mail -r "peecloud@peecloud.lan (Trump, Grand King Emporer of PeeCloud and the Holy Lands)" -s "Receieved intergalactic bi-weekly status report from deepspace network..." $EMAIL_RECIPIENT
}

restore_all () {
	read -p "Restoration will erase everything in the data volumes!! \n \
		Are you sure you wish to continue?"
	if [ "$REPLY" != "yes" ]; then
   		exit 1
	fi

	rm -rf ${DB_CONTAINER_VOLUME}/*
#	rm -rf ${DB_CONTAINER_VOLUME}/*
#	rm -rf ${DB_CONTAINER_VOLUME}/*

	#do_restore $AWS_DB_BUCKET
	do_sync ${AWS_DB_BUCKET} ${DB_CONTAINER_VOLUME} 
}

do_duplicity_upload () {
	#Remove single process lock file, duplicity still keeps a set of previous
	#uploads and manifests in the same dir

	#rm -f /root/.cache/duplicity/*/lockfile.lock
	
	do_sync ${DB_CONTAINER_VOLUME} $AWS_DB_BUCKET
	do_sync ${APP_CONTAINER_VOLUME} $AWS_WWW_DATA_FOLDER_BUCKET
	#do_sync /mnt/nextcloud_encrypted/ $AWS_DATA_BUCKET 
}


# Call the function that does everything
main $1

