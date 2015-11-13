# NextBus real-time Route bus locations into an R Dataframe

Queries the `NextBus` XML Feed API to get the real-time change in the bus locations of a transit
service route into an `R` dataframe

What is loaded into an R dataframe is, according to current NextBus API, is at least the following
columns for *each* vehicle that is servicing a transit route in quasi real-time (see column below
on `secsSinceReport` for brief delay in real-time update):

     Vehicle-id: the unique ID of the transit vehicle (e.g., of the bus, streetcar, etc)

     The Transit-Route code

     The ID of the direction in which this vehicle is heading

     Latitude and Longitude: Geospatial position of the vehicle

     Speed of the Vehicle (in Kilometers/hour)

     Number of seconds passed since position and speed were last reported

     NextBus can predict the future position of the vehicle: a boolean value

# Note

NextBus has a request limit that only one `vehicleLocations` query is allowed every
5 minutes per client, as to avoid DoS abuse of their API:

    In order to prevent some users from being able to download so much data that
    it would interfere with other users we have imposed restrictions on data usage.
    These limitations could change at any time. They currently are:

       Maximum timespan for "vehicleLocations" command: 5min

# WIP

This project is a *work in progress*. The implementation is *incomplete* and
subject to change. The documentation can be inaccurate.

# An example ggplot of the NextBus vehicle locations dataframe

This is a simple `ggplot()` graph in `R` of the daframe obtained from the
NextBus real-time XML Feed API, giving the delay in updating the real-time
position of the transit vehicles according to their geographical location
for route `38R` in the `San Francisco Municipal Transportation Agency` at
one given moment:

![Delays of Real-Time Location of Vehicles in a Route](/delays_in_real_time_location_of_transit_vehicles.png?raw=true "Delays of Real-Time Location of Vehicles in a Route")

(The geographical locations of the transit buses don't need to be
ncessarily the coordinates of the bus stops, for a bus may be in
movement when its location was registered or updated in NextBus.)

# An example RgoogleMaps of the NextBus vehicle locations dataframe

The program uses `RgoogleMaps` to plot the real-time location of the
vehicles servicing a transit route, and saves this plot in a file
named
`nextbus_vehicles_on_gmap_agency_{agency}_route_{route}_time_{epoch_time}.png`.

An example of the RgoogleMaps plot with the NextBus real-time vehicle
locations for route `38R of San Francisco Muni` is below:

![A RgoogleMaps plot with the NextBus real-time vehicle locations for route 38R of San Francisco Muni](/nextbus_vehicles_on_gmap.png?raw=true "A RgoogleMaps plot with the NextBus real-time vehicle locations for route 38R of San Francisco Muni")

Vehicles in the same direction of a route (having a same value in their
attribute NextBus' `dirTag`), have the same color in the Google Map.
Note that in this map it happens to appear a vehicle which is filled in
`blue`: NextBus didn't provide a `dirTag` for it (a parked out-of-service
vehicle?), so the parser in `R` inserted a `NA` value for the column
`dir_tag` for it, and the plotter choose blue as an allowable color to
distinguish the case this vehicle represents.

There can be an optional legend describing the mapping of the colors
to the directions of the vehicles according to NextBus. Note that some
agencies, for a same NextBus route, have subroutes with a `small
variation` of the directions from the main route, folded inside the
main route code: in this case multiple colors will be generated in
the locations on the Google Map (and the legend will identify exactly
which sub-route it is referring to). For example, for the `Toronto
Transit Commission (TTC) 501 Queen St. streetcar` the real-time
location plot on Google Maps (with a legend generated) can appear as:

![A route with smaller subroutes: the Toronto TTC 501 Queen St. streetcar](/nextbus_vehicles_on_gmap_agency_ttc_route_501_toronto_transit_routes_with_small_variations_as_subroutes.png?raw=true "A route with smaller subroutes: the Toronto TTC 501 Queen St. streetcar")

