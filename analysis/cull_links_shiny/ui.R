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

shinyUI(pageWithSidebar(
  headerPanel("Link Trimming Distance"),
  sidebarPanel(
      sliderInput('BREAK_LINKS', 'Break links longer than (m):', min=100, max=50000, value=4000, step=100)
    ),
  mainPanel(plotOutput('links'))  
  ))
