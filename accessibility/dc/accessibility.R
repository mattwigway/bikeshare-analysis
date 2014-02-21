# Run a linear regression of popularity on accessibility measures, and generate plots
# and descriptive statistics

setwd('accessibility/dc')

library(plyr)
library(boot)
library(leaps)
library(spatstat)
library(spdep)
library(AID)

BREAK_LINKS_OVER <- 4000

# load and clean data
population60d <- read.csv('walk_transit_60min_housing.csv')
# There is a projected version of this file, which has all coordinates in it
jobs60d <- read.csv('walk_transit_60min_jobs_proj.csv')
population10d <- read.csv('walk_10min_housing.csv')
jobs10d <- read.csv('walk_10min_jobs.csv')
bike30d <- read.csv('bike_30min_stations.csv')

population60d <- rename(population60d, c('output'='population60','input'='popularity'))
jobs60d <- rename(jobs60d, c('output'='jobs60','input'='popularity'))
population10d <- rename(population10d, c('output'='population10','input'='popularity'))
jobs10d <- rename(jobs10d, c('output'='jobs10','input'='popularity'))
bike30d <- rename(bike30d, c('output'='bike30','input'='popularity'))

# Scale data
population60d$population60 <- population60d$population60 / 10000
jobs60d$jobs60 <- jobs60d$jobs60 / 10000
population10d$population10 <- population10d$population10 / 10000
jobs10d$jobs10 <- jobs10d$jobs10 / 10000
# bike30 needs no rescaling

# merge data

data <- merge(jobs60d, population60d[,c('label', 'population60')], by='label')
data <- merge(data, population10d[,c('label','population10')], by='label')
data <- merge(data, jobs10d[,c('label','jobs10')], by='label')
data <- merge(data, bike30d[,c('label','bike30')], by='label')

# population10 is contained in population60 and jobs10 in jobs60
# separate them
data$jobs60 <- data$jobs60 - data$jobs10
data$population60 <- data$population60 - data$population10

attach(data)

# calculate some descriptive statistics
cor(data[,c('popularity', 'jobs60', 'jobs10', 'population60', 'population10', 'bike30')])

# make some pretty pictures
# scatterplot matrix
pairs(data[,c('popularity', 'jobs60', 'jobs10', 'population60', 'population10', 'bike30')],
      labels=c('Popularity', 'Jobs within\n60 minutes\nby transit\n(tens of thousands)',
              'Jobs within\n10 minutes\nby walking\n(tens of thousands)',
              'Population within\n60 minutes\nby transit\n(tens of thousands)',
              'Population within\n10 minutes\nby walking\n(tens of thousands)',
              'Bike stations within\n30 minutes\nby bike'),
      cex.labels=1.85)

# boxplots
layout(matrix(1:6, 2, 3, byrow=T))
hist(popularity, main='Popularity', xlab='')
hist(jobs60, main='Jobs within\n60 minutes by transit\n(tens of thousands)', xlab='')
hist(population60, main='Population within\n60 minutes by transit\n(tens of thousands)', xlab='')
hist(bike30, main='Bikeshare stations within\n30 minutes by bike', xlab='')
hist(jobs10, main='Jobs within\n10 minutes by walking\n(tens of thousands)', xlab='')
hist(population10, main='Population within\n10 minutes by walking\n(tens of thousands)', xlab='')

# calculate box-cox coefs
bctransform <- function (data, lambda) {
  if (lambda == 0) {
    return(log(data))
  }
  else {
    return((data^lambda - 1)/lambda)
  }
}

calcBcCoefs <- function (data) {
  coefs <- list()
  for (name in names(data)) {
    coefs[[name]] <- boxcoxnc(data[,name][data[,name] != 0], method='sw', lam=seq(-2, 4, 0.01))$result
  }
  
  return(coefs)
}

bccoefs <- calcBcCoefs(data[,c('popularity', 'jobs60', 'jobs10', 'population60', 'population10', 'bike30')])
for (name in names(bccoefs)) {
  data[,paste(name, 'bc', sep='')] <- bctransform(data[,name], bccoefs[[name]][1])
}

# Calculate some log plots
data$lpopularity <- log(data$popularity)
data$lpopulation10 <- log(data$population10)
data$ljobs10 <- log(data$jobs10)
data$ljobs60 <- log(data$jobs60)

attach(data)

# transformed plots
layout(matrix(1:3, 1, 3, byrow=T))
hist(lpopularity, main='log(Popularity)', xlab='')
hist(ljobs10, main='log(Jobs) within\n10 minutes by walking\n(tens of thousands)', xlab='')
hist(lpopulation10, main='log(Population) within\n10 minutes by walking\n(tens of thousands)', xlab='')



layout(matrix(1:6, 2, 3, byrow=T))
hist(popularity, xlab='Popularity', cex.lab=1.85)
hist(jobs60, xlab='Jobs within 60 minutes by transit\n(tens of thousands)', cex.lab=1.85)
hist(population60, xlab='Population within 60 minutes by transit\n(tens of thousands)', cex.lab=1.85)
hist(bike30, xlab='Bikeshare stations within\n30 minutes by bike', cex.lab=1.85)
hist(jobs10, xlab='Jobs within 10 minutes by walking\n(tens of thousands)', cex.lab=1.85)
hist(population10, xlab='Population within 10 minutes by walking\n(tens of thousands)', cex.lab=1.85)


# Fit the model
# TODO: Best subset selection?
# Note: we're using glm instead of lm so we can do cross-validation later
# with no family argument, glm fits a standard least-squares linear model
# When we fit this model, we find that the only significant variables are jobs60 and population10
lm.fit <- lm(lpopularity~jobs60+jobs10+population10)
lm.fit <- lm(popularitybc~jobs60+jobs10+population60+population10)
summary(lm.fit)
plot(lm.fit)

# Best subset selection with cross-validation
# See page 250, James, Gareth, Daniela Witten, Trevor Hastie, and Robert Tibshirani.
# An Introduction to Statistical Learning, with Applications in R. New York: Springer, 2013.

# predict.regsubsets formula from James et al. 2013, 249.
predict.regsubsets <- function(object, newdata, id, ...) {
  form <- as.formula(object$call[[2]])
  mat <- model.matrix(form, newdata)
  coefi <- coef(object, id)
  xvars <- names(coefi)
  mat[,xvars]%*%coefi
}

# We use 5-fold validation in the interests of being conservative, leaning towards bias over variance
k <- 5
# In the book they use the sample function, but that has the downside that the folds may not all be the
# same size. So instead we get a bit more elaborate . . .
# First, assign everything to folds of approximately equal size
folds <- rep(1:k, ceiling(nrow(data)/k))[1:nrow(data)]
# Then randomize which obs. is in which fold
folds <- folds[order(runif(nrow(data)))]

# Store errors in a k x 5 matrix (five for max number of variables)
# Thus each column represents a number of variables, and each row represents a fold
cv.errors <- matrix(NA,k,5)
for (fold in 1:k) {
  fit <- regsubsets(popularitybc~jobs60+population60+jobs10+population10+bike30, data[folds != fold,])
  for (nvar in 1:5) {
    pred <- predict(fit, data[folds==fold,], id=nvar)
    cv.errors[fold,nvar] <- mean((data$popularity[folds==fold] - pred)^2)
  }
}

cv.errors.mean <- apply(cv.errors,2,mean)

# Now, perform BSS on full dataset
fit <- regsubsets(popularity~jobs60+population60+jobs10+population10+bike30, data)
fit.summ <- summary(fit)

# Plot adjusted R^2 and CV MSE
graphics.off()
par(mar=c(5,4,4,5) + 0.1)
plot(1:5,cv.errors.mean, type='b', ylab='Cross-validation MSE', xlab='Number of variables', lty=1, pch=c(8,8,8,1,1))
par(new=T)
plot(1:5,fit.summ$adjr2, type='b', axes=F, ylab='', xlab='', lty=2, ylim=c(0.59,0.61), pch=c(8,8,8,1,1))
axis(4, labels=T)
mtext(expression(paste('Adjusted ', R^2)), 4, line=4)
legend('bottomleft', lty=c(1,2,0), pch=c(NA,NA,8), inset=0.005, cex=0.75, text.width=2,
       legend=c('Cross-validation MSE', expression(paste('Adjusted ', R^2)),
                'All variables statistically significant (p < 0.05)'))

lm.fit <- lm(popularity~jobs60+jobs10+population10)
plot(lm.fit)

# check for spatial autocorrelation
#resid.spat <- data.frame(rlabel=label[population10!=0],resid=resid(lm.fit),x=X[population10 != 0],y=Y[population10!=0])
resid.spat <- data.frame(rlabel=label,resid=resid(lm.fit),x=X,y=Y)

attach(resid.spat)

# build the neighbor matrix
nbmat <- tri2nb(resid.spat[,c('x','y')], row.names=rlabel)

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
plot(weights, coords=resid.spat[,c('x','y')], main="Station adjacency")

# check for autocorrelation
moran.plot(resid.spat$resid, weights)

# original (transformed)
moran.test(bcpopularity, weights)

# residuals
moran.test(resid.spat$resid, weights)
