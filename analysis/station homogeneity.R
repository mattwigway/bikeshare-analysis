# Check for spatial inhomogeneity in station locations

library(spatstat)

st <- read.csv('data/stations.csv')
attach(st)

# build a point pattern
# TODO: window is very bad, use polygonal boundary of DC, Alexandria, Arlington and
# Montgomery Co.
st.pp <- ppp(x, y, xrange=c(min(x), max(x)), yrange=c(min(y), max(y)))

# plot at four bandwiths
dev.new(width=8.5, height=11)
layout(matrix(1:4, nrow=2, ncol=2, byrow=T))
par(mai=rep(0.5,4))

bws <- c(400, 800, 1600, 3200)
for (bw in bws) {
  plot(density.ppp(st.pp,bw),main=paste(bw, 'm', sep=''))
  points(st.pp,pch='.')
}