# Time periods

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

# We use the same time-of-day spans as used by MWCOG in their four-step model, page 14:
# Metropolitan Washington Council of Governments. User's Guide for the MWCOG/NCRTPB Travel
# Forecasting Model, Version 2.3, Build 52: Draft Report. Washington, 2013.
# http://www.mwcog.org/transportation/activities/models/files/V2.3.52_Users_Guide_v2_w_appA.pdf.

period.all <- 1:8
period.wkmorn <- 1
period.wkmid <-2
period.wkeve <- 3
period.wknight <- 4
period.wemorn <- 5
period.wemid <- 6
period.weeve <- 7
period.wenight <- 8
period.count <- 8
