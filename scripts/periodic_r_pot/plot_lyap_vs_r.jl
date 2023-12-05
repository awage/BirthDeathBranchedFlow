using BranchedFlowSim
using CairoMakie
using LaTeXStrings
using LinearAlgebra
using StaticArrays
using Peaks
using DrWatson 
using ChaosTools


function detect_bounded(u,a)

    ind = findall(abs.(u[:,2]) .> a/2) 
    if length(ind) > 0
        return 0
    else 
        return 1
    end
end 

function quasi2d_map!(du,u,p,t)
        x,y,py = u; potential, dt = p
        # kick
        du[3] = py + dt * force_y(potential, x, y)
        # drift
        du[2] = y + dt .* du[3]
        du[1] = x + dt
        return nothing
end

function _get_lyap(d) 
    @unpack θ , r,  a, v0, dt, T, res = d
    if θ != 0. 
        pot2 = RotatedPotential(θ, CosMixedPotential(r,a, v0)) 
    else 
        pot2 = CosMixedPotential(r, a, v0)
    end

    df = DeterministicIteratedMap(quasi2d_map!, [0., 0.4, 0.2], [pot2, dt])

    yrange = range(-0.5, 0.5, res)
    pyrange = range(0, 1, res)
    λ = [lyapunov(df, T; u0 = [0., y, py]) for y in yrange, py in pyrange]
    bnd_traj = [ detect_bounded(trajectory(df, 10000, [0, y, py])[1],a) for y in yrange, py in pyrange]

    return @strdict(λ, bnd_traj, yrange, pyrange, d)
end


function _get_lyap_1D(d) 
    @unpack θ , r,  a, v0, dt, T, res = d
    if θ != 0. 
        pot2 = RotatedPotential(θ, CosMixedPotential(r,a, v0)) 
    else 
        pot2 = CosMixedPotential(r, a, v0)
    end
    df = DeterministicIteratedMap(quasi2d_map!, [0., 0.4, 0.2], [pot2, dt])
    yrange = range(-0.5, 0.5, res)
    py = 0.
    λ = [lyapunov(df, T; u0 = [0., y, py]) for y in yrange]
    return @strdict(λ, yrange, d)
end


function print_fig_lyap(r; res = 500,  a = 1, v0 = 1., dt = 0.01, T = 10000, θ = 0.)
    d = @dict(res, r, a, v0,  T, dt, θ) # parametros
    data, file = produce_or_load(
        datadir("./storage"), # path
        d, # container for parameter
        _get_lyap_1D, # function
        prefix = "periodic_bf_lyap_1D", # prefix for savename
        force = false, # true for forcing sims
        wsave_kwargs = (;compress = true)
    )

    @unpack yrange, λ = data
    s = savename("plot_lyap_1D", d, "png")
    fig = Figure(resolution=(800, 600))
    ax1= Axis(fig[1, 1], title = string("r = ", r) , xlabel = L"y", ylabel = L"\lambda_{max}", yticklabelsize = 40, xticklabelsize = 40, ylabelsize = 40, xlabelsize = 40,  titlesize = 40) 
    hm = scatter!(ax1, yrange, λ)
    lines!(ax1,[-0.5, 0.5], [0.001, 0.001]; color = :red) 
    save(string("./outputs/", s),fig)
end

function get_lyap_index(r, threshold; res = 500,  a = 1, v0 = 1., dt = 0.01, T = 10000, θ = 0.)
    d = @dict(res, r, a, v0,  T, dt, θ) # parametros
    data, file = produce_or_load(
        datadir("./storage"), # path
        d, # container for parameter
        _get_lyap_1D, # function
        prefix = "periodic_bf_lyap_1D", # prefix for savename
        force = false, # true for forcing sims
        wsave_kwargs = (;compress = true)
    )
    @unpack λ = data
    ind = findall(λ .> threshold)
    l_index = length(ind)/length(λ) 
    return l_index
end

# for r in 0:0.1:1 
#     print_fig_lyap(r)
# end

res = 500;  a = 1; v0 = 1.; dt = 0.01; T = 10000; θ = 0.; threshold = 0.001
rrange = range(0,0.5, length = 50)
ll = Float64[]
for r in rrange
    lidx = get_lyap_index(r, 0.001; res, a, v0, dt, T, θ)
    push!(ll, lidx)
end

d = @dict(res, a, v0,  T, dt, θ) # parametros
s = savename("lyap_index",d, "png")
fig = Figure(resolution=(800, 600))
ax1= Axis(fig[1, 1],  xlabel = L"r", ylabel = "lyap index", yticklabelsize = 40, xticklabelsize = 40, ylabelsize = 40, xlabelsize = 40,  titlesize = 40) 
lines!(ax1, rrange, ll, color = :blue)
save(string("./outputs/",s),fig)

print_fig_lyap(0.0)
print_fig_lyap(0.12)
print_fig_lyap(0.25)
print_fig_lyap(0.5)
