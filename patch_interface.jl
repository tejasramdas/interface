using GLMakie, NIDAQ, ThreadPools


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
time_index=Observable(DISPLAY_TS)


#HELPER FUNCTIONS

#NIDAQ SETUP
function reset_nidaq()
	try
		clear(a_in)
		clear(a_out)
	catch
	end
	global a_in=analog_input("Dev2/ai0:2")
	global a_out=analog_output("Dev2/ao0")
	NIDAQ.CfgSampClkTiming(a_in.th, convert(Ref{UInt8},b""), SAMPLE_RATE, NIDAQ.Val_Rising, NIDAQ.Val_ContSamps, SAMPLE_RATE)
	NIDAQ.CfgSampClkTiming(a_out.th, convert(Ref{UInt8},b""), SAMPLE_RATE, NIDAQ.Val_Rising, NIDAQ.Val_FiniteSamps, SAMPLE_RATE)
	start(a_out)
	NIDAQ.write(a_out,[0.0])
end

function reset()
	#DATA
	global i_vec=zeros(DISPLAY_TS)
	global o_vec=zeros(DISPLAY_TS)
	global m_vec=zeros(DISPLAY_TS).+5 #initialize mode to N/A
	global t_vec=Vector(-DISPLAY_TS:-1)*DT
	#RESET OBSERVABLE VALUES
	mode[]=5.0
	recording[]=false
	time_index[]=DISPLAY_TS
end

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
    push!(out,0.0)
	return out
end

function res_test()
	if recording[]==false && voltage_to_mode(mode[])[1]==3
		println("SEAL TEST")
		stim=generate_pulse(0.1, 0.5, 3)
		recording[]=true
		NIDAQ.write(a_out, stim)
		sleep(2)
		recording[]=false
		dat_i=i_vec[end-2*SAMPLE_RATE-500:end]	
		dat_o=o_vec[end-2*SAMPLE_RATE-500:end]	
		ser_res=10^3*(0.5/50)/maximum(dat_o)
		println(ser_res)
	else
		println("Stop recording and/or change mode to V-Clamp.")
	end
end

function read_loop()
	read_length=0
	start(a_in)
	read_length=0
	println("STARTED")
	while recording[]
		data = NIDAQ.read(a_in)
		global i_vec=vcat(i_vec,data[:,2])
		global o_vec=vcat(o_vec,data[:,1])
		read_length+=size(data)[1]
		if read_length>=PLOT_TS
			time_index[]+=read_length
			read_length=0
		end
		# if mode[] != Int(round(data[end,3]))
		#	println("Why would you change modes while recording!?!?!?")
		# end
		if size(data)[1]>0
			mode[] = Int(round(data[end, 3]))
			mode_label.text[]="Mode: "*voltage_to_mode(mode[])[2]
		end
		sleep(0.001)
	end
	println("STOPPED")
	stop(a_in)
end

function reset_plot_lims()
	xlims!(ax_i,X_L,X_H)
	xlims!(ax_o,X_L,X_H)
	ylims!(ax_i,I_Y_L,I_Y_H)
	ylims!(ax_o,O_Y_L,O_Y_H)
end

#PLOT ELEMENTS
figure=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))

a=figure[1,1:2] = GridLayout()
b=figure[2,1:2] = GridLayout()
c=figure[1:2,3] = GridLayout()


ax_i=Axis(a[1,1],ylabel="Input",xlims=(X_L,X_H), ylims=(I_Y_L,I_Y_H))
ax_o=Axis(b[1,1],xlabel="Time",ylabel="Output",xlims=(X_L,X_H), ylims=(O_Y_L,O_Y_H))

seal_test_rm= Label(c[2,1], "R_m: N/A", textsize =24, tellwidth=false)
seal_test_rs= Label(c[2,2], "R_s: N/A", textsize =24, tellwidth=false)

mode_label=Label(c[10,:], "Mode: "*voltage_to_mode(mode[])[2],textsize=24, tellwidth=false) 

reset_plot=Button(c[3,:], label="Reset plot limits", textsize=30, tellwidth=false) 
switch=Button(c[9,:], label=@lift($recording ? "Stop recording" : "Start recording"), textsize=30, tellwidth=false) 
seal_test_button = Button(c[1,:], label="Run seal test", textsize=30,tellwidth=false)


#LISTENERS
on(switch.clicks) do x
	recording[] = 1-recording[]
#	println("Pressed")
end

on(recording) do x
	if x==1
		@tspawnat 1 read_loop()
	end
end

on(seal_test_button.clicks) do x
	@tspawnat 1 res_test()
end

on(reset_plot.clicks) do x
	reset_plot_lims()
end

reset()
reset_nidaq()
reset_plot_lims()

@tspawnat 1 lines!(ax_i,t_vec,@lift(i_vec[$time_index-DISPLAY_TS+1:$time_index]))
@tspawnat 1 lines!(ax_o,t_vec,@lift(o_vec[$time_index-DISPLAY_TS+1:$time_index]))

display(figure)
