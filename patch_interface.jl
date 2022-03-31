using GLMakie, NIDAQ

figure=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))

a=figure[1,1:2] = GridLayout()
b=figure[2,1:2] = GridLayout()
c=figure[1:2,3] = GridLayout(tellwidth=false)


ax_v=Axis(a[1,1],ylabel="Voltage",xlims=(-100,0), ylims=(-1,1))
ax_i=Axis(b[1,1],xlabel="Time",ylabel="Current",xlims=(-100,0), ylims=(-1,1))

mode = Observable(5.0)

function voltage_to_mode(x)
	axo_mode = [5, 2, 1, 4, 0, 3]
	axo_desc = ["I-Clamp Fast", "I-Clamp", "I=0", "Track", "N/A", "V-Clamp"]
	m=Int(round(x))
	return axo_mode[m], axo_desc[m]
end



mode_label=Label(ca[1,1], "Mode: "*@lift(voltage_to_mode($mode)[2]), textsize=24, tellheight=false, tellwidth=false) 

switch=Button(cd[1,1], label=@lift($recording ? "Stop recording" : "Start recording"), textsize=30, tellheight=false, tellwidth=false) 
seal_test_button = Button(ca[1,1], label="Run seal test", textsize=30, tellheight=false,tellwidth=false)

on(switch.clicks) do x
	recording[] = 1-recording[]
	println("Pressed")
end


on_width, offwidth, number, high_amplitude, low_amplitude
frequency, cycle_time


display_time_points=100

v_vec=zeros(display_time_points)
i_vec=zeros(display_time_points)
t_vec=Vector(1:display_timepoints)*0.01


lines!(ax_v,@lift(t_vec[$time_index-display_time_points:$time_index]-t_vec[$time_index],v_vec[$time_index-display_time_points:$time_index]))
lines!(ax_i,@lift(t_vec[$time_index-display_time_points:$time_index]-t_vec[$time_index],i_vec[$time_index-display_time_points:$time_index]))

recording=Observable(false)

#use button to toggle recording

time_index=Observable(display_time_points)

for i in 1:10000
	datum = NIDAQ.read(daq_input)
	if recording[]
		#push!(v_vec,NIDAQ.read(daq_input)) #fix
		#push!(t_vec,get_current_time()) #fix
		if mode[] != Int(round(datum[end,3]))
			println("Why would you change mode while recording!?!?!?")
		end
	end
	mode[] = Int(round(datum[end, 3]))
	sleep(0.2)
end
		
