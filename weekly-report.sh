#!/bin/sh

#set -x

#Set
source /var/peacloud/settings.sh

rm -f /tmp/peecloud-sync-result*

BODY="Bi-weekly status report:\n----------------------------\n\n"

do_fsck () {
	#1st arg is partition name
	PARTITION=$1
	FSCK_RESULT="$(fsck -nv $PARTITION 2>&1)"
	if [ $? -ne 0 ]; then
		BODY=$BODY"[ FAIL ] fsck of partition $PARTITION failed with code: $?\n"
		BODY=${BODY}${FSCK_RESULT}
	else
		BODY=$BODY"[ PASS ] fsck of partition $PARTITION was a-ok :)\n"
		#BODY=${BODY}${FSCK_RESULT}
	fi	
}

TMP_FILE=$(mktemp /tmp/peecloud-sync-result-XXXX.txt)
       
do_sync () {
	# Create a rule to move the non manifest and non signature files to glacier
	# after 30 days. The files are prefixed so that an AWS lifecycle rule can be created
	FOLDER=$1
	BUCKET=$2
	ulimit -n 2048
	
	SYNC_RESULT="$(duplicity --s3-use-new-style \
		--verbosity i --s3-use-ia \
		--s3-use-multiprocessing \
		--s3-use-server-side-encryption \
		--file-prefix-manifest manifest_ \
		--file-prefix-archive archive_ \
		--file-prefix-signature signature_ \
		$FOLDER \
		$BUCKET \
		2>&1)"
	printf $SYNC_RESULT
	printf $SYNC_RESULT >> $TMP_FILE
							
}

#do_fsck /dev/mapper/ubuntu--peecloud--vg-storage
#do_fsck /dev/mapper/ubuntu--peecloud--vg-root

#do_sync . $AWS_DATA_BUCKET
#do_sync /tmp/db-backup $AWS_DB_BUCKET

DF="$(df -Pkh)"
#DF="$(df -PTh | column -t | sort -n -k6n)"
BODY="${BODY}\nDisk usage:\n---------------------\n${DF}"

echo "$DF"
echo $BODY
echo "$BODY" | mail -a $TMP_FILE -r "peecloud@peecloud.lan (Trump, Grand King Emporer of PeeCloud and the Holy Lands)" -s "Receieved intergalactic bi-weekly status report from deepspace network..." $EMAIL_RECIPIENTS
#fsck -nv /dev/mapper/ubuntu--peecloud--vg-root

