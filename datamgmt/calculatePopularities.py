# calculatePopularities.py: Calculate bikeshare station popularity based on a table of trips
# First create a combined trip table using fetchData.sh, csvMerge.py and expandFileWithXY.py, then
# run this to condense it.

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

import csv
from sys import argv
import time
from math import sqrt

stations = dict()

def newStation(terminal, name, x, y):
    return dict(terminal=terminal, name=name, orig=0, dest=0, x=x, y=y, firstTime=None, lastTime=None)

def getSecs(tstr):
    t = time.strptime(tstr, '%m/%d/%Y %H:%M')
    return time.mktime(t)

with open(argv[1]) as infileraw:
    infile = csv.DictReader(infileraw)
    for trip in infile:
        # Drop trips over 2 hours or 20km
        if int(trip['duration_sec']) > 7200:
            continue

        if trip['start_x'] == '' or trip['start_y'] == '' or trip['end_x'] == '' or trip['end_y'] == '':
            continue

        # Since we're using projected (UTM) data in meters, we can just use
        # the pythagorean theorem to calculate the distance
        if sqrt(pow(int(trip['start_x']) - int(trip['end_x']), 2) +\
                pow(int(trip['start_y']) - int(trip['end_y']), 2)) > 20000:
            continue

        if not stations.has_key(trip['start_terminal']):
            stations[trip['start_terminal']] = newStation(trip['start_terminal'], trip['start_station'], trip['start_x'], trip['start_y'])

        if not stations.has_key(trip['end_terminal']):
            stations[trip['end_terminal']] = newStation(trip['end_terminal'], trip['end_station'], trip['end_x'], trip['end_y'])

        stations[trip['start_terminal']]['orig'] += 1
        start = getSecs(trip['start_date'])
        if start < stations[trip['start_terminal']]['firstTime'] or stations[trip['start_terminal']]['firstTime'] == None:
            stations[trip['start_terminal']]['firstTime'] = start
        if start > stations[trip['start_terminal']]['lastTime'] or stations[trip['start_terminal']]['lastTime'] == None:
            stations[trip['start_terminal']]['lastTime'] = start

        stations[trip['end_terminal']]['dest'] += 1
        end = getSecs(trip['end_date'])
        if end < stations[trip['end_terminal']]['firstTime'] or stations[trip['end_terminal']]['firstTime'] == None:
            stations[trip['end_terminal']]['firstTime'] = end
        if end > stations[trip['end_terminal']]['lastTime'] or stations[trip['end_terminal']]['lastTime'] == None:
            stations[trip['end_terminal']]['lastTime'] = end


with open(argv[2], 'wb') as outfileraw:
    outfile = csv.DictWriter(outfileraw, fieldnames=['terminal', 'name', 'origin', 'destination', 'overall', 'first', 'last', 'days', 'x', 'y'])
    outfile.writeheader()

    for key in stations:
        s = stations[key]
        # NB: the reason the results from this code differ (very) slightly from the original algorithm is that
        # the original algorithm added one day to all spans to account for the first day (e.g. if there was only
        # one trip that is one trip per day). We don't do that here because it commits the MAUP w.r.t. time: it assumes
        # that days are meaningful units of analysis. This analysis is unitless.
        weight = (s['lastTime'] - s['firstTime']) / (24 * 60 * 60.0) 

        if weight == 0:
            print 'Station %s (%s) had %s movements, unable to calculate popularity' % (s['terminal'], s['name'], s['orig'] + s['dest'])
            continue
         
        outfile.writerows([dict(
                terminal=s['terminal'], 
                name=s['name'],
                origin=s['orig'] / weight,
                destination=s['dest'] / weight,
                overall=(s['orig'] + s['dest']) / weight,
                first=time.ctime(s['firstTime']),
                last=time.ctime(s['lastTime']),
                days=weight,
                x=s['x'],
                y=s['y'])]
                          )
