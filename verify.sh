#!/bin/bash

set -x

#Cron needs path setting
export PATH=$PATH:/sbin/:/usr/bin/:/bin:/usr/local/bin/

#Set
source /usr/peacloud/settings.sh

do_verify () {
        # Create a rule to move the non manifest and non signature files to glacier
        # after 30 days. The files are prefixed so that an AWS lifecycle rule can be created
        FOLDER=$1
        BUCKET=$2

        ulimit -n 2048

	# --compare-data \

	duplicity verify --s3-use-new-style \
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

        SYNC_RESULT=${PIPESTATUS[0]}


}

#do_verify /tmp/peacloud-sqlbkp.bak $AWS_DB_BUCKET
#do_verify /var/www/peecloud/config $AWS_CONFIG_BUCKET
do_verify /storage $AWS_DATA_BUCKET 

