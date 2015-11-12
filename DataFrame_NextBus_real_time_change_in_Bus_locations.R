
# documentation of the R package "sp" (geo-spatial):
#     https://cran.r-project.org/web/packages/sp/sp.pdf
#
# of RgoogleMaps:
#
#     https://cran.r-project.org/web/packages/RgoogleMaps/RgoogleMaps.pdf

required_packages <- c("XML", "sp", "RgoogleMaps", "gglot2")

missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if( 0 < length(missing_packages) ) {
  install.packages(missing_packages, dep=TRUE)
}

require(XML)
require(sp)
require(ggplot2)
require(RgoogleMaps)

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

# Function to parse one real-time NextBus XML vehicle to an R dataframe
# Note that there can be missing attributes in the real-time NextBus
# XML vehicle (e.g., XML attribute "dirTag" or "routeTag" can be
# missing when the NextBus vehicle happen to turn around in real-time)
parse_nextbus_vehicle_to_df <- function(vehicle) {
  # parse the NextBus XML dataframe
  if (debug_nextbus == TRUE ) {
    print("Parsing NextBus XML real-time vehicle location:")
    print(vehicle)
  }

  vehicle_id <- xmlGetAttr(vehicle, "id")
  route_tag <- xmlGetAttr(vehicle, "routeTag")
  route_tag <- ifelse(length(route_tag)==0,NA,route_tag) # NextBus sometimes omits it
  dir_tag <- xmlGetAttr(vehicle, "dirTag")
  dir_tag <- ifelse(length(dir_tag)==0,NA,dir_tag) # NextBus sometimes omits it
  lat <- xmlGetAttr(vehicle, "lat")
  lat <- ifelse(length(lat)==0,NA,as.numeric(lat))
  lon <- xmlGetAttr(vehicle, "lon")
  lon <- ifelse(length(lon)==0,NA,as.numeric(lon))
  secsSinceReport <- xmlGetAttr(vehicle, "secsSinceReport")
  secsSinceReport <- ifelse(length(secsSinceReport)==0,NA,as.numeric(secsSinceReport))
  predictable <- xmlGetAttr(vehicle, "predictable")
  heading <- xmlGetAttr(vehicle, "heading")
  speed <- xmlGetAttr(vehicle, "speedKmHr")
  speed <- ifelse(length(speed)==0,NA,as.numeric(speed))

  nextbus_veh_df <- data.frame(vehicle_id, route_tag, dir_tag,
                               lat, lon, secsSinceReport,
                               predictable, heading, speed,
                               stringsAsFactors = FALSE)

  if (debug_nextbus == TRUE ) {
    print("Parsed data frame from NextBus XML real-time vehicle location:")
    print(nextbus_veh_df, digits = 6)
  }
  # return the parsed data frame from NextBus XML
  nextbus_veh_df
}


df <- do.call(rbind,
              xpathApply(xml_recs, "/body/vehicle",
                         parse_nextbus_vehicle_to_df))


# This is an example ggplot with the delay in the real-time of the locations

plot_title <- sprintf("Delays in the Real-Time Location of the Transit Vehicles servicing the route %s (Transit Agency %s)",
                      bus_route, toupper(agency_code))

ggplot(df, aes(lat, lon, colour=secsSinceReport)) +
  theme_minimal() + geom_point() +
  labs(x = "Latitude", y = "Longitude", title=plot_title)

# Function to plot the NextBus real-time vehicle locations data frame
# onto a Google Maps of the locality.

plot_nextbus_vehicle_df_gmaps <- function(nextbus_df, dest_png_fname,
                                          gmap_type = "roadmap") {

  allowable_gmap_types <- c("roadmap", "mobile", "satellite", "terrain",
                            "hybrid", "mapmaker-roadmap", "mapmaker-hybrid")

  gmap_type_to_req <- gmap_type
  if ( ! ( gmap_type_to_req %in% allowable_gmap_types ) ) {
    # What to do? Silently correct the gmap_type or fail ? In more
    # production-ready environments it should be strict, so the callee is
    # making an assumption that is wrong, so the caller should be fail.
    # In more relaxed envs, either filter-and-adjust this wrong parameter,
    # or pass it through as-is (very risky).

    cat("Invalid Google Map type requested '", gmap_type_to_req,
        "'. Filtering it ", sep = "")
    gmap_type_to_req <- "roadmap"
  }

  bounding_box <- qbbox(lat = nextbus_df[,"lat"], lon = nextbus_df[,"lon"])

  # A temporary Google maps with background of the place where the transit
  # agency's route has the vehicles servicing it

  basemap_fname <- file.path(tempdir(), "basemap_google.png")

  # The zoom to apply to the Google Maps

  gmap_zoom <- min(MaxZoom(range(nextbus_df$lat), range(nextbus_df$lon)))

  # Should  MINIMUMSIZE be TRUE ? Then it wouldn't need the zoom argument.
  # The issue is that sometimes when MINIMUMSIZE=TRUE, it returns:
  # 'Error: all(size <= 640) is not TRUE'

  plot_gmap <- GetMap.bbox(bounding_box$lonR, bounding_box$latR,
                                size = c(640, 640), zoom = gmap_zoom,
                                format = "png32", maptype = gmap_type_to_req,
                                SCALE=1, destfile = basemap_fname,
                                MINIMUMSIZE = FALSE, RETURNIMAGE = TRUE,
                                GRAYSCALE = FALSE)

  # Redirect the graphical output to a PNG file

  png(dest_png_fname, type = 'cairo-png')
  # dev.cur()
  plot.new()

  # Try to map the NextBus vehicle locations on the background Google map
  # giving colors according to the "dir_tag" of the vehicles servicing that
  # route (if there are many directions inside the route, e.g., many more
  # than the two -outgoing and returning- directions that the Generalized
  # Transit Feed Specification recommends, then the colors will be re-used:
  # the color palette only has five colors yet). For this reason, sort()
  # is needed around the unique(), as to have the NA values in "dir_tag" as
  # the last value analyzed (if NA does occur in "dir_tag"), if not NA will
  # use up some of the most common colors in the palette.

  possible_dir_tags <- sort(unique(nextbus_df$dir_tag), na.last = TRUE)
  color_palette <- c("green", "red", "blue", "yellow", "orange")

  for (i in 1:length(possible_dir_tags)){
    a_dir_tag <- possible_dir_tags[i]
    assoc_color <- color_palette[i %% length(color_palette)]
    if ( debug_nextbus == TRUE ) {
      cat("Plotting vehicles in direction '", a_dir_tag,
          "' with color '", assoc_color, "'\n", sep = "")
    }
    to_add <- ifelse( i == 1, FALSE, TRUE )

    # Sometimes NextBus (or the transit agency reporting to NextBus) doesn't
    # give a "dir_tag" for the real-time location of a vehicle (is it turning
    # direction at the end of the trip?), so our parser adds the dir_tag
    # anyway but explicitly as an NA value for this vehicle. (This might
    # happen also with other columns that NextBus provides.)

    if(! is.na(a_dir_tag)) {
      vehicles_in_this_direction <- nextbus_df[nextbus_df$dir_tag == a_dir_tag,]
    } else {
      vehicles_in_this_direction <- nextbus_df[is.na(nextbus_df$dir_tag),]
    }

    tmp <- PlotOnStaticMap(plot_gmap,
                           lat = vehicles_in_this_direction$lat,
                           lon = vehicles_in_this_direction$lon,
                           zoom = gmap_zoom, NEWMAP = FALSE, add = to_add,
                           FUN = points, cex = 1.5, pch = 20, col = assoc_color)
  }

  # Draw the vehicle IDs as labels on the map
  ## (This below works but is not ready yet because of font sizes and
  ## distance to points)
  #
  # TextOnStaticMap(plot_gmap,
  #                 lat = nextbus_df$lat, lon = nextbus_df$lon,
  #                 labels = nextbus_df$vehicle_id,
  #                 add = TRUE)

  # Stop redirecting this graphical output
  dev.off()
}

# Request to plot the NextBus real-time vehicle locations data frame
# on a Google Map, saving the result to a PNG image file

plot_nextbus_vehicle_df_gmaps(df, dest_png_fname = "nextbus_vehicles_on_gmap.png",
                              gmap_type = "hybrid")

cat("The image in 'nextbus_vehicles_on_gmap.png' can now be opened.")
