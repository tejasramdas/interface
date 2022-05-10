using NIDAQ, GLMakie, ThreadPools, DataStructures


a_in=analog_input("Dev2/ai0")

a_in=analog_input("Dev2/ai2")

a_in=analog_input("Dev2/ai3")

NIDAQ.CfgSampClkTiming(a_in.th, convert(Ref{UInt8},b""), 10000, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, 50000)

vec=CircularBuffer{Float64}(100000)
fill!(vec,0)

t_obs=Observable(1)

f=Figure()
a=Axis(f[1,1])

ylims!(a,-1,12)

lines!(a,@lift(vec[$t_obs:end]))

a_out=analog_output("Dev2/ao0")

NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b""), 1000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, 6000)

NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b""), 1000, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, 50000)

NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b"Dev2/aiSampleClock"), 10000, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, 50000)

@time begin
start(a_in)
sleep(0.001)
x=size(NIDAQ.read(a_in))
stop(a_in)
end
println(x)

@time begin
start(a_in)
sleep(0.001)
for i in 1:100
	dat=NIDAQ.read(a_in)
	append!(vec,dat)
	notify(t_obs)
    sleep(0.01)
end
stop(a_in)
end


stream=true
t= @tspawnat 1 begin
start(a_in)
sleep(0.001)
while stream
	dat=NIDAQ.read(a_in)
	append!(vec,dat)
	#Core.println(i," ",vec[end])
	notify(t_obs)
    sleep(0.01)
end
stop(a_in)
end

stream=false

fetch(t)

stop(a_in)

sig=0.5.*sin.((1:5000).*(pi/2500))

start(a_out)

stop(a_out)

stop(a_out)
start(a_out)

NIDAQ.write(a_out,[0.0])

NIDAQ.write(a_out,sig)

clear(a_out)
