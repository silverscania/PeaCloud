#!/bin/bash

#Cron needs path setting
export PATH=$PATH:/sbin/:/usr/bin/:/bin:/usr/local/bin/

#Runs a script and pipes all output to a dated log file
LOG_FILE="/usr/peacloud/results/$(date +%y.%m.%d-%X).log"
echo "Log and run $@\n" >> $LOG_FILE
$@ 2>&1 | /usr/bin/tee -a $LOG_FILE
