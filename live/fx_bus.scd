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
SynthDef(\fxReverb, {
    arg in, out = 0, mix = 0.4, room = 0.85, damp = 0.4,
        freeze = 0, amp = 1.0;
    var sig = In.ar(in, 2);
    sig = FreeVerb2.ar(sig[0], sig[1],
        Select.kr(freeze, [mix, 1.0]),
        Select.kr(freeze, [room, 0.999]),
        Select.kr(freeze, [damp, 0.001]));
    Out.ar(out, sig * amp);
}).add;

// --- DELAY ping-pong avec saturation tape ---
SynthDef(\fxDelay, {
    arg in, out = 0, delayTime = 0.375, feedback = 0.5,
        mix = 0.5, color = 0.3, amp = 1.0;
    var dry, wet, l, r, fb;
    dry = In.ar(in, 2);
    fb = LocalIn.ar(2);                  // vrai feedback stereo
    l = DelayC.ar(fb[1] + dry[0], 2.0, delayTime) * feedback;   // ping
    r = DelayC.ar(fb[0] + dry[1], 2.0, delayTime) * feedback;   // pong
    // Color : LPF pour effet tape vintage
    l = LPF.ar(l, color.linexp(0, 1, 800, 16000));
    r = LPF.ar(r, color.linexp(0, 1, 800, 16000));
    LocalOut.ar([l, r]);
    wet = [l, r];
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// --- CHORUS (modulation stereo) ---
SynthDef(\fxChorus, {
    arg in, out = 0, rate = 0.4, depth = 0.005,
        mix = 0.5, amp = 1.0;
    var sig = In.ar(in, 2);
    var l = DelayC.ar(sig[0], 0.05, SinOsc.kr(rate, 0).range(0.005, 0.005 + depth));
    var r = DelayC.ar(sig[1], 0.05, SinOsc.kr(rate, pi).range(0.005, 0.005 + depth));
    var wet = [l, r];
    Out.ar(out, ((sig * (1 - mix)) + (wet * mix)) * amp);
}).add;

// --- PHASER (4-stage allpass + LFO) ---
SynthDef(\fxPhaser, {
    arg in, out = 0, rate = 0.3, depth = 0.7, feedback = 0.4,
        mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var lfo = SinOsc.kr(rate).range(200, 200 + (3000 * depth));
    var sig = AllpassN.ar(dry, 0.01, lfo.reciprocal, 0.05);
    sig = AllpassN.ar(sig, 0.01, (lfo * 1.3).reciprocal, 0.05);
    sig = AllpassN.ar(sig, 0.01, (lfo * 1.7).reciprocal, 0.05);
    sig = AllpassN.ar(sig + (LocalIn.ar(2) * feedback), 0.01, (lfo * 2.1).reciprocal, 0.05);
    LocalOut.ar(sig);
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;

// --- FLANGER (court delay + LFO + feedback) ---
SynthDef(\fxFlanger, {
    arg in, out = 0, rate = 0.2, depth = 0.003, feedback = 0.6,
        mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var lfo = SinOsc.kr(rate).range(0.0005, 0.0005 + depth);
    var fb = LocalIn.ar(2) * feedback;
    var sig = DelayC.ar(dry + fb, 0.02, lfo);
    LocalOut.ar(sig);
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;

// --- BITCRUSHER (lo-fi sample rate + bit depth) ---
SynthDef(\fxBitcrush, {
    arg in, out = 0, bits = 8, sampleRate = 8000,
        mix = 0.6, amp = 1.0;
    var dry = In.ar(in, 2);
    // Bit reduction native (sans Decimator de sc3-plugins)
    var step = 2.pow(bits - 1);
    var crushed = (dry * step).round / step;
    var sig = Latch.ar(crushed, Impulse.ar(sampleRate));
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;

// --- TAPE (saturation analog + wow/flutter) ---
SynthDef(\fxTape, {
    arg in, out = 0, drive = 1.5, wow = 0.0015, flutter = 0.0008,
        mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var modL = SinOsc.kr(0.3).range(0, wow) + LFNoise2.kr(8).range(0, flutter);
    var modR = SinOsc.kr(0.31).range(0, wow) + LFNoise2.kr(8).range(0, flutter);
    var sig = [DelayC.ar(dry[0], 0.02, 0.005 + modL),
               DelayC.ar(dry[1], 0.02, 0.005 + modR)];
    sig = (sig * drive).tanh / drive.sqrt;
    sig = LPF.ar(sig, 12000);   // EQ tape rolloff aigu
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;

// --- SHIMMER REVERB (octave up + reverb hall) ---
SynthDef(\fxShimmer, {
    arg in, out = 0, mix = 0.5, room = 0.92, shimmer = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var pitched = PitchShift.ar(dry, 0.2, 2, 0.01, 0.005) * shimmer;
    var sig = FreeVerb2.ar(dry[0] + pitched[0], dry[1] + pitched[1],
        1.0, room, 0.3);
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;

// --- DISTORTION (overdrive + tone) ---
SynthDef(\fxDist, {
    arg in, out = 0, drive = 3.0, tone = 0.5,
        mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var sig = (dry * drive).tanh;
    sig = (sig * 1.5).tanh;
    sig = MoogFF.ar(sig, tone.linexp(0, 1, 500, 12000), 1.5);
    Out.ar(out, ((dry * (1 - mix)) + (sig * mix)) * amp);
}).add;

// --- SEND (copie audio vers un FX bus, ratio reglable) ---
SynthDef(\fxSend, {
    arg srcBus = 0, dstBus, amount = 0.3;
    var sig = In.ar(srcBus, 2);
    Out.ar(dstBus, sig * amount);
}).add;

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
~fxPreset = { |name|
    switch (name,
        \dry, {
            [\rev,\dly,\chr,\phs,\flg,\crsh,\tape,\shim,\dist]
                .do { |k| ~send.(k, 0) };
            "preset DRY".postln;
        },
        \dub, {
            ~sendReverb.(0.5);  ~sendDelay.(0.6); ~sendTape.(0.7);
            ~setFx.(\dly, \delayTime, 0.5);
            ~setFx.(\dly, \feedback, 0.7);
            ~setFx.(\rev, \room, 0.92);
            "preset DUB (rev hall + delay long + tape)".postln;
        },
        \space, {
            ~sendReverb.(0.55); ~sendShimmer.(0.4); ~sendChorus.(0.3);
            ~setFx.(\rev, \room, 0.95);
            "preset SPACE (shimmer + reverb + chorus)".postln;
        },
        \trance, {
            ~sendReverb.(0.35); ~sendDelay.(0.4); ~sendChorus.(0.5);
            ~setFx.(\dly, \delayTime, 0.375);
            ~setFx.(\dly, \feedback, 0.5);
            "preset TRANCE (rev + delay 1/8 + chorus)".postln;
        },
        \dubstep, {
            ~sendReverb.(0.2);  ~sendDist.(0.3); ~sendBitcrush.(0.2);
            ~setFx.(\dist, \drive, 4); ~setFx.(\dist, \tone, 0.4);
            ~setFx.(\crsh, \bits, 6);
            "preset DUBSTEP (dist + bitcrush + reverb)".postln;
        },
        \retro, {
            ~sendBitcrush.(0.4); ~sendTape.(1.0); ~sendChorus.(0.4);
            ~setFx.(\crsh, \bits, 8); ~setFx.(\crsh, \sampleRate, 12000);
            ~setFx.(\tape, \drive, 1.8);
            "preset RETRO (bitcrush + tape + chorus)".postln;
        },
        \industrial, {
            ~sendDist.(0.6); ~sendFlanger.(0.4); ~sendBitcrush.(0.3);
            ~setFx.(\dist, \drive, 5);
            ~setFx.(\flg, \rate, 0.15); ~setFx.(\flg, \feedback, 0.7);
            "preset INDUSTRIAL (dist + flanger + bitcrush)".postln;
        },
        \dream, {
            ~sendShimmer.(0.6); ~sendReverb.(0.5); ~sendChorus.(0.4);
            ~setFx.(\shim, \shimmer, 0.7);
            "preset DREAM (shimmer + reverb + chorus)".postln;
        },
        \cosmic, {
            ~sendPhaser.(0.5); ~sendShimmer.(0.4); ~sendReverb.(0.4);
            ~lfo.(\phs, \rate, 0.05, 0.1, 0.8);
            "preset COSMIC (phaser LFO + shimmer + reverb)".postln;
        },
        \drone, {
            ~sendReverb.(0.7); ~sendShimmer.(0.5);
            ~setFx.(\rev, \freeze, 1); ~setFx.(\rev, \room, 0.99);
            "preset DRONE (reverb FROZEN + shimmer)".postln;
        }
    );
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
