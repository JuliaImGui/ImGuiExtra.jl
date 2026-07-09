module ImGuiExtra

import CImGui
using CImGui.CSyntax: @c

export ScrubberInt, Player, advance!, LoopMode, ONCE, LOOP, BOUNCE

include("scrubber.jl")

end
