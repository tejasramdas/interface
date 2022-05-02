using NIDAQ, GLMakie, ThreadPools


a_in=analog_input("Dev2/ai1")
vec=zeros(100000)
t_obs=Observable(100000)


NIDAQ.CfgSampClkTiming(a_in.th, convert(Ref{UInt8},b""), 10000, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, 50000)

lines(@lift(vec[$t_obs-99999:$t_obs]))

start(a_in)
@tspawnat 1 for i in 1:1000
	dat=NIDAQ.read(a_in)
    vec=vcat(vec, dat)
	t_obs[]+=size(dat)
    sleep(0.001)
end
stop(a_in)



using NIDAQ
a_out=analog_output("Dev2/ao0")

NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b""), 10000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, 50000)


square=repeat(vcat(zeros(1000).-0.5,zeros(1000).+0.5),5)

NIDAQ.write(a_out,square)
