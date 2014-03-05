#!/usr/bin/python

# Extract station popularities from archives of realtime feeds

from sys import argv
import json
import time
from pyproj import Proj, transform
import csv
from traceback import print_exc

stations = dict()

# TODO: abstract this to own file, use in calculatePopularities.py
class Station:
    def __init__(self, terminal, name, x=None, y=None, lat=None, lon=None, proj='epsg:32618'):
        self.terminal = terminal
        self.name = name
        self.x = x
        self.y = y
        
        self.proj = proj

        if lat and lon:
            self.setCoords(lat, lon)

        self.arrivals = 0
        self.departures = 0

        self.firstTime = None
        self.lastTime = None

    def setCoords(self, lat, lon):
        sourceProj = Proj(init='epsg:4326')
        destProj = Proj(init=self.proj)
        x, y = transform(sourceProj, destProj, lon, lat)
        self.x = int(round(x))
        self.y = int(round(y))

    def incrementArrivals(self, value=1):
        self.arrivals += value

    def incrementDepartures(self, value=1):
        self.departures += value

    def addTime(self, timeStr):
        "Add this time to the station's open time, by expanding the time range in whatever direction is needed"
        
        # first, parse the time
        # TODO: make more robust
        secs = time.mktime(time.strptime(timeStr, '%Y-%m-%d %I:%M:%S %p'))

        if self.firstTime == None or secs < self.firstTime:
            self.firstTime = secs

        if self.lastTime == None or secs > self.lastTime:
            self.lastTime = secs

    def getCsvRow(self):
        # NB: the reason the results from this code differ (very) slightly from the original algorithm is that
        # the original algorithm added one day to all spans to account for the first day (e.g. if there was only
        # one trip that is one trip per day). We don't do that here because it commits the MAUP w.r.t. time: it assumes
        # that days are meaningful units of analysis. This analysis is unitless.
        weight = (self.lastTime - self.firstTime) / (24 * 60 * 60.0) 

        if weight == 0:
            print 'Station %s (%s) had %s movements, unable to calculate popularity' % (self.terminal, self.name, self.arrivals + self.departures)
            return
         
        return dict(
                terminal=self.terminal,
                name=self.name,
                origin=self.departures / weight,
                destination=self.arrivals / weight,
                overall=(self.departures + self.arrivals) / weight,
                first=time.ctime(self.firstTime),
                last=time.ctime(self.lastTime),
                days=weight,
                x=self.x,
                y=self.y)

outfile = csv.DictWriter(open(argv[-1], 'w'), fieldnames=['terminal', 'name', 'origin', 'destination', 'overall', 'first', 'last', 'days', 'x', 'y'])
outfile.writeheader()

priorIndex = None
currentTime = None
for infile in argv[1:-1]:
    print 'Processing %s' % infile
    
    inf = open(infile)

    # walk through the file, splitting into individual JSON files
    for line in inf:
        if line[-1] == '\n':
            line = line[:-1]

        # Ignore blank lines, separators, and dates
        if line == '':
            continue

        if line[0] == '-':
            continue

        if line[0] == '2':
            currentTime = line
            continue

        # Load the station status
        try:
            status = json.loads(line)
        except ValueError:
            print_exc()
            print 'error loading %s, skipping' % currentTime
            continue

        # build an index by station id
        index = dict()
        for stJson in status['stationBeanList']:
            index[stJson['id']] = stJson

        if priorIndex != None:
            for stJson in index.values():
                # get the station record, or create it
                if not stations.has_key(stJson['id']):
                    # proj: State Plan California Zone 3, meters
                    stations[stJson['id']] = Station(stJson['id'], stJson['stationName'], lat=stJson['latitude'], lon=stJson['longitude'], proj='epsg:26943')
                station = stations[stJson['id']]

                # Calculate the delta
                if not priorIndex.has_key(stJson['id']):
                    continue

                delta = stJson['availableBikes'] - priorIndex[stJson['id']]['availableBikes']


                # Note: this does not account for when arrivals and departures occurred in the same time period
                # Also, this does not account for rebalancing
                if delta < 0:
                    station.incrementDepartures(-delta)

                elif delta > 0:
                    station.incrementArrivals(delta)
            
                station.addTime(status['executionTime'])

                # we do this each time because some of the stations move and we want to use the most up-to-date coordinates
                # in particular, the coordinates for the San Mateo Gov't Center were originally the same as those for the
                # Redwood City Library. This corrects for that.
                station.setCoords(stJson['latitude'], stJson['longitude'])


        priorIndex = index
        index = None

# Write out results
outfile.writerows([s.getCsvRow() for s in stations.values()])

