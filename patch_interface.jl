using GLMakie, NIDAQ

#TO DO
# - figure out why analog output has an arbitrary floor
# - send seal test pulse and get input
# - calculate input resistance and seal resistance (and display)
# - figure out whether to have a loop running for the whole session or trigger functions using listeners
# - add reset and save for data
# - make sure time points of data map correctly. FIFO but dt is different for input and ouput looks like. Also how much memory does the card have? And is it possible to read until the end (i.e. clear memory after stopping the channel)



#OBSERVABLES
mode = Observable(5.0)
recording=Observable(false)

#PLOT ELEMENTS
figure=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))

a=figure[1,1:2] = GridLayout()
b=figure[2,1:2] = GridLayout()
c=figure[1:2,3] = GridLayout(tellwidth=false)


ax_v=Axis(a[1,1],ylabel="Voltage",xlims=(-100,0), ylims=(-1,1))
ax_i=Axis(b[1,1],xlabel="Time",ylabel="Current",xlims=(-100,0), ylims=(-1,1))

mode_label=Label(c[5,1], "Mode: "*@lift(voltage_to_mode($mode)[2])[], textsize=24, tellheight=false, tellwidth=false) 

switch=Button(c[4,1], label=@lift($recording ? "Stop recording" : "Start recording"), textsize=30, tellheight=false, tellwidth=false) 
seal_test_button = Button(c[1,1], label="Run seal test", textsize=30, tellheight=false,tellwidth=false)



#HELPER FUNCTIONS
function voltage_to_mode(x)
	axo_mode = [5, 2, 1, 4, 0, 3]
	axo_desc = ["I-Clamp Fast", "I-Clamp", "I=0", "Track", "N/A", "V-Clamp"]
	m=Int(round(x))
	return axo_mode[m], axo_desc[m]
end

function generate_pulse(width, amplitude, number)
	x=zeros(Int(round(width/DT)))
	x=vcat(x, zeros(Int(round(width/DT))).+amplitude)
	out=x
	for i in 1:number
		out=vcat(out,x)
	return out
end

function seal_test(a_in,a_out)
	if voltage_to_mode(mode[])[1]==3
		stim=generate_pulse(100, 0.25, 5)
		NIDAQ.write(a_out, stim)
		current=NIDAQ.read(a_in, "LENGTH OF INPUT") #fix

	else
		print("Change mode to V-Clamp.")


on(switch.clicks) do x
	recording[] = 1-recording[]
#	println("Pressed")
end


on_width, offwidth, number, high_amplitude, low_amplitude
frequency, cycle_time
OUT_DT=getproperties(a_out, "Dev1/ai0")[..] #FIX

display_time_points=100

v_vec=zeros(display_time_points)
i_vec=zeros(display_time_points)
t_vec=Vector(1:display_timepoints)*0.01


lines!(ax_v,@lift(t_vec[$time_index-display_time_points:$time_index]-t_vec[$time_index],v_vec[$time_index-display_time_points:$time_index]))
lines!(ax_i,@lift(t_vec[$time_index-display_time_points:$time_index]-t_vec[$time_index],i_vec[$time_index-display_time_points:$time_index]))



time_index=Observable(display_time_points)

for i in 1:10000
	datum = NIDAQ.read(daq_input)
	if recording[]
		#push!(v_vec,NIDAQ.read(daq_input)) #fix
		#push!(t_vec,get_current_time()) #fix
		if mode[] != Int(round(datum[end,3]))
			println("Why would you change modes while recording!?!?!?")
		end
	end
	mode[] = Int(round(datum[end, 3]))
	sleep(0.2)
end
		
