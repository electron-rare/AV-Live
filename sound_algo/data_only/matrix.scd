// matrix.scd — 16-voice x 32-bar song-arrangement matrix
// Additive: reads base Pdefs from launchpad.scd, does NOT modify them.
// Each cell = 0 (off) or 1-6 (a parametric variation color of the voice's pattern).
// A playhead Routine advances bar-by-bar on the launchpad clock, applying cells.
// Colors 1-6 map to Pchain overlays (\stretch / \octave / \amp). 0 = Pdef.stop.
// Loaded after sections.scd (boot step 6i). Idempotent reload, nil-guarded.
// NOTE: the \amp variation is multiplied by the per-voice fader (~lp[\vol]) so the
//       web mixer (/launch/vol) controls matrix output in real time.
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
~matInstruments  = ~matInstruments  ? Array.fill(~matVoices.size, nil);
~matMod          = ~matMod          ? Array.fill(~matVoices.size, nil);
~matPoseBindings = ~matPoseBindings ? Array.fill(~matVoices.size, { [] });
~matModTargets   = ~matModTargets   ? IdentityDictionary[
    \kick->[\amp], \hats->[\amp], \clap->[\amp], \perc->[\amp],
    \sub->[\amp], \acid->[\amp,\cutoff,\pan], \arp->[\amp,\cutoff,\pan],
    \lead->[\amp,\cutoff,\pan], \stab->[\amp,\cutoff,\pan], \pad->[\amp,\cutoff],
    \ride->[\amp], \rim->[\amp], \tom->[\amp], \reese->[\amp],
    \bells->[\amp], \sweep->[\amp]
];
~matModNeutralCut = ~matModNeutralCut ? IdentityDictionary[
    \acid->700, \arp->3000, \lead->4000, \stab->2200, \pad->1500
];

// -- default color defs reproduce the historical global variation table --
~matDefaultColorDefs = {
    [ nil,
        (stretch: 1.0, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, steps: Array.fill(16, nil)),
        (stretch: 0.5, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, steps: Array.fill(16, nil)),
        (stretch: 1.0, octave:  1, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, steps: Array.fill(16, nil)),
        (stretch: 2.0, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, steps: Array.fill(16, nil)),
        (stretch: 1.0, octave: -1, amp: 1.05, inst: nil, cutoff: nil, pan: nil, steps: Array.fill(16, nil)),
        (stretch: 0.5, octave:  0, amp: 1.2,  inst: nil, cutoff: nil, pan: nil, steps: Array.fill(16, nil)) ]
};
~matColorDefs = ~matColorDefs ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });

~lp[\matLoopStart] = ~lp[\matLoopStart] ? 0;
~lp[\matLoopEnd]   = ~lp[\matLoopEnd]   ? (~matBars - 1);

// -- Persistence env init (nil-guarded) --
~matDir        = ~matDir        ? "~/.config/av-live/matrices".standardizePath;
~matPresetDir  = ~matPresetDir  ? (PathName(thisProcess.nowExecutingPath).pathOnly ++ "matrix_presets");
~matSavedNames = ~matSavedNames ? Set.new;
File.exists(~matDir).not.if({ ("mkdir -p " ++ ~matDir.quote).systemCmd });

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

// -- per-voice curated instrument choices (symbol must be a loaded SynthDef) --
// ONLY note-terminating synths are allowed (perc env + doneAction, or gated ASR).
// The continuous \do_ drones (do_drone/do_body_drone/do_body_gran/do_weather/
// do_geo) have NO gate and NO doneAction -> driven per-note by the matrix Pbind
// they never free and pile up forever, so they are NOT offered. The gated \lp_
// sustained voices (lp_sub/lp_reese/lp_pad/lp_sweep) cover the drone textures.
~matInstChoices = ~matInstChoices ? IdentityDictionary[
    \kick  -> [\lp_kick, \do_kick, \do_quake_sub],
    \hats  -> [\lp_hat,  \do_hat],
    \clap  -> [\lp_clap, \lp_rim, \do_hat],
    \perc  -> [\lp_perc, \do_strike, \lp_tom],
    \sub   -> [\lp_sub,  \lp_reese, \do_quake_sub],
    \acid  -> [\lp_acid, \lp_pluck],
    \arp   -> [\lp_pluck, \do_strike, \lp_bells],
    \lead  -> [\lp_pluck, \do_plane, \do_strike, \lp_bells],
    \stab  -> [\lp_pluck, \lp_acid],
    \pad   -> [\lp_pad,  \lp_reese, \lp_sub],
    \ride  -> [\lp_ride, \lp_hat, \do_hat],
    \rim   -> [\lp_rim,  \lp_clap, \do_hat],
    \tom   -> [\lp_tom,  \do_strike, \do_quake_sub],
    \reese -> [\lp_reese, \lp_sub, \lp_pad],
    \bells -> [\lp_bells, \do_strike, \do_plane],
    \sweep -> [\lp_sweep, \lp_pad, \lp_reese]
];

// -- fixed kits: kitName -> (voiceName -> instrument). Unlisted voices = default --
~matKits = ~matKits ? IdentityDictionary[
    \default -> IdentityDictionary[],
    \deep -> IdentityDictionary[
        \kick -> \do_kick, \sub -> \lp_reese, \reese -> \lp_reese,
        \pad -> \lp_reese, \sweep -> \lp_pad ],
    \industrial -> IdentityDictionary[
        \kick -> \do_quake_sub, \perc -> \do_strike, \tom -> \do_strike,
        \clap -> \lp_rim, \stab -> \lp_acid ],
    \acid -> IdentityDictionary[
        \lead -> \do_plane, \arp -> \do_strike, \sub -> \lp_reese, \bells -> \do_plane ]
];

// -- ~matApplyInstrument : set voice vi's instrument (nil = default), re-source, echo --
~matApplyInstrument = { |vi, instOrNil|
    (vi >= 0 and: { vi < ~matVoices.size }).if({
        var name = ~matVoices[vi];
        var inst = ((instOrNil == \default) or: { instOrNil == '' } or: { instOrNil.isNil })
            .if({ nil }, { instOrNil.asSymbol });
        var ok = inst.isNil or: { (~matInstChoices[name] ? []).includes(inst) };
        ok.if({
            ~matInstruments[vi] = inst;
            ~matLastColor[vi] = -1;                       // force re-source next bar
            (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
            ~toscSend !? { ~toscSend.("/matrix/instrument", vi, (inst ? \default).asString) }
        })
    })
};

// -- ~matApplyKit : apply a fixed kit map to all voices, echo each --
~matApplyKit = { |name|
    var kit = ~matKits[name.asSymbol];
    kit.notNil.if({
        ~matVoices.do { |vname, vi|
            ~matApplyInstrument.(vi, kit[vname] ? \default)
        }
    })
};

// -- ~matApplyMod : bind (or clear) a mod source→target for voice vi, echo --
// srcOrNil/tgtOrNil = \none or nil clears the binding.
// Rejected if: src not in ~matModSources, or tgt not in voice's ~matModTargets.
~matApplyMod = { |vi, srcOrNil, tgtOrNil, depth|
    (vi >= 0 and: { vi < ~matVoices.size }).if({
        var name = ~matVoices[vi];
        var src = ((srcOrNil == \none) or: { srcOrNil.isNil }).if({ nil }, { srcOrNil.asSymbol });
        var tgt = ((tgtOrNil == \none) or: { tgtOrNil.isNil }).if({ nil }, { tgtOrNil.asSymbol });
        var d = (depth ? 0).asFloat.clip(0, 1);
        var ok = (src.isNil or: tgt.isNil) or: {
            ~matModSources.includes(src) and: { (~matModTargets[name] ? []).includes(tgt) }
        };
        ok.if({
            ~matMod[vi] = (src.isNil or: tgt.isNil).if({ nil },
                { (source: src, target: tgt, depth: d) });
            ~matLastColor[vi] = -1;
            (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
            ~toscSend !? { ~toscSend.("/matrix/mod", vi,
                (src ? \none).asString, (tgt ? \none).asString, d) }
        })
    })
};

// -- ~matVariationOverlay : assemble the Pchain overlay given a resolved spec --
// Factored out of ~matVariation so the main function stays readable.
// cdPairs (static per-color cutoff/pan) come before modPairs so a live capture
// mod on the same target overrides the static color-def value — intended.
~matVariationOverlay = { |name, vi, spec, volOf, instPair, cdPairs, base|
    var mod = ~matMod[vi];
    // octave colors multiply \freq by 2**octave (main's freqRatio scheme), pitched
    // voices only — works for voices that set \freq directly via Pfunc.
    var pitched = [\sub, \acid, \arp, \lead, \stab, \pad, \reese, \bells, \perc, \tom];
    var freqRatio = 2 ** (spec[\octave] ? 0);
    var freqPair = (pitched.includes(name) and: { freqRatio != 1.0 }).if({
        [\freq, Pfunc({ |e| (e[\freq] ? 440) * freqRatio })]
    }, { [] });
    var modPairs = mod.isNil.if({ [] }, {
        var src = mod[\source], tgt = mod[\target], d = mod[\depth];
        (tgt == \cutoff).if({
            var c0 = ~matModNeutralCut[name] ? 1000;
            [\cutoff, Pfunc { var s = ~matModSourceVal.(src);
                c0 * (s.linexp(0, 1, 200, 6000) / c0).pow(d) }]
        }, {
            (tgt == \pan).if({
                [\pan, Pfunc { (~matModSourceVal.(src) * 2 - 1) * d }]
            }, {
                [\amp, Pfunc { ((spec[\amp] ? 1.0) * volOf.value) * (1 + (d * (~matModSourceVal.(src) * 2 - 1))).max(0) }]
            })
        })
    });
    Pchain(
        Pbind(*([
            \matGlow, Pfunc { |e| ~matEmitTrig.(vi, (e[\amp] ? spec[\amp]).clip(0, 1)); 0 },
            \stretch, spec[\stretch],
            \amp,     Pfunc({ (spec[\amp] ? 1.0) * volOf.value })
        ] ++ instPair ++ cdPairs ++ freqPair ++ modPairs)),
        base
    )
};

// -- ~matColorStepPattern : 16-step note+vel sequence (replaces base) --
// \matGlow first; \degree/\type from steps; \freq via ~lpNote x 2**octave; \amp =
// colorAmp x stepVel x volOf; \dur = bar/16; inst/cutoff/pan/mod applied like the overlay.
~matColorStepPattern = { |name, vi, color, spec, volOf, instPair, cdPairs|
    var freqRatio = 2 ** (spec[\octave] ? 0);
    var mod = ~matMod[vi];
    var modPairs = mod.isNil.if({ [] }, {
        var src = mod[\source], tgt = mod[\target], d = mod[\depth];
        (tgt == \cutoff).if({
            var c0 = ~matModNeutralCut[name] ? 1000;
            [\cutoff, Pfunc { var s = ~matModSourceVal.(src); c0 * (s.linexp(0,1,200,6000)/c0).pow(d) }]
        }, {
            (tgt == \pan).if({ [\pan, Pfunc { (~matModSourceVal.(src) * 2 - 1) * d }] },
                { [] })   // amp mod out of scope for v1
        })
    });
    Pbind(*([
        \stepIdx, Pseq((0..15), inf),
        \matGlow, Pfunc { |e|
            var s = spec[\steps][e[\stepIdx]];
            ~matEmitTrig.(vi, s.isNil.if({ 0 }, { ((spec[\amp] ? 1.0) * s[\vel]).clip(0, 1) }));
            0
        },
        \type, Pfunc { |e| spec[\steps][e[\stepIdx]].isNil.if({ \rest }, { \note }) },
        \degree, Pfunc { |e| var s = spec[\steps][e[\stepIdx]]; s.isNil.if({ 0 }, { s[\degree] }) },
        \freq, Pfunc { |e| (~lpNote.notNil).if({ ~lpNote.(e[\degree], 0).midicps * freqRatio }, { 440 }) },
        \amp, Pfunc { |e|
            var s = spec[\steps][e[\stepIdx]];
            ((spec[\amp] ? 1.0) * (s.isNil.if({ 0 }, { s[\vel] }))) * volOf.value },
        \stretch, spec[\stretch],
        \dur, ~matBeatsPerBar / 16
    ] ++ instPair ++ cdPairs ++ modPairs))
};

// -- ~matVariation : map color 1-6 to a Pchain overlay on the captured base --
// color 1 = base as-is, 2 = double-time, 3 = octave up, 4 = half-time,
// 5 = octave down + slight accent, 6 = accent roll (denser + louder).
// \stretch multiplies event duration; octave colors multiply the base \freq by
// 2**octave (x2 up, x0.5 down) via Pfunc, so they transpose even voices that set
// \freq directly (bypassing SC's \octave). Only pitched voices get the \freq
// multiply — drums keep their pitch. Reads ~matColorDefs[vi][color] so per-voice
// color tables are editable at runtime (octave field maps to the freq multiply).
~matVariation = { |name, color, vi = 0|
    (color == 0).if({ nil }, {
        var base = ~matBaseFor.(name);
        base.notNil.if({
            var spec = ~matColorDefs[vi][color];
            spec.notNil.if({
                var inst = spec[\inst] ? ~matInstruments[vi];      // per-color wins, else voice default
                var volOf = { (~lp[\vol].notNil).if({ ~lp[\vol][name.asSymbol] ? 0.8 }, { 0.8 }) };
                var instPair = inst.notNil.if({ [\instrument, inst] }, { [] });
                var cdPairs = [];
                (spec[\cutoff].notNil and: { (~matModTargets[name] ? []).includes(\cutoff) }).if({
                    cdPairs = cdPairs ++ [\cutoff, spec[\cutoff]] });
                (spec[\pan].notNil and: { (~matModTargets[name] ? []).includes(\pan) }).if({
                    cdPairs = cdPairs ++ [\pan, spec[\pan]] });
                (~matStepsEmpty.(spec[\steps]).not).if({
                    ~matColorStepPattern.(name, vi, color, spec, volOf, instPair, cdPairs)
                }, {
                    ~matVariationOverlay.(name, vi, spec, volOf, instPair, cdPairs, base)
                })
            }, { base })
        }, { nil })
    })
};

// -- ~matNextBar : compute next playhead bar clipped within the loop region --
// Wraps nb back to loop start when nb overshoots le or undershoots ls.
~matNextBar = { var nb = ~lp[\matBar] + 1; var ls = ~lp[\matLoopStart] ? 0; var le = ~lp[\matLoopEnd] ? (~matBars - 1);
    ((nb > le) or: { nb < ls }).if({ nb = ls });
    nb.clip(0, ~matBars - 1) };

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

// -- ~matLoopPush : send current loop region to surfaces --
~matLoopPush = { ~toscSend !? { ~toscSend.("/matrix/loop", ~lp[\matLoopStart] ? 0, ~lp[\matLoopEnd] ? (~matBars - 1)) } };

// -- ~matSetLoop : set loop region (auto-ordered) and push to surfaces --
~matSetLoop = { |s, e| var a = s.asInteger.clip(0, ~matBars - 1); var b = e.asInteger.clip(0, ~matBars - 1);
    (a <= b).if({ ~lp[\matLoopStart] = a; ~lp[\matLoopEnd] = b }, { ~lp[\matLoopStart] = b; ~lp[\matLoopEnd] = a });
    ~matLoopPush.() };

// -- ~matSeek : jump playhead to bar; re-applies if playing --
~matSeek = { |bar| ~lp[\matBar] = bar.asInteger.clip(0, ~matBars - 1);
    ~toscSend !? { ~toscSend.("/matrix/playhead", ~lp[\matBar]) };
    ~lp[\matPlaying].if({ ~matApplyBar.(~lp[\matBar]) }) };

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
    ~lp[\matBar]     = ~lp[\matLoopStart] ? 0;
    ~matRoutine = Routine({
        loop {
            ~matApplyBar.(~lp[\matBar]);
            ~toscSend !? { ~toscSend.("/matrix/playhead", ~lp[\matBar]) };
            ~matBeatsPerBar.wait;
            ~lp[\matBar] = ~matNextBar.value;
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

// -- ~matSafeName : sanitize a name to a safe filename (alphanumeric, -, _, space→_) --
~matSafeName = { |name|
    var s = name.asString.select({ |c| c.isAlphaNum or: { "-_ ".includes(c) } }).replace(" ", "_");
    (s.size > 0).if({ s }, { "untitled" })
};

// -- ~matGridValid : confirm a grid is 16 x matBars with integer cells 0..6 --
~matGridValid = { |g|
    g.isArray and: {
        g.size == ~matVoices.size and: {
            g.every({ |row|
                row.isArray and: {
                    row.size == ~matBars and: {
                        row.every({ |v| v.isInteger and: { v >= 0 and: { v <= 6 } } })
                    }
                }
            })
        }
    }
};

// -- ~matNames : list base names of .matrix files found in a directory --
// User dir: served from in-memory ~matSavedNames (populated by ~matSave) —
// avoids filesystem-scan quirks that can fail headless in some SC contexts.
// Other dirs (e.g. shipped presets): scan via ls+tmpfile (systemCmd is
// synchronous and works headless; pathMatch/Pipe.getLine are unreliable).
~matNames = { |dir|
    (dir == ~matDir).if({
        ~matSavedNames.asArray
    }, {
        var ext = ".matrix";
        var result = [];
        File.exists(dir).if({
            var tmp = "/tmp/_av_live_matnames_.txt";
            ("ls -1 '" ++ dir ++ "' > '" ++ tmp ++ "' 2>/dev/null").systemCmd;
            File.exists(tmp).if({
                var content = File.use(tmp, "r", { |f| f.readAllString });
                ("rm -f '" ++ tmp ++ "'").systemCmd;
                content.split($\n).do({ |fn|
                    (fn.size > ext.size and: {
                        fn.copyRange(fn.size - ext.size, fn.size - 1) == ext
                    }).if({
                        result = result.add(fn.copyRange(0, fn.size - ext.size - 1).asSymbol)
                    })
                })
            })
        });
        result
    })
};

// -- ~matGridPush : send full 512-int grid row-major to surfaces --
// index = vi * 32 + bar  (voice-major, flatten concatenates rows in order)
~matGridPush = {
    ~toscSend !? { ~toscSend.valueArray(["/matrix/grid"] ++ ~lp[\matrix].flatten) }
};

// -- ~matInstrPush : send 16 instrument names (or "default") to surfaces --
~matInstrPush = {
    ~toscSend !? {
        ~toscSend.valueArray(["/matrix/instruments"]
            ++ ~matInstruments.collect({ |x| (x ? \default).asString }))
    }
};

// -- ~matSetColorDef : set one field of one voice/color, validate, re-source, echo --
~matSetColorDef = { |vi, color, field, value|
    var fields = [\stretch, \octave, \amp, \inst, \cutoff, \pan];
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }
        and: { fields.includes(field.asSymbol) }).if({
        var name = ~matVoices[vi];
        var ok = true;
        var v = value;
        (field.asSymbol == \inst).if({
            v = ((value.asSymbol == \default) or: { value.isNil }).if({ nil }, { value.asSymbol });
            ok = v.isNil or: { (~matInstChoices[name] ? []).includes(v) };
        });
        ((field.asSymbol == \cutoff) or: { field.asSymbol == \pan }).if({
            ok = (~matModTargets[name] ? []).includes(field.asSymbol);
            v = value.asFloat;
        });
        ((field.asSymbol == \stretch) or: { field.asSymbol == \octave }
            or: { field.asSymbol == \amp }).if({
            v = (field.asSymbol == \octave).if({ value.asInteger }, { value.asFloat });
        });
        ok.if({
            ~matColorDefs[vi][color][field.asSymbol] = v;
            ~matLastColor[vi] = -1;
            (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
            ~matColorDefPush.(vi)
        })
    })
};

// -- ~matColorDefPush : send one voice's 6 color defs flattened to surfaces --
// flat layout per color (1..6): stretch, octave, amp, inst(str), cutoff(-1=nil), pan(-2=nil)
// Distinct OUTBOUND address (plural) so it never collides with the 4-arg inbound
// /matrix/colordef set (mirrors /matrix/instrument vs /matrix/instruments).
~matColorDefPush = { |vi|
    ~toscSend !? {
        var flat = (1..6).collect({ |c|
            var d = ~matColorDefs[vi][c];
            [ d[\stretch], d[\octave], d[\amp], (d[\inst] ? \default).asString,
              d[\cutoff] ? -1, d[\pan] ? -2 ]
        }).flatten;
        ~toscSend.valueArray(["/matrix/colordefs", vi] ++ flat)
    }
};

// -- ~matStepsEmpty : true when no step has a note (all rests) --
~matStepsEmpty = { |steps| steps.isNil or: { steps.every({ |s| s.isNil }) } };

// -- ~matSetStep : write one step (degree \rest/nil clears), re-source, echo --
~matSetStep = { |vi, color, stepIdx, degree, vel|
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }
        and: { stepIdx >= 0 and: { stepIdx < 16 } }).if({
        var steps = ~matColorDefs[vi][color][\steps];
        ((degree == \rest) or: { degree.isNil }).if({
            steps[stepIdx] = nil
        }, {
            steps[stepIdx] = (degree: degree.asInteger, vel: vel.asFloat.clip(0, 1))
        });
        ~matLastColor[vi] = -1;
        (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
        ~matStepsPush.(vi, color)
    })
};

// -- ~matStepsPush : send one color's 16 steps (degree, vel); rest -> (-99, 0) --
~matStepsPush = { |vi, color|
    ((vi >= 0 and: { vi < ~matVoices.size }) and: { color >= 1 and: { color <= 6 } }).if({
        ~toscSend !? {
            var flat = ~matColorDefs[vi][color][\steps].collect({ |s|
                s.isNil.if({ [-99, 0] }, { [s[\degree], s[\vel]] })
            }).flatten;
            ~toscSend.valueArray(["/matrix/steps", vi, color] ++ flat)
        }
    })
};

OSCdef(\mat_step, { |msg, time, addr|
    var deg;
    ~toscTouch !? { ~toscTouch.(addr) };
    deg = ((msg[4] ? -99) == -99).if({ \rest }, { msg[4] });
    ~matSetStep.((msg[1] ? 0).asInteger, (msg[2] ? 1).asInteger, (msg[3] ? 0).asInteger,
        deg, (msg[5] ? 0))
}, '/matrix/step');

OSCdef(\mat_steps_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    (1..6).do { |c| ~matStepsPush.((msg[1] ? 0).asInteger, c) }
}, '/matrix/steps/get');

// -- ~matModPush : send 16 mod triples (source,target,depth) flattened --
~matModPush = {
    ~toscSend !? {
        ~toscSend.valueArray(["/matrix/mods"] ++ ~matMod.collect({ |m|
            m.isNil.if({ ["none", "none", 0] },
                { [m[\source].asString, m[\target].asString, m[\depth]] })
        }).flatten)
    }
};

// -- ~matListPush : send all available preset + user-save names to surfaces --
~matListPush = {
    try {
        var names = (~matNames.(~matPresetDir) ++ ~matNames.(~matDir)).as(Set).asArray.sort;
        ~toscSend !? { ~toscSend.valueArray(["/matrix/list"] ++ names) };
        ~matLoopPush.()
    } { |e|
        ("[matrix] listPush err: " ++ e.class.name).postln
    }
};

// -- ~matSave : persist current grid + instruments to ~/.config/av-live/matrices/<name>.matrix --
~matSave = { |name|
    var safe = ~matSafeName.(name);
    var path = ~matDir +/+ (safe ++ ".matrix");
    var payload = (
        grid: ~lp[\matrix],
        instruments: ~matInstruments.collect({ |x| (x ? \default) }),
        mods: ~matMod.collect({ |m| m.isNil.if({ \none },
            { [m[\source], m[\target], m[\depth]] }) }),
        colorDefs: ~matColorDefs.collect({ |defs| (1..6).collect({ |c| defs[c] }) }),
        poseBindings: ~matPoseBindings
    );
    File.use(path, "w", { |f| f.write(payload.asCompileString) });
    ~matSavedNames.add(safe.asSymbol);
    ("[matrix] saved " ++ path).postln;
    ~matListPush.();
};

// -- ~matLoadFile : load and validate a grid from an absolute path --
// Accepts both legacy bare Array (grid only) and new Event (grid: + instruments:).
~matLoadFile = { |path|
    var raw, grid, insts;
    File.exists(path).if({
        raw = File.use(path, "r", { |f| f.readAllString }).interpret;
        // legacy: bare grid Array; new: Event (grid:, instruments:)
        grid  = raw.isArray.if({ raw }, { raw[\grid] });
        insts = raw.isArray.if({ nil }, { raw[\instruments] });
        ~matGridValid.(grid).if({
            ~lp[\matrix] = grid;
            // restore instruments (default nil; validate against choices)
            ~matVoices.do { |name, vi|
                var sym = (insts.notNil).if({ insts[vi] }, { \default });
                ~matInstruments[vi] = ((sym.isNil) or: { sym == \default } or: {
                    (~matInstChoices[name] ? []).includes(sym.asSymbol).not
                }).if({ nil }, { sym.asSymbol });
            };
            ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
            // restore mods (validate via ~matApplyMod, which rejects invalid)
            ~matVoices.size.do { |i| ~matMod[i] = nil };
            ((raw.isArray.not) and: { raw[\mods].notNil }).if({
                raw[\mods].do { |m, vi|
                    (m != \none and: { m.isArray and: { m.size == 3 } }).if({
                        ~matApplyMod.(vi, m[0], m[1], m[2])
                    })
                }
            });
            // restore color defs (default missing/legacy to the historical table)
            ~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
            ((raw.isArray.not) and: { raw[\colorDefs].notNil }).if({
                raw[\colorDefs].do { |voiceDefs, vi|
                    (voiceDefs.isArray and: { vi < ~matVoices.size }).if({
                        voiceDefs.do { |d, ci|
                            (d.isKindOf(Event)).if({
                                [\stretch, \octave, \amp, \inst, \cutoff, \pan].do { |f|
                                    d[f].notNil.if({ ~matColorDefs[vi][ci + 1][f] = d[f] })
                                }; (d[\steps].notNil and: { d[\steps].isArray }).if({ ~matColorDefs[vi][ci + 1][\steps] = d[\steps] })
                            })
                        }
                    })
                }
            });
            // restore pose bindings (default empty; legacy/missing -> empty arrays)
            ~matPoseBindings = Array.fill(~matVoices.size, { [] });
            ((raw.isArray.not) and: { raw[\poseBindings].notNil }).if({
                raw[\poseBindings].do { |list, vi|
                    (list.isArray and: { vi < ~matVoices.size }).if({ ~matPoseBindings[vi] = list })
                }
            });
            ~matVoices.size.do { |vi| ~matPosesPush.(vi) };
            ~lp[\matPlaying].if({ ~matApplyBar.(~lp[\matBar]) });
            ~matGridPush.();
            ~matInstrPush.();
            ~matModPush.();
            ~matVoices.size.do { |vi| ~matColorDefPush.(vi) };
            ("[matrix] loaded " ++ path).postln;
            true
        }, {
            ("[matrix] invalid grid in " ++ path).warn;
            false
        })
    }, {
        ("[matrix] not found " ++ path).warn;
        false
    })
};

// -- ~matLoad : load by name; user save wins over shipped preset --
~matLoad = { |name|
    var safe = ~matSafeName.(name);
    var up   = ~matDir       +/+ (safe ++ ".matrix");
    var pp   = ~matPresetDir +/+ (safe ++ ".matrix");
    File.exists(up).if({ ~matLoadFile.(up) }, { ~matLoadFile.(pp) })
};

// -- ~matAudition : preview a voice's 6 colors as a 1-beat-per-step loop --
// on=true starts a Routine cycling color 1..6 (re-sources the voice's Pdef each
// step); on=false stops the routine and silences the voice. Preview only — does
// not move the grid playhead.
~matAudition = { |vi, on|
    (vi >= 0 and: { vi < ~matVoices.size }).if({
        var name = ~matVoices[vi];
        var key  = ("lp_" ++ name).asSymbol;
        ~matAudRoutine = ~matAudRoutine ? IdentityDictionary.new;
        ~matAudRoutine[vi] !? { ~matAudRoutine[vi].stop };
        on.if({
            var clock = ~lp[\clock] ? TempoClock.default;
            ~matAudRoutine[vi] = Routine({
                var c = 1;
                var started = false;
                loop {
                    var pat = ~matVariation.(name, c, vi);
                    pat.notNil.if({
                        Pdef(key, pat);
                        started.not.if({ Pdef(key).play(clock, quant: 1); started = true });
                    });
                    1.wait;
                    c = (c % 6) + 1;
                }
            }).play(clock, quant: 1);
        }, {
            ~matAudRoutine[vi] = nil;
            Pdef.all.includesKey(key).if({ Pdef(key).stop });
            ~matLastColor[vi] = -1;       // force normal re-source on next grid bar
        })
    })
};

// -- ~matPosesPush : send a voice's pose bindings over OSC --
~matPosesPush = { |vi|
    ~toscSend !? {
        var flat = ~matPoseBindings[vi].collect({ |b|
            [b[\poseId].asString, b[\action].asString, b[\color]] }).flatten;
        ~toscSend.valueArray(["/matrix/poses", vi, ~matPoseBindings[vi].size] ++ flat)
    }
};

// -- ~matSetPoseBind : add/replace a (poseId, action, color) binding for a voice --
// empty/\none poseId clears all bindings for that voice.
~matSetPoseBind = { |vi, poseId, action, color|
    (vi >= 0 and: { vi < ~matVoices.size }).if({
        var pid = poseId.asSymbol;
        ((pid == '') or: { pid == \none }).if({
            ~matPoseBindings[vi] = []
        }, {
            // replace any existing binding for this poseId, else append
            ~matPoseBindings[vi] = ~matPoseBindings[vi].reject({ |b| b[\poseId] == pid })
                ++ [ (poseId: pid, action: action.asSymbol, color: color.asInteger.clip(1, 6)) ];
        });
        ~matPosesPush.(vi)
    })
};

// -- ~matPoseFire : run every binding matching poseId across all voices --
// \trigger re-sources the voice to the bound color; \gate toggles the voice's Pdef.
// Unknown poseId -> no-op (no raise).
~matPoseFire = { |poseId|
    var pid = poseId.asSymbol;
    ~matVoices.do { |name, vi|
        var key = ("lp_" ++ name).asSymbol;
        ~matPoseBindings[vi].do { |b|
            (b[\poseId] == pid).if({
                (b[\action] == \trigger).if({
                    Pdef.all.includesKey(key).if({
                        var pat = ~matVariation.(name, b[\color], vi);
                        pat.notNil.if({
                            Pdef(key, pat);
                            Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1)
                        })
                    })
                });
                (b[\action] == \gate).if({
                    Pdef.all.includesKey(key).if({
                        Pdef(key).isPlaying.if(
                            { Pdef(key).stop },
                            { Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) }
                        )
                    })
                });
            })
        }
    }
};

OSCdef(\mat_posebind, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetPoseBind.((msg[1] ? 0).asInteger, (msg[2] ? \none).asSymbol,
        (msg[3] ? \trigger).asSymbol, (msg[4] ? 1).asInteger)
}, '/matrix/posebind');

OSCdef(\mat_pose, { |msg, time, addr|
    ~matPoseFire.((msg[1] ? \none).asSymbol)
}, '/matrix/pose');

OSCdef(\mat_poses_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matPosesPush.((msg[1] ? 0).asInteger)
}, '/matrix/poses/get');

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

OSCdef(\mat_save, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSave.(msg[1].asString)
}, '/matrix/save');

OSCdef(\mat_load, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matLoad.(msg[1].asString)
}, '/matrix/load');

OSCdef(\mat_list, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matListPush.()
}, '/matrix/list');

OSCdef(\mat_inst, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matApplyInstrument.((msg[1] ? 0).asInteger, (msg[2] ? \default).asSymbol)
}, '/matrix/instrument');

OSCdef(\mat_kit, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matApplyKit.((msg[1] ? \default).asSymbol)
}, '/matrix/kit');

OSCdef(\mat_mod, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matApplyMod.((msg[1] ? 0).asInteger, (msg[2] ? \none).asSymbol,
        (msg[3] ? \none).asSymbol, (msg[4] ? 0).asFloat)
}, '/matrix/mod');

OSCdef(\mat_loop, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetLoop.(msg[1].asInteger, msg[2].asInteger)
}, '/matrix/loop');

OSCdef(\mat_seek, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSeek.(msg[1].asInteger)
}, '/matrix/seek');

OSCdef(\mat_colordef, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetColorDef.((msg[1] ? 0).asInteger, (msg[2] ? 1).asInteger,
        (msg[3] ? \amp).asSymbol, msg[4])
}, '/matrix/colordef');

OSCdef(\mat_colordef_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matColorDefPush.((msg[1] ? 0).asInteger)
}, '/matrix/colordefs/get');

OSCdef(\mat_audition, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matAudition.((msg[1] ? 0).asInteger, (msg[2] ? 0) > 0)
}, '/matrix/audition');

// -- Capture mod source cache (nil-guarded; idempotent reload) --
~matModCache   = ~matModCache ? IdentityDictionary.new;
~matModSources = ~matModSources ?
    [\lHandY, \rHandY, \lOpen, \rOpen, \handSpeed, \handDist, \bodyY, \depth];

// reader: clamp to 0..1, default 0 when absent
~matModSourceVal = { |key| (~matModCache[key] ? 0).clip(0, 1) };

// own capture listeners (independent of the pose pipeline's internal dicts)
OSCdef(\mat_mod_hands, { |msg|
    ~matModCache[\lHandY]    = 1 - (msg[3] ? 0.5);   // image y top-down -> up=1
    ~matModCache[\rHandY]    = 1 - (msg[7] ? 0.5);
    ~matModCache[\lOpen]     = msg[4] ? 0;
    ~matModCache[\rOpen]     = msg[8] ? 0;
    ~matModCache[\handSpeed] = ((msg[5] ? 0) max: (msg[9] ? 0));
    ~matModCache[\handDist]  = msg[10] ? 0;
}, '/pose/hands');

OSCdef(\mat_mod_center, { |msg|
    ~matModCache[\bodyY] = 1 - (msg[3] ? 0.5);       // /pose/center [pid, cx, cy]
}, '/pose/center');

OSCdef(\mat_mod_span, { |msg|
    ~matModCache[\depth] = ((msg[2] ? 0) * 2.5).clip(0, 1);  // /pose/sho_span depth proxy
}, '/pose/sho_span');

"[matrix] ready".postln;
)
