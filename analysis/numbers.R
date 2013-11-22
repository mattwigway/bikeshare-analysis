# Find station numbers

# Load the data and build the initial triangulation
stations <- read.csv('data/stations.csv')
attach(stations)
plot(x, y)
cat(terminal[identify(x, y)])