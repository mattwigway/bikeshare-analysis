#!/usr/bin/python
# Add X and Y coordinates to a Capital Bikeshare trip history file

# Copyright (C) 2013-2014 Matthew Wigginton Conway.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#   http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import csv
from xml.dom.minidom import parse
from sys import argv
import json
from pyproj import Proj, transform

sourceProj = Proj(init='epsg:4326')
# WGS 84 UTM Zone 18N meters
#destProj = Proj(init='epsg:32618')

# State Plane Minnesota South
#destProj = Proj(init='epsg:26993')

# State Plane CA Zone 3
destProj = Proj(init='epsg:26943')

# process arguments

inCsvFileName = argv[1]
locFileName = argv[2]
outCsvFileName = argv[3]

# Build the station database
stations = dict()

if locFileName[-4:] == '.xml':
    stationFile = parse(locFileName)

    # convenience
    def getTagContents(parent, tagName):
        return station.getElementsByTagName(tagName)[0].firstChild.nodeValue 

    for station in stationFile.getElementsByTagName('station'):
        stId = getTagContents(station, 'terminalName')

        # todo: project
        lat = float(getTagContents(station, 'lat'))
        lon = float(getTagContents(station, 'long'))

        x, y = transform(sourceProj, destProj, lon, lat)

        stations[stId] = dict(
            x=int(round(x)),
            y=int(round(y))
            )

elif locFileName[-4:] == '.csv':
    # niceride format station locations
    inf = csv.DictReader(open(locFileName))
    for line in inf:
        stId = line['Terminal']
        lat = float(line['Latitude'])
        lon = float(line['Longitude'])
    
        x, y = transform(sourceProj, destProj, lon, lat)
    
        stations[stId] = dict(
            x=int(round(x)),
            y=int(round(y))
            )

elif locFileName[-5:] == '.json':
    # Bay Area Bike Share format locations
    stations = json.load(open(locFileName))

    for st in stations['stationBeanList']:
        stId = st['id']
        lat = st['latitude']
        lon = st['longitude']

        x, y = transform(sourceProj, destProj, lon, lat)
    
        stations[str(stId)] = dict(
            x=int(round(x)),
            y=int(round(y))
            )

    # dirty hack for stations which have two ids
    stations['53'] = stations['39']


else:
    print 'unrecognized file extension for spatial data'
    exit(1)

# read CSV
inCsv = csv.DictReader(open(inCsvFileName))
outFieldNames = [n for n in inCsv.fieldnames]
outFieldNames.append('start_x')
outFieldNames.append('start_y')
outFieldNames.append('end_x')
outFieldNames.append('end_y')
outCsv = csv.DictWriter(open(outCsvFileName, 'w'), outFieldNames)
outCsv.writeheader()

unmatched = 0
count = 0

try:
    for row in inCsv:
        try:
            row['start_x'] = stations[row['start_terminal']]['x']
            row['start_y'] = stations[row['start_terminal']]['y']
            row['end_x'] = stations[row['end_terminal']]['x']
            row['end_y'] = stations[row['end_terminal']]['y']

        except KeyError:
            unmatched += 1
            row['start_x'] = ''
            row['start_y'] = ''
            row['end_x'] = ''
            row['end_y'] = ''

        outCsv.writerow(row)

        count += 1
        if count % 50000 == 0:
            print '%s trips processed' % count


finally:
    print '%s / %s trips unmatched' % (unmatched, count)
