using NIDAQ, GLMakie


a_in=analog_input("Dev2/ai1")

vec=zeros(100000)

t_obs=Observable(100000)


lines(@lift(vec[$t_obs-99999:$t_obs]))


NIDAQ.CfgSampClkTiming(a_in.th, convert(Ref{UInt8},b""), 10000, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, 50000)



start(a_in)
for i in 1:1000
    vec=vcat(vec, NIDAQ.read(a_in,1000))
    t_obs[]+=1000
    sleep(0.001)
end
stop(a_in)



