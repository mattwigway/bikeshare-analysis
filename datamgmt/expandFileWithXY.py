#!/usr/bin/python
# Add X and Y coordinates to a Capital Bikeshare trip history file
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

import csv
from xml.dom.minidom import parse
from sys import argv

# process arguments

inCsvFileName = argv[1]
xmlFileName = argv[2]
outCsvFileName = argv[3]

# Build the station database
stationFile = parse(xmlFileName)

stations = dict()

# convenience
def getTagContents(parent, tagName):
    return station.getElementsByTagName(tagName)[0].firstChild.nodeValue 

for station in stationFile.getElementsByTagName('station'):
    stId = getTagContents(station, 'terminalName')

    # todo: project
    lat = float(getTagContents(station, 'lat'))
    lon = float(getTagContents(station, 'long'))

    stations[stId] = dict(
        x=lon,
        y=lat
        )

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
