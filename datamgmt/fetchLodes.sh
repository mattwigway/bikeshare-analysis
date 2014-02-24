#!/bin/bash

# Fetch Census LODES data for the given states
states='dc va md mn ca'
year='2011'
seg='S000' # all jobs, see LODES tech docs
typ='JT00' # all jobs

for state in $states; do
    filename=${state}_wac_${seg}_${typ}_${year}.csv
    url=http://lehd.ces.census.gov/data/lodes/LODES7/${state}/wac/${filename}.gz
    echo fetching $url
    wget $url
    gunzip $filename.gz
    mv $filename $filename.orig
    csvtool namedcol w_geocode,C000 $filename.orig > $filename
done