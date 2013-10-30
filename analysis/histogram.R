# Generate a histogram of travel time
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

setwd('~/bikeshare-analysis/data')

data_raw <- read.csv('all-trips.csv')
# data_raw <- read.csv('sample-trips-1pct.csv')

# grab only trips 2 hours or less
data_subset <- subset(data_raw, data_raw["duration_sec"] <= 7200)

# and 20 km or less
data_subset <- subset(data_subset, sqrt((data_subset["start_x"] - data_subset["end_x"])^2
                                        + (data_subset["start_y"] - data_subset["end_y"])^2)
                      <= 20000)

attach(data_subset)

hist(duration_sec/60, breaks = 24, xlab='Trip Duration (minutes)', title="Distribution of Trip Times")