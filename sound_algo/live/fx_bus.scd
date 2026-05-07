// =====================================================================
//  live/fx_bus.scd  --  Systeme FX live complet
//
//  9 bus FX : reverb / delay / chorus / phaser / flanger / bitcrush /
//             tape / shimmer / distortion
//  + helpers send / setFx
//  + automation LFO sur tout param
//  + presets / snapshots
//  + tap tempo pour delay
//  + freeze reverb (capture)
//  + crossfade entre FX
//
//  USAGE
//    1. SETUP FX -- charge SynthDefs + alloue les bus + lance les FX
//       en queue + cree les helpers (~send / ~lfo / ~fxPreset / ~tap /
//       ~crossfadeFx). Compatible .load (un seul bloc top-level).
//    2. Helpers ~sendXxx pour envoyer dans un FX (live)
//    3. Helpers ~lfoXxx pour automatiser un parametre (live)
//    4. Presets ~fxPreset.(\name) pour rappeler un combo (live)
// =====================================================================


// =====================================================================
//  1. SETUP FX (single-block) -- SynthDefs + bus + FX en queue + helpers
// =====================================================================
(
// --- BUS allocation ---
~fxBuses !? { ~fxBuses.do(_.free) };
~fxBuses = (
    rev:     Bus.audio(s, 2),
    dly:     Bus.audio(s, 2),
    chr:     Bus.audio(s, 2),
    phs:     Bus.audio(s, 2),
    flg:     Bus.audio(s, 2),
    crsh:    Bus.audio(s, 2),
    tape:    Bus.audio(s, 2),
    shim:    Bus.audio(s, 2),
    dist:    Bus.audio(s, 2),
);

// --- REVERB (FreeVerb stereo + freeze) ---


// --- DELAY ping-pong avec saturation tape ---


// --- CHORUS (modulation stereo) ---


// --- PHASER (4-stage allpass + LFO) ---


// --- FLANGER (court delay + LFO + feedback) ---


// --- BITCRUSHER (lo-fi sample rate + bit depth) ---


// --- TAPE (saturation analog + wow/flutter) ---


// --- SHIMMER REVERB (octave up + reverb hall) ---


// --- DISTORTION (overdrive + tone) ---


// --- SEND (copie audio vers un FX bus, ratio reglable) ---


s.sync;

// --- INSTANCIER les 9 FX en queue + master limiter ----------------
// .do sur Event : 1 arg = value. Le 2-arg form est |value, key| (synth d'abord).
~fxFx !? { ~fxFx.do { |syn| syn !? { syn.free } } };
~fxFx = (
    rev:  Synth.tail(s.defaultGroup, \fxReverb,  [\in, ~fxBuses[\rev].index]),
    dly:  Synth.tail(s.defaultGroup, \fxDelay,   [\in, ~fxBuses[\dly].index]),
    chr:  Synth.tail(s.defaultGroup, \fxChorus,  [\in, ~fxBuses[\chr].index]),
    phs:  Synth.tail(s.defaultGroup, \fxPhaser,  [\in, ~fxBuses[\phs].index]),
    flg:  Synth.tail(s.defaultGroup, \fxFlanger, [\in, ~fxBuses[\flg].index]),
    crsh: Synth.tail(s.defaultGroup, \fxBitcrush,[\in, ~fxBuses[\crsh].index]),
    tape: Synth.tail(s.defaultGroup, \fxTape,    [\in, ~fxBuses[\tape].index]),
    shim: Synth.tail(s.defaultGroup, \fxShimmer, [\in, ~fxBuses[\shim].index]),
    dist: Synth.tail(s.defaultGroup, \fxDist,    [\in, ~fxBuses[\dist].index, \mix, 0.5]),
);

// Master limiter en queue absolue
~masterLim !? { ~masterLim.free };
~masterLim = Synth.tail(s.defaultGroup, \masterLim);

~fxSends = ();   // dictionnaire des Synth de send actifs
~fxLfos  = ();   // dictionnaire des Routines LFO actives

// ---------- HELPERS SEND ---------------------------------------------
~send = { |fxName, amount = 0.3|
    var key = fxName.asSymbol;
    ~fxSends[key] !? { ~fxSends[key].free };
    if (amount > 0) {
        ~fxSends[key] = Synth.before(~masterLim, \fxSend,
            [\srcBus, 0, \dstBus, ~fxBuses[key].index, \amount, amount]);
    } { ~fxSends.removeAt(key) };
    ("send " ++ key ++ " = " ++ amount).postln;
};

// Raccourcis
~sendReverb    = { |a = 0.3| ~send.(\rev,  a) };
~sendDelay     = { |a = 0.3| ~send.(\dly,  a) };
~sendChorus    = { |a = 0.3| ~send.(\chr,  a) };
~sendPhaser    = { |a = 0.3| ~send.(\phs,  a) };
~sendFlanger   = { |a = 0.3| ~send.(\flg,  a) };
~sendBitcrush  = { |a = 0.3| ~send.(\crsh, a) };
~sendTape      = { |a = 1.0| ~send.(\tape, a) };
~sendShimmer   = { |a = 0.3| ~send.(\shim, a) };
~sendDist      = { |a = 0.3| ~send.(\dist, a) };

// Set un parametre de FX (~setFx.(\rev, \room, 0.95))
~setFx = { |fxName, param, value|
    ~fxFx[fxName.asSymbol] !? { ~fxFx[fxName.asSymbol].set(param, value) };
};

// ---------- AUTOMATION LFO -------------------------------------------
~lfo = { |fxName, param, rateHz = 0.5, lo = 0.0, hi = 1.0, shape = \sin|
    var key = (fxName ++ "_" ++ param).asSymbol;
    ~fxLfos[key] !? { ~fxLfos[key].stop };
    ~fxLfos[key] = Routine({
        var phase = 0;
        inf.do { |i|
            var x;
            x = switch (shape,
                \sin,  { (phase * 2 * pi).sin * 0.5 + 0.5 },
                \tri,  { (phase * 4 - 1).abs.linlin(0, 1, 1, 0) },
                \saw,  { phase },
                \sqr,  { if (phase < 0.5) {0} {1} },
                \rand, { 1.0.rand }
            );
            ~setFx.(fxName, param, lo + (x * (hi - lo)));
            phase = (phase + (rateHz * 0.05)).mod(1);
            0.05.wait;
        };
    }).play;
    ("LFO " ++ fxName ++ "." ++ param ++ " " ++ rateHz ++ "Hz " ++ shape).postln;
};

~lfoStop = { |fxName, param|
    var key = (fxName ++ "_" ++ param).asSymbol;
    ~fxLfos[key] !? { ~fxLfos[key].stop; ~fxLfos.removeAt(key) };
    ("LFO " ++ fxName ++ "." ++ param ++ " STOPPED").postln;
};

~lfoStopAll = {
    ~fxLfos.do { |r| r.stop }; ~fxLfos = ();
    "all LFOs stopped".postln;
};

// ---------- TAP TEMPO pour le delay ----------------------------------
~tapTempo = ();
~tap = {
    var now = SystemClock.seconds;
    ~tapTempo[\last] !? { |last|
        var interval = now - last;
        if (interval < 2.0 and: { interval > 0.1 }) {
            ~setFx.(\dly, \delayTime, interval);
            ("TAP : " ++ interval.round(0.001) ++ "s = " ++
                (60 / interval).round(0.1) ++ " BPM").postln;
        };
    };
    ~tapTempo[\last] = now;
};

// ---------- CROSSFADE entre 2 FX -------------------------------------
~crossfadeFxRoutine = ~crossfadeFxRoutine ?? { nil };
~crossfadeFx = { |fromFx, toFx, dur = 4|
    ~crossfadeFxRoutine !? { ~crossfadeFxRoutine.stop };
    ~crossfadeFxRoutine = Routine({
        var steps = (dur * 20).asInteger;
        steps.do { |i|
            var x = (i + 1) / steps;
            ~send.(fromFx, 0.3 * (1 - x));
            ~send.(toFx,   0.3 * x);
            (dur / steps).wait;
        };
        ~crossfadeFxRoutine = nil;
    }).play;
    ("crossfade " ++ fromFx ++ " -> " ++ toFx ++ " sur " ++ dur ++ "s").postln;
};
~crossfadeFxStop = {
    ~crossfadeFxRoutine !? { ~crossfadeFxRoutine.stop; ~crossfadeFxRoutine = nil };
    "crossfade stopped".postln;
};

// ---------- PRESETS FX (combos pret a l'emploi par genre) ------------
//
// REVERT : ~fxPresetReset retiree car cause une fuite/crash explosive
// sclang quand combinee avec switch+sub-calls. La cascade des sends
// reste un probleme connu mais geree par ~ff.(\dry) explicit reset.
~fxPresetReset = nil;

// Dispatch via dictionary pour eviter le bug de switch() qui crashe sclang
// avec 11 cases sur certaines versions SC.
~fxPresetTable = (
    dry: {
        [\rev,\dly,\chr,\phs,\flg,\crsh,\tape,\shim,\dist]
            .do { |k| ~send.(k, 0) };
        "preset DRY".postln;
    },
    dub: {
        ~sendReverb.(0.5);  ~sendDelay.(0.6); ~sendTape.(0.7);
        ~setFx.(\dly, \delayTime, 0.5);
        ~setFx.(\dly, \feedback, 0.7);
        ~setFx.(\rev, \room, 0.92);
        "preset DUB (rev hall + delay long + tape)".postln;
    },
    space: {
        ~sendReverb.(0.55); ~sendShimmer.(0.4); ~sendChorus.(0.3);
        ~setFx.(\rev, \room, 0.95);
        "preset SPACE (shimmer + reverb + chorus)".postln;
    },
    trance: {
        ~sendReverb.(0.35); ~sendDelay.(0.4); ~sendChorus.(0.5);
        ~setFx.(\dly, \delayTime, 0.375);
        ~setFx.(\dly, \feedback, 0.5);
        "preset TRANCE (rev + delay 1/8 + chorus)".postln;
    },
    dubstep: {
        ~sendReverb.(0.2);  ~sendDist.(0.3); ~sendBitcrush.(0.2);
        ~setFx.(\dist, \drive, 4); ~setFx.(\dist, \tone, 0.4);
        ~setFx.(\crsh, \bits, 6);
        "preset DUBSTEP (dist + bitcrush + reverb)".postln;
    },
    retro: {
        ~sendBitcrush.(0.4); ~sendTape.(1.0); ~sendChorus.(0.4);
        ~setFx.(\crsh, \bits, 8); ~setFx.(\crsh, \sampleRate, 12000);
        ~setFx.(\tape, \drive, 1.8);
        "preset RETRO (bitcrush + tape + chorus)".postln;
    },
    industrial: {
        ~sendDist.(0.6); ~sendFlanger.(0.4); ~sendBitcrush.(0.3);
        ~setFx.(\dist, \drive, 5);
        ~setFx.(\flg, \rate, 0.15); ~setFx.(\flg, \feedback, 0.7);
        "preset INDUSTRIAL (dist + flanger + bitcrush)".postln;
    },
    dream: {
        ~sendShimmer.(0.6); ~sendReverb.(0.5); ~sendChorus.(0.4);
        ~setFx.(\shim, \shimmer, 0.7);
        "preset DREAM (shimmer + reverb + chorus)".postln;
    },
    cosmic: {
        ~sendPhaser.(0.5); ~sendShimmer.(0.4); ~sendReverb.(0.4);
        ~lfo.(\phs, \rate, 0.05, 0.1, 0.8);
        "preset COSMIC (phaser LFO + shimmer + reverb)".postln;
    },
    drone: {
        ~sendReverb.(0.7); ~sendShimmer.(0.5);
        ~setFx.(\rev, \freeze, 1); ~setFx.(\rev, \room, 0.99);
        "preset DRONE (reverb FROZEN + shimmer)".postln;
    }
);

~fxPreset = { |name|
    var fn = ~fxPresetTable[name.asSymbol];
    if (fn.notNil) { fn.value } { ("!! preset " ++ name ++ " inconnu").postln };
};

"=== 9 FX BUSES + master limiter en queue ===".postln;
"   bus dispos : rev / dly / chr / phs / flg / crsh / tape / shim / dist".postln;
"=== ~send / ~sendReverb / ~setFx / ~lfo / ~tap / ~crossfadeFx / ~fxPreset prets ===".postln;
"=== presets : dry / dub / space / trance / dubstep / retro / industrial / dream / cosmic / drone ===".postln;
)


// =====================================================================
//  2. EXEMPLES / TWEAKS LIVE -- Cmd+Entree sur ligne pendant track
//     (tout ce qui est en bas est interactif et NON .load -- garde
//      du multi-bloc pour evaluer un effet a la fois)
// =====================================================================

// --- Send levels ----------------------------------------------------
( ~sendReverb.(0.4); ~sendDelay.(0.3); )
( ~sendReverb.(0); ~sendDelay.(0); ~sendChorus.(0); )
( ~sendShimmer.(0.5); ~setFx.(\shim, \shimmer, 0.7); )
( ~sendBitcrush.(0.5); ~setFx.(\crsh, \bits, 4); )
( ~sendDist.(0.5); ~setFx.(\dist, \drive, 4); ~setFx.(\dist, \tone, 0.3); )
( ~sendFlanger.(0.5); ~setFx.(\flg, \rate, 0.15); )
( ~sendPhaser.(0.4); ~setFx.(\phs, \rate, 0.2); ~setFx.(\phs, \depth, 0.8); )
( ~sendTape.(1.0); ~setFx.(\tape, \drive, 2.5); )

// --- Tempo synced delay ---------------------------------------------
( ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo / 4); ) // 1/16
( ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo / 2); ) // 1/8
( ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo); )    // 1/4
( ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo * 0.75); ) // 1/4 dotted

// --- Reverb size ----------------------------------------------------
( ~setFx.(\rev, \room, 0.5); ~setFx.(\rev, \damp, 0.6); ) // room
( ~setFx.(\rev, \room, 0.85);~setFx.(\rev, \damp, 0.4); ) // hall
( ~setFx.(\rev, \room, 0.97);~setFx.(\rev, \damp, 0.1); ) // cathedral

// --- LFO automation -------------------------------------------------
( ~lfo.(\dly, \feedback, 0.1, 0.2, 0.85, \sin); )         // feedback qui pulse
( ~lfo.(\rev, \mix, 0.05, 0.1, 0.7, \tri); )              // wash de reverb
( ~lfo.(\crsh, \bits, 0.2, 4, 12, \sqr); )                // glitch lo-fi
( ~lfo.(\phs, \rate, 0.02, 0.1, 1.5, \sin); )             // phaser qui accelere
( ~lfo.(\shim, \shimmer, 0.1, 0.2, 0.8, \rand); )         // shimmer chaos
( ~lfoStopAll.value; )

// --- Tap tempo (au moins 2 fois pour calibrer) ---------------------
( ~tap.value; )

// --- Freeze reverb (drone infini) -----------------------------------
( ~setFx.(\rev, \freeze, 1); ~sendReverb.(0.6); )
( ~setFx.(\rev, \freeze, 0); )

// --- Crossfade entre FX --------------------------------------------
( ~crossfadeFx.(\dly, \rev, 8); )    // delay -> reverb sur 8s
( ~crossfadeFx.(\dist, \shim, 4); )  // dist -> shimmer sur 4s

// --- Presets --------------------------------------------------------
( ~fxPreset.(\dry); )         // tout off
( ~fxPreset.(\dub); )          // dub techno
( ~fxPreset.(\trance); )       // uplifting trance
( ~fxPreset.(\dubstep); )      // dubstep dirty
( ~fxPreset.(\space); )        // space ambient
( ~fxPreset.(\retro); )        // 80s lo-fi
( ~fxPreset.(\industrial); )   // hard distorted
( ~fxPreset.(\dream); )        // dream pop
( ~fxPreset.(\cosmic); )       // psy cosmic + LFO phaser
( ~fxPreset.(\drone); )        // drone freeze infini


// =====================================================================
//  3. STOP FX -- libere tout
// =====================================================================
(
~lfoStopAll.value;
~fxSends.do { |s| s.free }; ~fxSends = ();
~fxFx.do { |s| s.free }; ~fxFx = ();
~fxBuses.do { |b| b.free }; ~fxBuses = ();
"=== ALL FX STOPPED ===".postln;
)
