#!/usr/bin/python
# Count the number of trips with no geo coordinates

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

from csv import DictReader

r = DictReader(open('all-trips.csv'))

nospatial = 0
i = 0
for line in r:
    i += 1
    if i % 100000 == 0:
        print '%s (%s) . . . ' % (i, nospatial)

    if line['start_x'] == '' or line['end_x'] == '' or\
            line['start_y'] == '' or line['end_y'] == '':
        nospatial += 1

print
print 'Trips with no spatial coordinates: %s' % nospatial
