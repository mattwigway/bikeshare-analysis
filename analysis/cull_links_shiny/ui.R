library(shiny)

shinyUI(pageWithSidebar(
  headerPanel("Link Trimming Distance"),
  sidebarPanel(
      sliderInput('BREAK_LINKS', 'Break links longer than (m):', min=100, max=50000, value=4000, step=100)
    ),
  mainPanel(plotOutput('links'))  
  ))