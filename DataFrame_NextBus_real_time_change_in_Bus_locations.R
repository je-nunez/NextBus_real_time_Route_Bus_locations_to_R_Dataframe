
# documentation of the R package "sp" (geo-spatial):
#     https://cran.r-project.org/web/packages/sp/sp.pdf

required_packages <- c("XML", "sp", "gglot2")

missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if( 0 < length(missing_packages) ) {
  install.packages(missing_packages, dep=TRUE)
}

require(XML)
require(sp)
library(ggplot2)

# how long in time to analyze changes in the vehicle locations in NextBus:
# in the most recent 15 minutes
#
time_window_bus_movement <- 15 * 60

# whether to debug our use of the NextBus Feed webservices or not

debug_nextbus <- FALSE

# the list of transit agencies for NextBus can be taken here:
#
#     http://webservices.nextbus.com/service/publicXMLFeed?command=agencyList
#
# url_agencies <- "http://webservices.nextbus.com/service/publicXMLFeed?command=agencyList"
#
# NextBus "sf-muni" = San Francisco Municipal Transportation Agency

agency_code <- "sf-muni"

# the bus route code. For a given transit agency, it can be taken from here:
#
#   http://webservices.nextbus.com/service/publicXMLFeed?command=routeList&a=<agency-code>
#
# In this case, the NextBus code is the same as the bus#, ie., San Francisco Muni 38R bus

bus_route <- "38R"

# NextBus Vehicle locations NextBus API
#
#   http://webservices.nextbus.com/service/publicXMLFeed?command=vehicleLocations&a=<agency_tag>&r=<route tag>&t=<epoch time in msec>
#
base_nextbus_vehicle_locations_fmt <- "http://webservices.nextbus.com/service/publicXMLFeed?command=vehicleLocations&a=%s&r=%s&t=%d000"

# current time
options(digits.secs=3)
now_str <- Sys.time()
now_epoch <- as.integer(unclass(now_str))

# Get the changes in vehicle locations since the last 15 minutes
url_nextbus_feed <- sprintf(base_nextbus_vehicle_locations_fmt,
                            agency_code, bus_route,
                            now_epoch - time_window_bus_movement)

if (debug_nextbus == TRUE ) {

  # download NextBus to a temporary XML file and parse it
  tempfile <- "/tmp/nextbus_vehicle_locations.xml"
  # tempfile <- tempfile()

  # quiet = FALSE: debug download operation of NextBus Vehicle locations
  # (to use RCurl could be another possibility)
  download.file(url_nextbus_feed, tempfile,
                method="internal", quiet=FALSE, mode="w")

  xml_recs <- xmlParse(tempfile)
} else {
  xml_recs <- xmlParse(url_nextbus_feed)
}

# recs <- xmlToList(xml_recs)

df <- as.data.frame(t(xmlSApply(xml_recs["/body/vehicle"],xmlAttrs)),
                    stringsAsFactors=FALSE)

# This is an example ggplot with the delay in the real-time of the locations

plot_title <- sprintf("Delays in the Real-Time Location of the Transit Vehicles servicing the route %s (Transit Agency %s)",
                      bus_route, toupper(agency_code))

ggplot(df, aes(lat, lon, colour=secsSinceReport)) +
  theme_minimal() + geom_point() +
  labs(x = "Latitude", y = "Longitude", title=plot_title)
