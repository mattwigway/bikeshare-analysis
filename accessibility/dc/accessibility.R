# Run a linear regression of popularity on accessibility measures, and generate plots
# and descriptive statistics

setwd('accessibility/dc')

library(plyr)
library(boot)
library(leaps)
library(spatstat)
library(spdep)
library(AID)
library(ggplot2)
library(scales)

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

# We take a log to normalize the data and reduce heteroscedasticity
# We could use a box-cox transformation, but that makes the method much more flexible
# We don't want to be too flexible as we're trying to transfer the model
data$lpopularity <- log(data$popularity)

attach(data)

# calculate some descriptive statistics
corplot <- function(data) {
  # We save two copies because we'll be monkeying with the cors matrix to make the colors
  # right
  cors <- ret <- cor(data)
  
  # Principal diagonal: show white so text is visible
  diag(cors) <- 0
  
  label <- matrix(as.character(round(cors, 2)), nrow(cors), ncol(cors))
  diag(label) <- names(data)
  
  df <- data.frame(x=rep(1:ncol(cors), nrow(cors)), y=-sort(rep(1:nrow(cors), ncol(cors))),
                   r=as.vector(cors), label=as.vector(label))
  
  p <- ggplot(df)
  #p + geom_text(x=1:ncol(cors), y=-(1:nrow(cors)), labels=names(data))
  benchplot(p + scale_fill_gradient2(lim=c(-1, 1), low=muted('orange'), high=muted('blue')) +
              geom_raster(mapping=aes(x, y, fill=r)) +
              geom_text(mapping=aes(x, y, label=label)) +
              theme(axis.title=element_blank(), axis.text=element_blank(),
                    axis.line=element_blank(), axis.ticks=element_blank(),
                    panel.border=element_blank())
              )
  
  return(cors)
}

cors <- corplot(data[,c('lpopularity', 'jobs60', 'jobs10', 'population60', 'population10', 'bike30')])

# make some pretty pictures
# scatterplot matrix
pairs(data[,c('lpopularity', 'jobs60', 'jobs10', 'population60', 'population10', 'bike30')],
      labels=c('log(Popularity)', 'Jobs within\n60 minutes\nby transit\n(tens of thousands)',
              'Jobs within\n10 minutes\nby walking\n(tens of thousands)',
              'Population within\n60 minutes\nby transit\n(tens of thousands)',
              'Population within\n10 minutes\nby walking\n(tens of thousands)',
              'Bike stations within\n30 minutes\nby bike'),
      cex.labels=1.85)

# histograms
layout(matrix(1:6, 2, 3, byrow=T))
hist(lpopularity, main='log(Popularity)', xlab='')
hist(jobs60, main='Jobs within\n60 minutes by transit\n(tens of thousands)', xlab='')
hist(population60, main='Population within\n60 minutes by transit\n(tens of thousands)', xlab='')
hist(bike30, main='Bikeshare stations within\n30 minutes by bike', xlab='')
hist(jobs10, main='Jobs within\n10 minutes by walking\n(tens of thousands)', xlab='')
hist(population10, main='Population within\n10 minutes by walking\n(tens of thousands)', xlab='')

# Best subset selection with cross-validation
# See page 250, Gareth James, Daniela Witten, Trevor Hastie, and Robert Tibshirani.
# An Introduction to Statistical Learning, with Applications in R. New York: Springer, 2013.

# predict.regsubsets function from James et al. 2013, 249.
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
  fit <- regsubsets(lpopularity~jobs60+population60+jobs10+population10+bike30, data[folds != fold,])
  for (nvar in 1:5) {
    pred <- predict(fit, data[folds==fold,], id=nvar)
    cv.errors[fold,nvar] <- mean((data$lpopularity[folds==fold] - pred)^2)
  }
}

cv.errors.mean <- apply(cv.errors,2,mean)
cv.errors.se <- apply(cv.errors,2,sd)


# Now perform best-subset selection on the full dataset
fit <- regsubsets(lpopularity~jobs60+population60+jobs10+population10+bike30, data)
fit.summ <- summary(fit)

# Plot adjusted R^2 and CV MSE
graphics.off()
par(mar=c(5,4,4,5) + 0.1)
ylim <- c(min(cv.errors.mean - cv.errors.se), max(cv.errors.mean + cv.errors.se))
# 1 SE band
plot(1:5,cv.errors.mean, ylab='Cross-validation MSE', xlab='Number of variables', ylim=ylim, pch=NA)
polygon(c(1:5, 5:1), c(cv.errors.mean + cv.errors.se, rev(cv.errors.mean - cv.errors.se)),
        border=NA, col='gray80', ylim=ylim)
# awkward
lines(1:5,cv.errors.mean, type='b',pch=c(8,8,8,1,1), lty=1)

par(new=T)
plot(1:5,fit.summ$adjr2, type='b', axes=F, ylab='', xlab='', lty=2, pch=c(8,8,8,1,1))
axis(4, labels=T)
mtext(expression(paste('Adjusted ', R^2)), 4, line=4)
legend('bottomright', lty=c(1,2,0), pch=c(NA,NA,8), inset=0.005, cex=0.75, text.width=2,
       legend=c('Cross-validation MSE (shaded area 1 SD)', expression(paste('Adjusted ', R^2)),
                'All variables statistically significant (p < 0.05)'))

# Best fit has only 1 variable
lm.fit <- lm(lpopularity~jobs60)
summary(lm.fit)
plot(lm.fit, which=1)

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
moran.test(lpopularity, weights)

# residuals
moran.test(resid.spat$resid, weights)

# Test actual model residuals, not transformed residuals
yhat <- exp(lm.fit$fitted)
residpop <- popularity - yhat

moran.test(residpop, weights)

# Plot the model in untransformed space
plot(popularity~jobs60)
simjobs <- seq(0, 60, 0.5)
lines(simjobs, exp(lm.fit$coef[1] + lm.fit$coef[2] * simjobs))

# show why we took a log
# vertical for paper
layout(matrix(1:6, 3, 2))
hist(popularity, main='Station popularity')
untransformed.fit <- lm(popularity~jobs60)
plot(untransformed.fit, which=1:2)

hist(lpopularity, main='log(Popularity)')
plot(lm.fit, which=1:2)

# horizontal for presentation
layout(matrix(1:6, 2, 3, byrow=T))
hist(popularity, main='Station Popularity')
untransformed.fit <- lm(popularity~jobs60)
plot(untransformed.fit, which=1:2)

hist(lpopularity, main='log(Popularity)')
plot(lm.fit, which=1:2)
