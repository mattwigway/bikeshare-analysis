#!/bin/bash

for i in $@; do
    echo "###############################################"
    echo Processing file "$i"
    echo "###############################################"
    ~/OpenTripPlanner/otp-batch-analyst $i
done;