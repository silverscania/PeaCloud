#!/bin/bash

set -x

#Cron needs path setting
export PATH=$PATH:/sbin/:/usr/bin/:/bin:/usr/local/bin/

#Set
source /usr/peacloud/settings.sh

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

do_db_dump () {
	mysqldump --single-transaction -h localhost -u peecloud -ppassword nextcloud > /tmp/peacloud-sqlbkp.bak
}

resume_upload () {
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

resume_upload

