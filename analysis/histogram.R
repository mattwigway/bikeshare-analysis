# Generate a histogram of travel time

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
