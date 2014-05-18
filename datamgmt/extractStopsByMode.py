# Extract stops from a GTFS file and write out individual files for different modes

# Copyright (C) 2014 Matthew Wigginton Conway.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#   http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


from zipfile import ZipFile
from sys import argv
from csv import DictReader, DictWriter
import codecs

# Note that we're not including Cable Car in here as it seems to
# qualitatively different from other rail modes in San Francisco
modes = dict(
    bus = (3,), # Bus
    rail = (0, 1, 2) # Tram, Metro, Heavy/Commuter
)

def getModeForType(routeType):
    for mode in modes:
        if routeType in modes[mode]:
            return mode

outfiles = dict()
for mode in modes:
    outfiles[mode] = DictWriter(open(mode + '.csv', 'w'), ('stop_id', 'stop_lat', 'stop_lon', 'stop_name', 'input'))
    outfiles[mode].writeheader()

# Dirty hack to remove BOM from first column name
def fixupBom(reader):
    if reader.fieldnames[0].startswith(codecs.BOM_UTF8):
        reader.fieldnames[0] = reader.fieldnames[0][len(codecs.BOM_UTF8):]
    return reader
    

for filePath in argv[1:]:
    with ZipFile(filePath, 'r') as gtfs:
        print filePath + ':'

        # First, build a mapping of routes to modes
        print '  routes'
        routeModeMap = dict()

        for line in fixupBom(DictReader(gtfs.open('routes.txt'))):
            routeModeMap[line['route_id']] = int(line['route_type'])

        # then a mapping of trips to modes
        print '  trips'
        tripModeMap = dict()
        for line in fixupBom(DictReader(gtfs.open('trips.txt'))):
            tripModeMap[line['trip_id']] = routeModeMap[line['route_id']]

        # save ram
        del routeModeMap

        # Now, load stop data
        # We prefix stop IDs with the file name they came from
        print '  stops'
        prefix = filePath.replace('.zip', '')
        
        stops = dict()
        for line in fixupBom(DictReader(gtfs.open('stops.txt'))):
            stopId = prefix + '_' + line['stop_id']
            stops[stopId] = dict(stop_id = stopId,
                                 stop_lat = float(line['stop_lat']),
                                 stop_lon = float(line['stop_lon']),
                                 stop_name = line['stop_name'],
                                 input = 1
                                 )

        # Now merge them
        print '  stop times'
        stopsByMode = dict()
        for mode in modes:
            stopsByMode[mode] = {}
            
        for line in fixupBom(DictReader(gtfs.open('stop_times.txt'))):
            stopId = prefix + '_' + line['stop_id']
            routeType = tripModeMap[line['trip_id']]

            # some modes are ignored, e.g. cable car
            mode = getModeForType(routeType)
            if mode != None:
                stopsByMode[mode][stopId] = stops[stopId]

        for mode in stopsByMode:
            theFile = outfiles[mode]
            theFile.writerows(stopsByMode[mode].values())
            
