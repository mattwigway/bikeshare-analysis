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

from sys import argv
import csv
from xml.dom.minidom import parse
from pyproj import Proj, transform

sourceProj = Proj(init='epsg:4326')
# WGS 84 UTM Zone 18N meters
destProj = Proj(init='epsg:32618')

# process arguments

xmlFileName = argv[1]
csvFileName = argv[2]


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

    x, y = transform(sourceProj, destProj, lon, lat)

    stations[stId] = dict(
        x=int(round(x)),
        y=int(round(y))
        )

# write the file
of = open(csvFileName, 'w')
w = csv.DictWriter(of, ['terminal','x','y'])
for stId in stations:
    w.writerow(dict(terminal=stId, x=stations[stId]['x'], y=stations[stId]['y']))

of.close()
