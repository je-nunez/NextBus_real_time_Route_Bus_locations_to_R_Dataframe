
options(echo=FALSE)

cmd_line_usage <- function() {
  # Command-line usage
  cat("Program to retrieve and plot the real-time location of NextBus transit vehicles.\n",
      "Execute this program passing it two arguments in the command-line:\n\n",
      "    First argument: the code of the NextBus transit agency\n",
      "    Second argument: the code of the transit route in that agency\n\n",
      "Example:\n\n",
      "     R -f <this-script.R> --args  sf-muni  38\n\n",
      "to download the data frame of the San Francisco Muni route 38 Geary Blvd route.\n",
      sep = "")

  quit( save = "no", status = 1 )
}

# the list of transit agencies for NextBus can be taken here:
#
#     http://webservices.nextbus.com/service/publicXMLFeed?command=agencyList
#
# url_agencies <- "http://webservices.nextbus.com/service/publicXMLFeed?command=agencyList"
#
# No validation of a valid transit route code in NextBus
# (For testing purposes, agency "sf-muni" refers to the San Francisco Municipal Transportation Agency

cmdline_args <- commandArgs(TRUE)

if ( length(cmdline_args) != 2 || cmdline_args[1] == "" || cmdline_args[2] == "" ) {
  cmd_line_usage()
}

agency_code <- cmdline_args[1]

# the bus route code. For a given transit agency, it can be taken from here:
#
#   http://webservices.nextbus.com/service/publicXMLFeed?command=routeList&a=<agency-code>
#
# No validation of a valid transit route code in NextBus
# (For testing purposes, route "38R" is valid for transit agency "sf-muni")

bus_route <- cmdline_args[2]

# documentation of the R package "sp" (geo-spatial):
#     https://cran.r-project.org/web/packages/sp/sp.pdf
#
# of RgoogleMaps:
#
#     https://cran.r-project.org/web/packages/RgoogleMaps/RgoogleMaps.pdf

required_packages <- c("XML", "sp", "RgoogleMaps", "gglot2")

missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]
if( 0 < length(missing_packages) ) {
  options(repos=c(CRAN="http://cran.cnr.Berkeley.edu/"))
  install.packages(missing_packages, dep=TRUE)
}

require(XML)
require(sp)
require(ggplot2)
require(RgoogleMaps)

# whether to debug our use of the NextBus Feed webservices or not

debug_nextbus <- FALSE

# how long in time to analyze changes in the vehicle locations in NextBus:
# in the most recent 15 minutes
#
time_window_bus_movement <- 15 * 60

# NextBus Vehicle locations NextBus API
#
#   http://webservices.nextbus.com/service/publicXMLFeed?command=vehicleLocations&a=<agency_tag>&r=<route tag>&t=<epoch time in msec>
#
base_nextbus_vehicle_locations_fmt <- "http://webservices.nextbus.com/service/publicXMLFeed?command=vehicleLocations&a=%s&r=%s&t=%d000"

# current time
options(digits.secs=3)
now_str <- Sys.time()
now_epoch <- as.integer(unclass(now_str))

# Get the changes in vehicle locations since the last 15 minutes (ie., in the
# variable time_window_bus_movement)

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

# Get the data frame with the location of all vehicles servicing this transit
# route by parsing all the NextBus real-time XML answer.

df <- do.call(rbind,
              xpathApply(xml_recs, "/body/vehicle",
                         parse_nextbus_vehicle_to_df))


# This is an example ggplot with the delay in the real-time of the locations

plot_title <- sprintf("Delays in the Real-Time Location of the Transit Vehicles servicing the route %s (Transit Agency %s)",
                      bus_route, toupper(agency_code))

ggplot(df, aes(lat, lon, colour=secsSinceReport)) +
  theme_minimal() + geom_point() +
  labs(x = "Latitude", y = "Longitude", title=plot_title)

# Function to return which percentile range of the data has the least samples

least_populated_quantile <- function (v, quantile_probs) {

  quantile_delims <- quantile(v, probs = quantile_probs, names = FALSE)
  if ( debug_nextbus == TRUE ) {
    cat("Least populated segment of", sort(v),
        "in segments", quantile_delims, "\n")
  }
  # Initialization: the current segment in the quantiles which has the
  # least number of elements is the very first (lowest) segment
  curr_open_range <- quantile_delims[1]
  curr_min <- sum(v <= curr_open_range)
  curr_min_pos <- 1
  curr_close_range <- curr_open_range

  for (i in 2:(length(quantile_delims) - 1)){
    curr_close_range <- quantile_delims[i]
    if ( debug_nextbus == TRUE ) {
      cat("Analyzing quantile range [", i,
          "] of population from", curr_open_range,
          "to", curr_close_range, "\n")
    }

    curr_count <- sum( v > curr_open_range & v <= curr_close_range )
    if ( curr_count < curr_min ) {
      curr_min <- curr_count
      curr_min_pos <- i
    }
    curr_open_range <- curr_close_range
  }

  last_segm_count <- sum(v > curr_close_range)
  if ( last_segm_count < curr_min ) {
    curr_min_pos <- length(quantile_delims)
  }

  if ( debug_nextbus == TRUE ) {
    cat("Least populated quantile range is", curr_min_pos, "\n")
  }

  return(curr_min_pos)
}

# Function to plot the NextBus real-time vehicle locations data frame
# onto a Google Maps of the locality.

plot_nextbus_vehicle_df_gmaps <- function(nextbus_df, dest_png_fname,
                                          gmap_type = "roadmap",
                                          show_legend = TRUE,
                                          fixed_legend_pos = "bottomleft") {

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
  # giving colors according to the "dir_tag" of the vehicles servicing this
  # route (if there are many directions inside the route, e.g., many more
  # than the two -outgoing and returning- directions that the Generalized
  # Transit Feed Specification recommends, then the colors will be re-used:
  # the color palette only has nine colors yet). For this reason, sort()
  # is needed around the unique(), as to have the NA values in "dir_tag" as
  # the last value analyzed (if NA does occur in "dir_tag"), if not NA will
  # use up some of the most common colors in the palette.

  possible_dir_tags <- sort(unique(nextbus_df$dir_tag), na.last = TRUE)
  color_palette <- c("green", "red", "blue", "yellow", "orange",
                     "brown", "purple", "gray", "white")

  for (i in 1:length(possible_dir_tags)){
    a_dir_tag <- possible_dir_tags[i]
    assoc_color <- color_palette[i %% length(color_palette)]
    if ( debug_nextbus == TRUE ) {
      cat("Plotting vehicles in direction '", a_dir_tag,
          "' with color '", assoc_color, "'\n", sep = "")
    }
    to_add <- ifelse( i == 1, FALSE, TRUE )

    # Get the vehicles which are now in this direction 'a_dir_tag' of the
    # transit route.
    # NA values: sometimes NextBus (or the transit agency reporting to
    # NextBus) doesn't give a "dir_tag" for the real-time location of a
    # vehicle (is it turning direction at the end of the trip?), so our
    # parser adds the dir_tag anyway but explicitly as an NA value for this
    # vehicle. (This might happen also with other columns that NextBus
    # provides.)

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

  # Plot the legend of the colors of the route directions in Google Maps

  if ( ! show_legend ) {
    # we don't have to show the legend
    # Stop redirecting this graphical output
    dev.off()
    return
  }

  legend_text <- possible_dir_tags
  legend_text[is.na(legend_text)] <- "N.A."

  if ( fixed_legend_pos == "" ) {
    # The legend for the NextBus real-time vehicle locations on the Google Map
    # was requested but its position wasn't given: we need to calculate were to
    # better put it.
    # The legend ought to be dynamically located on the map in a position
    # where there are no other coordinates from nextbus_df$lat and
    # nextbus_df$lon, so that the legend does not intersect data points. For
    # this, take the three quantiles of the NextBus vehicles' latitudes and
    # longitudes (pbby a smaller segmentation in more quantiles, not in three
    # quantiles only, renders better graphics)

    # You need to add latitudes/longitudes of bounding box 'bounding_box' too,
    # because the Google Map is between them too

    latitudes_v <- append(nextbus_df$lat, bounding_box$latR)
    longitudes_v <- append(nextbus_df$lon, bounding_box$lonR)

    if ( debug_nextbus == TRUE ) {
      cat("Region expanded to analyze for legend: latitudes expanded from\n",
          sort(nextbus_df$lat), "\nto include also\n", bounding_box$latR,
          "\nresulting in\n", sort(latitudes_v),
          "\nlongitudes expanded from\n",
          sort(nextbus_df$lon), "\nto include also\n", bounding_box$lonR,
          "\nresulting in\n", sort(longitudes_v), "\n")
    }

    # Find the geometrical segment (of latitude/longitudes) with NextBus
    # transit vehicles that is the least populated according to each
    # quantiles of latitudes/longitudes: in this least populated segment is
    # where it is best to locate the dinamycally placed legend

    l_popul_lat <- least_populated_quantile(latitudes_v, c(1.0/3, 2.0/3, 1))
    l_popul_lon <- least_populated_quantile(longitudes_v, c(1.0/3, 2.0/3, 1))

    legend_pos_vertl <- switch(l_popul_lat, "top", "", "bottom",
                               stop("Unknown most populated quantile in latitude"))

    legend_pos_horiz <- switch(l_popul_lon, "left", "", "right",
                               stop("Unknown most populated quantile in longitude"))

    legend_pos <- sprintf("%s%s", legend_pos_vertl, legend_pos_horiz)
    if ( legend_pos == "") {
      legend_pos <- "center"
    }

    if ( debug_nextbus == TRUE ) {
      cat("Choosing to plot the legend at quadrant '", legend_pos,
          "' because (lat: ", l_popul_lat, ", long: ", l_popul_lon,
          " meaning '", legend_pos_vertl, "', ", legend_pos_horiz,
          "')\n", sep = "")
    }
  } else {
    legend_pos <- fixed_legend_pos
  }

  # Should the legend's background be transparent? If there is no background for
  # the legend (argument bty="n") then it will paint no box around the legend,
  # so the directions of the NextBus vehicles could confound with the Google Map,
  # ie., their respective colors could become mixed and irrecognozible

  legend(legend_pos, legend = legend_text, fill = color_palette,
         title = "Directions", cex=0.6, pt.cex = 1, border = "white",
         pch = '.', bty="o")

  # Stop redirecting this graphical output
  dev.off()
}

# Request to plot the NextBus real-time vehicle locations data frame
# on a Google Map, saving the result to a PNG image file

gmaps_png_fname <- sprintf("nextbus_vehicles_on_gmap_agency_%s_route_%s_time_%d.png",
                            agency_code, bus_route, now_epoch)

plot_nextbus_vehicle_df_gmaps(df, dest_png_fname = gmaps_png_fname,
                              gmap_type = "hybrid", fixed_legend_pos = "topleft")

cat("The image in '", gmaps_png_fname, "' can now be opened.\n", sep = "")
