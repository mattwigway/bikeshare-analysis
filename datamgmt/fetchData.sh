#!/bin/sh
# fetch and process all of the capital bikeshare data

BASEDIR=$(dirname $0)

wget http://capitalbikeshare.com/assets/files/trip-history-data/2010-4th-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2011-1st-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2011-2nd-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2011-3rd-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2011-4th-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2012-1st-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2012-2nd-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2012-3rd-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2012-4th-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2013-1st-quarter.csv
wget http://capitalbikeshare.com/assets/files/trip-history-data/2013-2nd-quarter.csv

# for the latitude and longitude
wget http://capitalbikeshare.com/data/stations/bikeStations.xml

# merge the csv files
${BASEDIR}/csvMerge.py 201?-???-quarter.csv all-trips-aspatial.csv

# expand the csv file
${BASEDIR}/expandFileWithXY.py all-trips-aspatial.csv bikeStations.xml all-trips.csv