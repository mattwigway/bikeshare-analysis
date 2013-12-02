# Create some fake point patterns
# Lay out 31 points

source('analysis/calcINorm.R')
library(spatstat)

x <- rep(0, 161)
y <- rep(0, 161)
ripplevals <- distvals <- rep(NA, 161)

x[1] <- y[1] <- 0
ripplevals[1] <- 1
distvals[1] <- 0

val <- 1
i <- 2
radii <- 1:20
for (r in radii) {
  pyr <- r / sqrt(2)
  x[i] <- r
  x[i + 1] <- -r
  y[i + 2] <- r
  y[i + 3] <- -r
  x[i + 4] <- y[i + 4] <- pyr
  x[i + 5] <- y[i + 5] <- -pyr
  x[i + 6] <- y[i + 7] <- pyr
  x[i + 7] <- y[i + 6] <- -pyr
  
  val <- -val
  ripplevals[seq(i,i+7,1)] <- val
  distvals[seq(i,i+7,1)] <- r
  i <- i + 8
}

dists <- pairdist(x, y)
sds <- seq(0.5, 20, 0.1)
ripple <- calcINorm(sds, ripplevals, dists)
dist <- calcINorm(sds, distvals, dists)
randvals <- runif(distvals)
rand <- calcINorm(sds, randvals, dists)
trendvals <- x + y
trend <- calcINorm(sds, trendvals, dists)

# plot
layout(matrix(1:4,2,2,byrow=T))
par(mai=rep(0.5,4))
plot(sds, ripple, main='Ripple data', xlab='Standard deviation', ylab='I value',
      type='l')
plot(sds, dist, main='Peak data', xlab='Standard deviation', ylab='I value',
     type='l')
plot(sds, rand, main='Random data', xlab='Standard deviation', ylab='I value',
     type='l')
plot(sds, trend, main='Trending data', xlab='Standard deviation', ylab='I value',
     type='l')