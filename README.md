# NextBus real-time Route bus locations into an R Dataframe

Queries the `NextBus` API to get the real-time change in the bus locations of a transit service route into an `R` dataframe

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

# WIP

This project is a *work in progress*. The implementation is *incomplete* and
subject to change. The documentation can be inaccurate.

