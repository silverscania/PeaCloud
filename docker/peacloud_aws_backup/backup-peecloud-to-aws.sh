#!/bin/bash

# Make docker stop work without having to resort to SIGKILL
trap 'exit 0' SIGTERM
trap 'exit 0' SIGTRAP

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
        EXTRA_ARGS=$3

	ulimit -n 2048

	# TODO: to be able to interrupt this with "docker stop" it must be run in the 
	# background with & and then "wait $PID". If this process (process 1) receives
	# a signal, it must be forwarded to the duplicity process. Otherwise the normal
	# stop command will time out and end up sending SIGKILL to duplicity.
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
		--allow-source-mismatch \
		$EXTRA_ARGS \
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

			sleepDays=7
			sleepSecondsInterval=5
			sleepLoops=$(( ${sleepDays} * 24 * 60 * 60 / ${sleepSecondsInterval} ))
			echo "Sleep seconds: " ${sleepSeconds}
			echo "Sleep loops: " ${sleepLoops}
			set +x # Don't log 1 million of these lines
			# Sleep in small intervals so that "docker stop" works without killing.
			# Killing is bad because a duplicity upload might be active.
			for ((i=0; i<sleepLoops; i++))
			do
        			sleep ${sleepSecondsInterval}
			done
			set -x # Re-enable logging
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

##
# Stop database and app containers so that there is no data changing
# while backup is happening. Otherwise if you needed to restore it,
# it might be corrupted.
#
stop_containers () {
	# Stop containers (as gracefully as possible 10 mins timeout)
	docker stop --time=600 docker_app_1
	docker stop --time=600 docker_db_1
}

start_containers () {
	docker start docker_db_1
	docker start docker_app_1
}

restore_all () {
	read -p "Restoration will erase everything in the data volumes!! \n \
		Are you sure you wish to continue? (yes)"
	if [ "$REPLY" != "yes" ]; then
   		exit 1
	fi

	stop_containers

	#TODO: not sure whether deleting everything first is a good idea or not?
	#rm -rf ${DB_CONTAINER_VOLUME}/*
	#rm -rf ${APP_CONTAINER_VOLUME}/*
	#rm -rf ${DB_CONTAINER_VOLUME}/*

        # Add force option because folders will be overwritten
	do_sync ${AWS_DB_BUCKET} ${DB_CONTAINER_VOLUME} --force
##	do_sync ${AWS_WWW_DATA_FOLDER_BUCKET} ${APP_CONTAINER_VOLUME} --force 
#	do_sync ${AWS_DATA_BUCKET} /mnt/nextcloud_encrypted/ --force

	start_containers
}

do_duplicity_upload () {
	stop_containers

	#Remove single process lock file, duplicity still keeps a set of previous
	#uploads and manifests in the same dir
	#rm -f /root/.cache/duplicity/*/lockfile.lock
	
	do_sync ${DB_CONTAINER_VOLUME} ${AWS_DB_BUCKET}
	do_sync ${APP_CONTAINER_VOLUME} ${AWS_WWW_DATA_FOLDER_BUCKET}
	do_sync /mnt/nextcloud_encrypted/ $AWS_DATA_BUCKET 

	start_containers
}


# Call the function that does everything
main $1

