# ImGuiExtra.jl

Extra widgets for [CImGui.jl](https://github.com/Gnimuc/CImGui.jl).

Currently: `ScrubberInt`, a timeline scrubber with play/pause, speed, and loop controls.

```julia
using ImGuiExtra

# persistent across frames:
player = Player()
idx = Ref(1)

# inside your CImGui frame:
if ScrubberInt("frame", player, idx, 100)
    # idx[] changed — react to the new frame
end
```
https://github.com/user-attachments/assets/98f02639-d4c3-4d7c-94b6-cdba9bd71c2f
