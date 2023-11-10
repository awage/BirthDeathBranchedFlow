using BranchedFlowSim
using CairoMakie
using LaTeXStrings
using DrWatson 
using DynamicalSystems


function quasi2d_map!(du,u,p,t)
        x,y,py = u; potential, dt = p
        # kick
        du[3] = py + dt * force_y(potential, x, y)
        # drift
        du[2] = y + dt .* du[3]
        du[1] = x + dt
        return nothing
end



function plot_curves(r) 
    a = 1; v0 = 1.; dt = 0.01; T = 100000; θ = 0.
    pot2 = 0 
    if θ != 0. 
        pot2 = RotatedPotential(θ, CosMixedPotential(r,a, v0)) 
    else 
        pot2 = CosMixedPotential(r, a, v0)
    end
    df = DeterministicIteratedMap(quasi2d_map!, [0., 0.4, 0.2], [pot2, dt])
    yrange = range(-a/2, a/2, length = 40); py = 0.

    s = savename("poincare_r_", @dict(a,v0,dt,r),  "png")
    fig = Figure(resolution = (800, 600))
    ax = Axis(fig[1,1], ylabel = "py", xlabel = "y", yticklabelsize = 40, xticklabelsize = 40, ylabelsize = 40, xlabelsize = 40, title = string("r = ", r), titlesize = 40)
    for (j,y) in enumerate(yrange)
        u,t = trajectory(df, T, [0., y, py])
        ind = range(100, T, step = 100)
        scatter!(ax, rem.(u[ind,2], a, RoundNearest), u[ind,3], markersize = 1.7, color = Cycled(j), rasterize = 1)
    end
    save(string("../outputs/",s), fig)
end

rrange = range(0,1, step = 0.1)
for r in rrange
    plot_curves(r)
end
