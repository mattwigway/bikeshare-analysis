# Relabel the data and test for a effect of time
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

# Number of simulations for the relabel
NSIMS = 999

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

# This computes the test statistic for two matrices
calcTs <- function (observed, expected) { 
  return(sum((observed - expected)^2)/sum(expected)^2)
}

# This computes pairwise test statistics for each time period relative to every other
computePairwiseStats <- function (tripMatrix) {
  # Build a matrix for the test statistics
  pairwiseStats <- matrix(NA, nrow=period.count, ncol=period.count)
  
  # compare each one to all others
  for (i in period.all) {
    for (j in period.all) {
      obs <- tripMatrix[i,,]
      ex  <- tripMatrix[j,,]
      
      # scale so sums are same
      pairwiseStats[i,j] <- calcTs(obs, ex * (sum(ex)/sum(obs)))
    }
  }
  
  return(pairwiseStats)
}

data <- read.csv('data/data-cleaned-labeled.csv')
orig <- buildTripMatrix(data)

origTS <- computePairwiseStats(orig)

# Make an array to store the test statistics in
simulatedTS <- array(NA, dim=c(NSIMS, period.count, period.count))

for (i in 1:NSIMS) {
  cat('Repetition', i, '\n')
  
  # Randomize the labels, preserving the marginals
  data$label <- randomizeOrder(data$label)
  
  tripMatrix <- buildTripMatrix(data)
  
  # Compute the pairwise stats and store them
  simulatedTS[i,,] <- computePairwiseStats(tripMatrix)
}

# Find the p-values
pvals <- matrix(NA, nrow=period.count, ncol=period.count)
for (i in period.all) {
  for (j in period.all) {
     pvals[i,j] <- sum(simulatedTS[,i,j] >= origTS[i,j]) / (NSIMS + 1)
  }
}

# Write a CSV file that is used to generate the table in the TeX writeup
write.csv(pvals, 'writeup/pvals.csv')

