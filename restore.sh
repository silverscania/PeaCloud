
#!/bin/bash

set -x

#Set
source ./settings.sh

do_restore () {
        # Create a rule to move the non manifest and non signature files to glacier
        # after 30 days. The files are prefixed so that an AWS lifecycle rule can be created
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

        SYNC_RESULT=${PIPESTATUS[0]}


}

rm -rf /tmp/restore

do_restore /tmp/restore $AWS_DB_BUCKET
#do_verify /var/www/peecloud/config $AWS_CONFIG_BUCKET
#do_verify /storage $AWS_DATA_BUCKET 




