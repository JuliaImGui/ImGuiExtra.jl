"""
    LoopMode

Playback behavior at the ends of the range: `ONCE` (stop), `LOOP` (wrap), `BOUNCE` (reverse).
"""
@enum LoopMode ONCE LOOP BOUNCE

"""
    Player(; speed = nothing, loop = LOOP)

Persistent playback state for [`ScrubberInt`](@ref). The index itself stays caller-owned
(imgui-style); this holds only play/pause, speed, loop mode, and direction.
`speed` is in indices per second.
If not given, the first draw sets it so that a full sweep takes 10 s.
"""
@kwdef mutable struct Player
    playing::Bool = false
    speed::Union{Nothing,Float64} = nothing
    loop::LoopMode = LOOP
    dir::Int = +1         # +1 / -1
    last::Float64 = 0.0   # GetTime() up to which playback has been accounted
end

"""
    advance!(p::Player, idx::Integer, n::Integer, now) -> next_idx

Pure playback core: given wall-clock `now`, current 1-based `idx`, and count `n`, return the
next index (of the same type as `idx`) per `p`'s speed and loop mode: one step per `1/speed`
seconds elapsed — several per call if due, remainder carried over.
Mutates `p.dir`/`p.playing`/`p.last`. Headless-testable.
"""
function advance!(p::Player, idx::Integer, n::Integer, now::Real)
    (!p.playing || n <= 1) && return idx
    k = floor(Int, (now - p.last) * p.speed)          # steps due since the last advance
    k == 0 && return idx
    p.last += k / p.speed                             # keep the remainder → exact average rate
    # After the first step LOOP/BOUNCE repeat with period n / 2(n-1), ONCE is stopped after ≤ n steps.
    # `mod1` keeps that first step: BOUNCE states (1, dir=+1) and (n, dir=-1) are start-only, never revisited.
    k = p.loop === LOOP ? mod1(k, n) : p.loop === BOUNCE ? mod1(k, 2(n - 1)) : min(k, n)
    for _ in 1:k
        idx = step!(p, idx, n)
        p.playing || break
    end
    return idx
end

# One playback step from `idx` per `p.dir` and `p.loop`.
function step!(p::Player, idx::Integer, n::Integer)
    nxt = idx + oftype(idx, p.dir)
    1 <= nxt <= n     && return nxt
    p.loop === LOOP   && return p.dir > 0 ? one(idx) : oftype(idx, n)          # wrap
    p.loop === BOUNCE && (p.dir = -p.dir; return idx + oftype(idx, p.dir))     # reverse
    p.playing = false; return idx                                  # ONCE: stop
end

# Play/stop toggle plus its right-click speed/loop popup. Speed range follows the domain `width`:
# a full sweep takes 1000 s … 1 s.
function play_button!(p::Player, width)
    p.speed === nothing && (p.speed = width / 10)
    # `###id` keeps the button's ID tied to its stable tag, not its glyph (play toggles ▶⇄⏹).
    if CImGui.Button(p.playing ? "⏹###play" : "▶###play")
        p.playing = !p.playing
        p.last = CImGui.GetTime()
    end
    CImGui.SetItemTooltip("right-click: speed & loop")
    if CImGui.BeginPopupContextItem("##playopts")        # must immediately follow the play button
        let s = Ref(Cfloat(p.speed))
            (@c CImGui.SliderFloat("##speed", &s[], width / 1000, width, "%.3g /s",
                                   CImGui.ImGuiSliderFlags_Logarithmic)) && (p.speed = s[])
        end
        CImGui.Text("loop:")
        for (lbl, m) in (("once", ONCE), ("loop", LOOP), ("bounce", BOUNCE))
            CImGui.RadioButton(lbl, p.loop === m) && (p.loop = m)
            m === BOUNCE || CImGui.SameLine()
        end
        CImGui.EndPopup()
    end
end

# Value to continue from when playback starts: parked at the ONCE end → jump to the other end.
_start_value(p::Player, v, lo, hi) =
    p.loop === ONCE && v == (p.dir > 0 ? hi : lo) ? (p.dir > 0 ? lo : hi) : v

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
    CImGui.Button("⏮###prev") && v > 1 && (v -= 1; changed = true; p.playing = false)
    CImGui.SameLine()
    was_playing = p.playing
    play_button!(p, n)
    if !was_playing && p.playing
        nv = _start_value(p, v, 1, n)
        nv != v && (v = nv; changed = true)
    end
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
