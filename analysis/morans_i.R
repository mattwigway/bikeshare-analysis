# Calculate Moran's I for bike share data; are station popularities autocorrelated?
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

TIMEZONE <- 'America/New_York'

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
                        x=first(end_x),
                        y=first(end_y),
                        # note: *200 is counter effects of random sample
                        # remove when using population
                        N=length(end_x),
                        span=maxDate(start_date) - minDate(start_date),
                        pop=length(end_x) * 200 / ((maxDate(start_date) - minDate(start_date)) / 86400)
)

popularityOrig <- ddply(data, c('start_terminal'), summarise,
                        x=first(start_x),
                        y=first(start_y),
                        # note: *200 is counter effects of random sample
                        # remove when using population
                        N=length(end_x),
                        span=maxDate(start_date) - minDate(start_date),
                        pop=length(end_x) * 200 / ((maxDate(start_date) - minDate(start_date) + 1) / 86400)
)

popularity <- popularityDest # Note: include orig
attach(popularity)

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
