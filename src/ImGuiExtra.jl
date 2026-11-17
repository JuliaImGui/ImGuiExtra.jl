module ImGuiExtra

import CImGui
using CImGui.CSyntax: @c
using IntervalSets: AbstractInterval, endpoints, width
using PyFormattedStrings: @f_str

export ScrubberInt, ScrubberFloat, Player, advance!, LoopMode, ONCE, LOOP, BOUNCE

include("scrubber.jl")

end
