using NIDAQ

a_out=analog_output("Dev2/ao0")


NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b""), 1000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, 10000)

NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b"Dev2/ai/SampleClock"), 10000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, 50000)

sig=0.5.*sin.((1:5000).*(pi/2500))

start(a_out)

stop(a_out)

stop(a_out)
start(a_out)


NIDAQ.write(a_out,sig)

