@testitem "_" begin
    import Aqua
    Aqua.test_all(ImGuiExtra)

    import CompatHelperLocal as CHL
    CHL.@check()
end

@testitem "advance! playback logic" begin
    # (input state → expected) table, expected derived by hand from the loop semantics.
    # Timing: step_interval = 1/SPEEDS[speed_i] (BASE_RATE=1). speed_i=3 → step=1.0.
    # last=0.0, now=1e6 forces an advance; now=last forces "too soon"; advancing sets last:=now.
    cases = [
        # ── normal forward / backward advance (interior; dir & playing unchanged, last := now) ──
        (name="fwd",              playing=true,  speed_i=3, loop=LOOP,   dir=+1, last=0.0,   idx=3,  n=10, now=1e6,
                                  exp_idx=4,  exp_dir=+1, exp_playing=true,  exp_last=1e6),
        (name="bwd",              playing=true,  speed_i=3, loop=LOOP,   dir=-1, last=0.0,   idx=5,  n=10, now=1e6,
                                  exp_idx=4,  exp_dir=-1, exp_playing=true,  exp_last=1e6),
        # ── LOOP wrap at both ends ──
        (name="loop wrap top",    playing=true,  speed_i=3, loop=LOOP,   dir=+1, last=0.0,   idx=10, n=10, now=1e6,
                                  exp_idx=1,  exp_dir=+1, exp_playing=true,  exp_last=1e6),
        (name="loop wrap bottom", playing=true,  speed_i=3, loop=LOOP,   dir=-1, last=0.0,   idx=1,  n=10, now=1e6,
                                  exp_idx=10, exp_dir=-1, exp_playing=true,  exp_last=1e6),
        # ── BOUNCE reversal at both ends (dir flips, idx steps back inward) ──
        (name="bounce top",       playing=true,  speed_i=3, loop=BOUNCE, dir=+1, last=0.0,   idx=10, n=10, now=1e6,
                                  exp_idx=9,  exp_dir=-1, exp_playing=true,  exp_last=1e6),
        (name="bounce bottom",    playing=true,  speed_i=3, loop=BOUNCE, dir=-1, last=0.0,   idx=1,  n=10, now=1e6,
                                  exp_idx=2,  exp_dir=+1, exp_playing=true,  exp_last=1e6),
        # ── ONCE stops at both ends (playing→false, idx unchanged; last still updated) ──
        (name="once stop top",    playing=true,  speed_i=3, loop=ONCE,   dir=+1, last=0.0,   idx=10, n=10, now=1e6,
                                  exp_idx=10, exp_dir=+1, exp_playing=false, exp_last=1e6),
        (name="once stop bottom", playing=true,  speed_i=3, loop=ONCE,   dir=-1, last=0.0,   idx=1,  n=10, now=1e6,
                                  exp_idx=1,  exp_dir=-1, exp_playing=false, exp_last=1e6),
        # ── no-advance guards (return idx, mutate nothing) ──
        (name="not playing",      playing=false, speed_i=3, loop=LOOP,   dir=+1, last=0.0,   idx=3,  n=10, now=1e6,
                                  exp_idx=3,  exp_dir=+1, exp_playing=false, exp_last=0.0),
        (name="n<=1",             playing=true,  speed_i=3, loop=LOOP,   dir=+1, last=0.0,   idx=1,  n=1,  now=1e6,
                                  exp_idx=1,  exp_dir=+1, exp_playing=true,  exp_last=0.0),
        (name="too soon",         playing=true,  speed_i=3, loop=LOOP,   dir=+1, last=100.0, idx=3,  n=10, now=100.0,
                                  exp_idx=3,  exp_dir=+1, exp_playing=true,  exp_last=100.0),
        # ── timing boundary: now-last == step_interval is NOT "too soon" (guard is strict <) ──
        (name="exactly due",      playing=true,  speed_i=3, loop=LOOP,   dir=+1, last=5.0,   idx=2,  n=10, now=6.0,
                                  exp_idx=3,  exp_dir=+1, exp_playing=true,  exp_last=6.0),
        # ── step_interval scales with speed: speed_i=8 → SPEEDS=32.0 → step=1/32=0.03125 ──
        (name="fast advances",    playing=true,  speed_i=8, loop=LOOP,   dir=+1, last=0.0,   idx=4,  n=10, now=0.05,
                                  exp_idx=5,  exp_dir=+1, exp_playing=true,  exp_last=0.05),
        (name="fast too soon",    playing=true,  speed_i=8, loop=LOOP,   dir=+1, last=0.0,   idx=4,  n=10, now=0.02,
                                  exp_idx=4,  exp_dir=+1, exp_playing=true,  exp_last=0.0),
        # ── narrower numeric types accepted via Integer/Real signature: Int32 idx/n, Float32 now, no MethodError ──
        (name="int32/float32",    playing=true,  speed_i=3, loop=LOOP,   dir=+1, last=0.0,   idx=Int32(3), n=Int32(10), now=1f6,
                                  exp_idx=4,  exp_dir=+1, exp_playing=true,  exp_last=1e6),
    ]

    for c in cases
        @testset "$(c.name)" begin
            p = Player(c.playing, c.speed_i, c.loop, c.dir, c.last)
            got = advance!(p, c.idx, c.n, c.now)
            @test got == c.exp_idx
            @test p.dir == c.exp_dir
            @test p.playing == c.exp_playing
            @test p.last == c.exp_last
        end
    end
end
