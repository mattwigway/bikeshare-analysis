#!/bin/bash

# Fetch Census LODES data for the given states
states='dc va md mn ca'
year='2011'
seg='S000' # all jobs, see LODES tech docs
typ='JT00' # all jobs

for state in $states; do
  filename=${state}_wac_${seg}_${typ}_${year}.csv

  # Allow the script to be run with prefetched files
  if [ "$1" != '--no-fetch' ]; then
    url=http://lehd.ces.census.gov/data/lodes/LODES7/${state}/wac/${filename}.gz
    echo fetching $url
    wget $url

    gunzip $filename.gz
    mv $filename $filename.orig
  fi

  # C000: total jobs
  # CNS07: retail jobs
  # CNS18: restaurant + hotel jobs
  # see http://lehd.ces.census.gov/data/lodes/LODES7/LODESTechDoc7.0.pdf, p.8
  csvtool namedcol w_geocode,C000,CNS07,CNS18 $filename.orig |\
    sed -e 1s/C000/total_jobs/ -e 1s/CNS07/retail_jobs/ \
    -e 1s/CNS18/restaurant_hotel_jobs/ >\
     $filename

done
