# Take a random sample from lines in a file
# Usage: sample.py file percent output
# The first line is always preserved as it is likely a header

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
from random import random

with open(argv[1]) as infile:
    with open(argv[3], 'w') as outfile:
        cut = float(argv[2])

        firstLine = True
        for line in infile:
            if firstLine:
                outfile.write(line)
                firstLine = False
                continue

            if random() < cut:
                outfile.write(line)
