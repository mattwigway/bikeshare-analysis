library(shiny)
library(spdep)

# Load the data and build the initial triangulation
setwd("/media/matthewc/Excelsior/GEOG172/bikeshare-analysis") 
stations <- read.csv('data/stations.csv')
attach(stations)
globalNbmat <- tri2nb(stations[,c('x','y')])

shinyServer(function(input, output) {
  output$links <- renderPlot({
    nbmat <- globalNbmat
    # Drop really long links
    for (i in 1:length(nbmat)) {
      newNb <- c()
      for (j in nbmat[[i]]) {
        dist <- sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2)
        if (dist <= input$BREAK_LINKS) {
          newNb <- c(newNb, as.integer(j))
        }
      }
      nbmat[[i]] <- newNb
    }
    
    weights <- nb2listw(nbmat, style='W')
    
    plot(weights, stations[,c('x','y')])
  })
})