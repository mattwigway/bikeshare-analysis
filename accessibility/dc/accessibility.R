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
library(randomForest)

BREAK_LINKS_OVER <- 4000

# load and clean data
load_data <- function () {
  population60d <- read.csv('walk_transit_60min_housing.csv')
  # There is a projected version of this file, which has all coordinates in it
  jobs60d <- read.csv('walk_transit_60min_jobs_proj.csv')
  population30d <- read.csv('walk_transit_30min_housing.csv')
  jobs30d <- read.csv('walk_transit_30min_jobs.csv')
  population10d <- read.csv('walk_10min_housing.csv')
  jobs10d <- read.csv('walk_10min_jobs.csv')
  bike30d <- read.csv('bike_30min_stations.csv')

  population60d <- rename(population60d, c('output'='population60','input'='popularity'))
  jobs60d <- rename(jobs60d, c('output'='jobs60','input'='popularity'))
  population30d <- rename(population30d, c('output'='population30', 'input'='popularity'))
  jobs30d <- rename(jobs30d, c('output'='jobs30', 'input'='popularity'))
  population10d <- rename(population10d, c('output'='population10','input'='popularity'))
  jobs10d <- rename(jobs10d, c('output'='jobs10','input'='popularity'))
  bike30d <- rename(bike30d, c('output'='bike30','input'='popularity'))
  
  # Scale data
  population60d$population60 <- population60d$population60 / 10000
  jobs60d$jobs60 <- jobs60d$jobs60 / 10000
  population30d$population30 <- population30d$population30 / 10000
  jobs30d$jobs30 <- jobs30d$jobs30 / 10000
  population10d$population10 <- population10d$population10 / 10000
  jobs10d$jobs10 <- jobs10d$jobs10 / 10000
  # bike30 needs no rescaling
  
  # merge data
  
  data <- merge(jobs60d, population60d[,c('label', 'population60')], by='label')
  data <- merge(data, population30d[,c('label','population30')], by='label')
  data <- merge(data, population10d[,c('label','population10')], by='label')
  data <- merge(data, jobs10d[,c('label','jobs10')], by='label')
  data <- merge(data, jobs30d[,c('label','jobs30')], by='label')
  data <- merge(data, bike30d[,c('label','bike30')], by='label')
  
  # population10 is contained in population60 and jobs10 in jobs60
  # separate them
  #data$jobs60 <- data$jobs60 - data$jobs10
  #data$population60 <- data$population60 - data$population10
  # Note: if this code is uncommented add subtractions for 30 min
  
  # We take a log to normalize the data and reduce heteroscedasticity
  # We could use a box-cox transformation, but that makes the method more flexible
  # We don't want to be too flexible as we're trying to transfer the model
  data$lpopularity <- log(data$popularity)
  
  return(data)
}

data <- load_data()
attach(data)

corplot <- function(data, title=NA, varNames=NA) {
  # We save two copies because we'll be monkeying with the cors matrix to make the colors
  # right
  cors <- ret <- cor(data)
  # Principal diagonal: show white so text is visible
  diag(cors) <- 0
  label <- matrix(as.character(round(cors, 2)), nrow(cors), ncol(cors))
  
  if (is.na(varNames))
    varNames <- names(data)
  
  diag(label) <- varNames
  df <- data.frame(x=rep(1:ncol(cors), nrow(cors)), y=-sort(rep(1:nrow(cors), ncol(cors))),
                   r=as.vector(cors), label=as.vector(label))
  p <- ggplot(df)
  # default color scheme inspired by color scheme in The Elements of Statistical Learning, by
  # Hastie, Tibshirani and Friedman.
  p <- p + scale_fill_gradient2(lim=c(-1, 1), low=muted('orange'), high=muted('blue')) +
    geom_raster(mapping=aes(x, y, fill=r)) +
    geom_text(mapping=aes(x, y, label=label)) +
    theme(axis.title=element_blank(), axis.text=element_blank(),
          axis.line=element_blank(), axis.ticks=element_blank(),
          panel.border=element_blank())
  if (!is.na(title)) {
    p <- p + ggtitle(title)
  }
  benchplot(p)
  return(cors)
}

# convenience, don't retype field names all the time
predictors <- c('lpopularity', 'jobs60', 'jobs30', 'jobs10', 'population60', 'population30', 'population10', 'bike30')
labels <- c('log(Popularity)', 'Jobs within\n60 minutes\nby transit',
            'Jobs within\n30 minutes\nby transit',
            'Jobs within\n10 minutes\nby walking',
            'Population within\n60 minutes\nby transit',
            'Population within\n30 minutes\nby transit',
            'Population within\n10 minutes\nby walking',
            'Bike stations within\n30 minutes\nby bike')
cors <- corplot(data[,predictors], 'Variable correlations (Washington, DC)', labels)

# make some pretty pictures
# scatterplot matrix
pairs(data[,c('lpopularity', 'jobs60', 'jobs30', 'jobs10', 'population60', 'population30', 'population10', 'bike30')],
      labels=labels,
      cex.labels=1.85)

# histograms
layout(matrix(1:6, 2, 3, byrow=T))
hist(lpopularity, main='log(Popularity)', xlab='')
hist(jobs60, main='Jobs within\n60 minutes by transit', xlab='')
hist(population60, main='Population within\n60 minutes by transit', xlab='')
hist(bike30, main='Bikeshare stations within\n30 minutes by bike', xlab='')
hist(jobs10, main='Jobs within\n10 minutes by walking', xlab='')
hist(population10, main='Population within\n10 minutes by walking', xlab='')

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

# Store errors in a k x nvar matrix
# Thus each column represents a number of variables, and each row represents a fold
nvars <- 7
cv.errors <- matrix(NA,k,nvars)
for (fold in 1:k) {
  bss.fit <- regsubsets(lpopularity~jobs60+jobs30+jobs10+population60+population30+population10+bike30, data[folds != fold,])
  for (nvar in 1:nvars) {
    pred <- predict(bss.fit, data[folds==fold,], id=nvar)
    cv.errors[fold,nvar] <- mean((data$lpopularity[folds==fold] - pred)^2)
  }
}

# Fit a random forest for each fold and m
rf.errors <- matrix(NA, k, nvars)
for (fold in 1:k) {
  for (m in 1:nvars) {
    rf.fit <- randomForest(
      lpopularity~jobs60+jobs30+jobs10+population60+population30+population10+bike30,
      data[folds != fold,],
      mtry=m)
    pred <- predict(rf.fit, data[folds==fold,])
    rf.errors[fold,m] <- mean((data$lpopularity[folds==fold] - pred)^2)
  }
}

cv.errors.mean <- apply(cv.errors,2,mean)
cv.errors.se <- apply(cv.errors,2,sd)
rf.errors.mean <- apply(rf.errors,2,mean)
rf.errors.se <- apply(rf.errors,2,sd)

# CV MSE for linear regression
graphics.off()
ylim <- c(min(cv.errors.mean-cv.errors.se),
          max(cv.errors.mean + cv.errors.se))
# 1 SE band, linear model
plot(1:nvars,cv.errors.mean, ylab='Cross-validation MSE', xlab='Number of variables',
     ylim=ylim,type='b',lty=1)
lines(1:nvars,cv.errors.mean + cv.errors.se,type='l',col='gray70')
lines(1:nvars,cv.errors.mean - cv.errors.se,type='l',col='gray70')

ylim <- c(min(rf.errors.mean-rf.errors.se),
          max(rf.errors.mean + rf.errors.se))
# Random forests with varying m
plot(1:nvars, rf.errors.mean, ylab='Cross-validation MSE', xlab='Number of variables',
     ylim=ylim,type='b',lty=1)
lines(1:nvars,rf.errors.mean + rf.errors.se,type='l',col='gray70')
lines(1:nvars,rf.errors.mean - rf.errors.se,type='l',col='gray70')

# Show why taking logs is needed for regression
log.fit <- lm(lpopularity~jobs60,data)
raw.fit <- lm(popularity~jobs60,data)

layout(matrix(1:2, 1, 2))
plot(raw.fit, which=1, main='Untransformed response')
plot(log.fit, which=1, main='Log response')

# Show it on MN data
#par(new=T)
#ylim <- c(min(cv.errors.mn.mean - cv.errors.mn.se), max(cv.errors.mn.mean + cv.errors.mn.se))
#plot(1:nvars,cv.errors.mn.mean,lty=2,axes=F,xlab='',ylab='',type='b',ylim=ylim)
# 1 SE band
#lines(1:nvars,cv.errors.mn.mean + cv.errors.mn.se,type='l',lty=2,col='gray70')
#lines(1:nvars,cv.errors.mn.mean - cv.errors.mn.se,type='l',lty=2,col='gray70')
#axis(4,labels=T)
#mtext('MSE on validation data',4,line=4)

# No real reason to show adjusted R2, it's not particularly meaningful
#par(new=T)
#plot(1:8,fit.summ$adjr2, type='b', axes=F, ylab='', xlab='', lty=2)
#axis(4, labels=T)
#mtext(expression(paste('Adjusted ', R^2)), 4, line=4)

# Best fit has only 1 variable
lm.fit <- lm(lpopularity~jobs60, data)
summary(lm.fit)
plot(lm.fit, which=1)

# Random forest fit: m's all equivalent, we'll use 2 (~= 7/3)
rf.fit <- randomForest(
  lpopularity~jobs60+jobs30+jobs10+population60+population30+population10+bike30,
  data,
  mtry=2)
summary(rf.fit)
# Check for convergence
plot(rf.fit$rsq)

# check for spatial autocorrelation
#resid.spat <- data.frame(rlabel=label[population10!=0],resid=resid(lm.fit),x=X[population10 != 0],y=Y[population10!=0])
resid.spat <- data.frame(rlabel=label,residlm=resid(lm.fit),residrf=lpopularity-rf.fit$predicted,x=X,y=Y)

attach(resid.spat)

# build the neighbor matrix
getWeights <- function (x, y, labels) {
  nbmat <- tri2nb(data.frame(x=x, y=y), row.names=labels)

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
  return(weights)
}

weights <- getWeights(x, y, rlabel)

# Plot the triangulation
plot(weights, coords=resid.spat[,c('x','y')], main="Station adjacency")

# check for autocorrelation
moran.plot(residrf, weights)

# original (transformed)
moran.test(lpopularity, weights)

# residuals
moran.test(residlm, weights)
moran.test(residrf, weights)

# Transfer models
# Minneapolis
setwd('../mn')
mndata <- load_data()

corplot(mndata[,predictors])

# weight matrix

mndata$rfpreds <- predict(rf.fit, mndata)
mndata$lmpreds <- predict(lm.fit, mndata)

# Test R^2 for linear model
tss <- sum((mndata$lpopularity - mean(mndata$lpopularity))^2)
rss <- sum((mndata$lpopularity - mndata$lmpreds)^2)
testr2 <- 1 - rss/tss
testr2

# Test MSE for linear model
mean((mndata$lpopularity - mndata$lmpreds)^2)

# Test MSE for random forest
mean((mndata$lpopularity - mndata$rfpreds)^2)

# Test R^2 for random forest
tss <- sum((mndata$lpopularity - mean(mndata$lpopularity))^2)
rss <- sum((mndata$lpopularity - mndata$rfpreds)^2)
testr2 <- 1 - rss/tss
testr2

# New fit, same predictor

# cross-validation
cv.errors.mn <- rep(NA, k)
# First, assign everything to folds of approximately equal size
mnfolds <- rep(1:k, ceiling(nrow(mndata)/k))[1:nrow(mndata)]
# Then randomize which obs. is in which fold
mnfolds <- mnfolds[order(runif(nrow(mndata)))]
for (fold in 1:k) {
  cv.fit <- lm(lpopularity~jobs60,mndata[mnfolds != fold,])
  pred <- predict(cv.fit, mndata[mnfolds==fold,])
  cv.errors.mn[fold] <- mean((pred - mndata[mnfolds==fold,]$lpopularity)^2)
}

# CV MSE
mean(cv.errors.mn)

mn.lm.fit <- lm(lpopularity~jobs60,mndata)
summary(mn.lm.fit)

# Partial least squares-esque fit
mn.rf.fit <- lm(lpopularity~rfpreds,mndata)
summary(mn.rf.fit)

# Completely new random forest
mn.fullrf.fit <- randomForest(lpopularity~jobs60+jobs30+jobs10+population60+population30+population10+bike30,
                              data=mndata, mtry=2)
mn.fullrf.fit

# check for autocorrelation
mnweights <- getWeights(mndata$X, mndata$Y, mndata$terminal)
moran.test(mndata$lpopularity, mnweights)
# direct transfer
moran.test(mndata$lpopularity - mndata$lmpreds, mnweights)
# refit lm
moran.test(resid(mn.lm.fit), mnweights)
# pls
moran.test(resid(mn.rf.fit), mnweights)
# refit random forest
moran.test(mndata$lpopularity - mn.fullrf.fit$predicted, mnweights)

# San Francisco!
setwd('../sf')
sfdata <- load_data()

corplot(sfdata[,predictors])

# do the predictions
sfdata$lmpreds <- predict(lm.fit, sfdata)
sfdata$rfpreds <- predict(rf.fit, sfdata)

tss <- sum((sfdata$lpopularity - mean(sfdata$lpopularity))^2)
rss <- sum((sfdata$lpopularity - sfdata$lmpreds)^2)
testr2 <- 1 - rss/tss
testr2

# Test MSE for linear model
mean((sfdata$lpopularity - sfdata$lmpreds)^2)

# Test MSE for random forest
mean((sfdata$lpopularity - sfdata$rfpreds)^2)

tss <- sum((sfdata$lpopularity - mean(sfdata$lpopularity))^2)
rss <- sum((sfdata$lpopularity - sfdata$rfpreds)^2)
testr2 <- 1 - rss/tss
testr2

# New fit, same predictor
# cross-validation
cv.errors.sf <- rep(NA, k)
# First, assign everything to folds of approximately equal size
sffolds <- rep(1:k, ceiling(nrow(sfdata)/k))[1:nrow(sfdata)]
# Then randomize which obs. is in which fold
sffolds <- sffolds[order(runif(nrow(sfdata)))]
for (fold in 1:k) {
  cv.fit <- lm(lpopularity~jobs60,sfdata[sffolds != fold,])
  pred <- predict(cv.fit, sfdata[sffolds==fold,])
  cv.errors.sf[fold] <- mean((pred - sfdata[sffolds==fold,]$lpopularity)^2)
}

# CV MSE
mean(cv.errors.sf)

sf.lm.fit <- lm(lpopularity~jobs60,sfdata)
summary(sf.lm.fit)

# Partial least squares-esque fit
sf.rf.fit <- lm(lpopularity~rfpreds,sfdata)
summary(sf.rf.fit)

# Completely new random forest
sf.fullrf.fit <- randomForest(lpopularity~jobs60+jobs30+jobs10+population60+population30+population10+bike30,
                              data=sfdata, mtry=2)
sf.fullrf.fit

# check for autocorrelation
sfweights <- getWeights(sfdata$X, sfdata$Y, sfdata$terminal)
moran.test(sfdata$lpopularity, sfweights)
# direct transfer
moran.test(sfdata$lpopularity - sfdata$lmpreds, sfweights)
# refit lm
moran.test(resid(sf.lm.fit), sfweights)
# pls
moran.test(resid(sf.rf.fit), sfweights)
# refit random forest
moran.test(sfdata$lpopularity - sf.fullrf.fit$predicted, sfweights)

# Plot the SF and MN linear models
layout(matrix(1:2, 1, 2))
ylim <- c(min(sfdata$lpopularity, mndata$lpopularity), max(sfdata$lpopularity, mndata$lpopularity))
xlim <- c(min(sfdata$jobs60, mndata$jobs60), max(sfdata$jobs60, mndata$jobs60))
plot(lpopularity~jobs60,mndata,main='Minneapolis/St. Paul',
     xlab='Jobs within 60 minutes by transit\n(tens of thousands)',
     ylab='log(popularity)',
     ylim=ylim,xlim=xlim)
abline(lm.fit)
plot(lpopularity~jobs60,sfdata,main='San Francisco Bay Area',
     xlab='Jobs within 60 minutes by transit\n(tens of thousands)',
     ylab='log(popularity)',
     ylim=ylim,xlim=xlim)
abline(lm.fit)

# lm fit
sf.lm.fit <- lm(lpopularity~jobs60,sfdata)
summary(sf.lm.fit)

