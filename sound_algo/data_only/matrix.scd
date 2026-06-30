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
    \tom,  \reese, \bells, \sweep,
    \melody, \chord, \fx, \snare, \crash, \shaker
];
~matBars        = ~matBars        ? 64;
~lp[\matrix]    = ~lp[\matrix]    ? Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
~lp[\matBar]    = ~lp[\matBar]    ? 0;
~lp[\matPlaying] = ~lp[\matPlaying] ? false;
~matBase        = ~matBase        ? IdentityDictionary.new;
~matBeatsPerBar = ~matBeatsPerBar ? 4;
~matLastColor   = ~matLastColor   ? Array.fill(~matVoices.size, -1);
~matInstruments  = ~matInstruments  ? Array.fill(~matVoices.size, nil);
~matModTargets   = ~matModTargets   ? IdentityDictionary[
    \kick->[\amp,\pan,\rev], \hats->[\amp,\pan,\rev], \clap->[\amp,\pan,\rev],
    \perc->[\amp,\cutoff,\pan,\rev,\pitch],
    \sub->[\amp,\pan,\rev,\res,\pitch], \acid->[\amp,\cutoff,\pan,\rev,\res,\pitch], \arp->[\amp,\cutoff,\pan,\rev,\res,\pitch],
    \lead->[\amp,\cutoff,\pan,\rev,\res,\pitch], \stab->[\amp,\cutoff,\pan,\rev,\res,\pitch], \pad->[\amp,\cutoff,\pan,\rev,\res,\pitch],
    \ride->[\amp,\pan,\rev], \rim->[\amp,\pan,\rev], \tom->[\amp,\pan,\rev,\pitch],
    \reese->[\amp,\cutoff,\pan,\rev,\res,\pitch],
    \bells->[\amp,\pan,\rev,\res,\pitch], \sweep->[\amp,\pan,\rev],
    \melody->[\amp,\cutoff,\pan,\rev,\res], \chord->[\amp,\cutoff,\pan,\rev,\res],
    \fx->[\amp,\pan,\rev], \snare->[\amp,\pan,\rev],
    \crash->[\amp,\pan,\rev], \shaker->[\amp,\pan,\rev]
];
~matModNeutralCut = ~matModNeutralCut ? IdentityDictionary[
    \perc->1260, \acid->700, \arp->3000, \lead->4000, \stab->2200,
    \pad->1500, \reese->1100, \melody->3500, \chord->2000
];
// voices whose SynthDef has a resonant filter (res param). rev (reverb send)
// is accepted by all lp_/classic synths, so it is not gated by voice.
~matResVoices = ~matResVoices ? [\sub, \acid, \arp, \lead, \stab, \pad, \reese, \bells, \melody, \chord];

// -- default color defs reproduce the historical global variation table --
~matDefaultColorDefs = {
    [ nil,
        (stretch: 1.0, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, res: nil, rev: nil, steps: Array.fill(16, nil), mod: nil, pose: Array.new),
        (stretch: 0.5, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, res: nil, rev: nil, steps: Array.fill(16, nil), mod: nil, pose: Array.new),
        (stretch: 1.0, octave:  1, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, res: nil, rev: nil, steps: Array.fill(16, nil), mod: nil, pose: Array.new),
        (stretch: 2.0, octave:  0, amp: 1.0,  inst: nil, cutoff: nil, pan: nil, res: nil, rev: nil, steps: Array.fill(16, nil), mod: nil, pose: Array.new),
        (stretch: 1.0, octave: -1, amp: 1.05, inst: nil, cutoff: nil, pan: nil, res: nil, rev: nil, steps: Array.fill(16, nil), mod: nil, pose: Array.new),
        (stretch: 0.5, octave:  0, amp: 1.2,  inst: nil, cutoff: nil, pan: nil, res: nil, rev: nil, steps: Array.fill(16, nil), mod: nil, pose: Array.new) ]
};
~matColorDefs = ~matColorDefs ? Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });

~lp[\matLoopStart] = ~lp[\matLoopStart] ? 0;
~lp[\matLoopEnd]   = ~lp[\matLoopEnd]   ? (~matBars - 1);

// -- Persistence env init (nil-guarded) --
~matDir        = ~matDir        ? "~/.config/av-live/matrices".standardizePath;
~matPresetDir  = ~matPresetDir  ? (PathName(thisProcess.nowExecutingPath).pathOnly ++ "matrix_presets");
~matSavedNames = ~matSavedNames ? Set.new;
~matQueuedLoad = ~matQueuedLoad ? nil;   // armed preset name for /matrix/loadnext (nil = none)
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
    \kick  -> [\lp_kick, \tr909_kick, \tr808_kick, \sp1200, \do_kick, \do_quake_sub],
    \hats  -> [\lp_hat,  \tr909_hat, \tr808_hat, \sp1200, \do_hat],
    \clap  -> [\lp_clap, \tr909_clap, \tr808_clap, \sp1200, \lp_rim],
    \perc  -> [\lp_perc, \tr808_cowbell, \sp1200, \akai_s, \do_strike],
    \sub   -> [\lp_sub,  \sh101, \minimoog, \system100, \lp_reese],
    \acid  -> [\lp_acid, \tb303, \ms20, \system100, \lp_pluck],
    \arp   -> [\lp_pluck, \tb303, \supersaw, \juno, \do_strike],
    \lead  -> [\lp_pluck, \ms20, \supersaw, \do_plane, \sh101],
    \stab  -> [\lp_pluck, \ms20, \supersaw, \tb303, \lp_acid],
    \pad   -> [\lp_pad,  \juno, \supersaw, \ms20, \lp_reese],
    \ride  -> [\lp_ride, \tr909_ride, \lp_hat, \do_hat],
    \rim   -> [\lp_rim,  \tr808_cowbell, \tr909_clap, \sp1200],
    \tom   -> [\lp_tom,  \sp1200, \do_strike, \do_quake_sub],
    \reese -> [\lp_reese, \ms20, \minimoog, \system100, \supersaw],
    \bells -> [\lp_bells, \dx7, \akai_s, \do_plane],
    \sweep -> [\lp_sweep, \akai_s, \lp_pad, \lp_reese],
    \melody -> [\lp_pluck, \supersaw, \ms20, \sh101, \dx7],
    \chord  -> [\lp_pad, \juno, \supersaw, \ms20],
    \fx     -> [\lp_fx, \akai_s, \lp_sweep],
    \snare  -> [\lp_snare, \tr909_clap, \tr808_clap, \lp_clap],
    \crash  -> [\lp_crash, \tr909_ride, \akai_s],
    \shaker -> [\lp_shaker, \tr909_hat, \tr808_hat]
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

// -- ~matModPairs : per-voice additive binding list -> flat pair list for Pbind --
// Reads ~matVoiceMods[name] (array of (source:,target:,depth:) events).
// Groups by target, sums contributions, returns flat [tgt1, Pfunc1, tgt2, Pfunc2, ...].
// Targets not in ~matModTargets[name] are silently dropped.
~matModPairs = { |name, spec, volOf|
    var allowed = ~matModTargets[name] ? [];
    var byTarget = IdentityDictionary.new;
    var pairs = [];
    ((~matVoiceMods[name] ? []).select { |b|
        b[\source].notNil and: { b[\target].notNil }
            and: { b[\target] != \pitch } and: { allowed.includes(b[\target]) }
    }).do { |b| byTarget[b[\target]] = (byTarget[b[\target]] ? []) ++ [b] };
    byTarget.keysValuesDo { |tgt, list|
        (tgt == \cutoff).if({
            var c0 = ~matModNeutralCut[name] ? 1000;
            pairs = pairs ++ [\cutoff, Pfunc {
                var f = c0;
                list.do { |b| var s = ~matModSourceVal.(b[\source]);
                    f = f * (s.linexp(0, 1, 200, 6000) / c0).pow(b[\depth]) };
                f
            }]
        }, {
        (tgt == \pan).if({
            pairs = pairs ++ [\pan, Pfunc {
                var a = 0; list.do { |b| a = a + ((~matModSourceVal.(b[\source]) * 2 - 1) * b[\depth]) };
                a.clip(-1, 1)
            }]
        }, {
        (tgt == \rev).if({
            pairs = pairs ++ [\rev, Pfunc {
                var a = 0; list.do { |b| a = a + (~matModSourceVal.(b[\source]) * b[\depth]) };
                a.clip(0, 1)
            }]
        }, {
        (tgt == \res).if({
            pairs = pairs ++ [\res, Pfunc {
                var a = 0; list.do { |b| a = a + (~matModSourceVal.(b[\source]) * b[\depth]) };
                a.clip(0, 1)
            }]
        }, {
            pairs = pairs ++ [\amp, Pfunc {
                var base = (spec[\amp] ? 1.0) * volOf.value;
                list.do { |b| base = base * (1 + (b[\depth] * (~matModSourceVal.(b[\source]) * 2 - 1))).max(0) };
                base
            }]
        }) }) }) })
    };
    pairs
};

// -- ~matVariationOverlay : assemble the Pchain overlay given a resolved spec --
// Factored out of ~matVariation so the main function stays readable.
// cdPairs (static per-color cutoff/pan) come before modPairs so a live capture
// mod on the same target overrides the static color-def value — intended.
~matVariationOverlay = { |name, vi, spec, volOf, instPair, cdPairs, base|
    // octave colors multiply \freq by 2**octave (main's freqRatio scheme), pitched
    // voices only — works for voices that set \freq directly via Pfunc.
    var pitched = [\sub, \acid, \arp, \lead, \stab, \pad, \reese, \bells, \perc, \tom];
    var freqRatio = 2 ** (spec[\octave] ? 0);
    var freqPair = (pitched.includes(name) and: { freqRatio != 1.0 }).if({
        [\freq, Pfunc({ |e| (e[\freq] ? 440) * freqRatio })]  // pitch mod step-path only (no degree here)
    }, { [] });
    var modPairs = ~matModPairs.(name, spec, volOf);
    Pchain(
        Pbind(*([
            \matGlow, Pfunc { |e| ~matEmitTrig.(vi, (e[\amp] ? spec[\amp]).clip(0, 1)); 0 },
            \stretch, (spec[\stretch] * ~matTxStretch.value),
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
    var pitched = [\sub, \acid, \arp, \lead, \stab, \pad, \reese, \bells, \perc, \tom];
    var modPairs = ~matModPairs.(name, spec, volOf);
    var freqPair = pitched.includes(name).if({
        [\freq, Pfunc { |e| (~lpNote.notNil).if({ ~lpNote.(e[\degree] + ~matPitchOffset.(name), 0).midicps * freqRatio }, { 440 }) }]
    }, { [] });
    Pbind(*([
        \stepIdx, Pseq((0..15), inf),
        \matGlow, Pfunc { |e|
            var s = spec[\steps][e[\stepIdx]];
            ~matEmitTrig.(vi, s.isNil.if({ 0 }, { ((spec[\amp] ? 1.0) * s[\vel]).clip(0, 1) }));
            0
        },
        \type, Pfunc { |e| spec[\steps][e[\stepIdx]].isNil.if({ \rest }, { \note }) },
        \degree, Pfunc { |e| var s = spec[\steps][e[\stepIdx]]; s.isNil.if({ 0 }, { s[\degree] }) },
        \amp, Pfunc { |e|
            var s = spec[\steps][e[\stepIdx]];
            ((spec[\amp] ? 1.0) * (s.isNil.if({ 0 }, { s[\vel] }))) * volOf.value },
        \stretch, (spec[\stretch] * ~matTxStretch.value),
        \dur, ~matBeatsPerBar / 16
    ] ++ freqPair ++ instPair ++ cdPairs ++ modPairs))
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
                (spec[\res].notNil and: { ~matResVoices.includes(name) }).if({
                    cdPairs = cdPairs ++ [\res, spec[\res]] });
                ((spec[\rev].notNil) or: { ~matTxRev.value > 0 }).if({
                    cdPairs = cdPairs ++ [\rev, ((spec[\rev] ? 0) + ~matTxRev.value).clip(0, 1)] });
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
        var color = ~matEffColor.(name, vi, ~lp[\matrix][vi][bar]);
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

// -- generative per-cycle evolution (SP-B) --
~matEvolve     = ~matEvolve     ? false;
~matEvolveRate = ~matEvolveRate ? 0.15;   // fraction of active cells recoloured per cycle
~matBaseGrid   = ~matBaseGrid   ? nil;     // immutable clean snapshot while evolving

// re-derive ~lp[\matrix] from ~matBaseGrid: recolour active cells (0 stays 0),
// mutated colour differs from base and is in 1..6. Bounded (always from base).
~matEvolveStep = {
    ~matBaseGrid.notNil.if({
        ~matVoices.do { |name, vi|
            ~matBars.do { |b|
                var base = ~matBaseGrid[vi][b];
                ((base != 0) and: { 1.0.rand < ~matEvolveRate }).if({
                    ~lp[\matrix][vi][b] = (1..6).reject({ |c| c == base }).choose
                }, {
                    ~lp[\matrix][vi][b] = base
                })
            }
        };
        ~matVoices.size.do { |i| ~matLastColor[i] = -1 };   // force re-source next bar
        ~matGridPush.()
    })
};

// push evolve state to surfaces
~matEvolvePush = {
    ~toscSend !? { ~toscSend.("/matrix/evolve", ~matEvolve.if({ 1 }, { 0 }), ~matEvolveRate) }
};

// enable/disable: snapshot base on enable; restore clean grid on disable
~matSetEvolve = { |on|
    on.asBoolean.if({
        ~matEvolve.not.if({ ~matBaseGrid = ~lp[\matrix].collect({ |row| row.copy }) });
        ~matEvolve = true;
    }, {
        ~matEvolve = false;
        ~matBaseGrid.notNil.if({
            ~lp[\matrix] = ~matBaseGrid.collect({ |row| row.copy });
            ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
            ~matGridPush.()
        });
        ~matBaseGrid = nil;
    });
    ~matEvolvePush.()
};

// -- global morceau actions: momentary transient overrides + gesture mapping --
~matTransient     = ~matTransient     ? nil;          // (kind:, voices:[Symbol], bars:Int) or nil
~matGlobalSettings = ~matGlobalSettings ? ( transientBars: 1, breakdownKeep: [\kick, \sub] );
~matGlobalActions = ~matGlobalActions ? [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next];  // 8 pinch slots 0..7
~matDrumVoices = ~matDrumVoices ? [\kick,\hats,\clap,\ride,\rim,\sweep,\fx,\snare,\crash,\shaker,\perc,\tom];
~matMeloVoices = ~matMeloVoices ? [\sub,\acid,\arp,\lead,\stab,\pad,\reese,\bells,\melody,\chord];
// transient param channels read by ~matVariation (1.0/0.0 when no transient or a colour-only kind)
~matTxStretch = { (~matTransient.notNil).if({ ~matTransient[\stretch] ? 1.0 }, { 1.0 }) };
~matTxRev     = { (~matTransient.notNil).if({ ~matTransient[\rev] ? 0.0 }, { 0.0 }) };

// effective colour for a voice this bar, given any active transient (grid untouched)
~matEffColor = { |name, vi, base|
    var t = ~matTransient;
    t.isNil.if({ base }, {
        var k = t[\kind];
        (k == \drop).if({ 0 },
        { (k == \fill).if({ (base == 0).if({ 0 }, { 6 }) },
        { (k == \breakdown).if({ ((t[\voices] ? []).includes(name)).if({ base }, { 0 }) },
        { (k == \mute).if({ ((t[\voices] ? []).includes(name)).if({ 0 }, { base }) },
        { base }) }) }) })
    })
};

// set a transient + re-source now (effect lands at the next bar via Pdef quant)
~matSetTransient = { |kind, voices|
    var stretch = (kind == \doubleTime).if({ 0.5 }, { (kind == \halfTime).if({ 2.0 }, { 1.0 }) });
    var rev = (kind == \washReverb).if({ 0.4 }, { 0.0 });
    ~matTransient = (kind: kind, voices: (voices ? []), bars: (~matGlobalSettings[\transientBars] ? 1),
                     stretch: stretch, rev: rev);
    ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
    (~lp[\matPlaying] == true).if({ ~matApplyBar.(~lp[\matBar] ? 0) });
};

// count one bar of transient use; clear + force re-source when exhausted (routine-only)
~matTransientTick = {
    ~matTransient.notNil.if({
        ~matTransient[\bars] = ~matTransient[\bars] - 1;
        (~matTransient[\bars] <= 0).if({
            ~matTransient = nil;
            ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
        });
    });
};

// one mutation + re-source (the evolve one-shot). When the evolve toggle is
// OFF, snapshot/mutate/discard so ~matBaseGrid (owned by the toggle: non-nil
// iff evolve active) is never leaked across a preset load. When ON, keep the
// persistent base and just re-mutate from it.
~matRelanceEvolve = {
    var hadBase = ~matBaseGrid.notNil;
    hadBase.not.if({ ~matBaseGrid = ~lp[\matrix].collect({ |row| row.copy }) });
    ~matEvolveStep.();
    hadBase.not.if({ ~matBaseGrid = nil });
    ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
    (~lp[\matPlaying] == true).if({ ~matApplyBar.(~lp[\matBar] ? 0) });
};

// dispatch the action mapped to a gesture slot (0=LHopen,1=LHclosed,2=RHopen,3=RHclosed)
~matFireGlobal = { |slot|
    var act = (~matGlobalActions[slot]) ? \none;
    (act == \fill).if({ ~matSetTransient.(\fill, []) });
    (act == \drop).if({ ~matSetTransient.(\drop, []) });
    (act == \breakdown).if({ ~matSetTransient.(\breakdown, ~matGlobalSettings[\breakdownKeep] ? [\kick, \sub]) });
    (act == \evolve).if({ ~matRelanceEvolve.() });
    (act == \muteDrums).if({ ~matSetTransient.(\mute, ~matDrumVoices) });
    (act == \muteMelo).if({ ~matSetTransient.(\mute, ~matMeloVoices) });
    (act == \doubleTime).if({ ~matSetTransient.(\doubleTime, []) });
    (act == \halfTime).if({ ~matSetTransient.(\halfTime, []) });
    (act == \washReverb).if({ ~matSetTransient.(\washReverb, []) });
    (act == \next).if({ ~matNextPreset.() });
};

// push the 8-slot mapping to surfaces (symbols sent as strings)
~matGlobalActionsPush = {
    8.do { |i| ~toscSend !? { ~toscSend.("/matrix/globalaction", i, (~matGlobalActions[i] ? \none).asString) } }
};

// push settings to surfaces: transientBars, keepN, keep0..
~matGlobalSettingsPush = {
    var s = ~matGlobalSettings; var keep = s[\breakdownKeep] ? [];
    ~toscSend !? { ~toscSend.valueArray(["/matrix/globalsettings",
        s[\transientBars], keep.size] ++ keep.collect({ |v| v.asString })) }
};
~matBpm = ~matBpm ? 120;
~matSetBpm = { |bpm|
    var b = bpm.asFloat.clip(20, 300);
    ~matBpm = b;
    (~lp[\clock] ? TempoClock.default).tempo = b / 60;
    ~toscSend !? { ~toscSend.("/matrix/bpm", b) };
};
~matBpmPush = { ~toscSend !? { ~toscSend.("/matrix/bpm", ~matBpm) } };
~matCurrentName = ~matCurrentName ? nil;
~matAllNames = { (~matNames.(~matPresetDir) ++ ~matNames.(~matDir)).as(Set).asArray.sort };
~matNextPreset = {
    var names = ~matAllNames.value;
    (names.size > 0).if({
        var i = names.indexOf(~matCurrentName) ? -1;
        var nxt = names[(i + 1) % names.size];
        ~matLoad.(nxt);
        ~toscSend !? { ~toscSend.("/matrix/loaded", nxt.asString) };
    });
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
    ~matRoutine     !? { ~matRoutine.stop };     ~matRoutine     = nil;
    ~matStepRoutine !? { ~matStepRoutine.stop }; ~matStepRoutine = nil;
    ~lp[\matPlaying] = false;
    ~matVoices.do { |name|
        var k = ("lp_" ++ name).asSymbol;
        Pdef.all.includesKey(k).if({ Pdef(k).stop })
    };
    ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
    ~matPush.()
};

// -- ~matWrapStep : runs once per loop wrap. A queued load (/matrix/loadnext)
//    wins over evolve so a freshly loaded preset plays one clean cycle before
//    ÉVOLUE mutates it; otherwise evolve mutates as before. --
~matWrapStep = {
    ~matQueuedLoad.notNil.if({
        var name = ~matQueuedLoad;
        ~matLoad.(name);
        ~matQueuedLoad = nil;
        ~toscSend !? { ~toscSend.("/matrix/loaded", name) };   // name tracks the actual swap
        ~toscSend !? { ~toscSend.("/matrix/queued", "") };
    }, {
        ~matEvolve.if({ ~matEvolveStep.() });
    });
};

// -- ~matPlay : start the playhead Routine from bar 0, looping over ~matBars --
~matPlay = {
    var clock = ~lp[\clock] ? TempoClock.default;
    ~matRoutine     !? { ~matRoutine.stop };     ~matRoutine     = nil;
    ~matStepRoutine !? { ~matStepRoutine.stop }; ~matStepRoutine = nil;
    ~lp[\matPlaying] = true;
    ~lp[\matBar]     = ~lp[\matLoopStart] ? 0;
    ~matRoutine = Routine({
        loop {
            ~matApplyBar.(~lp[\matBar]);
            ~matTransientTick.();
            ~toscSend !? { ~toscSend.("/matrix/playhead", ~lp[\matBar]) };
            ~matBeatsPerBar.wait;
            ~matPrevBar  = ~lp[\matBar];
            ~lp[\matBar] = ~matNextBar.value;
            // loop wrapped (playhead jumped backward) -> queued load wins, else mutate
            (~lp[\matBar] < ~matPrevBar).if({ ~matWrapStep.() });
        }
    }).play(clock, quant: ~matBeatsPerBar);
    // -- per-step playhead: emits /matrix/stephead s (0..15) every 16th note --
    ~matStepRoutine = Routine({
        loop {
            16.do { |s|
                ~toscSend !? { ~toscSend.("/matrix/stephead", s) };
                (~matBeatsPerBar / 16).wait
            }
        }
    }).play(clock, quant: ~matBeatsPerBar);
    ~matPush.()
};

// -- ~matSetCell : write matrix[vi][bar] = color; apply live if playhead is there --
~matSetCell = { |vi, bar, color|
    (vi >= 0 and: { vi < ~matVoices.size and: { bar >= 0 and: { bar < ~matBars } } }).if({
        ~lp[\matrix][vi][bar] = color.clip(0, 6).asInteger;
        (~matEvolve and: { ~matBaseGrid.notNil }).if({ ~matBaseGrid[vi][bar] = ~lp[\matrix][vi][bar] });
        (~lp[\matPlaying] and: { bar == ~lp[\matBar] }).if({ ~matApplyBar.(bar) });
        ~toscSend !? { ~toscSend.("/matrix/cell", vi, bar, ~lp[\matrix][vi][bar]) }
    })
};

// -- ~matClear : reset all cells to 0 and push state --
~matClear = {
    ~lp[\matrix] = Array.fill(~matVoices.size, { Array.fill(~matBars, 0) });
    (~matEvolve and: { ~matBaseGrid.notNil }).if({
        ~matBaseGrid = ~lp[\matrix].collect({ |row| row.copy }) });
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

// -- ~matMigrateGrid : coerce any grid to current ~matVoices.size x ~matBars --
// Legacy presets (e.g. 16 x 32) get padded to the current voice count (new
// voices silent) and their bars tiled (wrapAt) to fill ~matBars; cells clipped.
~matMigrateGrid = { |g|
    Array.fill(~matVoices.size, { |vi|
        var src = (g.isArray and: { vi < g.size } and: {
            g[vi].isArray and: { g[vi].size > 0 } }).if({ g[vi] }, { nil });
        Array.fill(~matBars, { |bar|
            src.notNil.if({ (src.wrapAt(bar) ? 0).asInteger.clip(0, 6) }, { 0 })
        })
    })
};

// -- ~matNames : list base names of .matrix files found in a directory --
// User dir: served from in-memory ~matSavedNames (populated by ~matSave) —
// avoids filesystem-scan quirks that can fail headless in some SC contexts.
// Other dirs (e.g. shipped presets): scan via ls+tmpfile (systemCmd is
// synchronous and works headless; pathMatch/Pipe.getLine are unreliable).
~matNames = { |dir|
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
    // user dir: union the disk scan with in-memory saves (covers a just-saved
    // name even if the fs scan races); other dirs: pure disk scan.
    (dir == ~matDir).if({ result = (result ++ ~matSavedNames.asArray).as(Set).asArray });
    result
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
    var fields = [\stretch, \octave, \amp, \inst, \cutoff, \pan, \res, \rev];
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
        (field.asSymbol == \res).if({
            ok = ~matResVoices.includes(name);
            v = value.asFloat;
        });
        (field.asSymbol == \rev).if({
            v = value.asFloat;
            // rev accepted for all voices (ungated)
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
// flat layout per color (1..6) — stride 8:
//   stretch, octave, amp, inst(str), cutoff(-1=nil), pan(-2=nil), res(-3=nil), rev(-4=nil)
// Distinct OUTBOUND address (plural) so it never collides with the 4-arg inbound
// /matrix/colordef set (mirrors /matrix/instrument vs /matrix/instruments).
~matColorDefPush = { |vi|
    ~toscSend !? {
        var flat = (1..6).collect({ |c|
            var d = ~matColorDefs[vi][c];
            [ d[\stretch], d[\octave], d[\amp], (d[\inst] ? \default).asString,
              d[\cutoff] ? -1, d[\pan] ? -2, d[\res] ? -3, d[\rev] ? -4 ]
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
            steps[stepIdx] = (degree: degree.asInteger.clip(-48, 48), vel: vel.asFloat.clip(0, 1))
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
        grid: (~matEvolve.if({ ~matBaseGrid ? ~lp[\matrix] }, { ~lp[\matrix] })),
        instruments: ~matInstruments.collect({ |x| (x ? \default) }),
        colorDefs: ~matColorDefs.collect({ |defs| (1..6).collect({ |c| defs[c] }) }),
        voiceMods:  ~matVoices.collect({ |name| ~matVoiceMods[name]  ? [] }),
        voicePoses: ~matVoices.collect({ |name| ~matVoicePoses[name] ? [] }),
        globalActions: ~matGlobalActions,
        globalSettings: ~matGlobalSettings
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
        grid  = grid.isArray.if({ ~matMigrateGrid.(grid) }, { grid });   // pad/tile to current dims
        ~matGridValid.(grid).if({
            ~lp[\matrix] = grid;
            (~matEvolve).if({ ~matBaseGrid = ~lp[\matrix].collect({ |row| row.copy }) });
            // restore instruments (default nil; validate against choices)
            ~matVoices.do { |name, vi|
                var sym = (insts.notNil).if({ insts[vi] }, { \default });
                ~matInstruments[vi] = ((sym.isNil) or: { sym == \default } or: {
                    (~matInstChoices[name] ? []).includes(sym.asSymbol).not
                }).if({ nil }, { sym.asSymbol });
            };
            ~matVoices.size.do { |i| ~matLastColor[i] = -1 };
            // restore color defs (default missing/legacy to the historical table)
            ~matColorDefs = Array.fill(~matVoices.size, { ~matDefaultColorDefs.value });
            ((raw.isArray.not) and: { raw[\colorDefs].notNil }).if({
                raw[\colorDefs].do { |voiceDefs, vi|
                    (voiceDefs.isArray and: { vi < ~matVoices.size }).if({
                        voiceDefs.do { |d, ci|
                            (d.isKindOf(Event)).if({
                                [\stretch, \octave, \amp, \inst, \cutoff, \pan, \res, \rev].do { |f|
                                    d[f].notNil.if({ ~matColorDefs[vi][ci + 1][f] = d[f] })
                                }; (d[\steps].notNil and: { d[\steps].isArray }).if({ ~matColorDefs[vi][ci + 1][\steps] = d[\steps] });
                                (d[\mod].notNil).if({ ~matColorDefs[vi][ci + 1][\mod] = d[\mod] });
                                (d[\pose].notNil and: { d[\pose].isArray }).if({ ~matColorDefs[vi][ci + 1][\pose] = d[\pose] });
                            })
                        }
                    })
                }
            });
            // migrate legacy per-voice mods -> all colors; poseBindings -> their color
            ((raw.isArray.not) and: { raw[\mods].notNil }).if({
                raw[\mods].do { |m, vi|
                    (m != \none and: { m.isArray and: { m.size == 3 } and: { vi < ~matVoices.size } }).if({
                        (1..6).do { |c| (~matColorDefs[vi][c][\mod].isNil).if({ ~matColorDefs[vi][c][\mod] = (source: m[0], target: m[1], depth: m[2]) }) }
                    })
                }
            });
            ((raw.isArray.not) and: { raw[\poseBindings].notNil }).if({
                raw[\poseBindings].do { |list, vi|
                    (list.isArray and: { vi < ~matVoices.size }).if({
                        list.do { |b| (b.isArray and: { b.size == 3 }).if({
                            var c = b[2].asInteger.clip(1, 6);
                            (~matColorDefs[vi][c][\pose].isEmpty).if({ ~matColorDefs[vi][c][\pose] = ~matColorDefs[vi][c][\pose] ++ [ (poseId: b[0], action: b[1]) ] })
                        }) }
                    })
                }
            });
            // -- voice-level mods/poses: reset, restore new format, then migrate legacy --
            ~matVoices.do { |name| ~matVoiceMods[name] = []; ~matVoicePoses[name] = [] };
            ((raw.isArray.not) and: { raw[\voiceMods].notNil }).if({
                raw[\voiceMods].do { |list, vi| (list.isArray and: { vi < ~matVoices.size }).if({
                    ~matVoiceMods[~matVoices[vi]] = list.select({ |m| m.isKindOf(Event) and: { m[\source].notNil } })
                }) }
            });
            ((raw.isArray.not) and: { raw[\voicePoses].notNil }).if({
                raw[\voicePoses].do { |list, vi| (list.isArray and: { vi < ~matVoices.size }).if({
                    ~matVoicePoses[~matVoices[vi]] = list.select({ |b| b.isKindOf(Event) and: { b[\poseId].notNil } })
                }) }
            });
            // legacy: collapse per-colour \mod/\pose into voice lists (dedup) when new keys absent
            (raw.isArray.not).if({
                ~matVoices.do { |name, vi|
                    (~matVoiceMods[name].isEmpty).if({
                        var seen = [], acc = [];
                        (1..6).do { |c| var m = ~matColorDefs[vi][c][\mod];
                            (m.notNil and: { seen.includes(m[\target]).not }).if({
                                seen = seen.add(m[\target]);
                                acc = acc.add((source: m[\source], target: m[\target], depth: m[\depth])) }) };
                        ~matVoiceMods[name] = acc;
                    });
                    (~matVoicePoses[name].isEmpty).if({
                        var acc = [];
                        (1..6).do { |c| ((~matColorDefs[vi][c][\pose]) ? []).do { |b|
                            (acc.any({ |x| (x[\poseId] == b[\poseId]) and: { x[\action] == b[\action] } }).not).if({
                                acc = acc.add((poseId: b[\poseId], action: b[\action])) }) } };
                        ~matVoicePoses[name] = acc;
                    });
                }
            });
            // restore global morceau actions (default when absent/legacy)
            ~matGlobalActions = [\fill, \drop, \breakdown, \evolve, \muteDrums, \muteMelo, \washReverb, \next];
            ((raw.isArray.not) and: { raw[\globalActions].notNil and: { raw[\globalActions].isArray } }).if({
                raw[\globalActions].do { |s, i| (i < 8 and: { s.notNil }).if({ ~matGlobalActions[i] = s.asSymbol }) }
            });
            // restore global settings (default when absent/legacy)
            ~matGlobalSettings = ( transientBars: 1, breakdownKeep: [\kick, \sub] );
            ((raw.isArray.not) and: { raw[\globalSettings].notNil and: { raw[\globalSettings].isKindOf(Event) } }).if({
                var g = raw[\globalSettings];
                g[\transientBars].notNil.if({ ~matGlobalSettings[\transientBars] = g[\transientBars].asInteger });
                (g[\breakdownKeep].notNil and: { g[\breakdownKeep].isArray }).if({
                    ~matGlobalSettings[\breakdownKeep] = g[\breakdownKeep].collect({ |v| v.asSymbol }) });
            });
            ~lp[\matPlaying].if({ ~matApplyBar.(~lp[\matBar]) });
            ~matGridPush.();
            ~matInstrPush.();
            ~matVoices.size.do { |vi| ~matColorDefPush.(vi) };
            ~matVoices.size.do { |vi| (1..6).do { |c| ~matStepsPush.(vi, c) } };
            ~matVoices.size.do { |vi| ~matVoiceModPush.(vi); ~matVoicePosePush.(vi) };
            ~matEvolvePush.();
            ~matGlobalActionsPush.();
            ~matGlobalSettingsPush.();
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
    ~matCurrentName = safe.asSymbol;
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

// -- ~matSetVoiceMod : replace a voice's whole additive binding list; validate; re-source; echo --
~matSetVoiceMod = { |vi, n, tail|
    ((vi >= 0) and: { vi < ~matVoices.size }).if({
        var name = ~matVoices[vi];
        var allowed = ~matModTargets[name] ? [];
        ~matVoiceMods[name] = Array.fill(n.asInteger, { |k|
            var s = (tail[k * 3]       ? \none).asSymbol;
            var t = (tail[(k * 3) + 1] ? \none).asSymbol;
            var d = (tail[(k * 3) + 2] ? 0).asFloat.clip(0, 1);
            ((s != \none) and: { t != \none }
                and: { ~matModSources.includes(s) } and: { allowed.includes(t) }).if(
                { (source: s, target: t, depth: d) }, { nil })
        }).reject({ |x| x.isNil });
        ~matLastColor[vi] = -1;
        (~lp[\matPlaying] and: { ~matApplyBar.notNil }).if({ ~matApplyBar.(~lp[\matBar]) });
        ~matVoiceModPush.(vi)
    })
};

// -- ~matVoiceModPush : echo a voice's binding list to surfaces --
~matVoiceModPush = { |vi|
    ~toscSend !? {
        ((vi >= 0) and: { vi < ~matVoices.size }).if({
            var list = ~matVoiceMods[~matVoices[vi]] ? [];
            var flat = list.collect({ |m| [m[\source], m[\target], m[\depth]] }).flatten;
            ~toscSend.valueArray(["/matrix/voicemod", vi, list.size] ++ flat)
        })
    }
};

OSCdef(\mat_voicemod, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetVoiceMod.((msg[1] ? 0).asInteger, (msg[2] ? 0).asInteger, msg.copyToEnd(3))
}, '/matrix/voicemod');
OSCdef(\mat_voicemod_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matVoiceModPush.((msg[1] ? 0).asInteger)
}, '/matrix/voicemod/get');
OSCdef(\mat_voicepose, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetVoicePose.((msg[1] ? 0).asInteger, (msg[2] ? 0).asInteger, msg.copyToEnd(3))
}, '/matrix/voicepose');
OSCdef(\mat_voicepose_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matVoicePosePush.((msg[1] ? 0).asInteger)
}, '/matrix/voicepose/get');

// -- ~matPoseFire : run every per-voice binding matching poseId across all voices --
// \trigger re-sources the voice to its current bar color; \gate toggles the voice's Pdef.
// Unknown poseId -> no-op (no raise).
~matPoseFire = { |poseId|
    var pid = poseId.asSymbol;
    ~matVoices.do { |name, vi|
        var key = ("lp_" ++ name).asSymbol;
        ((~matVoicePoses[name]) ? []).do { |b|
            (b[\poseId] == pid).if({
                var bar   = ~lp[\matBar] ? 0;
                var color = (~lp[\matrix][vi][bar] ? 0);
                color = (color == 0).if({ 1 }, { color });
                (b[\action] == \trigger).if({
                    Pdef.all.includesKey(key).if({
                        var pat = ~matVariation.(name, color, vi);
                        pat.notNil.if({ Pdef(key, pat); Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) })
                    })
                });
                (b[\action] == \gate).if({
                    Pdef.all.includesKey(key).if({ Pdef(key).isPlaying.if({ Pdef(key).stop },
                        { Pdef(key).play(~lp[\clock] ? TempoClock.default, quant: 1) }) })
                });
            })
        }
    }
};

// -- ~matSetVoicePose : replace a voice's pose binding list; echo --
~matSetVoicePose = { |vi, n, tail|
    ((vi >= 0) and: { vi < ~matVoices.size }).if({
        ~matVoicePoses[~matVoices[vi]] = Array.fill(n.asInteger, { |k|
            var pid = (tail[k * 2]       ? \none).asSymbol;
            var act = (tail[(k * 2) + 1] ? \trigger).asSymbol;
            ((pid == \none) or: { pid == '' }).if({ nil }, { (poseId: pid, action: act) })
        }).reject({ |x| x.isNil });
        ~matVoicePosePush.(vi)
    })
};

~matVoicePosePush = { |vi|
    ~toscSend !? {
        ((vi >= 0) and: { vi < ~matVoices.size }).if({
            var list = ~matVoicePoses[~matVoices[vi]] ? [];
            var flat = list.collect({ |b| [b[\poseId], b[\action]] }).flatten;
            ~toscSend.valueArray(["/matrix/voicepose", vi, list.size] ++ flat)
        })
    }
};

// canonical event -> poseId mappers (hand 0=L, 1=R; finger strikes 1..5, pinch 1..4)
~matEventFinger = { |hand, finger| ("finger" ++ (hand.asInteger == 0).if({ "L" }, { "R" }) ++ (finger.asInteger + 1)).asSymbol };
~matEventPinch  = { |hand, finger| ("pinch"  ++ (hand.asInteger == 0).if({ "L" }, { "R" }) ++ finger.asInteger).asSymbol };

OSCdef(\mat_ev_finger, { |msg| ~matPoseFire.(~matEventFinger.(msg[2] ? 0, msg[3] ? 0)) }, '/pose/finger');
OSCdef(\mat_ev_pinch, { |msg|
    var hand = (msg[2] ? 0).asInteger;
    var finger = (msg[3] ? 1).asInteger;
    ~matPoseFire.(~matEventPinch.(hand, finger));          // per-voice pinch bindings (unchanged)
    ~matFireGlobal.((hand * 4) + (finger - 1));            // global action by pinch slot 0..7
}, '/pose/pinch');

OSCdef(\mat_pose, { |msg, time, addr|
    ~matPoseFire.((msg[1] ? \none).asSymbol)
}, '/matrix/pose');

// -- OSCdefs (unique \mat_* keys; register sender for TouchOSC feedback) --
OSCdef(\mat_cell, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetCell.(msg[1].asInteger, msg[2].asInteger, msg[3].asInteger)
}, '/matrix/cell');

OSCdef(\mat_play, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matPlay.()
}, '/matrix/play');

OSCdef(\mat_evolve, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetEvolve.((msg[1] ? 0).asInteger > 0)
}, '/matrix/evolve');

OSCdef(\mat_evolverate, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matEvolveRate = (msg[1] ? 0.15).asFloat.clip(0, 1);
    ~matEvolvePush.()
}, '/matrix/evolverate');

OSCdef(\mat_globalaction, { |msg, time, addr|
    var slot = (msg[1] ? 0).asInteger;
    var sym  = (msg[2] ? \none).asSymbol;
    ~toscTouch !? { ~toscTouch.(addr) };
    (slot >= 0 and: { slot < 8 }).if({
        ~matGlobalActions[slot] = sym;
        ~toscSend !? { ~toscSend.("/matrix/globalaction", slot, sym.asString) };
    })
}, '/matrix/globalaction');
OSCdef(\mat_globalaction_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matGlobalActionsPush.()
}, '/matrix/globalaction/get');
OSCdef(\mat_globalsettings, { |msg, time, addr|
    var tb = (msg[1] ? 1).asInteger.clip(1, 8);
    var keepN = (msg[2] ? 0).asInteger.clip(0, 22);
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matGlobalSettings[\transientBars] = tb;
    (keepN > 0).if({
        ~matGlobalSettings[\breakdownKeep] = (0..(keepN - 1)).collect({ |k| (msg[3 + k] ? \kick).asSymbol })
    });
    ~matGlobalSettingsPush.()
}, '/matrix/globalsettings');
OSCdef(\mat_globalsettings_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matGlobalSettingsPush.()
}, '/matrix/globalsettings/get');
OSCdef(\mat_bpm, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matSetBpm.((msg[1] ? 120))
}, '/matrix/bpm');
OSCdef(\mat_bpm_get, { |msg, time, addr|
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matBpmPush.()
}, '/matrix/bpm/get');

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
    var name = msg[1].asString;
    ~toscTouch !? { ~toscTouch.(addr) };
    ~matLoad.(name);
    ~toscSend !? { ~toscSend.("/matrix/loaded", name) };       // web: track loaded name
}, '/matrix/load');

OSCdef(\mat_loadnext, { |msg, time, addr|
    var name = msg[1].asString;
    ~toscTouch !? { ~toscTouch.(addr) };
    ~lp[\matPlaying].if({
        ~matQueuedLoad = name;                                  // armed: swaps at next wrap
        ~toscSend !? { ~toscSend.("/matrix/queued", name) };
    }, {
        ~matLoad.(name);                                        // not playing -> load now
        ~toscSend !? { ~toscSend.("/matrix/loaded", name) };
        ~toscSend !? { ~toscSend.("/matrix/queued", "") };
    });
}, '/matrix/loadnext');

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
~matModCache   = ~matModCache   ? IdentityDictionary.new;
~matVoiceMods  = ~matVoiceMods  ? IdentityDictionary.new;   // voice -> [ (source:,target:,depth:) ]
~matVoicePoses = ~matVoicePoses ? IdentityDictionary.new;   // voice -> [ (poseId:,action:) ]
~matModSources = ~matModSources ?
    [\lHandY, \rHandY, \lHandX, \rHandX, \lOpen, \rOpen, \handSpeed, \handDist,
     \bodyX, \bodyY, \depth,
     \bodyVitesse, \bodyAccel, \bodySym, \headX, \headY, \limbSpan, \danse, \mouthOpen];

// Fixed wire order for /matrix/modvalues (mirrors web MOD_SOURCE_ORDER). No \none.
~matModOrder = [
    \lHandY, \rHandY, \lHandX, \rHandX, \lOpen, \rOpen, \handSpeed, \handDist,
    \bodyX, \bodyY, \depth, \bodyVitesse, \bodyAccel, \bodySym, \headX, \headY,
    \limbSpan, \danse, \mouthOpen];

// Normalization for raw iPhone units -> 0..1 (env-tunable, no code edit to retune).
~matKinSpeedMax  = ~matKinSpeedMax  ? 3.0;    // m/s mapped to 1.0
~matKinAccelMax  = ~matKinAccelMax  ? 10.0;   // m/s^2 mapped to 1.0
~matLimbSpanGain = ~matLimbSpanGain ? 1.0;    // limb span scale

// Sources whose neutral/rest value is centre (0.5): positions + symmetry.
// All other sources (magnitudes: speed, accel, openness, span, danse, depth,
// mouth) correctly rest at 0.
~matModRest = ~matModRest ? IdentityDictionary[
    \lHandX -> 0.5, \lHandY -> 0.5, \rHandX -> 0.5, \rHandY -> 0.5,
    \bodyX -> 0.5, \bodyY -> 0.5, \headX -> 0.5, \headY -> 0.5, \bodySym -> 0.5
];
// reader: clamp to 0..1, use per-source rest value when absent from cache
~matModSourceVal = { |key| (~matModCache[key] ? (~matModRest[key] ? 0)).clip(0, 1) };

// +/- scale-degree offset at full deflection (env-tunable; 7 ~= 1 diatonic octave)
~matPitchRange = ~matPitchRange ? 7;
// bipolar additive sum of \pitch bindings -> integer degree offset applied in the freq Pfunc
~matPitchOffset = { |name|
    var off = 0;
    ((~matVoiceMods[name] ? []).select { |b| b[\target] == \pitch }).do { |b|
        off = off + (((~matModSourceVal.(b[\source]) * 2 - 1) * b[\depth] * ~matPitchRange).round.asInteger)
    };
    off
};

// -- Live modvalues push (~12 Hz) --
~matModValuesPush = {
    ~toscSend !? {
        ~toscSend.valueArray(["/matrix/modvalues"]
            ++ ~matModOrder.collect({ |k| (~matModCache[k] ? (~matModRest[k] ? 0)).clip(0, 1) }))
    }
};
~matModValuesRoutine !? { ~matModValuesRoutine.stop };
~matModValuesRoutine = Routine({ loop { ~matModValuesPush.(); (1/12).wait } }).play(AppClock);

// own capture listeners (independent of the pose pipeline's internal dicts)
OSCdef(\mat_mod_hands, { |msg|
    ~matModCache[\lHandY]    = 1 - (msg[3] ? 0.5);   // image y top-down -> up=1
    ~matModCache[\rHandY]    = 1 - (msg[7] ? 0.5);
    ~matModCache[\lHandX]    = msg[2] ? 0.5;          // image x left->right
    ~matModCache[\rHandX]    = msg[6] ? 0.5;
    ~matModCache[\lOpen]     = msg[4] ? 0;
    ~matModCache[\rOpen]     = msg[8] ? 0;
    ~matModCache[\handSpeed] = ((msg[5] ? 0) max: (msg[9] ? 0));
    ~matModCache[\handDist]  = msg[10] ? 0;
}, '/pose/hands');

OSCdef(\mat_mod_center, { |msg|
    ~matModCache[\bodyX] = msg[2] ? 0.5;             // /pose/center [pid, cx, cy]
    ~matModCache[\bodyY] = 1 - (msg[3] ? 0.5);
}, '/pose/center');

OSCdef(\mat_mod_span, { |msg|
    ~matModCache[\depth] = ((msg[2] ? 0) * 2.5).clip(0, 1);  // /pose/sho_span depth proxy
}, '/pose/sho_span');

OSCdef(\mat_mod_kin, { |msg|
    // /pose/kin [pid, speed, accel, sym]
    ~matModCache[\bodyVitesse] = ((msg[2] ? 0) / ~matKinSpeedMax).clip(0, 1);
    ~matModCache[\bodyAccel]   = ((msg[3] ? 0) / ~matKinAccelMax).clip(0, 1);
    ~matModCache[\bodySym]     = (((msg[4] ? 0) + 1) / 2).clip(0, 1);
}, '/pose/kin');

OSCdef(\mat_mod_head, { |msg|
    // /pose/head [pid, x, y, c]
    ~matModCache[\headX] = (msg[2] ? 0.5).clip(0, 1);
    ~matModCache[\headY] = (1 - (msg[3] ? 0.5)).clip(0, 1);
}, '/pose/head');

OSCdef(\mat_mod_limb, { |msg|
    // /pose/limb_span [pid, span]
    ~matModCache[\limbSpan] = ((msg[2] ? 0) * ~matLimbSpanGain).clip(0, 1);
}, '/pose/limb_span');

OSCdef(\mat_mod_mouth, { |msg|
    // /pose/mouth [pid, open]
    ~matModCache[\mouthOpen] = (msg[2] ? 0).clip(0, 1);
}, '/pose/mouth');

~matActionLabels = ~matActionLabels ? [\debout, \assise, \danse];
~matLastAction   = ~matLastAction   ? IdentityDictionary.new;
OSCdef(\mat_mod_action, { |msg|
    // /pose/action [pid, idx, p0, p1, p2] : danse proba feeds \danse; label change fires pose
    var pid = (msg[1] ? 0).asInteger;
    var idx = (msg[2] ? 0).asInteger.clip(0, 2);
    var lab = ~matActionLabels[idx];
    ~matModCache[\danse] = (msg[5] ? 0).clip(0, 1);
    (~matLastAction[pid] != lab).if({ ~matLastAction[pid] = lab; ~matPoseFire.(lab) });
}, '/pose/action');

"[matrix] ready".postln;
)
