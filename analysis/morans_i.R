# Calculate Moran's I for bike share data; are station popularities autocorrelated?
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

TIMEZONE <- 'America/New_York'
# StarLab
setwd('E:/GEOG172/bikeshare-analysis')
data <- read.csv('data/data-cleaned-labeled-.005.csv')
library(plyr)
library(spatstat)
library(spdep)

# First, calculate station popularities
first <- function (vect) { return(vect[1]) }

epoch <- function (date) {
  return(as.integer(as.POSIXct(date)))
}

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
popularityDest <- ddply(data, c('end_terminal'), summarise,
				# No need to have x's and y's here, they come from orig
                        NDest=length(end_x),
                        firstDest=minDate(start_date),
				lastDest=maxDate(start_date)
)

popularityOrig <- ddply(data, c('start_terminal'), summarise,
                        x=first(start_x),
                        y=first(start_y),
                        # note: *200 is to counter effects of random sample
                        # remove when using population
                        NOrig=length(start_x),
                        firstOrig=minDate(start_date),
				lastOrig=maxDate(start_date)
)

# Full outer join
popularity <- merge(popularityOrig, popularityDest, all=T, by.x='start_terminal', by.y='end_terminal')
popularity$NOrig[is.na(popularity$NOrig)] <- NA
popularity$NDest[is.na(popularity$NDest)] <- NA

origCt <- dim(popularity)[1]
# Drop ones with no coords, shouldn't happen
popularity <- subset(popularity, !is.na(x))

cat('Removed', origCt - dim(popularity)[1], 'stations with no coordinates\n')

attach(popularity)

# Sum up the number of bike movements and divide by the number of days the station is open
# First, calculate span
lastOpDate <- apply(matrix(c(lastOrig, lastDest), ncol=2), 1, max, na.rm=T)
firstOpDate <- apply(matrix(c(lastOrig, lastDest), ncol=2), 1, min, na.rm=T)
spans <- (((lastOpDate - firstOpDate) / 86400) + 1)
popularity$pop <- (NOrig + NDest) / spans

# We take the log of popularity to normalize the distribution
popularity$lpop <- log(popularity$pop)

detach(popularity)
attach(popularity)

# Make a plot for the writeup showing why we took a log
layout(matrix(1:2, 1, 2))
hist(pop, main=NA, xlab='Bike movements/day', ylab='Number of stations')
hist(lpop, main=NA, xlab='log(Bike movements/day)', ylab='Number of stations')

# TODO: neighbor matrix

dists <- pairdist(popularity$x, popularity$y)
sds <- seq(0, 20000, 25)
ivals <- rep(NA, length(sd))
for (j in 1:length(sds)) {
  sd <- sds[j]
  # weights
  weights <- pnorm(dists, sd=sd, lower.tail=F)
  diag(weights) <- 0
  wlw <- mat2listw(weights)
  # compute Moran's i
  ivals[j] <- moran(pop, wlw, length(pop), Szero(wlw))$I
}

# Plot Moran's I
plot(sds, ivals, type='l',
     main="Moran's I, Gaussian distance weights",
     xlab="Gaussian standard deviation", ylab="I value")
