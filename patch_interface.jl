using GLMakie, NIDAQ, ThreadPools, Statistics, DataStructures, Dates, CSV, Tables

#DATA FOlDER

DATA_SAVE="/home/"*ENV["USER"]*"/data/"

#CONSTANTS
SAMPLE_RATE=10000 #sampling rate into DAQ buffer
DISPLAY_TS=SAMPLE_RATE*5 #plot width
DT=1/SAMPLE_RATE 
READ_RATE=100 #sampling from DAQ buffer (per read, not per unit time)
PLOT_TS=500 #update plot after multiple reads. should be lower than DISPLAY_TS so that the whole plot does not get overwritten

# Input = AxoClamp => Cell (NIDAQ Out)
# Output = Cell => AxoClamp (NIDAQ In)

V_I = 0.05 # 1 V/20 mV = 0.05 V/mV
I_I = 0.5 # 1 V/2 nA = 0.5 V/nA

I_O = 1000 # 1 V/V = 1000 mV/V
V_O = 1 # 1 nA/V

#AXES_LIMITS

#A_B_C_D:
#A=V-Clamp/I-Clamp
#B=Input/Outout
#C=X/Y Axis
#D=LOW/HIGH

X_L=-DISPLAY_TS*DT
X_H=0


V_I_Y_L=-70
V_I_Y_H=30
V_O_Y_L=-1
V_O_Y_H=1

I_I_Y_L=-1
I_I_Y_H=1
I_O_Y_L=-70
I_O_Y_H=30


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
	analog_input(a_in,"Dev2/ai2")
	analog_input(a_in,"Dev2/ai4")
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
	global I_c = V_I
	global O_c = V_O
	fill!(i_buf,0)
	fill!(o_buf,0)
	#RESET OBSERVABLE VALUES
	mode[]=5.0
	recording[]=false
	notify(update)
end

function voltage_to_mode(x)
	axo_mode = [5, 2, 1, 4, 0, 3]
	axo_desc = ["I-Clamp Fast", "I-Clamp", "I=0", "Track", "N/A", "V-Clamp"]
	m=Int(round(x))
	if m==0
		m=5
	end
	v_c=m in [4,5,6]
	return axo_mode[m], axo_desc[m],v_c
end

function generate_pulse(width, isi, amplitude, number)
    x=zeros(Int(round(SAMPLE_RATE*isi)))
    y=zeros(Int(round(SAMPLE_RATE*width)))
	x=vcat(x, y.+amplitude*I_c)
	out=x
	for i in 2:number
		out=vcat(out,x)
    end
    push!(out,0.0)
	return out
end

function save_data()
	if recording[]
		println("Stop recording before saving data.")
	else
		save_dir=SAVE_DATA*Dates.format(now(),"yyyy-mm-dd-HH-MM-SS")
		mkdir(save_dir)
		println("Description:")
		desc=readline()
		open(save_dir*"/desc.txt","w") do io
			   write(io,desc)
		end
		CSV.write(save_dir*"/data.csv",Tables.table(hcat(i_vec,o_vec,m_vec)),header=["Input","Output,"Mode"]) 
	end
end


function res_test(;debug=false)
	looping =true
	if  voltage_to_mode(mode[])[1]==3
		pulse_time=0.2
		dur=pulse_time*2+0.1
		println("SEAL TEST \n")
		stim=generate_pulse(pulse_time, pulse_time, 10, 1)
		res_fig=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))
		end_loop = Button(res_fig[10,2], label="Stop seal test", textsize=30,tellwidth=false)
		on(end_loop.clicks) do x
			looping=false
		end
		ax=Axis(res_fig[1:9,1:3], xlabel="Time", ylabel="Current", title="Seal test", xlims=[0,dur], ylims=[-1,1])
		seal_rm= Label(res_fig[4,4], "R_m: N/A", textsize =24, tellwidth=false)
		seal_rs= Label(res_fig[6,4], "R_s: N/A", textsize =24, tellwidth=false)
		seal_n= Label(res_fig[8,4], "R_s: N/A", textsize =24, tellwidth=false)

		ser_r=[]
		i_r=[]
		noises=[]
		display(res_fig)
		while looping
			NIDAQ.write(a_out, stim)
			sleep(dur)
			dat_i=i_buf[end-Int(round((dur+0.05)*SAMPLE_RATE)):end]	
			dat_o=o_buf[end-Int(round((dur+0.05)*SAMPLE_RATE)):end]	
			ser_res=(maximum(dat_i))/maximum(dat_o)
			#println(ser_res)
			push!(ser_r,ser_res)
			l_b=argmax(dat_o)+Int(round(0.01*SAMPLE_RATE))
			u_b=argmin(dat_o)-Int(round(0.01*SAMPLE_RATE))
			i_res=(mean(dat_i[l_b:u_b]))/mean(dat_o[l_b:u_b])
			push!(i_r,i_res)
			noise=std(dat_o[l_b:u_b])
			push!(noises,noise)
			lines!(ax,(1:size(dat_o)[1])/SAMPLE_RATE,dat_o)
			seal_rs.text[]="R_s: $(round(mean(ser_r),digits=1)) MΩ"
			seal_rm.text[]="R_m: $(round(mean(i_r),digits=1)) MΩ"
			seal_n.text[]="Noise: $(round(mean(noises),digits=4))"
		end
		i_r-=ser_r
		seal_test_rs.text[]="R_s: $(round(mean(ser_r),digits=1)) MΩ"
		seal_test_rm.text[]="R_m: $(round(mean(i_r),digits=1)) MΩ"
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

function stim_pulse(h,w,i,n)
	stim=generate_pulse(w,i,h,n)
	dur=w*2*n+0.1
	NIDAQ.write(a_out,stim)
	sleep(dur)
end

function read_loop()
	read_length=0
	println("STARTED \n")
	while MASTER_SWITCH[]
		data = NIDAQ.read(a_in)
		append!(i_buf,data[:,2]/I_c)
		append!(o_buf,data[:,1]*O_c)
		if size(data)[1]>0
			if mode[]!=Int(round(data[end,3]))
				if voltage_to_mode(data[end,3])[3]
					global I_c=V_I
					global O_c=V_O
					ylims!(ax_i,V_I_Y_L,V_I_Y_H)
					ylims!(ax_o,V_O_Y_L,V_O_Y_H)
				else
					global I_c=I_I
					global O_c=I_O
					ylims!(ax_i,I_I_Y_L,I_I_Y_H)
					ylims!(ax_o,I_O_Y_L,I_O_Y_H)
				end
			end
			mode[]=Int(round(data[end,3]))
		end
		if recording[]
			append!(i_vec,data[:,2])
			append!(o_vec,data[:,1])
			append!(m_vec,data[:,3])
		end
		read_length+=size(data)[1]
		if read_length>=PLOT_TS
			notify(update)
			read_length=0
		end
		sleep(0.001)
	end
	println("STOPPED \n")
	stop(a_in)
end

function reset_plot_lims()
	xlims!(ax_i,X_L,X_H)
	xlims!(ax_o,X_L,X_H)
	ylims!(ax_i,V_I_Y_L,V_I_Y_H)
	ylims!(ax_o,V_O_Y_L,V_O_Y_H)
end

function bye()
	MASTER_SWITCH=false
	sleep(0.5)
	exit()
end

#PLOT ELEMENTS

fontsize_theme = Theme(fontsize = 20)
set_theme!(fontsize_theme)

figure=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(1200,900))

a=figure[1,1:2] = GridLayout()
b=figure[2,1:2] = GridLayout()
c=figure[1:2,3] = GridLayout()


ax_i=Axis(a[1,1],ylabel=@lift(voltage_to_mode($mode)[3] ?  "Voltage Input (mV)" : "Current Input (nA)"),xlims=(X_L,X_H), ylims=(V_I_Y_L,V_I_Y_H))
ax_o=Axis(b[1,1],xlabel="Time",ylabel=@lift(voltage_to_mode($mode)[3] ?  "Current Output (nA)" : "Voltage Output (mV)"),xlims=(X_L,X_H), ylims=(V_O_Y_L,V_O_Y_H))

seal_test_rm= Label(c[2,1], "R_m: N/A", textsize =24, tellwidth=false)
seal_test_rs= Label(c[2,2], "R_s: N/A", textsize =24, tellwidth=false)

noise_label= Label(c[3,:], "Noise: N/A", textsize =24, tellwidth=false)

mode_label=Label(c[12,:], @lift("Mode: "*voltage_to_mode($mode)[2]),textsize=24, tellwidth=false) 


reset_plot=Button(c[9,:], label="Reset plot limits", textsize=30, tellwidth=false) 



stim_w=Textbox(c[5,1], placeholder="W",validator = Float64,tellwidth=false, textsize=24)
stim_i=Textbox(c[5,2], placeholder="I",validator = Float64,tellwidth=false, textsize=24)
stim_h=Textbox(c[6,1], placeholder="H",validator = Float64,tellwidth=false, textsize=24)
stim_n=Textbox(c[6,2], placeholder="N",validator = Int,tellwidth=false,textsize=24)

stim_trig=Button(c[7,:], label="Stimulate", textsize=30, tellwidth=false) 


switch=Button(c[11,:], label=@lift($recording ? "Stop recording" : "Start recording"), textsize=30, tellwidth=false) 
seal_test_button = Button(c[1,:], label="Run seal test", textsize=30,tellwidth=false)

#LISTENERS
on(switch.clicks) do x
	append!(i_vec,zeros(5))
	append!(o_vec,zeros(5))
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
		h,w,i,n=parse(Float64,stim_h.stored_string[]),parse(Float64,stim_w.stored_string[]),parse(Float64,stim_i.stored_string[]),parse(Int,stim_n.stored_string[])
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
