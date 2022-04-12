## Patch Clamp Interface
### Minimal interface for patch clamp recording using Axopatch/NIDAQ written in Julia/Makie



### TODOTODOTODO
 - figure out why analog output has an arbitrary floor
 - send seal test pulse and get input
 - calculate input resistance and seal resistance (and display)
 - figure out whether to have a loop running for the whole session or trigger functions using listeners
 - add reset and save for data
 - make sure time points of data map correctly. FIFO but dt is different for input and ouput looks like. Also how much memory does the card have? And is it possible to read until the end (i.e. clear memory after stopping the channel)
 - DAQmxReadAnalogF64 reads all samples in buffer when set to continuous. But Julia wrapper only returns 1 sample for some reason.



