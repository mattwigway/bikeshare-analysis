# Crosstab the trips by origin, destination and time of day, and compare the test statistics
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

# Constants
TIMEZONE="America/New_York"

# hiram, hortense
setwd('/media/matthewc/Excelsior/GEOG172/bikeshare-analysis')
# Starlab
#setwd('E:/GEOG172/bikeshare-analysis')

source('analysis/load_data.R')
source('analysis/periods.R')

data <- load_data(sample=F)

label <- function(rawDate) {
  date <- strptime(rawDate, format='%m/%d/%Y %H:%M', tz=TIMEZONE)

  # first check the time
  hr <- date$hour
  
  if (hr >= 6 && hr < 9) {
    period <- period.wkmorn
  } else if (hr >= 9 && hr < 15) {
    period <- period.wkmid
  } else if (hr >= 15 && hr < 19) {
    period <- period.wkeve
  } else {
    period <- period.wknight
  }
  
  # check for weekend
  if (date$wday == 0 || date$wday == 6) {
    period <- period + 4
  }
  
  # Apply correction for Friday nights (weekends) and Sunday nights (weekday)
  if (date$wday == 0 && hr >= 19) {
    period <- period.wknight
  } else if (date$wday == 5 && hr >= 19) {
    period <- period.wenight
  }
  
  return(period)
}

# label all of the data
# It would seem simple to just use vapply, but that crashes R. So we chunk it into groups of
# 10000
# data$label <- apply(data, )
dataLen <- length(data$start_date)
# Writing directly into a data frame is really slow
data_label <- rep(NA, dataLen)

# don't store a huge vector that is really just an index
i <- 1
while (i <= dataLen) {
  if (i %% 100000 == 0)
    cat(i, ' . . . ')
  data_label[i] <- label(data$start_date[i])
  
  i <- i + 1
}

data$label <- data_label

# store labeled data
write.csv(data, file="data/data-cleaned-labeled.csv")