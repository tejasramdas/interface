using GLMakie, NIDAQ, ThreadPools, Statistics, DataStructures


#CONSTANTS
SAMPLE_RATE=10000 #sampling rate into DAQ buffer
DISPLAY_TS=SAMPLE_RATE*5 #plot width
DT=1/SAMPLE_RATE 
READ_RATE=100 #sampling from DAQ buffer (per read, not per unit time)
PLOT_TS=500 #update plot after multiple reads. should be lower than DISPLAY_TS so that the whole plot does not get overwritten


X_L=-DISPLAY_TS*DT
X_H=0
O_Y_L=-1
O_Y_H=1
I_Y_L=-1
I_Y_H=1

#OBSERVABLES
mode = Observable(5.0)
recording=Observable(false)
MASTER_SWITCH=Observable(true)
update=Observable(1)


#HELPER FUNCTIONS

#NIDAQ SETUP
function reset_nidaq()
	try
		clear(a_in)
		clear(a_out)
	catch
	end
	global a_in=analog_input("Dev2/ai0")
	analog_input(a_in,"Dev2/ai2:3")
	global a_out=analog_output("Dev2/ao0")

	NIDAQ.CfgSampClkTiming(a_in.th, convert(Ref{UInt8},b""), SAMPLE_RATE, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, SAMPLE_RATE*10)

	NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b""), SAMPLE_RATE, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, SAMPLE_RATE*10)

	start(a_out)
	NIDAQ.write(a_out,[0.0])
end

function reset_vars()
	#DATA
	global i_vec=zeros(1)
	global o_vec=zeros(1)
	global m_vec=zeros(1).+5 #initialize mode to N/A
	global t_vec=Vector(-DISPLAY_TS:-1)*DT
	global i_buf=CircularBuffer{Float64}(DISPLAY_TS)
	global o_buf=CircularBuffer{Float64}(DISPLAY_TS)
	fill!(i_buf,0)
	fill!(o_buf,0)
	#RESET OBSERVABLE VALUES
	mode[]=5.0
	recording[]=false
	notify(update)
end

function voltage_to_mode(x)
	if x==0
		x=5
	end
	axo_mode = [5, 2, 1, 4, 0, 3]
	axo_desc = ["I-Clamp Fast", "I-Clamp", "I=0", "Track", "N/A", "V-Clamp"]
	v_in=x in [0,3]
	m=Int(round(x))
	return axo_mode[m], axo_desc[m],v_in
end

function generate_pulse(width, amplitude, number)
    x=zeros(Int(round(SAMPLE_RATE*width)))
	x=vcat(x, x.+amplitude)
	out=x
	for i in 2:number
		out=vcat(out,x)
    end
    push!(out,0.0)
	return out
end

function res_test(;debug=false)
	looping =true
	if  voltage_to_mode(mode[])[1]==3
		pulse_time=0.2
		dur=pulse_time*2+0.1
		println("SEAL TEST \n")
		stim=generate_pulse(pulse_time, 0.5, 1)
		res_fig=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))
		end_loop = Button(res_fig[2,1], label="Stop seal test", textsize=30,tellwidth=false)
		on(end_loop.clicks) do x
			looping=false
		end
		ax=Axis(res_fig[1,1], xlabel="Time", ylabel="Current", title="Seal test", xlims=[0,dur], ylims=[-1,1])
		ser_r=[]
		i_r=[]
		noises=[]
		display(res_fig)
		while looping
			NIDAQ.write(a_out, stim)
			sleep(dur)
			dat_i=i_buf[end-Int(round((dur+0.05)*SAMPLE_RATE)):end]	
			dat_o=o_buf[end-Int(round((dur+0.05)*SAMPLE_RATE)):end]	
			ser_res=10^3*(maximum(dat_i)/50)/maximum(dat_o)
			#println(ser_res)
			push!(ser_r,ser_res)
			l_b=argmax(dat_o)+Int(round(0.01*SAMPLE_RATE))
			u_b=argmin(dat_o)-Int(round(0.01*SAMPLE_RATE))
			i_res=10^3*(mean(dat_i[l_b:u_b])/50)/mean(dat_o[l_b:u_b])
			push!(i_r,i_res)
			noise=std(dat_o[l_b:u_b])
			push!(noises,noise)
			lines!(ax,(1:size(dat_o)[1])/SAMPLE_RATE,dat_o)
		end
		i_r-=ser_r
		seal_test_rs.text[]="R_s: $(round(mean(ser_r),digits=1))"
		seal_test_rm.text[]="R_m: $(round(mean(i_r),digits=1))"
		noise_label.text[]="Noise: $(round(mean(noises),digits=4))"
		println("SEAL TEST COMPLETE \n")
		if debug
			println("Press ENTER to return.")
			readline()
		else
			sleep(2)
		end
		display(figure)
	else
		println("Change mode to V-Clamp.\n")
	end
end

function stim_pulse(h,w,n)
	stim=generate_pulse(w,h,n)
	dur=w*2*n+0.1
	NIDAQ.write(a_out,stim)
	sleep(dur)
end

function read_loop()
	read_length=0
	println("STARTED \n")
	while MASTER_SWITCH[]
		data = NIDAQ.read(a_in)
		append!(i_buf,data[:,2])
		append!(o_buf,data[:,1])
		if recording[]
			append!(i_vec,data[:,2])
			append!(o_vec,data[:,1])
		end
		read_length+=size(data)[1]
		if read_length>=PLOT_TS
			notify(update)
			read_length=0
		end
		# if mode[] != Int(round(data[end,3]))
		#	println("Why would you change modes while recording!?!?!?")
		# end
		if size(data)[1]>0
			mode[] = Int(round(data[end, 3]))
		end
		sleep(0.001)
	end
	println("STOPPED \n")
	stop(a_in)
end

function reset_plot_lims()
	xlims!(ax_i,X_L,X_H)
	xlims!(ax_o,X_L,X_H)
	ylims!(ax_i,I_Y_L,I_Y_H)
	ylims!(ax_o,O_Y_L,O_Y_H)
end

function bye()
	MASTER_SWITCH=false
	sleep(0.5)
	exit()
end

#PLOT ELEMENTS
figure=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))

a=figure[1,1:2] = GridLayout()
b=figure[2,1:2] = GridLayout()
c=figure[1:2,3] = GridLayout()


ax_i=Axis(a[1,1],ylabel="Input",xlims=(X_L,X_H), ylims=(I_Y_L,I_Y_H))
ax_o=Axis(b[1,1],xlabel="Time",ylabel="Output",xlims=(X_L,X_H), ylims=(O_Y_L,O_Y_H))

seal_test_rm= Label(c[2,1], "R_m: N/A", textsize =24, tellwidth=false)
seal_test_rs= Label(c[2,3], "R_s: N/A", textsize =24, tellwidth=false)

noise_label= Label(c[3,:], "Noise: N/A", textsize =24, tellwidth=false)

mode_label=Label(c[11,:], @lift("Mode: "*voltage_to_mode($mode)[2]),textsize=24, tellwidth=false) 


reset_plot=Button(c[8,:], label="Reset plot limits", textsize=30, tellwidth=false) 



stim_h=Textbox(c[5,1], placeholder="H",validator = Float64,tellwidth=false, textsize=24)
stim_w=Textbox(c[5,2], placeholder="W",validator = Float64,tellwidth=false, textsize=24)
stim_n=Textbox(c[5,3], placeholder="N",validator = Int,tellwidth=false,textsize=24)

stim_trig=Button(c[6,:], label="Stimulate", textsize=30, tellwidth=false) 


switch=Button(c[10,:], label=@lift($recording ? "Stop recording" : "Start recording"), textsize=30, tellwidth=false) 
seal_test_button = Button(c[1,:], label="Run seal test", textsize=30,tellwidth=false)

#LISTENERS
on(switch.clicks) do x
	recording[] = 1-recording[]
#	println("Pressed")
end

on(seal_test_button.clicks) do x
	@tspawnat 1 res_test()
end

on(reset_plot.clicks) do x
	reset_plot_lims()
end

on(stim_trig.clicks) do x
	try
		h,w,n=parse(Float64,stim_h.stored_string[]),parse(Float64,stim_w.stored_string[]),parse(Int,stim_n.stored_string[])
		println("Starting stim protocol\n H:$h, W:$w, N:$n, T:$(w*2*n) s")
		stim_pulse(h,w,n)
	catch
		println("Enter all values.")
	end
end


reset_vars()
reset_plot_lims()
reset_nidaq()

lines!(ax_i,t_vec,@lift(i_buf[$update:DISPLAY_TS]))
lines!(ax_o,t_vec,@lift(o_buf[$update:DISPLAY_TS]))

display(figure)


@tspawnat 1 read_loop()

