# Take a random sample from lines in a file
# Usage: sample.py file percent output
# The first line is always preserved as it is likely a header
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

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
