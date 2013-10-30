# Generate a plot of travel time by distance for the bikeshare trips in DC
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

setwd('~/bikeshare-analysis/data')

# data_raw <- read.csv('all-trips.csv')
data_raw <- read.csv('sample-trips-1pct.csv')

# grab only trips 2 hours or less
data_subset <- subset(data_raw, data_raw["duration_sec"] <= 7200)

# and 20 km or less
data_subset <- subset(data_subset, sqrt((data_subset["start_x"] - data_subset["end_x"])^2
                                        + (data_subset["start_y"] - data_subset["end_y"])^2)
                      <= 20000)

attach(data_subset)

trip_length_km <- (sqrt((start_x - end_x)^2 + (start_y - end_y)^2)/1000)
duration_min <- duration_sec / 60

# create the best-fit line
fit <- lm(duration_min ~ trip_length_km)

# plot the point cloud
plot(sqrt((start_x - end_x)^2 + (start_y - end_y)^2)/1000, duration_sec/60, 
     xlab="Trip Length (km)", ylab="Trip Time (min)", pch=".", col="gray")

# plot the best-fit line
abline(fit)

# Summarize the model
summary(fit)
