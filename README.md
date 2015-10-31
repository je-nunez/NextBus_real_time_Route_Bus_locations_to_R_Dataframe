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

# An example ggplot of the dataframe

This is a simple `ggplot()` graph in `R` of the daframe obtained from the
NextBus real-time XML Feed API, giving the delay in updating the real-time
position of the transit vehicles according to their geographical location
for route `38R` in the `San Francisco Municipal Transportation Agency` at
one given moment:

![Delays of Real-Time Location of Vehicles in a Route](/delays_in_real_time_location_of_transit_vehicles.png?raw=true "Delays of Real-Time Location of Vehicles in a Route")

(The geographical locations of the transit buses don't need to be
ncessarily the coordinates of the bus stops, for a bus may be in
movement when its location was registered or updated in NextBus.)

