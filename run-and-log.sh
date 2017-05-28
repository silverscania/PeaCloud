#!/bin/bash

#Runs a script and pipes all output to a dated log file
LOG_FILE="/usr/peacloud/results/$(date +%y.%m.%d-%X).log"

$@ 2>&1 | /usr/bin/tee $LOG_FILE
