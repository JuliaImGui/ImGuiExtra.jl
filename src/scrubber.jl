"""
    LoopMode

Playback behavior at the ends of the range: `ONCE` (stop), `LOOP` (wrap), `BOUNCE` (reverse).
"""
@enum LoopMode ONCE LOOP BOUNCE

const SPEEDS = (0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0)   # ×-multipliers on BASE_RATE
const BASE_RATE = 1.0                                        # snapshots per second at 1×

"""
    Player(; speed = 1.0, loop = LOOP)

Persistent playback state for [`ScrubberInt`](@ref). The index itself stays caller-owned
(imgui-style); this holds only play/pause, speed, loop mode, and direction. `speed` must be one of
`SPEEDS` — the popup slider only ever produces those, so an off-lattice value would silently snap.
"""
mutable struct Player
    playing::Bool
    speed_i::Int      # index into SPEEDS
    loop::LoopMode
    dir::Int          # +1 / -1
    last::Float64     # GetTime() at the last advance
end
Player(; speed = 1.0, loop = LOOP) =
    Player(false, @something(findfirst(==(speed), SPEEDS), error("speed $speed is not one of $SPEEDS")),
           loop, +1, 0.0)

step_interval(p::Player) = 1.0 / (BASE_RATE * SPEEDS[p.speed_i])   # seconds per snapshot

"""
    advance!(p::Player, idx::Integer, n::Integer, now) -> next_idx

Pure playback core: given wall-clock `now`, current 1-based `idx`, and count `n`, return the
next index (of the same type as `idx`) per `p`'s speed and loop mode.
Mutates `p.dir`/`p.playing`/`p.last`. Headless-testable.
"""
function advance!(p::Player, idx::Integer, n::Integer, now::Real)
    (!p.playing || n <= 1 || now - p.last < step_interval(p)) && return idx
    p.last = now
    nxt = idx + oftype(idx, p.dir)
    1 <= nxt <= n     && return nxt
    p.loop === LOOP   && return p.dir > 0 ? one(idx) : oftype(idx, n)          # wrap
    p.loop === BOUNCE && (p.dir = -p.dir; return idx + oftype(idx, p.dir))     # reverse
    p.playing = false; return idx                                  # ONCE: stop
end

# Right-click popup on the play button: speed slider + loop-mode radios.
function speed_popup!(p::Player)
    if CImGui.BeginPopupContextItem("##playopts")
        let v = Ref(Cint(p.speed_i - 1))
            (@c CImGui.SliderInt("##speed", &v[], 0, length(SPEEDS)-1, "$(SPEEDS[v[]+1])×")) &&
                (p.speed_i = Int(v[]) + 1)
        end
        CImGui.Text("loop:")
        for (lbl, m) in (("once", ONCE), ("loop", LOOP), ("bounce", BOUNCE))
            CImGui.RadioButton(lbl, p.loop === m) && (p.loop = m)
            m === BOUNCE || CImGui.SameLine()
        end
        CImGui.EndPopup()
    end
end

# Slider text goes through printf, so a literal '%' in a label must be doubled.
_escape_fmt(s) = replace(s, "%" => "%%")

"""
    ScrubberInt(id, p::Player, idx::Ref{<:Integer}, n::Integer; label = string) -> changed::Bool

Interactive scrubber row: `[<] [play/stop] [>] [====slider====]` plus a right-click
speed/loop popup and time-based auto-advance. Same call shape as `CImGui.SliderInt` — `id` is
the widget ID string; `idx[]` is mutated in place and `true` is returned iff it changed this
frame. `label(i)` maps an index to its display text.
"""
function ScrubberInt(id, p::Player, idx::Ref{<:Integer}, n::Integer; label = string)
    CImGui.PushID(id)
    v = clamp(idx[], 1, n)
    changed = v != idx[]
    # `###id` keeps each button's ID tied to its stable tag, not its glyph (play toggles ▶⇄⏹).
    CImGui.Button("⏮###prev") && v > 1 && (v -= 1; changed = true; p.playing = false)
    CImGui.SameLine()
    if CImGui.Button(p.playing ? "⏹###play" : "▶###play")
        p.playing = !p.playing
        if p.playing
            p.last = CImGui.GetTime()
            p.loop === ONCE && v == (p.dir > 0 ? n : 1) && (v = p.dir > 0 ? 1 : n; changed = true)  # restart if parked at end
        end
    end
    CImGui.SetItemTooltip("right-click: speed & loop")
    speed_popup!(p)                            # must immediately follow the play button
    CImGui.SameLine()
    CImGui.Button("⏭###next") && v < n && (v += 1; changed = true; p.playing = false)
    CImGui.SameLine()
    let vv = Ref(Cint(v))
        if @c CImGui.SliderInt("##scrubidx", &vv[], 1, n, "$(_escape_fmt(label(v)))  %d/$n")
            v = oftype(v, vv[]); changed = true; p.playing = false   # manual scrub pauses
        end
    end
    nv = advance!(p, v, n, CImGui.GetTime())
    nv != v && (v = nv; changed = true)
    idx[] = v
    CImGui.PopID()
    return changed
end
