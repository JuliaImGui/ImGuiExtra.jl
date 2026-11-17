@testitem "_" begin
    import Aqua
    Aqua.test_all(ImGuiExtra)

    import CompatHelperLocal as CHL
    CHL.@check()
end

@testitem "Player keyword constructor" begin
    # `Player` is mutable, so `==` is identity: compare fields, never two objects
    p = Player()
    @test (p.playing, p.speed, p.loop, p.dir, p.last) == (false, nothing, LOOP, +1, 0.0)
    @test Player(; speed = 16).speed === 16.0
    @test Player(; loop = BOUNCE).loop === BOUNCE
end

@testitem "advance! integer playback" begin
    # (input state → expected) table, expected derived by hand from the loop semantics.
    # Timing: floor((now-last)·speed) steps are due; last advances by exactly that many 1/speed intervals.
    # speed=1, last=0.0, now=1.0 → one step; now=last → "too soon".
    cases = [
        # ── normal forward / backward advance (interior; dir & playing unchanged, last += 1/speed) ──
        (name="fwd",              playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=0.0,   idx=3,  n=10, now=1.0,
                                  exp_idx=4,  exp_dir=+1, exp_playing=true,  exp_last=1.0),
        (name="bwd",              playing=true,  speed=1.0, loop=LOOP,   dir=-1, last=0.0,   idx=5,  n=10, now=1.0,
                                  exp_idx=4,  exp_dir=-1, exp_playing=true,  exp_last=1.0),
        # ── LOOP wrap at both ends ──
        (name="loop wrap top",    playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=0.0,   idx=10, n=10, now=1.0,
                                  exp_idx=1,  exp_dir=+1, exp_playing=true,  exp_last=1.0),
        (name="loop wrap bottom", playing=true,  speed=1.0, loop=LOOP,   dir=-1, last=0.0,   idx=1,  n=10, now=1.0,
                                  exp_idx=10, exp_dir=-1, exp_playing=true,  exp_last=1.0),
        # ── BOUNCE reversal at both ends (dir flips, idx steps back inward) ──
        (name="bounce top",       playing=true,  speed=1.0, loop=BOUNCE, dir=+1, last=0.0,   idx=10, n=10, now=1.0,
                                  exp_idx=9,  exp_dir=-1, exp_playing=true,  exp_last=1.0),
        (name="bounce bottom",    playing=true,  speed=1.0, loop=BOUNCE, dir=-1, last=0.0,   idx=1,  n=10, now=1.0,
                                  exp_idx=2,  exp_dir=+1, exp_playing=true,  exp_last=1.0),
        # ── ONCE stops at both ends (playing→false, idx unchanged; last still updated) ──
        (name="once stop top",    playing=true,  speed=1.0, loop=ONCE,   dir=+1, last=0.0,   idx=10, n=10, now=1.0,
                                  exp_idx=10, exp_dir=+1, exp_playing=false, exp_last=1.0),
        (name="once stop bottom", playing=true,  speed=1.0, loop=ONCE,   dir=-1, last=0.0,   idx=1,  n=10, now=1.0,
                                  exp_idx=1,  exp_dir=-1, exp_playing=false, exp_last=1.0),
        # ── no-advance guards (return idx, mutate nothing) ──
        (name="not playing",      playing=false, speed=1.0, loop=LOOP,   dir=+1, last=0.0,   idx=3,  n=10, now=1.0,
                                  exp_idx=3,  exp_dir=+1, exp_playing=false, exp_last=0.0),
        (name="n<=1",             playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=0.0,   idx=1,  n=1,  now=1.0,
                                  exp_idx=1,  exp_dir=+1, exp_playing=true,  exp_last=0.0),
        (name="too soon",         playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=100.0, idx=3,  n=10, now=100.0,
                                  exp_idx=3,  exp_dir=+1, exp_playing=true,  exp_last=100.0),
        # ── timing boundary: exactly one interval elapsed → one step ──
        (name="exactly due",      playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=5.0,   idx=2,  n=10, now=6.0,
                                  exp_idx=3,  exp_dir=+1, exp_playing=true,  exp_last=6.0),
        # ── step interval scales with speed: speed=32 → step=1/32=0.03125 ──
        (name="fast advances",    playing=true,  speed=32.0, loop=LOOP,   dir=+1, last=0.0,   idx=4,  n=10, now=0.05,
                                  exp_idx=5,  exp_dir=+1, exp_playing=true,  exp_last=1/32),
        (name="fast too soon",    playing=true,  speed=32.0, loop=LOOP,   dir=+1, last=0.0,   idx=4,  n=10, now=0.02,
                                  exp_idx=4,  exp_dir=+1, exp_playing=true,  exp_last=0.0),
        # ── several steps due in one call (catch-up), remainder carried in `last` ──
        (name="multi fwd",        playing=true,  speed=10.0, loop=LOOP,  dir=+1, last=0.0,   idx=2,  n=10, now=0.35,
                                  exp_idx=5,  exp_dir=+1, exp_playing=true,  exp_last=0.3),
        (name="multi loop wrap",  playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=0.0,   idx=9,  n=10, now=4.0,
                                  exp_idx=3,  exp_dir=+1, exp_playing=true,  exp_last=4.0),
        (name="multi bounce",     playing=true,  speed=1.0, loop=BOUNCE, dir=+1, last=0.0,   idx=9,  n=10, now=4.0,
                                  exp_idx=7,  exp_dir=-1, exp_playing=true,  exp_last=4.0),
        (name="multi once stop",  playing=true,  speed=1.0, loop=ONCE,   dir=+1, last=0.0,   idx=8,  n=10, now=5.0,
                                  exp_idx=10, exp_dir=+1, exp_playing=false, exp_last=5.0),
        # ── full BOUNCE cycle 2(n-1) from a start-only state: ends in the cycle, not back at the start state ──
        (name="bounce cycle 1",   playing=true,  speed=1.0, loop=BOUNCE, dir=+1, last=0.0,   idx=1,  n=10, now=18.0,
                                  exp_idx=1,  exp_dir=-1, exp_playing=true,  exp_last=18.0),
        (name="bounce cycle n",   playing=true,  speed=1.0, loop=BOUNCE, dir=-1, last=0.0,   idx=10, n=10, now=18.0,
                                  exp_idx=10, exp_dir=+1, exp_playing=true,  exp_last=18.0),
        # ── huge backlog (e.g. window hidden): reduced by the cycle period, not stepped through ──
        (name="huge loop",        playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=0.0,   idx=3,  n=10, now=1e6,
                                  exp_idx=3,  exp_dir=+1, exp_playing=true,  exp_last=1e6),
        (name="huge bounce",      playing=true,  speed=1.0, loop=BOUNCE, dir=+1, last=0.0,   idx=3,  n=10, now=1_000_005.0,
                                  exp_idx=2,  exp_dir=-1, exp_playing=true,  exp_last=1_000_005.0),
        (name="huge bounce 1",    playing=true,  speed=1.0, loop=BOUNCE, dir=+1, last=0.0,   idx=1,  n=10, now=1_000_008.0,
                                  exp_idx=1,  exp_dir=-1, exp_playing=true,  exp_last=1_000_008.0),
        (name="huge once",        playing=true,  speed=1.0, loop=ONCE,   dir=+1, last=0.0,   idx=3,  n=10, now=1e6,
                                  exp_idx=10, exp_dir=+1, exp_playing=false, exp_last=1e6),
        # ── narrower numeric types accepted via Integer/Real signature: Int32 idx/n, Float32 now, no MethodError ──
        (name="int32 loop wrap",  playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=0.0,   idx=Int32(10), n=Int32(10), now=1.0,
                                  exp_idx=1,  exp_dir=+1, exp_playing=true,  exp_last=1.0),
        (name="int32/float32",    playing=true,  speed=1.0, loop=LOOP,   dir=+1, last=0.0,   idx=Int32(3), n=Int32(10), now=1f0,
                                  exp_idx=4,  exp_dir=+1, exp_playing=true,  exp_last=1.0),
    ]

    for c in cases
        @testset "$(c.name)" begin
            p = Player(c.playing, c.speed, c.loop, c.dir, c.last)
            got = @inferred advance!(p, c.idx, c.n, c.now)
            @test got == c.exp_idx
            @test got isa typeof(c.idx)
            @test p.dir == c.exp_dir
            @test p.playing == c.exp_playing
            @test p.last == c.exp_last
        end
    end
end

@testitem "start value" begin
    using ImGuiExtra: _start_value
    # (loop, dir, v, first, last) → value playback resumes from
    cases = [
        (ONCE,   +1, 10, 1, 10) => 1,      # parked at the end → restart
        (ONCE,   -1, 1,  1, 10) => 10,     # parked at the start while reversed → restart from the end
        (ONCE,   +1, 5,  1, 10) => 5,      # interior: unchanged
        (LOOP,   +1, 10, 1, 10) => 10,     # only ONCE restarts
        (BOUNCE, +1, 10, 1, 10) => 10,
        (ONCE,   +1, 2.5, 0.0, 2.5) => 0.0,
    ]
    for ((loop, dir, v, first, last), expected) in cases
        @test _start_value(Player(false, 1.0, loop, dir, 0.0), v, first, last) == expected
    end
end

@testitem "label escaping" begin
    using ImGuiExtra: _escape_fmt
    @test _escape_fmt("50% done") == "50%% done"
    @test _escape_fmt("plain") == "plain"
end
