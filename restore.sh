#!/bin/bash

set -x

. ./settings.sh

do_restore () {
        FOLDER=$1
        BUCKET=$2

        ulimit -n 2048

        # --compare-data \

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

rm -rf /tmp/restore

do_restore /tmp/restore/mysql $AWS_DB_BUCKET
#do_verify /var/www/peecloud/config $AWS_CONFIG_BUCKET
#do_verify /storage $AWS_DATA_BUCKET 




