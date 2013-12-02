#!/bin/sh
# fetch and process all of the capital bikeshare data

# Copyright (C) 2013 Matthew Wigginton Conway.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#   http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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