using GLMakie, NIDAQ


figure=Figure(backgroundcolor=RGBf(0.8,0.8,0.8),resolution=(800,600))

a=figure[1,1:2] = GridLayout()
b=figure[2,1:2] = GridLayout()
c=figure[1:2,3] = GridLayout()

ca=c[5,1] = GridLayout()

ax_a=Axis(a[1,1],ylabel="Voltage")
ax_b=Axis(b[1,1],xlabel="Time",ylabel="Current")

mode = Toggle(ca[1,1], active = false) 


on_width, offwidth, number, high_amplitude, low_amplitude
frequency, cycle_time


tail_plot=figure[1:5,3] = GridLayout()
tail_viz=Axis(tail_plot[1,1])

tail_angles=Vector{GridLayout}(undef,5)
tail_axes=Vector{Axis}(undef,5)

for i in 1:5
	tail_angles[i] = figure[i,1:2] = GridLayout()
	tail_axes[i] = Axis(tail_angles[i][1,1])
	if i!=5
		hidexdecorations!(tail_axes[i])
	end
	hidexdecorations!(tail_axes[i], ticks=false,ticklabels=false)
end

data = Matrix(DataFrame(CSV.File("data.csv")))

function get_bout(row_num,data)
	t_max=findall(x->x===missing,data[row_num,:])[1]-1
	bout_mat=convert(Matrix{Float32},reshape(data[row_num,1:size(data)[2]-3],(35,:))'[:,1:t_max])
end

function plot_tail(ax,viz_ax,bout;dt=0.005)
	seg_num=1
	t=Observable(1)
	plot_obs=on(t) do t
		for seg_num = 1:5
			empty!(ax[seg_num])
			lines!(ax[seg_num],0:2:2*t-1,bout[seg_num,1:t[]],color=:black)
			sleep(dt)
		end
		seg_x=cumsum([0; sin.(bout[:, t[]])])
		seg_y=-cumsum([0; cos.(bout[:, t[]])])
		empty!(viz_ax)
		lines!(viz_ax,seg_x,seg_y,color=:black)
	end
	xlims!(viz_ax,-3,3)
	ylims!(viz_ax,-8,2)
	for seg_num in 1:5
		ylims!(ax[seg_num], minimum(bout[:,:]), maximum(bout[:,:]))
		xlims!(ax[seg_num],0,size(bout)[2])
	end
	for i in 1:size(bout)[2]
		t[]=i
	end
end

plot_tail(tail_axes,tail_viz,get_bout(1,data),dt=0.01)



time_index=Observable(0)

timestamps=Vector{Int}()
data=Vector{Int}()

lines(@lift(timestamps[time_index-20:time_index]-timestamps[time_index-20]),@lift(data[time_index-20:time_index]))


for i=1:1000
	push!(data,NIDAQ.read()) #fix
	push!(timestamps,get_current_time()) #fix
