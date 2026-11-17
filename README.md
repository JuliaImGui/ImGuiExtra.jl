# ImGuiExtra.jl

Extra widgets for [CImGui.jl](https://github.com/Gnimuc/CImGui.jl).

Currently: timeline scrubbers with play/pause, speed, and loop controls — `ScrubberInt` over frames
`1:n`, `ScrubberFloat` over a continuous interval.

```julia
using ImGuiExtra, IntervalSets

# persistent across frames:
player = Player()
idx = Ref(1)
tplayer = Player()
t = Ref(0.0)

# inside your CImGui frame:
if ScrubberInt("frame", player, idx, 100)
    # idx[] changed — react to the new frame
end
if ScrubberFloat("time", tplayer, t, 0..10)
    # t[] changed
end
```
https://github.com/user-attachments/assets/98f02639-d4c3-4d7c-94b6-cdba9bd71c2f
