#!/usr/bin/python
# Merge CSV files with the same columns
# Copyright (C) 2013 by Matthew Wigginton Conway. All rights reserved.

from sys import argv
import csv
import re

# get the last argument
outfileName = argv[-1]

fieldnames = ['duration', 'duration_sec', 'start_date', 'start_station', 'start_terminal', 'end_date', 'end_station', 'end_terminal', 'bike_num', 'subscription_type', 'bike_key']
out = csv.DictWriter(open(outfileName, 'w'), fieldnames)
out.writeheader()

def renameKey(row, key, newKey):
    if row.has_key(key):
        row[newKey] = row[key]
        del row[key]
        return row

count = 0
for infile in argv[1:-1]:
    print '\nProcessing %s' % infile
    
    reader = csv.DictReader(open(infile))

    for row in reader:
        # Standardize field names
        renameKey(row, 'Member Type', 'Type')
        renameKey(row, 'Start station', 'Start Station')
        renameKey(row, 'End station', 'End Station')
        renameKey(row, 'Duration (Sec)', 'Duration(Sec)')
        renameKey(row, 'Duration (sec)', 'Duration(Sec)')
        renameKey(row, 'Start terminal', 'Start Terminal')
        renameKey(row, 'End terminal', 'End Terminal')
        renameKey(row, 'Subscriber Type', 'Subscription Type')
        renameKey(row, 'Type', 'Subscription Type')

        # Make field names R-friendly
        renameKey(row, 'Duration', 'duration')
        renameKey(row, 'Duration(Sec)', 'duration_sec')
        renameKey(row, 'Start date', 'start_date')
        renameKey(row, 'Start Station', 'start_station')
        renameKey(row, 'Start Terminal', 'start_terminal')
        renameKey(row, 'End date', 'end_date')
        renameKey(row, 'End Station', 'end_station')
        renameKey(row, 'End Terminal', 'end_terminal')
        renameKey(row, 'Bike#', 'bike_num')
        renameKey(row, 'Subscription Type', 'subscription_type')
        renameKey(row, 'Start time', 'start_date')
        renameKey(row, 'Bike Key', 'bike_key')

        # Sometimes they don't explicitly record the terminals
        if not row.has_key('start_terminal'):
            # rstrip ensures there is no trailing white space
            row['start_terminal'] = row['start_station'].rstrip()[-6:-1]

        if not row.has_key('end_terminal'):
            row['end_terminal'] = row['end_station'].rstrip()[-6:-1]

        # Back out the duration
        if not row.has_key('duration_sec'):
            m = re.search('([0-9]+)h[ .]+([0-9]+)mi?n?[ .]+([0-9]+)s', row['duration'])
            if m == None:
                print 'Unable to parse duration %s' % row['duration']
            else:
                row['duration_sec'] = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + int(m.group(3))

        out.writerow(row)

        count += 1
        if count % 50000 == 0:
            print '%s . . . ' % count,

print '%s total rows processed' % count
