# Relabel the data and test for a effect of time
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

# Number of simulations for the relabel
NSIMS = 100

source('analysis/periods.R')

# This builds a 3-dimensional Xtab, with x being the label, Y being the start station, and Z being the end station
buildTripMatrix <- function(data) {
  return(xtabs(~label + start_terminal + end_terminal, data))
}

# This randomizes the order of the character vector passed to it
randomizeOrder <- function(vector) {
  # We order by random numbers
  orderBy <- runif(length(vector))
  return(vector[order(orderBy)])
}

# This computes the chi-squared test statistic for two matrices
chi.gof <- function (observed, expected) {
  
}

data <- read.csv('data/data-cleaned-labeled.csv')
orig <- buildTripMatrix(data)

# Make a matrix to store the results
gof <- matrix(NA, 100, 7)

for (i in 1:NSIMS) {
  cat('Repetition', i, '\n')
  
  # Randomize the labels, preserving the marginals
  data$label <- randomizeOrder(data$label)
  
  tripMatrix <- buildTripMatrix(data)
  
  # Compute the GOF statistic (chi-squared) for each time period
  # H_0: the original distribution fits a random distribution
  # TODO: should we test the other way (i.e. make the actual values the expected values?)
  for (period in period.all) {
    chisq = 
  }
  
}

