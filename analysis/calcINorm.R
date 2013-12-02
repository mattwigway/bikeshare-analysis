# Calculate i values using the normal distribution at many distances
# Copyright (C) 2013 Matthew Wigginton Conway. All rights reserved.

library(spdep)

# Calculate Moran's I using a Gaussian weighting function, the given
# standard deviations, values, and distance matrix
calcINorm <- function (sds, vals, dists) {
  ivals <- rep(NA, length(sds))
  for (j in 1:length(sds)) {
    sd <- sds[j]
    # weights
    weights <- pnorm(dists, sd=sd, lower.tail=F)
    diag(weights) <- 0
    wlw <- mat2listw(weights)
    # compute Moran's i
    ivals[j] <- moran(vals, wlw, length(vals), Szero(wlw))$I
  }
  return(ivals)
}