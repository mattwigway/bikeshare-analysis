# load-data.R: Abstract data loading
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

# If the argument is true, then load just a 1 percent sample of the data
load_data <- function(sample=F) {
  if (sample) {
    data_raw <- read.csv('data/sample-trips-.1pct.csv')
  }
  else {
    data_raw <- read.csv('data/all-trips.csv')
  }
  
  # grab only trips 2 hours or less
  data_subset <- subset(data_raw, data_raw["duration_sec"] <= 7200)
  
  # and 20 km or less
  data_subset <- subset(data_subset, sqrt((data_subset["start_x"] - data_subset["end_x"])^2
                                          + (data_subset["start_y"] - data_subset["end_y"])^2)
                        <= 20000)
  
  # Remove trips with null start times
  data_subset <- subset(data_subset, data_subset["start_date"] != '')
  
  return(data_subset)
}