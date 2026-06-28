// matrix.scd — 16-voice x 32-bar song-arrangement matrix
// Additive: reads base Pdefs from launchpad.scd, does NOT modify them.
// Each cell = 0 (off) or 1-6 (a parametric variation color of the voice's pattern).
// A playhead Routine advances bar-by-bar on the launchpad clock, applying cells.
// Colors 1-6 map to Pchain overlays (\stretch / \octave / \amp). 0 = Pdef.stop.
// Loaded after sections.scd (boot step 6i). Idempotent reload, nil-guarded.
// NOTE: the \amp variation override bypasses ~lpVol per-voice volume; web vol sliders
//       have no effect while a matrix variation plays — deferred to v2.
(

// -- Env init (nil-guarded; idempotent reload) --
~lp = ~lp ? ();
~matVoices = ~matVoices ? [
    \kick, \hats, \clap, \perc,
    \sub,  \acid, \arp,  \lead,
    \stab, \pad,  \ride, \rim,
    \tom,  \reese, \bells, \sweep
];
~matBars        = ~matBars        ? 32;
~lp[\matrix]    = ~lp[\matrix]    ? Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
~lp[\matBar]    = ~lp[\matBar]    ? 0;
~lp[\matPlaying] = ~lp[\matPlaying] ? false;
~matBase        = ~matBase        ? IdentityDictionary.new;
~matBeatsPerBar = ~matBeatsPerBar ? 4;
~matLastColor   = ~matLastColor   ? Array.fill(~matVoices.size, -1);

// -- ~matBaseFor : capture base Pdef source once (lazy, per voice name symbol) --
// Returns nil when the Pdef is missing (safe for partial environments).
~matBaseFor = { |name|
    var key = ("lp_" ++ name).asSymbol;
    ~matBase[name] ?? {
        ~matBase[name] = Pdef.all.includesKey(key).if(
            { Pdef(key).source },
            { nil }
        );
        ~matBase[name]
    }
};

// -- ~matVariation : map color 1-6 to a Pchain overlay on the captured base --
// color 1 = base as-is, 2 = double-time, 3 = octave up, 4 = half-time,
// 5 = octave down + slight accent, 6 = accent roll (denser + louder).
// \stretch multiplies event duration; \octave shifts degree-based pitch.
// NOTE: voices that compute \freq via Pfunc (ignoring \octave) will not respond
// to the octave variation — acceptable for v1; tune the palette at the live gate.
// Single function so all variation logic lives in one place.
~matVariation = { |name, color, vi = 0|
    (color == 0).if({ nil }, {
        var base = ~matBaseFor.(name);
        base.notNil.if({
            var spec = [
                nil,
                (stretch: 1.0, octave:  0, amp: 1.0),
                (stretch: 0.5, octave:  0, amp: 1.0),
                (stretch: 1.0, octave:  1, amp: 1.0),
                (stretch: 2.0, octave:  0, amp: 1.0),
                (stretch: 1.0, octave: -1, amp: 1.05),
                (stretch: 0.5, octave:  0, amp: 1.2)
            ][color];
            spec.notNil.if({
                Pchain(
                    Pbind(
                        \matGlow, Pfunc { |e|
                            ~matEmitTrig.(vi, (e[\amp] ? spec[\amp]).clip(0, 1));
                            0
                        },
                        \stretch, spec[\stretch],
                        \octave,  spec[\octave],
                        \amp,     spec[\amp]
                    ),
                    base
                )
            }, { base })
        }, { nil })
    })
};

// -- ~matApplyBar : set each voice's Pdef to its cell color and (re)play or stop --
// Re-sourcing a playing Pdef updates it at the next quant boundary (smooth for v1).
~matApplyBar = { |bar|
    ~matVoices.do { |name, vi|
        var color = ~lp[\matrix][vi][bar];
        var key   = ("lp_" ++ name).asSymbol;
        Pdef.all.includesKey(key).if({
            (color == 0).if(
                {
                    Pdef(key).stop;
                    ~matLastColor[vi] = 0
                },
                {
                    (color != ~matLastColor[vi]).if({
                        var pat = ~matVariation.(name, color, vi);
                        pat.notNil.if({
                            ~matLastColor[vi] = color;
                            Pdef(key, pat);
                            Pdef(key).play(
                                ~lp[\clock] ? TempoClock.default,
                                quant: ~matBeatsPerBar
                            )
                        })
                    })
                }
            )
        })
    }
};

// -- ~matPush : push playhead position to all TouchOSC clients --
~matPush = {
    ~toscSend !? { ~toscSend.("/matrix/playhead", ~lp[\matBar]) }
};

// -- ~matEmitTrig : push a per-note amplitude pulse to web/TouchOSC clients --
// vi = voice index, amp clipped to 0..1. Same ~toscSend path as /matrix/playhead.
~matEmitTrig = { |vi, amp|
    ~toscSend !? { ~toscSend.("/matrix/trig", vi, amp.clip(0, 1)) }
};

// -- ~matStop : halt the playhead Routine and silence all matrix voices --
~matStop = {
    ~matRoutine !? { ~matRoutine.stop };
    ~lp[\matPlaying] = false;
    ~matVoices.do { |name|
        var k = ("lp_" ++ name).asSymbol;
        Pdef.all.includesKey(k).if({ Pdef(k).stop })
    };
    ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
    ~matPush.()
};

// -- ~matPlay : start the playhead Routine from bar 0, looping over ~matBars --
~matPlay = {
    var clock = ~lp[\clock] ? TempoClock.default;
    ~matRoutine !? { ~matRoutine.stop };
    ~lp[\matPlaying] = true;
    ~lp[\matBar]     = 0;
    ~matRoutine = Routine({
        loop {
            ~matApplyBar.(~lp[\matBar]);
            ~toscSend !? { ~toscSend.("/matrix/playhead", ~lp[\matBar]) };
            ~matBeatsPerBar.wait;
            ~lp[\matBar] = (~lp[\matBar] + 1) % ~matBars
        }
    }).play(clock, quant: ~matBeatsPerBar);
    ~matPush.()
};

// -- ~matSetCell : write matrix[vi][bar] = color; apply live if playhead is there --
~matSetCell = { |vi, bar, color|
    (vi >= 0 and: { vi < ~matVoices.size and: { bar >= 0 and: { bar < ~matBars } } }).if({
        ~lp[\matrix][vi][bar] = color.clip(0, 6).asInteger;
        (~lp[\matPlaying] and: { bar == ~lp[\matBar] }).if({ ~matApplyBar.(bar) });
        ~toscSend !? { ~toscSend.("/matrix/cell", vi, bar, ~lp[\matrix][vi][bar]) }
    })
};

// -- ~matClear : reset all cells to 0 and push state --
~matClear = {
    ~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
    ~matPush.()
};

// -- OSCdefs (unique \mat_* keys; register sender for TouchOSC feedback) --
OSCdef(\mat_cell, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetCell.(msg[1].asInteger, msg[2].asInteger, msg[3].asInteger)
}, '/matrix/cell');

OSCdef(\mat_play, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matPlay.()
}, '/matrix/play');

OSCdef(\mat_stop, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matStop.()
}, '/matrix/stop');

OSCdef(\mat_clear, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matClear.()
}, '/matrix/clear');

"[matrix] ready".postln;
)
