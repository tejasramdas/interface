using GLMakie, NIDAQ, ThreadPools


#CONSTANTS
SAMPLE_RATE=10000
DISPLAY_TS=SAMPLE_RATE
DT=1/SAMPLE_RATE
READ_RATE=1000
PLOT_TS=20000 #should be higher than read rate so that the whole plot does not get overwritten

#NIDAQ SETUP
a_in=analog_input("Dev2/ai0:2")
a_out=analog_output("Dev2/ao0")


NIDAQ.CfgSampClkTiming(a_in.th, convert(Ref{UInt8},b""), SAMPLE_RATE, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, SAMPLE_RATE)
NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b""), SAMPLE_RATE, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, SAMPLE_RATE)

#HELPER FUNCTIONS
function voltage_to_mode(x)
	axo_mode = [5, 2, 1, 4, 0, 3]
	axo_desc = ["I-Clamp Fast", "I-Clamp", "I=0", "Track", "N/A", "V-Clamp"]
	m=Int(round(x))
	return axo_mode[m], axo_desc[m]
end

function generate_pulse(width, amplitude, number)
    x=zeros(Int(round(SAMPLE_RATE*width)))
	x=vcat(x, x.+amplitude)
	out=x
	for i in 2:number
		out=vcat(out,x)
    end
    push!(out,0)
	return out
end

function res_test(a_in,a_out)
	if voltage_to_mode(mode[])[1]==3
		stim=generate_pulse(100, 0.25, 5)
		NIDAQ.write(a_out, stim)
		current=NIDAQ.read(a_in, "LENGTH OF INPUT") #fix
		# get peak after x ms
		# divide
		# return
	else
		print("Change mode to V-Clamp.")
	end
end


#OBSERVABLES
mode = Observable(5.0)
recording=Observable(false)
time_index=Observable(DISPLAY_TS)

#PLOT ELEMENTS
figure=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))

a=figure[1,1:2] = GridLayout()
b=figure[2,1:2] = GridLayout()
c=figure[1:2,3] = GridLayout()


ax_i=Axis(a[1,1],ylabel="Voltage",xlims=(-DISPLAY_TS*DT,0), ylims=(-1,1))
ax_o=Axis(b[1,1],xlabel="Time",ylabel="Current",xlims=(-DISPLAY_TS*DT,0), ylims=(-1,1))

mode_label=Label(c[5,1], "Mode: "*@lift(voltage_to_mode($mode)[2])[], textsize=24, tellwidth=false) 


seal_test_rm= Label(c[2,1], "R_m: N/A", textsize =24, tellwidth=false)
seal_test_rs= Label(c[2,2], "R_s: N/A", textsize =24, tellwidth=false)

switch=Button(c[4,1], label=@lift($recording ? "Stop recording" : "Start recording"), textsize=30, tellwidth=false) 
seal_test_button = Button(c[1,1], label="Run seal test", textsize=30,tellwidth=false)


#DATA
i_vec=zeros(DISPLAY_TS)
o_vec=zeros(DISPLAY_TS)
t_vec=Vector(1:DISPLAY_TS)*0.01
m_vec=zeros(DISPLAY_TS).+5 #initialize mode to N/A

#LISTENERS
on(switch.clicks) do x
	recording[] = 1-recording[]
#	println("Pressed")
end

lines!(ax_i,t_vec,@lift(i_vec[$time_index-DISPLAY_TS+1:$time_index]))
lines!(ax_o,t_vec,@lift(o_vec[$time_index-DISPLAY_TS+1:$time_index]))


read_length=0
for i in 1:10000
	datum = NIDAQ.read(daq_input,READ_RATE)
	if recording[]
        push!(i_vec,datum[:,2])
        push!(o_vec,datum[:,1])
    end
    read_length+=READ_RATE
    if read_length>=PLOT_RATE
        t_obs[]+=read_length
		sleep(0.001)
        read_length=0
    end
    if mode[] != Int(round(datum[end,3]))
		println("Why would you change modes while recording!?!?!?")
	end
	mode[] = Int(round(datum[end, 3]))
end
