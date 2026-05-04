// =====================================================================
//  live.scd  --  Boite a outils live performance
//
//  Ce fichier ajoute par-dessus engine.scd + fx_bus.scd + tweaks.scd :
//
//    1. LFO assignables sur N'IMPORTE QUELLE variable globale (~xxx)
//    2. Envelopes one-shot assignables (attack/sustain/release, sweep, burst)
//    3. VCF master inseres en chaine (moog / ms20 / ladder / formant /
//       comb / hpf / bpf / notch) avec presets et sweep auto
//    4. Tricks sceniques live : stutter, choke, drop, handsUp, breakdown,
//       buildup, tapeStop, glitch, freeze, reverbTail, tapeReverse,
//       swap (crossfade scenes), jumpCut
//    5. Sidechain dynamique entre N'IMPORTE QUELLE source et cible
//    6. Stuttering / glitch / pitch : slipTime, bitCrushNow, ringMod,
//       freqShift, granFreeze, scratch, repeat
//    7. Auto-pan / tremolo / autopan par voix
//    8. FX additionnels (12 nouveaux SynthDef)
//    9. Master compresseur / saturation switchable
//
//  PREREQUIS : engine.scd evalue + live/fx_bus.scd evalue + serveur boote.
//  USAGE     : `(~base ++ "live/live.scd").load` puis Cmd+Entree sur les
//              exemples en commentaire en bas.
//
//  Convention : helpers exposes en variables d'environnement ~xxx
//              + UN SEUL bloc top-level (compatible .load)
// =====================================================================

(

// =====================================================================
//  0. SYNTHDEFS additionnels
// =====================================================================

// --- VCF Moog (filtre 4-pole, MoogFF) ---------------------------------
SynthDef(\vcfMoog, {
    arg busIn = 0, freq = 1500, gain = 2.0, mix = 1.0, drive = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = MoogFF.ar(sig * drive, freq.clip(40, 18000), gain.clip(0, 4));
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- VCF MS20 (Sallen-Key style, agressif) ----------------------------
SynthDef(\vcfMs20, {
    arg busIn = 0, freq = 1500, q = 1.5, mix = 1.0, drive = 1.2;
    var sig = In.ar(busIn, 2);
    var wet = (sig * drive).tanh;
    wet = RLPF.ar(wet, freq.clip(40, 18000), q.reciprocal.clip(0.05, 1.5));
    wet = (wet * 1.3).tanh;
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- VCF Ladder (24 dB/oct vintage) -----------------------------------
SynthDef(\vcfLadder, {
    arg busIn = 0, freq = 1500, q = 1.0, mix = 1.0, drive = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = LPF.ar(LPF.ar(sig * drive, freq), freq);
    wet = wet + (RHPF.ar(wet, freq, q.reciprocal.clip(0.1, 2)) * (q * 0.3));
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- VCF Formant (voyelles a/e/i/o/u) ---------------------------------
// vowel : 0=a 1=e 2=i 3=o 4=u, mix entre crossfade
SynthDef(\vcfFormant, {
    arg busIn = 0, vowel = 0, q = 0.15, mix = 1.0;
    var sig = In.ar(busIn, 2);
    var f1 = Select.kr(vowel, [800, 400, 350, 450, 325]);
    var f2 = Select.kr(vowel, [1150, 1700, 1900, 800, 700]);
    var f3 = Select.kr(vowel, [2900, 2600, 2500, 2830, 2530]);
    var wet = BPF.ar(sig, f1, q) * 1.0
            + BPF.ar(sig, f2, q) * 0.7
            + BPF.ar(sig, f3, q) * 0.4;
    wet = wet * 1.5;
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- VCF Comb (resonator) ---------------------------------------------
SynthDef(\vcfComb, {
    arg busIn = 0, freq = 220, decay = 1.0, mix = 0.6;
    var sig = In.ar(busIn, 2);
    var wet = CombC.ar(sig, 0.05, freq.reciprocal.clip(0.0001, 0.05), decay);
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- VCF HPF resonant -------------------------------------------------
SynthDef(\vcfHpf, {
    arg busIn = 0, freq = 200, q = 0.5, mix = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = RHPF.ar(sig, freq.clip(20, 18000), q.clip(0.05, 2));
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- VCF BPF resonant -------------------------------------------------
SynthDef(\vcfBpf, {
    arg busIn = 0, freq = 1000, q = 0.3, mix = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = BPF.ar(sig, freq.clip(40, 18000), q.clip(0.05, 2)) * 1.5;
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- VCF Notch (sweepable, supprime une bande) ------------------------
SynthDef(\vcfNotch, {
    arg busIn = 0, freq = 1000, q = 0.3, mix = 1.0;
    var sig = In.ar(busIn, 2);
    var wet = BRF.ar(sig, freq.clip(40, 18000), q.clip(0.05, 2));
    ReplaceOut.ar(busIn, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- FX additionnels (lus depuis fxBuses[\xxx], compatibles fx_bus.scd) ---

// Ring modulator avec freq mod
SynthDef(\fxRingMod, {
    arg in, out = 0, freq = 200, modAmt = 1.0, mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = dry * SinOsc.ar(freq) * modAmt;
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Frequency shifter
SynthDef(\fxFreqShift, {
    arg in, out = 0, shift = 100, mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = FreqShift.ar(dry, shift);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Granular freeze (simule un "grain hold" via PitchShift en boucle)
SynthDef(\fxGran, {
    arg in, out = 0, grainDur = 0.1, density = 30, pitch = 1.0,
        mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = PitchShift.ar(dry, grainDur, pitch, 0.05, 0.05);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Comb filter resonator
SynthDef(\fxComb, {
    arg in, out = 0, freq = 220, decay = 1.0, mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = CombC.ar(dry, 0.05, freq.reciprocal.clip(0.0001, 0.05), decay);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Formant filter (Klank) - voyelle parametrable
SynthDef(\fxFormant, {
    arg in, out = 0, vowel = 0, q = 0.15, mix = 0.5, amp = 1.0;
    var dry = In.ar(in, 2);
    var f1 = Select.kr(vowel, [800, 400, 350, 450, 325]);
    var f2 = Select.kr(vowel, [1150, 1700, 1900, 800, 700]);
    var f3 = Select.kr(vowel, [2900, 2600, 2500, 2830, 2530]);
    var wet = BPF.ar(dry, f1, q)
            + BPF.ar(dry, f2, q) * 0.7
            + BPF.ar(dry, f3, q) * 0.4;
    wet = wet * 1.5;
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Auto-filter LFO sur cutoff
SynthDef(\fxAutoFilter, {
    arg in, out = 0, rate = 0.5, lo = 200, hi = 4000, q = 0.4,
        mix = 0.7, amp = 1.0;
    var dry = In.ar(in, 2);
    var lfo = SinOsc.kr(rate).range(lo, hi);
    var wet = RLPF.ar(dry, lfo, q.clip(0.05, 1.5));
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Tremolo (amp LFO)
SynthDef(\fxTremolo, {
    arg in, out = 0, rate = 5, depth = 0.7, mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var lfo = SinOsc.kr(rate).range(1 - depth, 1);
    var wet = dry * lfo;
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Auto-pan
SynthDef(\fxAutopan, {
    arg in, out = 0, rate = 0.3, depth = 1.0, mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var p = SinOsc.kr(rate) * depth;
    var wet = Balance2.ar(dry[0], dry[1], p);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Stutter rythmique (gate carre)
SynthDef(\fxStutter, {
    arg in, out = 0, rate = 8, dutyCycle = 0.5, mix = 1.0, amp = 1.0;
    var dry = In.ar(in, 2);
    var gate = LFPulse.kr(rate, 0, dutyCycle);
    var wet = dry * gate;
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Resonator Klank (pitched ringing)
SynthDef(\fxResonator, {
    arg in, out = 0, freq = 220, decay = 2.0, mix = 0.4, amp = 1.0;
    var dry = In.ar(in, 2);
    var ratios = [1, 1.5, 2.01, 2.5, 3.01];
    var amps = [1, 0.6, 0.4, 0.3, 0.2];
    var ringL = Klank.ar(`[ratios * freq, amps, ratios.collect { decay }],
                        dry[0] * 0.1);
    var ringR = Klank.ar(`[ratios * freq, amps, ratios.collect { decay }],
                        dry[1] * 0.1);
    var wet = [ringL, ringR];
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Reverb a ressort (allpass nested + filtre tonal)
SynthDef(\fxSpringRev, {
    arg in, out = 0, decay = 1.5, mix = 0.4, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = dry;
    // chaine d'allpass typique d'un spring tank
    [0.013, 0.029, 0.041, 0.067, 0.089].do { |t|
        wet = AllpassN.ar(wet, 0.1, t, decay);
    };
    wet = HPF.ar(wet, 200);    // pas de basses dans un spring
    wet = LPF.ar(wet, 4500);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// Plate reverb (court + brillant + dense)
SynthDef(\fxPlate, {
    arg in, out = 0, decay = 2.5, damp = 0.3, mix = 0.4, amp = 1.0;
    var dry = In.ar(in, 2);
    var wet = FreeVerb2.ar(dry[0], dry[1], 1.0,
        decay.linlin(0.5, 5.0, 0.7, 0.95), damp);
    wet = HPF.ar(wet, 80);
    Out.ar(out, ((dry * (1 - mix)) + (wet * mix)) * amp);
}).add;

// --- Master compresseur (insert avant masterLim) ----------------------
// Compander : threshold, slopeBelow=1 (no expand), slopeAbove<1 (compress)
SynthDef(\masterComp, {
    arg threshold = 0.4, ratio = 0.5, attack = 0.01, release = 0.1,
        makeup = 1.4;
    var sig = In.ar(0, 2);
    sig = Compander.ar(sig, sig, threshold, 1.0, ratio, attack, release);
    sig = sig * makeup;
    ReplaceOut.ar(0, sig);
}).add;

// --- Master saturation (tanh / softclip / fold) -----------------------
// mode : 0=tanh, 1=softclip, 2=fold
SynthDef(\masterSat, {
    arg amount = 1.5, mode = 0, mix = 1.0;
    var sig = In.ar(0, 2);
    var wet = Select.ar(mode.clip(0, 2), [
        (sig * amount).tanh / amount.sqrt,
        (sig * amount).softclip,
        (sig * amount).fold(-0.95, 0.95)
    ]);
    ReplaceOut.ar(0, (sig * (1 - mix)) + (wet * mix));
}).add;

// --- Bus master temporaire pour effets globaux serie -------------------
// utilise par ~slipTime, ~ringMod momentanes : un Synth applique l'effet
// inline dans une chaine ReplaceOut sur le bus 0.
SynthDef(\fxMasterPitch, {
    arg dur = 2, pitch = 1.0, releaseTime = 0.05;
    var sig = In.ar(0, 2);
    var wet = PitchShift.ar(sig, 0.2, pitch, 0.01, 0.005);
    var env = EnvGen.kr(Env.linen(0.01, dur, releaseTime), doneAction: 2);
    ReplaceOut.ar(0, XFade2.ar(sig, wet, env.linlin(0, 1, -1, 1)));
}).add;

SynthDef(\fxMasterRing, {
    arg dur = 1, freq = 200, mix = 0.7;
    var sig = In.ar(0, 2);
    var wet = sig * SinOsc.ar(freq);
    var env = EnvGen.kr(Env.linen(0.01, dur, 0.05), doneAction: 2);
    ReplaceOut.ar(0, ((sig * (1 - mix)) + (wet * mix)) * env
                     + (sig * (1 - env)));
}).add;

SynthDef(\fxMasterFreqShift, {
    arg dur = 1, shift = 100;
    var sig = In.ar(0, 2);
    var wet = FreqShift.ar(sig, shift);
    var env = EnvGen.kr(Env.linen(0.01, dur, 0.05), doneAction: 2);
    ReplaceOut.ar(0, XFade2.ar(sig, wet, env.linlin(0, 1, -1, 1)));
}).add;

SynthDef(\fxMasterBitcrush, {
    arg dur = 1, bits = 6, sr = 6000, mix = 0.7;
    var sig = In.ar(0, 2);
    // Bit + SR reduction native (sans Decimator de sc3-plugins)
    var step = 2.pow(bits - 1);
    var crushed = (sig * step).round / step;
    var wet = Latch.ar(crushed, Impulse.ar(sr));
    var env = EnvGen.kr(Env.linen(0.01, dur, 0.05), doneAction: 2);
    ReplaceOut.ar(0, ((sig * (1 - mix)) + (wet * mix)) * env
                     + (sig * (1 - env)));
}).add;

SynthDef(\fxMasterGran, {
    arg dur = 2, grainDur = 0.1, pitch = 1.0;
    var sig = In.ar(0, 2);
    var wet = PitchShift.ar(sig, grainDur, pitch, 0.05, 0.05);
    var env = EnvGen.kr(Env.linen(0.01, dur, 0.05), doneAction: 2);
    ReplaceOut.ar(0, XFade2.ar(sig, wet, env.linlin(0, 1, -1, 1)));
}).add;

s.sync;


// =====================================================================
//  1. LFO assignables sur N'IMPORTE QUELLE variable globale ~xxx
// =====================================================================
// Stockage : ~lfos (different de ~fxLfos qui est reserve aux LFO FX)
~lfos !? { ~lfos.do(_.stop) };
~lfos = ();

// Helper interne : recupere une variable par symbol
~getVar = { |sym|
    currentEnvironment[sym.asSymbol]
};

// Helper interne : assigne une variable par symbol
~setVar = { |sym, val|
    currentEnvironment[sym.asSymbol] = val
};

// LFO continu : assigne une oscillation a ~paramName
//   shape : \sin \tri \saw \sqr \rand \smoothRand \drunk \noise
//   center : valeur centrale (par defaut = valeur courante de la var)
//   doReload : si true, appelle ~reload a chaque step (utile pour les
//              params lus dans Pdef -- pour des params pousses au Synth
//              en live, mettre false)
~lfoTo = { |paramName, rate = 1.0, depth = 0.3, shape = \sin,
           center = nil, doReload = true, pulseWidth = 0.5|
    var sym = paramName.asSymbol;
    var c = center ?? { ~getVar.(sym) ? 0 };
    var stepDur = 0.05;
    ~lfos[sym] !? { ~lfos[sym].stop };
    ~lfos[sym] = Routine({
        var phase = 0;
        var lastRand = 0;
        var nextRand = 1.0.rand2;
        var drunk = 0;
        inf.do { |i|
            var x;
            x = switch (shape,
                \sin,        { (phase * 2 * pi).sin },
                \tri,        { ((phase * 4 - 1).abs - 1).neg },
                \saw,        { (phase * 2) - 1 },
                \sqr,        { if (phase < pulseWidth) { 1 } { -1 } },
                \rand,       {
                    if (i.even) { lastRand = 1.0.rand2 };
                    lastRand
                },
                \smoothRand, {
                    var p = (phase * 2);
                    if (p >= 1.0) {
                        lastRand = nextRand;
                        nextRand = 1.0.rand2;
                        phase = phase - 0.5;
                        p = phase * 2;
                    };
                    lastRand + ((nextRand - lastRand) * p)
                },
                \drunk,      {
                    drunk = (drunk + (rrand(-0.15, 0.15))).clip(-1, 1);
                    drunk
                },
                \noise,      { 1.0.rand2 }
            );
            ~setVar.(sym, c + (x * depth));
            if (doReload) { ~reload !? { ~reload.value } };
            phase = (phase + (rate * stepDur)).mod(1.0);
            stepDur.wait;
        };
    }).play;
    ("LFO ~" ++ sym ++ " " ++ rate ++ "Hz depth=" ++ depth
        ++ " " ++ shape ++ " center=" ++ c.round(0.01)).postln;
};

// LFO sync au tempo : beatsDiv = nombre de beats par cycle complet
//   ex: 4 = un cycle sur 4 beats (ralenti), 0.25 = 4 cycles par beat
~lfoSync = { |paramName, beatsDiv = 4, depth = 0.3, shape = \sin,
              center = nil, doReload = true|
    var bps = TempoClock.default.tempo;
    var rate = bps / beatsDiv;
    ~lfoTo.(paramName, rate, depth, shape, center, doReload);
};

// Stop un LFO sur une var precise
~lfoStopVar = { |paramName|
    var sym = paramName.asSymbol;
    ~lfos[sym] !? { ~lfos[sym].stop; ~lfos.removeAt(sym) };
    ("LFO ~" ++ sym ++ " STOPPED").postln;
};

// Stop tous les LFO de variables (different de ~lfoStopAll de fx_bus
// qui est pour les LFO FX). On garde un nom different pour ne pas
// ecraser ~lfoStopAll de fx_bus.scd. Voir aussi ~lfoStopEverything.
~lfoStopAllVars = {
    ~lfos.do { |r| r.stop }; ~lfos = ();
    "all variable LFOs stopped".postln;
};

// Stop tous les LFOs (FX + variables)
~lfoStopEverything = {
    ~lfos.do { |r| r.stop }; ~lfos = ();
    ~fxLfos !? { ~fxLfos.do { |r| r.stop }; ~fxLfos = () };
    "ALL LFOs stopped (vars + fx)".postln;
};

// Liste les LFO actifs
~lfoList = {
    "=== LFO actifs ===".postln;
    if (~lfos.size == 0) {
        "  (aucun LFO sur variable)".postln;
    } {
        ~lfos.keysValuesDo { |k, v| ("  ~" ++ k ++ "  -> Routine").postln };
    };
    if ((~fxLfos.notNil) and: { ~fxLfos.size > 0 }) {
        "--- LFO FX ---".postln;
        ~fxLfos.keysValuesDo { |k, v| ("  " ++ k).postln };
    };
};


// =====================================================================
//  2. Envelopes one-shot assignables
// =====================================================================
// Stockage des envelopes en cours (Routines)
~envs !? { ~envs.do(_.stop) };
~envs = ();

// Env attack/sustain/release sur une var globale
//   target : valeur de pic a la fin de l'attack
//   returnTo : valeur retour apres release (par defaut = valeur initiale)
~envTo = { |paramName, attack = 0.1, sustain = 0.5, release = 0.5,
            target = 1.0, returnTo = nil, doReload = true|
    var sym = paramName.asSymbol;
    var start = ~getVar.(sym) ? 0;
    var end = returnTo ? start;
    var stepDur = 0.02;
    ~envs[sym] !? { ~envs[sym].stop };
    ~envs[sym] = Routine({
        // ATTACK : start -> target
        var attackSteps = (attack / stepDur).max(1).asInteger;
        attackSteps.do { |i|
            var x = (i + 1) / attackSteps;
            ~setVar.(sym, start + ((target - start) * x));
            if (doReload) { ~reload !? { ~reload.value } };
            stepDur.wait;
        };
        // SUSTAIN : maintien
        sustain.wait;
        // RELEASE : target -> end
        attackSteps = (release / stepDur).max(1).asInteger;
        attackSteps.do { |i|
            var x = (i + 1) / attackSteps;
            ~setVar.(sym, target + ((end - target) * x));
            if (doReload) { ~reload !? { ~reload.value } };
            stepDur.wait;
        };
        ~envs.removeAt(sym);
    }).play;
    ("ENV ~" ++ sym ++ " " ++ start.round(0.01) ++ " -> "
        ++ target.round(0.01) ++ " -> " ++ end.round(0.01)).postln;
};

// Env percussive courte (linenv : attack rapide + decay)
~envBurst = { |paramName, target = 1.0, dur = 0.5, curve = -3,
                doReload = true|
    var sym = paramName.asSymbol;
    var start = ~getVar.(sym) ? 0;
    var stepDur = 0.02;
    ~envs[sym] !? { ~envs[sym].stop };
    ~envs[sym] = Routine({
        var totalSteps = (dur / stepDur).max(2).asInteger;
        var env = Env.perc(0.005, dur, target - start, curve);
        // attack
        ~setVar.(sym, target);
        if (doReload) { ~reload !? { ~reload.value } };
        // release exponentiel approche
        totalSteps.do { |i|
            var x = (i + 1) / totalSteps;
            // courbe approx exp negative
            var v = target - ((target - start) * x.pow(0.5));
            ~setVar.(sym, v);
            if (doReload) { ~reload !? { ~reload.value } };
            stepDur.wait;
        };
        ~setVar.(sym, start);
        if (doReload) { ~reload !? { ~reload.value } };
        ~envs.removeAt(sym);
    }).play;
};

// Sweep lineaire / expo entre fromVal et toVal en dur secondes
//   curve : \lin ou \exp
~envSweep = { |paramName, fromVal, toVal, dur = 4, curve = \lin,
                doReload = true|
    var sym = paramName.asSymbol;
    var stepDur = 0.04;
    ~envs[sym] !? { ~envs[sym].stop };
    ~envs[sym] = Routine({
        var steps = (dur / stepDur).max(2).asInteger;
        steps.do { |i|
            var x = (i + 1) / steps;
            var v;
            if (curve == \exp) {
                v = fromVal * ((toVal / fromVal.max(0.0001)).pow(x));
            } {
                v = fromVal + ((toVal - fromVal) * x);
            };
            ~setVar.(sym, v);
            if (doReload) { ~reload !? { ~reload.value } };
            stepDur.wait;
        };
        ~envs.removeAt(sym);
    }).play;
    ("SWEEP ~" ++ sym ++ " " ++ fromVal ++ " -> " ++ toVal
        ++ " sur " ++ dur ++ "s (" ++ curve ++ ")").postln;
};

// Variantes pratiques pour le filtre melody
~filterSweepUp   = { |dur = 4|
    ~envSweep.(\melodyCutoff, 200, 6000, dur, \exp);
};
~filterSweepDown = { |dur = 4|
    ~envSweep.(\melodyCutoff, 6000, 200, dur, \exp);
};

// Duck momentane sur l'amp master via masterAmp ou via tous les amps
~ampDuck = { |dur = 0.3, depth = 0.7|
    // applique un dip sur kickAmp/melodyAmp/acidAmp/harmonyAmp
    var startKick = ~kickAmp ? 0.5;
    var startMel  = ~melodyAmp ? 0.16;
    var startAcid = ~acidAmp ? 0.32;
    var startHarm = ~harmonyAmp ? 0.14;
    Routine({
        ~kickAmp    = startKick * (1 - depth);
        ~melodyAmp  = startMel  * (1 - depth);
        ~acidAmp    = startAcid * (1 - depth);
        ~harmonyAmp = startHarm * (1 - depth);
        ~reload !? { ~reload.value };
        dur.wait;
        ~kickAmp    = startKick;
        ~melodyAmp  = startMel;
        ~acidAmp    = startAcid;
        ~harmonyAmp = startHarm;
        ~reload !? { ~reload.value };
    }).play;
    ("AMP DUCK depth=" ++ depth ++ " dur=" ++ dur).postln;
};


// =====================================================================
//  3. VCF Master : insert filtre temps reel sur le master
// =====================================================================
// Le VCF lit le bus 0 et ReplaceOut.
// IMPORTANT : insertion en `addBefore: ~masterLim` pour rester
// avant le limiter. Si masterLim n'existe pas, on l'ajoute en tail.
~vcfActive = nil;
~vcfActiveType = nil;

~vcfOn = { |type = \moog, freq = 1500, q = 0.5|
    var defName, args = [\busIn, 0, \freq, freq, \mix, 1.0];
    // map type -> nom complet de SynthDef
    defName = switch (type.asSymbol,
        \moog,    \vcfMoog,
        \ms20,    \vcfMs20,
        \ladder,  \vcfLadder,
        \formant, \vcfFormant,
        \comb,    \vcfComb,
        \hpf,     \vcfHpf,
        \bpf,     \vcfBpf,
        \notch,   \vcfNotch,
        // default
        \vcfMoog
    );
    // Args adaptes par type
    args = switch (defName,
        \vcfMoog,    [\busIn, 0, \freq, freq, \gain, q * 4, \mix, 1.0],
        \vcfMs20,    [\busIn, 0, \freq, freq, \q, q * 2, \mix, 1.0],
        \vcfLadder,  [\busIn, 0, \freq, freq, \q, q * 2, \mix, 1.0],
        \vcfFormant, [\busIn, 0, \vowel, freq.asInteger.clip(0, 4),
                      \q, q.clip(0.05, 1), \mix, 1.0],
        \vcfComb,    [\busIn, 0, \freq, freq, \decay, q * 2, \mix, 0.6],
        \vcfHpf,     [\busIn, 0, \freq, freq, \q, q, \mix, 1.0],
        \vcfBpf,     [\busIn, 0, \freq, freq, \q, q, \mix, 1.0],
        \vcfNotch,   [\busIn, 0, \freq, freq, \q, q, \mix, 1.0]
    );
    ~vcfActive !? { ~vcfActive.free };
    if (~masterLim.notNil) {
        ~vcfActive = Synth.before(~masterLim, defName, args);
    } {
        ~vcfActive = Synth.tail(s.defaultGroup, defName, args);
    };
    ~vcfActiveType = type;
    ("VCF " ++ type ++ " ON freq=" ++ freq ++ " q=" ++ q).postln;
};

~vcfSet = { |param, value|
    ~vcfActive !? { ~vcfActive.set(param.asSymbol, value) };
};

// Sweep automatique du cutoff (ne touche pas le SynthDef, set en live)
~vcfSweep = { |fromHz = 200, toHz = 5000, dur = 4, curve = \exp|
    Routine({
        var steps = (dur / 0.03).max(2).asInteger;
        steps.do { |i|
            var x = (i + 1) / steps;
            var f;
            if (curve == \exp) {
                f = fromHz * ((toHz / fromHz.max(0.001)).pow(x));
            } {
                f = fromHz + ((toHz - fromHz) * x);
            };
            ~vcfSet.(\freq, f);
            0.03.wait;
        };
    }).play;
    ("VCF SWEEP " ++ fromHz ++ " -> " ++ toHz ++ "Hz sur " ++ dur ++ "s").postln;
};

~vcfOff = {
    ~vcfActive !? { ~vcfActive.free; ~vcfActive = nil; ~vcfActiveType = nil };
    "VCF OFF".postln;
};

// Presets prets a l'emploi
~vcfPreset = { |preset|
    switch (preset.asSymbol,
        \acid,     { ~vcfOn.(\moog,    600,  0.85) },
        \dub,      { ~vcfOn.(\ladder,  900,  0.5) },
        \deep,     { ~vcfOn.(\moog,    400,  0.4) },
        \bright,   { ~vcfOn.(\bpf,    3500,  0.4) },
        \dark,     { ~vcfOn.(\moog,    250,  0.3) },
        \formantA, { ~vcfOn.(\formant,    0, 0.15) },
        \formantE, { ~vcfOn.(\formant,    1, 0.15) },
        \formantI, { ~vcfOn.(\formant,    2, 0.15) },
        \formantO, { ~vcfOn.(\formant,    3, 0.15) },
        \formantU, { ~vcfOn.(\formant,    4, 0.15) },
        // par defaut
        { "preset VCF inconnu".postln }
    );
};


// =====================================================================
//  4. Tricks sceniques live (combos)
// =====================================================================

// --- Tracking des Routines de tricks (anti-spam / anti-fuite RAM) ---
~trickRoutines = ~trickRoutines ?? { () };
~trickStop = { |key|
    ~trickRoutines[key.asSymbol] !? {
        ~trickRoutines[key.asSymbol].stop;
        ~trickRoutines[key.asSymbol] = nil;
    };
};
~trickStopAll = {
    ~trickRoutines.keysValuesDo { |k, r| r !? { r.stop } };
    ~trickRoutines = ();
    "TRICKS STOPPED ALL".postln;
};

// Stutter master via amp gate (modulation sur kick/mel/acid/harm)
~stutter = { |rateHz = 8, dur = 1.0|
    ~trickStop.(\stutter);
    ~trickRoutines[\stutter] = Routine({
        var n = (dur * rateHz).max(2).asInteger;
        var period = 1.0 / rateHz;
        var startK = ~kickAmp; var startM = ~melodyAmp;
        var startA = ~acidAmp; var startH = ~harmonyAmp;
        n.do { |i|
            var on = i.even;
            ~kickAmp    = if (on) { startK } { 0 };
            ~melodyAmp  = if (on) { startM } { 0 };
            ~acidAmp    = if (on) { startA } { 0 };
            ~harmonyAmp = if (on) { startH } { 0 };
            ~reload !? { ~reload.value };
            period.wait;
        };
        ~kickAmp = startK; ~melodyAmp = startM;
        ~acidAmp = startA; ~harmonyAmp = startH;
        ~reload !? { ~reload.value };
    }).play;
    ("STUTTER " ++ rateHz ++ "Hz " ++ dur ++ "s").postln;
};

// Coupe la rythmique
~chokePerc = {
    ~kickAmp = 0; ~hatAmp = 0;
    ~snareAmp !? { ~snareAmp = 0 };
    ~clapAmp !? { ~clapAmp = 0 };
    ~percAmp !? { ~percAmp = 0 };
    ~reload !? { ~reload.value };
    "CHOKE PERC".postln;
};

// Coupe melodies / lead / acid
~chokeLead = {
    ~melodyAmp = 0; ~harmonyAmp = 0; ~acidAmp = 0;
    ~reload !? { ~reload.value };
    "CHOKE LEAD".postln;
};

// Drop : silence -> snareFill -> reverb freeze -> blast
~drop = { |buildDur = 4|
    var startK = ~kickAmp ? 0.5;
    var startM = ~melodyAmp ? 0.16;
    var startA = ~acidAmp ? 0.32;
    var startH = ~harmonyAmp ? 0.14;
    ~trickStop.(\drop);
    ~trickRoutines[\drop] = Routine({
        // 1. fade out tout sur buildDur secondes
        ~envSweep.(\kickAmp,    startK, 0, buildDur, \lin, true);
        ~envSweep.(\melodyAmp,  startM, 0, buildDur, \lin, false);
        ~envSweep.(\acidAmp,    startA, 0, buildDur, \lin, false);
        ~envSweep.(\harmonyAmp, startH, 0, buildDur, \lin, false);
        // riser pendant le build
        Synth(\riser, [\dur, buildDur, \amp, 0.4]);
        buildDur.wait;
        // 2. snare fill juste avant le drop
        ~snareFill !? { ~snareFill.value };
        // 3. reverb freeze + delay 1/4
        ~setFx !? {
            ~setFx.(\rev, \freeze, 1);
            ~sendReverb !? { ~sendReverb.(0.6) };
            ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo);
            ~sendDelay !? { ~sendDelay.(0.5) };
        };
        0.5.wait;
        // 4. BLAST - on rebalance tout
        ~kickAmp = startK; ~melodyAmp = startM;
        ~acidAmp = startA; ~harmonyAmp = startH;
        ~reload !? { ~reload.value };
        // impact
        Synth(\impact, [\amp, 0.7]);
        // unfreeze apres 1s
        1.0.wait;
        ~setFx !? { ~setFx.(\rev, \freeze, 0) };
    }).play;
    ("DROP build=" ++ buildDur ++ "s").postln;
};

// Hands up : sub kick mute + lead boost + delay courte + clap
~handsUp = {
    ~kickAmp = 0;     // pas de sub
    ~melodyAmp = (~melodyAmp ? 0.16) * 1.6;
    ~clapAmp !? { ~clapAmp = 0.5 };
    ~setFx !? {
        ~setFx.(\dly, \delayTime, 60 / TempoClock.default.tempo / 4);
        ~sendDelay !? { ~sendDelay.(0.5) };
    };
    ~reload !? { ~reload.value };
    "HANDS UP".postln;
};

// Breakdown : kill rythmique progressif puis melody seule + shimmer
~breakdown = { |dur = 8|
    var startK = ~kickAmp ? 0.5;
    var startA = ~acidAmp ? 0.32;
    var startH = (~hatAmp ? 0.18);
    ~trickStop.(\breakdown);
    ~trickRoutines[\breakdown] = Routine({
        ~envSweep.(\kickAmp, startK, 0, dur * 0.4, \lin, true);
        ~envSweep.(\acidAmp, startA, 0, dur * 0.4, \lin, false);
        ~envSweep.(\hatAmp,  startH, 0, dur * 0.4, \lin, false);
        ~sendShimmer !? { ~sendShimmer.(0.5) };
        ~sendReverb !? { ~sendReverb.(0.5) };
        dur.wait;
    }).play;
    ("BREAKDOWN " ++ dur ++ "s").postln;
};

// Buildup : crescendo (riser + fadein de tout + filterSweepUp)
~buildup = { |dur = 8|
    var endK = 0.5; var endM = 0.16; var endA = 0.32;
    Synth(\riser, [\dur, dur, \amp, 0.45]);
    ~envSweep.(\kickAmp,   ~kickAmp ? 0,   endK, dur, \lin, true);
    ~envSweep.(\melodyAmp, ~melodyAmp ? 0, endM, dur, \lin, false);
    ~envSweep.(\acidAmp,   ~acidAmp ? 0,   endA, dur, \lin, false);
    ~filterSweepUp.(dur);
    ("BUILDUP " ++ dur ++ "s").postln;
};

// Tape stop : ralenti progressif du tempo puis stop
~tapeStop = { |dur = 2|
    var startTempo = TempoClock.default.tempo;
    ~trickStop.(\tapeStop);
    ~trickRoutines[\tapeStop] = Routine({
        var steps = (dur / 0.03).max(2).asInteger;
        steps.do { |i|
            var x = (i + 1) / steps;
            // courbe expo (descend lentement puis vite)
            var t = startTempo * ((1 - x).pow(2));
            TempoClock.default.tempo = t.max(0.01);
            0.03.wait;
        };
        // stop
        [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq,
         \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
        TempoClock.default.tempo = startTempo;
    }).play;
    ("TAPE STOP " ++ dur ++ "s").postln;
};

// Glitch : bitcrush + stutter + delay courte momentanes
~glitch = { |dur = 2|
    Synth(\fxMasterBitcrush, [\dur, dur, \bits, 5, \sr, 5000, \mix, 0.7]);
    ~stutter.(16, dur);
    ~setFx !? {
        ~setFx.(\dly, \delayTime, 0.05);
        ~sendDelay !? { ~sendDelay.(0.4) };
    };
    ~trickStop.(\glitch);
    ~trickRoutines[\glitch] = Routine({
        dur.wait;
        ~sendDelay !? { ~sendDelay.(0) };
    }).play;
    ("GLITCH " ++ dur ++ "s").postln;
};

// Freeze : reverb freeze + cut sec
~freeze = { |dur = 4|
    var startK = ~kickAmp ? 0.5;
    var startM = ~melodyAmp ? 0.16;
    var startA = ~acidAmp ? 0.32;
    ~trickStop.(\freeze);
    ~trickRoutines[\freeze] = Routine({
        ~setFx !? {
            ~setFx.(\rev, \freeze, 1);
            ~sendReverb !? { ~sendReverb.(0.7) };
        };
        ~kickAmp = 0; ~melodyAmp = 0; ~acidAmp = 0;
        ~reload !? { ~reload.value };
        dur.wait;
        ~setFx !? {
            ~setFx.(\rev, \freeze, 0);
            ~sendReverb !? { ~sendReverb.(0.3) };
        };
        ~kickAmp = startK; ~melodyAmp = startM; ~acidAmp = startA;
        ~reload !? { ~reload.value };
    }).play;
    ("FREEZE " ++ dur ++ "s").postln;
};

// Reverb tail : kill all + reverb send max + dur secondes de queue
~reverbTail = { |dur = 4|
    var startK = ~kickAmp ? 0.5;
    var startM = ~melodyAmp ? 0.16;
    var startA = ~acidAmp ? 0.32;
    var startH = ~harmonyAmp ? 0.14;
    ~trickStop.(\reverbTail);
    ~trickRoutines[\reverbTail] = Routine({
        ~sendReverb !? { ~sendReverb.(0.9) };
        ~setFx !? { ~setFx.(\rev, \room, 0.97); ~setFx.(\rev, \damp, 0.1) };
        ~kickAmp = 0; ~melodyAmp = 0; ~acidAmp = 0; ~harmonyAmp = 0;
        ~reload !? { ~reload.value };
        dur.wait;
        ~kickAmp = startK; ~melodyAmp = startM;
        ~acidAmp = startA; ~harmonyAmp = startH;
        ~reload !? { ~reload.value };
        ~sendReverb !? { ~sendReverb.(0.3) };
    }).play;
    ("REVERB TAIL " ++ dur ++ "s").postln;
};

// Tape reverse : effet inverse via riser cutoff inverse + freeze
~tapeReverse = { |dur = 2|
    Synth(\sweep, [\dur, dur, \startCutoff, 200, \endCutoff, 8000, \amp, 0.3]);
    ~filterSweepUp.(dur);
    ~setFx !? {
        ~setFx.(\rev, \freeze, 1);
        ~sendReverb !? { ~sendReverb.(0.5) };
    };
    ~trickStop.(\tapeReverse);
    ~trickRoutines[\tapeReverse] = Routine({
        dur.wait;
        ~setFx !? { ~setFx.(\rev, \freeze, 0) };
    }).play;
    ("TAPE REVERSE " ++ dur ++ "s").postln;
};

// Swap : crossfade entre deux scenes (utilise scenes.scd ~scenes ou
// simplement bascule deux preset par nom). Si ~scene helper existe.
~swap = { |sceneA, sceneB, dur = 4|
    ~trickStop.(\swap);
    ~trickRoutines[\swap] = Routine({
        if (~scene.notNil) {
            // fade out current
            ~envSweep.(\melodyAmp, ~melodyAmp, 0, dur * 0.5, \lin, false);
            ~envSweep.(\acidAmp,   ~acidAmp,   0, dur * 0.5, \lin, false);
            (dur * 0.5).wait;
            ~scene.(sceneB);
        } {
            ("swap : pas de helper ~scene -- swap " ++ sceneA
                ++ " <-> " ++ sceneB ++ " (no-op)").postln;
        };
    }).play;
};

// Jump cut : silence sec dur secondes puis reprend tout
~jumpCut = { |dur = 1|
    var startK = ~kickAmp; var startM = ~melodyAmp;
    var startA = ~acidAmp; var startH = ~harmonyAmp;
    ~trickStop.(\jumpCut);
    ~trickRoutines[\jumpCut] = Routine({
        ~kickAmp = 0; ~melodyAmp = 0; ~acidAmp = 0; ~harmonyAmp = 0;
        ~reload !? { ~reload.value };
        dur.wait;
        ~kickAmp = startK; ~melodyAmp = startM;
        ~acidAmp = startA; ~harmonyAmp = startH;
        ~reload !? { ~reload.value };
    }).play;
    ("JUMP CUT " ++ dur ++ "s").postln;
};


// =====================================================================
//  5. Sidechain dynamique (source -> target)
// =====================================================================
// Le moteur a deja ~scBus utilise par kick. On etend pour permettre
// d'autres SC dynamiques en jouant simplement sur les ~xxxScAmt
// existants. Pour un vrai SC d'une voix arbitraire vers une autre
// arbitraire, on creerait un nouveau bus -- ici on offre une API
// qui module les SC amount existants en fonction d'une source.
~scTrigger = { |source = \kick, target = \acid, amount = 0.7,
                attack = 0.005, release = 0.2|
    // pour kick -> acid/lead : ce sont les SC built-in : on set juste les amounts
    var key = (source.asString ++ "->" ++ target.asString).asSymbol;
    if (source == \kick) {
        switch (target.asSymbol,
            \acid,    { ~acidScAmt = amount; ~kickScShape = release },
            \melody,  { ~leadScAmt = amount; ~kickScShape = release },
            \harmony, { ~leadScAmt = amount; ~kickScShape = release },
            \master,  {
                // duck global synthetique : ampDuck a chaque kick sans
                // implementer un vrai bus de SC : on map kick.amp -> tous
                // les amps via un helper Routine. Approche pragmatique.
                ~scAuto.(amount);
            },
            { "scTrigger : target inconnu".postln }
        );
        ~reload !? { ~reload.value };
    } {
        ("scTrigger : seule la source \\kick est cablee dans le moteur "
            ++ "(snare/clap necessitent un bus dedie)").postln;
    };
    ("SC " ++ key ++ " amount=" ++ amount).postln;
};

// SC auto sur tout le mix (fait pomper tout sur le kick)
~scAuto = { |amount = 0.6|
    ~acidScAmt = amount;
    ~leadScAmt = amount;
    ~reload !? { ~reload.value };
    ("SC AUTO global = " ++ amount).postln;
};

~scOff = {
    ~acidScAmt = 0; ~leadScAmt = 0;
    ~reload !? { ~reload.value };
    "SC OFF".postln;
};


// =====================================================================
//  6. Stuttering / glitch / pitch momentanes
// =====================================================================
// Tous via Synth a duree finie (doneAction:2) -> pas besoin de free.

~slipTime = { |amount = 0.5, dur = 1|
    // amount : 0.5 = -1 octave, 1.0 = identite, 2.0 = +1 octave
    Synth(\fxMasterPitch, [\dur, dur, \pitch, amount.clip(0.25, 4.0)]);
    ("SLIP TIME pitch=" ++ amount ++ " dur=" ++ dur).postln;
};

~bitCrushNow = { |bits = 6, sr = 6000, dur = 1|
    Synth(\fxMasterBitcrush, [\dur, dur, \bits, bits, \sr, sr, \mix, 0.7]);
    ("BITCRUSH bits=" ++ bits ++ " sr=" ++ sr).postln;
};

~ringMod = { |freq = 200, dur = 1|
    Synth(\fxMasterRing, [\dur, dur, \freq, freq, \mix, 0.6]);
    ("RING MOD " ++ freq ++ "Hz " ++ dur ++ "s").postln;
};

~freqShift = { |shift = 100, dur = 1|
    Synth(\fxMasterFreqShift, [\dur, dur, \shift, shift]);
    ("FREQ SHIFT " ++ shift ++ "Hz " ++ dur ++ "s").postln;
};

~granFreeze = { |dur = 2|
    Synth(\fxMasterGran, [\dur, dur, \grainDur, 0.15, \pitch, 1.0]);
    ("GRAN FREEZE " ++ dur ++ "s").postln;
};

// Utilise le SynthDef \scratch existant (synthdefs/authentic.scd)
~scratch = { |dir = 1, dur = 0.3|
    Synth(\scratch, [\dur, dur, \freq, rrand(400, 1500),
                     \sweepDir, dir, \amp, 0.4]);
    ("SCRATCH dir=" ++ dir ++ " dur=" ++ dur).postln;
};

// Beat repeat : on prend un snippet du bus 0 et on le loop pendant dur
// Approche pragmatique : on utilise fxStutter pour chopper le master en
// gates rythmiques pendant dur -- pas de capture/replay (necessiterait
// un buffer dedie).
~repeat = { |rate = 8, dur = 1|
    // gate rythmique sur le master via stutter rapide
    ~stutter.(rate, dur);
    ("REPEAT " ++ rate ++ "Hz " ++ dur ++ "s").postln;
};


// =====================================================================
//  7. Auto-pan / tremolo / autopan par voix (via LFO sur amp/pan)
// =====================================================================
// Comme les voix sont des Pdef avec amp dans l'event, on module les
// variables ~xxxAmp / ~xxxPan via les LFO existants.
~autoFx = ();   // dictionnaire d'auto-fx par cible

~autoPan = { |target = \melody, rate = 0.5, depth = 0.8|
    // on vise la variable ~xxxPan -- si elle n'existe pas, on la cree
    var sym = (target.asString ++ "Pan").asSymbol;
    ~setVar.(sym, 0);
    ~lfoTo.(sym, rate, depth, \sin, 0, true);
    ~autoFx[target.asSymbol] = sym;
    ("AUTOPAN " ++ target ++ " rate=" ++ rate
        ++ " depth=" ++ depth ++ " (sur ~" ++ sym ++ ")").postln;
};

~tremolo = { |target = \melody, rate = 5, depth = 0.5|
    var sym = (target.asString ++ "Amp").asSymbol;
    var center = ~getVar.(sym) ? 0.16;
    ~lfoTo.(sym, rate, center * depth, \sin, center, true);
    ~autoFx[target.asSymbol] = sym;
    ("TREMOLO " ++ target ++ " rate=" ++ rate ++ "Hz depth=" ++ depth).postln;
};

~stopAutoFx = { |target = \melody|
    var sym = ~autoFx[target.asSymbol];
    sym !? { ~lfoStopVar.(sym); ~autoFx.removeAt(target.asSymbol) };
    ("AUTO FX " ++ target ++ " STOPPED").postln;
};


// =====================================================================
//  8. FX additionnels : les nouveaux FX SynthDef sont definis plus haut.
//     Helper pour les ajouter au bus FX (~fxFx) et permettre ~send dessus.
// =====================================================================
// Les FX additionnels sont : ringmod, fshift, gran, comb, formant,
// autoflt, trem, autopan, stut, reson, spring, plate.
// Ils peuvent etre instancies en send avec ~addFx.(\name, args)
// qui cree un nouveau bus + un Synth de FX en queue avant le master.

~addFx = { |name, args = #[], def = nil|
    var key = name.asSymbol;
    var defName = def ? switch (key,
        \ringmod, \fxRingMod,
        \fshift,  \fxFreqShift,
        \gran,    \fxGran,
        \comb,    \fxComb,
        \formant, \fxFormant,
        \autoflt, \fxAutoFilter,
        \trem,    \fxTremolo,
        \autopan, \fxAutopan,
        \stut,    \fxStutter,
        \reson,   \fxResonator,
        \spring,  \fxSpringRev,
        \plate,   \fxPlate,
        \fxRingMod
    );
    ~fxBuses !? {
        // si le bus n'existe pas, on l'alloue
        if (~fxBuses[key].isNil) {
            ~fxBuses[key] = Bus.audio(s, 2);
        };
        ~fxFx[key] !? { ~fxFx[key].free };
        if (~masterLim.notNil) {
            ~fxFx[key] = Synth.before(~masterLim, defName,
                [\in, ~fxBuses[key].index] ++ args);
        } {
            ~fxFx[key] = Synth.tail(s.defaultGroup, defName,
                [\in, ~fxBuses[key].index] ++ args);
        };
        ("FX " ++ key ++ " (" ++ defName ++ ") ajoute -- ~send.(\\"
            ++ key ++ ", amount) pour l'utiliser").postln;
    };
};


// =====================================================================
//  9. Master compresseur / saturation switchable
// =====================================================================
~masterComp = nil;
~masterSatSyn = nil;

~compOn = { |preset = \glue|
    var args = switch (preset.asSymbol,
        \soft,  [\threshold, 0.5, \ratio, 0.7, \attack, 0.02,
                 \release, 0.2,  \makeup, 1.2],
        \glue,  [\threshold, 0.4, \ratio, 0.5, \attack, 0.01,
                 \release, 0.15, \makeup, 1.4],
        \punch, [\threshold, 0.3, \ratio, 0.4, \attack, 0.003,
                 \release, 0.05, \makeup, 1.6],
        \pump,  [\threshold, 0.25,\ratio, 0.25,\attack, 0.001,
                 \release, 0.25, \makeup, 1.8],
        // default
        [\threshold, 0.4, \ratio, 0.5, \attack, 0.01,
         \release, 0.15, \makeup, 1.4]
    );
    ~masterComp !? { ~masterComp.free };
    if (~masterLim.notNil) {
        ~masterComp = Synth.before(~masterLim, \masterComp, args);
    } {
        ~masterComp = Synth.tail(s.defaultGroup, \masterComp, args);
    };
    ("COMP " ++ preset ++ " ON").postln;
};

~compOff = {
    ~masterComp !? { ~masterComp.free; ~masterComp = nil };
    "COMP OFF".postln;
};

~satOn = { |amount = 1.5, mode = 0|
    ~masterSatSyn !? { ~masterSatSyn.free };
    if (~masterLim.notNil) {
        ~masterSatSyn = Synth.before(~masterLim, \masterSat,
            [\amount, amount, \mode, mode, \mix, 1.0]);
    } {
        ~masterSatSyn = Synth.tail(s.defaultGroup, \masterSat,
            [\amount, amount, \mode, mode, \mix, 1.0]);
    };
    ("SAT amount=" ++ amount ++ " mode=" ++ mode).postln;
};

~satOff = {
    ~masterSatSyn !? { ~masterSatSyn.free; ~masterSatSyn = nil };
    "SAT OFF".postln;
};


"=== live.scd CHARGE ===".postln;
"  ~lfoTo / ~lfoSync / ~lfoStopVar / ~lfoStopAllVars / ~lfoList".postln;
"  ~envTo / ~envBurst / ~envSweep / ~filterSweepUp/Down / ~ampDuck".postln;
"  ~vcfOn / ~vcfSet / ~vcfSweep / ~vcfOff / ~vcfPreset".postln;
"  ~stutter ~chokePerc ~chokeLead ~drop ~handsUp ~breakdown".postln;
"  ~buildup ~tapeStop ~glitch ~freeze ~reverbTail ~tapeReverse".postln;
"  ~swap ~jumpCut ~scTrigger ~scAuto ~scOff".postln;
"  ~slipTime ~bitCrushNow ~ringMod ~freqShift ~granFreeze ~scratch ~repeat".postln;
"  ~autoPan ~tremolo ~stopAutoFx ~addFx ~compOn/Off ~satOn/Off".postln;

)


// =====================================================================
//  EXEMPLES D'USAGE -- Cmd+Entree sur un bloc pour l'executer
//  PREREQUIS : avoir evalue le bloc SETUP en tete de fichier d'abord
// =====================================================================

// --- 1. LFO assignables ----------------------------------------------

// LFO sin 0.5Hz +/-1500 autour 2500 sur cutoff melody
( ~lfoTo.(\melodyCutoff, 0.5, 1500, \sin, 2500); )

// LFO triangle slow sur cutoff acid
( ~lfoTo.(\acidCutoff, 0.25, 800, \tri, 1000); )

// LFO sqr asymetrique (pulseWidth=0.3) sur kickAmp -> rythmique
( ~lfoTo.(\kickAmp, 2, 0.2, \sqr, 0.5, true, 0.3); )

// LFO smooth random sur amp harmony
( ~lfoTo.(\harmonyAmp, 0.3, 0.08, \smoothRand, 0.14); )

// LFO drunken walk sur drive melody
( ~lfoTo.(\melodyDrive, 0.1, 0.8, \drunk, 1.2); )

// LFO sync au tempo : 1 cycle complet sur 4 beats
( ~lfoSync.(\melodyCutoff, 4, 1500, \sin, 2500); )

// Stop un LFO precis
( ~lfoStopVar.(\melodyCutoff); )

// Stop tous les LFOs de variables
( ~lfoStopAllVars.(); )

// Liste les LFOs actifs
( ~lfoList.(); )


// --- 2. Envelopes one-shot -------------------------------------------

// Envelope ASR (attack/sustain/release) sur cutoff melody : 1500 -> 6000 -> 1500
( ~envTo.(\melodyCutoff, 0.5, 1.0, 2.0, 6000, 1500); )

// Burst percussif sur cutoff acid : pic a 4000 puis decay 0.3s
( ~envBurst.(\acidCutoff, 4000, 0.3); )

// Sweep expo sur cutoff melody : 200 -> 6000 en 4s
( ~envSweep.(\melodyCutoff, 200, 6000, 4, \exp); )

// Sweep filtre montant 4s
( ~filterSweepUp.(4); )

// Sweep filtre descendant 4s
( ~filterSweepDown.(4); )

// Duck momentane sur tous les amps (depth=0.7 pendant 0.3s)
( ~ampDuck.(0.3, 0.7); )


// --- 3. VCF Master ---------------------------------------------------

// VCF Moog 800Hz q=0.7
( ~vcfOn.(\moog, 800, 0.7); )

// Set un parametre du VCF actif
( ~vcfSet.(\freq, 1500); )

// Sweep automatique du cutoff 200 -> 5000 en 4s
( ~vcfSweep.(200, 5000, 4); )

// VCF off
( ~vcfOff.(); )

// Preset acid (moog 600Hz q=0.85)
( ~vcfPreset.(\acid); )

// Preset formant voyelle A
( ~vcfPreset.(\formantA); )

// Preset dub (ladder 900Hz q=0.5)
( ~vcfPreset.(\dub); )


// --- 4. Tricks sceniques ---------------------------------------------

// Stutter master 8Hz pendant 1s
( ~stutter.(8, 1); )

// Coupe la rythmique (kick/hat/snare/clap/perc)
( ~chokePerc.(); )

// Coupe melody/lead/acid
( ~chokeLead.(); )

// Drop classique : build 4s + snare fill + freeze + blast
( ~drop.(4); )

// Hands up : mute kick, boost lead, delay courte
( ~handsUp.(); )

// Breakdown progressif sur 8s
( ~breakdown.(8); )

// Buildup crescendo sur 8s (riser + filterSweepUp)
( ~buildup.(8); )

// Tape stop : ralenti tempo puis stop sur 2s
( ~tapeStop.(2); )

// Glitch : bitcrush + stutter + delay courte pendant 2s
( ~glitch.(2); )

// Freeze : reverb freeze + cut sec pendant 4s
( ~freeze.(4); )

// Reverb tail : kill all + reverb send max + queue 4s
( ~reverbTail.(4); )

// Tape reverse : sweep + freeze pendant 2s
( ~tapeReverse.(2); )

// Jump cut : silence sec 0.5s puis reprend
( ~jumpCut.(0.5); )


// --- 5. Sidechain ----------------------------------------------------

// Sidechain kick -> acid (amount 0.85)
( ~scTrigger.(\kick, \acid, 0.85); )

// Sidechain kick -> melody (amount 0.6)
( ~scTrigger.(\kick, \melody, 0.6); )

// Sidechain auto sur tout le mix (pompe global)
( ~scAuto.(0.7); )

// Stop tous les sidechains
( ~scOff.(); )


// --- 6. Pitch / glitch -----------------------------------------------

// Slip time : pitch -1 octave pendant 1s
( ~slipTime.(0.5, 1); )

// Slip time : pitch +1 octave pendant 0.5s
( ~slipTime.(2.0, 0.5); )

// Bitcrush master 4 bits / 4kHz pendant 1s
( ~bitCrushNow.(4, 4000, 1); )

// Ring mod 150Hz pendant 1s
( ~ringMod.(150, 1); )

// Freq shift +50Hz pendant 1s
( ~freqShift.(50, 1); )

// Gran freeze pendant 2s
( ~granFreeze.(2); )

// Scratch up
( ~scratch.(1, 0.3); )

// Scratch down (plus long)
( ~scratch.(-1, 0.5); )

// Beat repeat 8Hz pendant 1s
( ~repeat.(8, 1); )


// --- 7. Auto-pan / tremolo -------------------------------------------

// Auto-pan melody (rate 0.5Hz, depth 0.8)
( ~autoPan.(\melody, 0.5, 0.8); )

// Tremolo melody (rate 5Hz, depth 0.5)
( ~tremolo.(\melody, 5, 0.5); )

// Stop l'auto-fx d'une voie
( ~stopAutoFx.(\melody); )


// --- 8. FX additionnels ----------------------------------------------

// Ring mod en send (200Hz, mix 0.5)
( ~addFx.(\ringmod, [\freq, 200, \mix, 0.5]); ~send.(\ringmod, 0.4); )

// Frequency shifter en send (+80Hz)
( ~addFx.(\fshift, [\shift, 80]); ~send.(\fshift, 0.3); )

// Granular freeze en send (pitch -1 oct)
( ~addFx.(\gran, [\grainDur, 0.15, \pitch, 0.5]); ~send.(\gran, 0.4); )

// Comb resonator en send (220Hz, decay 2s)
( ~addFx.(\comb, [\freq, 220, \decay, 2]); ~send.(\comb, 0.4); )

// Formant filter A en send
( ~addFx.(\formant, [\vowel, 0]); ~send.(\formant, 0.5); )

// Auto-filter LFO en send (sweep 200-4000Hz a 0.3Hz)
( ~addFx.(\autoflt, [\rate, 0.3, \lo, 200, \hi, 4000]); ~send.(\autoflt, 0.5); )

// Tremolo en send (6Hz, depth 0.7)
( ~addFx.(\trem, [\rate, 6, \depth, 0.7]); ~send.(\trem, 1.0); )

// Auto-pan en send
( ~addFx.(\autopan, [\rate, 0.5, \depth, 1]); ~send.(\autopan, 1.0); )

// Stutter en send (8Hz duty 0.5)
( ~addFx.(\stut, [\rate, 8, \dutyCycle, 0.5]); ~send.(\stut, 1.0); )

// Resonator pitched en send (220Hz, decay 3s)
( ~addFx.(\reson, [\freq, 220, \decay, 3]); ~send.(\reson, 0.5); )

// Spring reverb en send (decay 1.5s)
( ~addFx.(\spring, [\decay, 1.5]); ~send.(\spring, 0.4); )

// Plate reverb en send (decay 2.5s, damp 0.3)
( ~addFx.(\plate, [\decay, 2.5, \damp, 0.3]); ~send.(\plate, 0.4); )


// --- 9. Master comp / sat --------------------------------------------

// Compresseur preset glue
( ~compOn.(\glue); )

// Compresseur preset punch
( ~compOn.(\punch); )

// Compresseur preset pump (sidechain-style)
( ~compOn.(\pump); )

// Compresseur off
( ~compOff.(); )

// Saturation tanh
( ~satOn.(1.5, 0); )

// Saturation softclip
( ~satOn.(2.0, 1); )

// Saturation fold (extreme)
( ~satOn.(1.8, 2); )

// Saturation off
( ~satOff.(); )


// --- Combos sceniques en chaine --------------------------------------

// Drop classique
( ~drop.(4); )

// Sequence complete : breakdown + buildup + drop
( ~breakdown.(8); ~buildup.(8); ~drop.(2); )

// Acid focus : preset VCF + LFO sync sur cutoff
( ~vcfPreset.(\acid); ~lfoSync.(\acidCutoff, 8, 600, \sin, 800); )

// Mix punchy : SC auto + comp pump + saturation
( ~scAuto.(0.7); ~compOn.(\pump); ~satOn.(1.5); )

// Reset complet : stop tous les LFOs + VCF off + comp/sat off
( ~lfoStopEverything.(); ~vcfOff.(); ~compOff.(); ~satOff.(); )
