## Patch Clamp Interface
### Minimal interface for patch clamp recording using Axopatch/NIDAQ written in Julia/Makie


### TODOTODOTODO
 - add reset and save for data.
 - make sure time points of data map correctly. FIFO but dt is different for input and ouput looks like. Also how much memory does the card have? And is it possible to read until the end (i.e. clear memory after stopping the channel) (mostly solved but ned to test rigorously).
 - Data listener works asynchronously even when read_loop is called on main thread. Not sure why. Makes everything work ok but not sure when it'll break.
 - Still need to handle switching modes correctly.
 - Seal test output seems to output extra pulses and restarts when task is restarted. Confusing.
 - Need to change timeout by writing custom wrapper for analog read.
 - Add more functions to reset things.
 - Connect stuff to buttons.
 - Label observable doesn't work so manually updating for now. 
 - I/O clocks need to be synced properly but good enough for now.


RIG
 - Add LED Array
 - Install camera
 - Add headstage to manipulator
 - Fabricate stage
 - Get rid of picospritzer
 - Connect air supply to table
 - Get green filter for BAPTA
 - Clean up
