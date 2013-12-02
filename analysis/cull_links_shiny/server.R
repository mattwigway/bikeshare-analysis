# Copyright (C) 2013 Matthew Wigginton Conway.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#   http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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
