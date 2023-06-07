using BranchedFlowSim
using CairoMakie
using Makie
using ColorSchemes
using ColorTypes
using FFTW

# Maybe should set somw
FFTW.set_num_threads(8)

path_prefix = "outputs/qm_planar/planar"
# rm(dirname(path_prefix), recursive=true)
mkpath(dirname(path_prefix))

ħ = 1.0
scale = 3.0
aspect_ratio = 8

Ny = 256
Nx = aspect_ratio * Ny

# Here are some hacks to make images with same feature size but with different
# angles.
# TODO: document better if this ends up being useful.
int_cot = 3
angle = acot(int_cot)

if int_cot != 0
    H = scale * int_cot / cos(angle)
else
    # Multiply by 2 to have more dots.
    H = scale * 2
end
W = H * aspect_ratio

px = scale * 10
x0 = scale * 1.5
packet_Δx = scale * 0.25
v0 = 20 * scale^2
# These are tuned to get rid of reflections
absorbing_wall_width = scale * 0.75
absorbing_wall_strength = 300 * scale.^2

with_walls = true

if !with_walls
    path_prefix = path_prefix * "_periodic"
end

function pixel_heatmap(path, data; kwargs...)
    data = transpose(data)
    scene = Scene(camera=campixel!, resolution=size(data))
    heatmap!(scene, data; kwargs...)
    save(path, scene)
end

function heatmap_with_potential(path, data, potential; colorrange=extrema(data))
    fire = reverse(ColorSchemes.linear_kryw_0_100_c71_n256)
    pot_colormap = ColorSchemes.grays
    # data_colormap = ColorSchemes.viridis
    data_colormap = fire

    V = real(potential)
    minV, maxV = extrema(V)
    minD, maxD = colorrange
    print("datarange: [$(minD),$(maxD)]\n")
    pot_img = get(pot_colormap, (V .- minV) ./ (maxV - minV + 1e-9))
    data_img = get(data_colormap, (data .- minD) / (maxD - minD))
    
    img = mapc.((d,v) -> clamp(d - 0.2 * v, 0, 1), data_img, pot_img) 
    save(path, img)
end

E = px^2 / 2
print("E=$(E)\n")
# Higher energies require smaller timesteps
dt = 1 / (E)
# Enough steps such that the packet travels the distance
T = 1.3 * (W / px)
num_steps = round(Int, T / dt)


@assert W / Nx == H / Ny

xgrid = range(0, step=W / Nx, length=Nx)
ygrid = range(0, step=H / Ny, length=Ny)

potential = zeros(ComplexF64, Ny, Nx)

# xstart = if with_walls
#     3
# else
#     1
# end
# for x ∈ xstart:cols
#     for y ∈ 1:rows
#         p = scale * [x - 0.5, y - 0.5]
#         add_fermi_dot!(potential, xgrid, ygrid, p, 0.25scale)
#     end
# end
# potential *= v0
# potential = v0 * make_angled_grid_potential(xgrid, ygrid, int_cot)
potential = (v0/3) * gaussian_correlated_random(xgrid, ygrid, 1)

# Make absorbing walls on the left and the right
if with_walls
    absorbing_profile = -1im * absorbing_wall_strength .*
                        (max.(0, (absorbing_wall_width .- xgrid) / absorbing_wall_width) .^ 2 .+
                         max.(0, (xgrid .- (W - absorbing_wall_width)) / absorbing_wall_width) .^ 2)
    potential += ones(Ny) * transpose(absorbing_profile)
end


# Make planar gaussian packet moves to the right
Ψ_initial = ones(Ny) * transpose(exp.(-((xgrid .- x0) ./ (packet_Δx * √2)) .^ 2 + 1im * px * xgrid / ħ))
Ψ_initial ./= sqrt(total_prob(xgrid, ygrid, Ψ_initial))

pixel_heatmap(path_prefix * "_potential.png", real(potential))
pixel_heatmap(path_prefix * "_initial_real.png", real(Ψ_initial))

evolution = time_evolution(xgrid, ygrid, potential, Ψ_initial, dt, num_steps, ħ)

@time "making animation" make_animation(path_prefix * ".mp4", evolution, potential,
    max_modulus=0.5)

# energies = LinRange(v0, E + (E-v0), 5)
# Other energies don't show up nicely.
energies = [E]
@time "eigenfunctions" ΨE = collect_eigenfunctions(evolution, energies,
    window=!with_walls)
for (ei, E) ∈ enumerate(energies)
    # pixel_heatmap(path_prefix * "_eigenfunc_$(round(Int, E)).png",
    #     abs.(ΨE[:, :, ei]) .^ 2)
    heatmap_with_potential(
        path_prefix * "_eigenfunc_$(round(Int, E)).png",
        abs.(ΨE[:,:,ei]) .^2, potential)
end