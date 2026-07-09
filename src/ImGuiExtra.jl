module ImGuiExtra

import CImGui
using CImGui.CSyntax: @c

export ScrubberInt, Player, advance!, LoopMode, ONCE, LOOP, BOUNCE

@enum LoopMode ONCE LOOP BOUNCE
const SPEEDS = (0.25, 0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0)   # ×-multipliers on the base rate
const BASE_RATE = 1.0                        # snapshots per second at 1×

# Persistent playback state (NOT the index — that stays caller-owned, imgui-style).
mutable struct Player
    playing::Bool
    speed_i::Int      # index into SPEEDS (default 3 → 1.0×)
    loop::LoopMode
    dir::Int          # +1 / -1 (used by BOUNCE and for direction)
    last::Float64     # CImGui.GetTime() at the last advance
end
Player() = Player(false, 3, LOOP, +1, 0.0)

step_interval(p::Player) = 1.0 / (BASE_RATE * SPEEDS[p.speed_i])   # seconds per snapshot

# Logic only (no CImGui): given wall-clock `now`, current 1-based `idx`, count `n`,
# return the next index. Mutates dir/playing/last → `!`. Unit-testable headless.
function advance!(p::Player, idx::Integer, n::Integer, now::Real)
    (!p.playing || n <= 1 || now - p.last < step_interval(p)) && return idx
    p.last = now
    nxt = idx + p.dir
    1 <= nxt <= n     && return nxt
    p.loop === LOOP   && return p.dir > 0 ? 1 : n                  # wrap
    p.loop === BOUNCE && (p.dir = -p.dir; return idx + p.dir)      # reverse at the end
    p.playing = false; return idx                                  # ONCE: stop
end

# Right-click popup on the play button: discrete speed slider + loop-mode radios.
function speed_popup!(p::Player)
    if CImGui.BeginPopupContextItem("##playopts")     # right-click the previous item (the play button)
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

# The whole interactive row: [<] [play/stop] [>] [====slider====] + popup + auto-advance.
# Same call shape as CImGui.SliderInt: first arg is the ID string (exactly like SliderInt's
# label — here `PushID`-scoped because the widget is compound), then mutates idx[] in place
# and returns true iff it changed this frame. `label(i)` → display text for index i.
function ScrubberInt(id, p::Player, idx::Ref{Int}, n::Int; label = string)
    CImGui.PushID(id)
    v = clamp(idx[], 1, n)          # clamp on entry, as SliderInt does
    changed = false
    # `###id` → each button's ID comes from the stable tag (prev/play/next), independent of the
    # visible glyph — so the play button keeps one ID even as it toggles ▶⇄⏹.
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
        if @c CImGui.SliderInt("##scrubidx", &vv[], 1, n, "$(label(v))  %d/$n")
            v = Int(vv[]); changed = true; p.playing = false   # manual scrub pauses
        end
    end
    nv = advance!(p, v, n, CImGui.GetTime())
    nv != v && (v = nv; changed = true)
    idx[] = v
    CImGui.PopID()
    return changed
end

end
