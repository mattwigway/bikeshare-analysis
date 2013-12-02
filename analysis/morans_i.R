# Calculate Moran's I for bike share data; are station popularities autocorrelated?

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

TIMEZONE <- 'America/New_York'
BREAK_LINKS_OVER <- 4000 # 4000 m, empirically determined; much less than 4000m and we start seeing more than
                         # two clusters, and we really do want to keep it clustered to just DC/Arlington/Alexandria
                         # and Montgomery County.
EXCLUDE_STATIONS <- c('32004', '32009', '32005', '32007') # Exclude the four stations in Montgomery County
# StarLab
setwd('E:/GEOG172/bikeshare-analysis')
library(plyr)
library(spatstat)
library(spdep)
library(AID)

data <- read.csv('data/data-cleaned-labeled.csv')

# First, calculate station popularities
first <- function (vect) { return(vect[1]) }

# This function returns the time as seconds since January 1, 1970
epoch <- function (date) {
  return(as.integer(as.POSIXct(date)))
}

# Calculate the lowest date in a vector of dates. Return an epoch time.
minDate <- function (rawDates) {
  lowest <- NA
  
  for (rawDate in rawDates) {
    date <- strptime(rawDate, format='%m/%d/%Y %H:%M', tz=TIMEZONE)
    
    if (is.na(lowest)) {
      lowest <- epoch(date)
    }
    else if (date < lowest) {
      lowest <- epoch(date)
    }      
  }
  
  return(lowest)
}

# Calculate the largest date in a vector of dates. Return an epoch time.
maxDate <- function (rawDates) {
  greatest <- NA
  
  for (rawDate in rawDates) {
    date <- strptime(rawDate, format='%m/%d/%Y %H:%M', tz=TIMEZONE)
    
    if (is.na(greatest)) {
      greatest <- epoch(date)
    }
    else if (date > greatest) {
      greatest <- epoch(date)
    }      
  }
  
  return(greatest)
}

# pop can be interpreted as trips per day, iff you're using population data
# First we summarise the bike movements at the start and end of trips
popularityDest <- ddply(data, c('end_terminal'), summarise,
				# No need to have x's and y's here, they come from orig
                        NDest=length(end_x),
                        firstDest=minDate(start_date),
				lastDest=maxDate(start_date)
)

popularityOrig <- ddply(data, c('start_terminal'), summarise,
                        x=first(start_x),
                        y=first(start_y),
                        NOrig=length(start_x),
                        firstOrig=minDate(start_date),
				lastOrig=maxDate(start_date)
)

# Now combine the origins and the destinations
# Full inner join; remove any station that doesn't have both trip origins and trip terminations
popularity <- merge(popularityOrig, popularityDest, all=F, by.x='start_terminal', by.y='end_terminal')
popularity <- rename(popularity, c("start_terminal"="terminal"))

# Remove stations
popularity <- subset(popularity, !(terminal %in% EXCLUDE_STATIONS))

attach(popularity)

# Sum up the number of bike movements and divide by the number of days the station is open
# First, calculate span
# The matrix bit gets the first movement recorded at the station, either an origin or a destionation.
# We can use min/max because all times are represented as seconds since Jan 1, 1970 at this point.
lastOpDate <- apply(matrix(c(lastOrig, lastDest), ncol=2), 1, max, na.rm=T)
firstOpDate <- apply(matrix(c(firstOrig, firstDest), ncol=2), 1, min, na.rm=T)
spans <- (((lastOpDate - firstOpDate) / 86400) + 1)
popularity$pop <- (NOrig + NDest) / spans

# Normalize the popularity as much as possible
# We use the Shapiro-Wilk method because it gave a number close to the average
# when used on sample data. Need to check with Dr. Sweeney regarding the best
# way to choose a method.
bctransform <- function (data, lambda) {
  if (lambda == 0) {
    return(log(data))
  }
  else {
    return((data^lambda - 1)/lambda)
  }
}
bclam <- boxcoxnc(popularity$pop, method='sw')
popularity$bcpop <- bctransform(popularity$pop, bclam$result[1])
cat('Box-Cox p-values:', bclam$result[2:4,])

detach(popularity)

# save the popularities to avoid recalculation later
write.csv(popularity, 'data/station-popularities.csv')
# Re-read popularities: start from here if you're repeating the analysis.
popularity <- read.csv('data/station-popularities.csv')

attach(popularity)

# Make a plot for the writeup showing why we used Box-Cox
layout(matrix(1:2, 1, 2))
hist(pop, main=NA, xlab='Bike movements/day', ylab='Number of stations')
hist(bcpop, main=NA, xlab=paste('Box-Cox transformed bike movements/day (lambda=', bclam$result[1], ')', sep=''), ylab='Number of stations')
graphics.off()

# build the neighbor matrix
nbmat <- tri2nb(popularity[,c('x','y')], row.names=terminal)

# Drop really long links
for (i in 1:length(nbmat)) {
  newNb <- c()
  for (j in nbmat[[i]]) {
    dist <- sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2)
    if (dist <= BREAK_LINKS_OVER) {
      newNb <- c(newNb, as.integer(j))
    }
  }
  nbmat[[i]] <- newNb
}

weights <- nb2listw(nbmat, style='W')

# Plot the triangulation
plot(weights, coords=popularity[,c('x','y')], main="Station adjacency")

# labels
text(locator(), labels=c('Washington', 'Arlington', 'Alexandria'))

graphics.off()

# Calulate moran's I
moran.test(bcpop, weights)
moran.plot(bcpop, weights, xlab='Box-Cox transformed bike movements/day', ylab='Spatially lagged transformed bike movements/day')
