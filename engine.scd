// =====================================================================
//  engine.scd  --  Moteur (SynthDef + helpers + Pdef + master limiter)
//
//  USAGE
//    1. Cmd+Entree sur le bloc SETUP (une fois par session)
//    2. Cmd+Entree sur le bloc PLAY pour lancer le beat
//    3. Charger separement : presets.scd, tweaks.scd, tracks/*.scd
//    4. Cmd+Entree sur STOP en bas pour couper
// =====================================================================

//  1. SETUP -- evalue UNE FOIS au demarrage de la session
// =====================================================================
(
s.waitForBoot {

    // ----- Acid 303 -----
    // Env ADSR sur l'amp avec doneAction:2 -- garanti pas de fuite
    // memoire meme si on l'utilise dans un Pbind classique. Avec
    // PmonoArtic legato<1, le release (50ms) ne finit jamais avant
    // le retrigger -> le synth reste vivant et le slide fonctionne.
    SynthDef(\acid, {
        arg freq = 110, gate = 1, accent = 0, slideTime = 0.005,
            cutoff = 800, cutoffEnv = 3500, rq = 0.15,
            envDecay = 0.35, ampDecay = 0.28,
            drive = 2.5, amp = 0.32, pan = 0,
            scBus = 0, scAmt = 0.7;
        var f, sig, ampEnv, fEnv, fc, duck;
        f = Lag.kr(freq, slideTime);
        sig = Saw.ar(f);
        fEnv = EnvGen.kr(Env.perc(0.001, envDecay * (1 - (accent * 0.4))),
                         gate, doneAction: 0);
        fc = (cutoff + (fEnv * cutoffEnv * (1 + accent))).clip(60, 14000);
        sig = RLPF.ar(sig, fc, rq);
        // ADSR avec sustain=0 : la note "perc" naturelle, mais le
        // release de 50ms permet le retrigger PmonoArtic sans free.
        // doneAction:2 libere le Synth quand release atteint 0 -> safe.
        ampEnv = EnvGen.kr(
            Env.adsr(0.003, ampDecay, 0, 0.05, curve: -3),
            gate, doneAction: 2
        );
        sig = (sig * drive * (1 + (accent * 0.6))).tanh / drive.sqrt;
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        sig = sig * ampEnv * amp * duck;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- Kick (rond, sub-charge, click discret + sidechain out) -----
    SynthDef(\kick, {
        arg freq = 55, pitchAmt = 3.0, pitchTime = 0.035,
            decay = 0.32, drive = 1.3, click = 0.2,
            amp = 0.5, pan = 0,
            scBus = 0, scShape = 0.18;     // sidechain : bus de sortie + duree decay
        var pEnv, body, sub, clickSig, ampEnv, sig, scEnv;
        // pitch drop expo court
        pEnv = EnvGen.kr(Env([freq * pitchAmt, freq], [pitchTime], -3));
        body = SinOsc.ar(pEnv);
        // sub-bass en parallele (octave en dessous, fixe)
        sub  = SinOsc.ar(freq * 0.5);
        // click haute frequence, court
        clickSig = HPF.ar(WhiteNoise.ar, 3000) *
                   EnvGen.kr(Env.perc(0.0005, 0.004));
        sig = body + (sub * 0.3) + (clickSig * click);
        ampEnv = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
        // tanh AVANT ampEnv : sature la forme d'onde brute, garde le
        // transitoire intact dans l'enveloppe (corrige M3 du critic)
        sig = (sig * drive).tanh;
        sig = sig * ampEnv;
        sig = LeakDC.ar(sig) * amp;
        // Sidechain : enveloppe percussive plus longue que l'amp pour
        // ducker les autres voix le temps que l'oreille percoive le kick
        scEnv = EnvGen.kr(Env.perc(0.001, scShape, curve: -4));
        Out.kr(scBus, scEnv);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- Hi-hat -----
    SynthDef(\hat, {
        arg hpf = 9000, decay = 0.04, amp = 0.18, pan = 0;
        var sig, env;
        sig = HPF.ar(WhiteNoise.ar, hpf);
        sig = BPF.ar(sig, 10000, 0.4);
        env = EnvGen.kr(Env.perc(0.001, decay), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;

    // ----- Lead melody (saw+pulse detunes + chorus stereo + LPF) -----
    SynthDef(\lead, {
        arg freq = 220, gate = 1, sawAmt = 0.6, pulseWidth = 0.4,
            cutoff = 2500, rq = 0.5,
            attack = 0.01, decay = 0.15, sustain = 0.4, release = 0.3,
            detune = 0.005, drive = 1.2, amp = 0.18, pan = 0,
            scBus = 0, scAmt = 0.5;
        var oscL, oscR, sig, ampEnv, duck;
        oscL = (Saw.ar(freq * (1 - detune)) * sawAmt) +
               (Pulse.ar(freq * (1 - detune), pulseWidth) * (1 - sawAmt));
        oscR = (Saw.ar(freq * (1 + detune)) * sawAmt) +
               (Pulse.ar(freq * (1 + detune), pulseWidth) * (1 - sawAmt));
        oscL = DelayC.ar(oscL, 0.02, SinOsc.kr(0.6, 0).range(0.001, 0.004));
        oscR = DelayC.ar(oscR, 0.02, SinOsc.kr(0.6, pi).range(0.001, 0.004));
        sig = RLPF.ar([oscL, oscR], cutoff, rq);
        ampEnv = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        sig = Balance2.ar(sig[0], sig[1], pan);
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, sig * ampEnv * amp * duck);
    }).add;

    // ----- Pad (super-saw 5 voix detunes + chorus + LPF) -----
    SynthDef(\pad, {
        arg freq = 220, gate = 1, detune = 0.012,
            cutoff = 1800, rq = 0.6,
            attack = 0.4, decay = 0.3, sustain = 0.7, release = 1.5,
            drive = 1.0, amp = 0.15, pan = 0,
            scBus = 0, scAmt = 0.4;
        var sig, env, duck;
        sig = Mix.fill(5, { |i|
            Saw.ar(freq * (1 + ((i - 2) * detune)))
        }) * 0.22;
        sig = RLPF.ar(sig, cutoff, rq);
        sig = sig + DelayC.ar(sig, 0.04,
            SinOsc.kr(0.3, 0).range(0.01, 0.03));
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                        gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
    }).add;

    // ----- Pluck (Karplus-Strong, decay naturel) -----
    SynthDef(\pluck, {
        arg freq = 220, gate = 1,
            cutoff = 5000, rq = 0.5,
            attack = 0.001, decay = 0.05, sustain = 0.0, release = 0.5,
            drive = 1.0, amp = 0.22, pan = 0,
            scBus = 0, scAmt = 0.5;
        var sig, env, duck, exciter, ks;
        exciter = WhiteNoise.ar(0.5) * EnvGen.kr(Env.perc(0.0005, 0.005));
        ks = LeakDC.ar(CombC.ar(exciter, 0.05, freq.reciprocal, 2.5));
        sig = LPF.ar(ks, cutoff);
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                        gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
    }).add;

    // ----- FM Bell DUBSTEP -- wobble + sub + detune + saturation -----
    // Inspire des growl/wobble dubstep : RLPF resonant module par LFTri
    // (wobble), 2 voix detunees, sub-bass parallele, distortion lourde.
    SynthDef(\fmBell, {
        arg freq = 220, gate = 1,
            modRatio = 1.41, modIndex = 3,
            cutoff = 400,                  // cutoff de base (bas pour dubstep)
            wobbleRate = 4,                // Hz (4 = 1/8 a 120 BPM)
            wobbleDepth = 1800,            // amplitude du wobble en Hz
            wobbleShape = 0,               // 0 = LFTri (smooth), 1 = LFPulse (chop)
            rq = 0.25,                     // resonance forte (audible)
            subAmt = 0.45,                 // niveau du sub-bass octave -1
            detune = 0.006,                // detune entre 2 voix L/R
            attack = 0.005, decay = 0.3, sustain = 0.4, release = 0.4,
            drive = 3.5,                   // saturation lourde
            amp = 0.18, pan = 0,
            scBus = 0, scAmt = 0.4;
        var carL, carR, mod, wobble, sig, sub, env, duck, lfo;
        // LFO wobble (mix tri / pulse selon shape)
        lfo = SelectX.kr(wobbleShape, [
            LFTri.kr(wobbleRate),
            LFPulse.kr(wobbleRate, 0, 0.5, 2, -1)
        ]);
        wobble = (cutoff + (lfo.range(0, 1) * wobbleDepth)).clip(80, 12000);
        // FM avec carrieres detunees L/R
        mod = SinOsc.ar(freq * modRatio) * freq * modIndex * 0.5;
        carL = SinOsc.ar(freq * (1 - detune) + mod);
        carR = SinOsc.ar(freq * (1 + detune) + mod);
        // Sub-bass : octave -1 + octave -2 + harmonique 3 (epaisseur)
        // sub massif typique dubstep : sub fonda + sub-sub + harmonique
        sub = (SinOsc.ar(freq * 0.5) * 0.7) +
              (SinOsc.ar(freq * 0.25) * 0.5) +
              (SinOsc.ar(freq * 0.5, pi * 0.5) * 0.2);   // legere phase shift
        sub = sub * subAmt * 1.3;                        // boost interne
        sub = sub.tanh;                                  // soft clip pour rester contenu
        sig = [carL + sub, carR + sub];
        // RLPF resonant module par le wobble
        sig = RLPF.ar(sig, wobble, rq);
        // Saturation lourde (le coeur du son dubstep)
        sig = (sig * drive).tanh / drive.sqrt;
        // Compression "tape" pour faire rentrer le sub
        sig = (sig * 1.4).tanh;
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                        gate, doneAction: 2);
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        sig = Balance2.ar(sig[0], sig[1], pan);
        Out.ar(0, sig * env * amp * duck);
    }).add;

    // ----- Stab (court, saw + saturation pour Detroit) -----
    SynthDef(\stab, {
        arg freq = 220, gate = 1, sawAmt = 0.7,
            cutoff = 1500, rq = 0.3,
            attack = 0.001, decay = 0.04, sustain = 0.0, release = 0.06,
            drive = 2.8, amp = 0.18, pan = 0,
            scBus = 0, scAmt = 0.5;
        var sig, env, duck;
        sig = (Saw.ar(freq) * sawAmt) +
              (Pulse.ar(freq * 1.005, 0.3) * (1 - sawAmt));
        sig = RLPF.ar(sig, cutoff, rq);
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release, curve: -3),
                        gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
    }).add;

    // ----- Saw3 (3 saws empilees, octaves -1/0/+1) -----
    SynthDef(\saw3, {
        arg freq = 220, gate = 1,
            cutoff = 2200, rq = 0.4,
            attack = 0.005, decay = 0.12, sustain = 0.5, release = 0.25,
            drive = 1.4, amp = 0.16, pan = 0,
            scBus = 0, scAmt = 0.5;
        var sig, env, duck;
        sig = (Saw.ar(freq * 0.5)  * 0.35) +
              (Saw.ar(freq)        * 0.55) +
              (Saw.ar(freq * 2)    * 0.25);
        sig = RLPF.ar(sig, cutoff, rq);
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release),
                        gate, doneAction: 2);
        sig = (sig * drive).tanh / drive.sqrt;
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
    }).add;

    // ----- Snare (tone + bruit blanc filtre) -----
    SynthDef(\snare, {
        arg freq = 200, decay = 0.13, noiseAmt = 0.6, drive = 1.5,
            amp = 0.5, pan = 0;
        var tone, noise, env, sig, pitchEnv;
        pitchEnv = EnvGen.kr(Env([freq * 2, freq], [0.02], -2));
        tone = SinOsc.ar(pitchEnv) * EnvGen.kr(Env.perc(0.001, 0.05));
        noise = HPF.ar(WhiteNoise.ar, 1500);
        noise = BPF.ar(noise, 3000, 0.5);
        noise = noise * EnvGen.kr(Env.perc(0.001, decay));
        sig = (tone * (1 - noiseAmt)) + (noise * noiseAmt);
        env = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
        sig = (sig * drive).tanh;
        sig = LeakDC.ar(sig) * amp * env;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- Clap (4 attaques rapides puis tail) -----
    SynthDef(\clap, {
        arg decay = 0.18, amp = 0.4, pan = 0;
        var noise, env, sig;
        noise = HPF.ar(WhiteNoise.ar, 800);
        noise = BPF.ar(noise, 1500, 0.5);
        env = EnvGen.kr(
            Env.new(
                [0, 1, 0.5, 1, 0.5, 1, 1, 0],
                [0.001, 0.008, 0.008, 0.008, 0.008, 0.005, decay],
                \exp
            ),
            doneAction: 2
        );
        sig = noise * env * amp;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- Riser (bruit qui monte sur N secondes) -----
    //  Courbe \sin (qui supporte zero) -- \exp + valeur 0 = NaN
    //  qui silenciait tout le bus.
    SynthDef(\riser, {
        arg dur = 4, startCutoff = 300, endCutoff = 8000,
            amp = 0.3, pan = 0;
        var noise, cutoff, env, sig;
        cutoff = Line.kr(startCutoff, endCutoff, dur).clip(20, 18000);
        noise = (WhiteNoise.ar * 0.5) + (PinkNoise.ar * 0.3);
        sig = HPF.ar(noise, cutoff);
        sig = BPF.ar(sig, cutoff.min(15000), 0.4);
        env = EnvGen.kr(
            Env.new([0, 0.3, 1, 0], [dur * 0.5, dur * 0.45, dur * 0.05], \sin),
            doneAction: 2
        );
        sig = LeakDC.ar(sig * env * amp);
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- Impact (boom + reverse hit, marque les drops) -----
    SynthDef(\impact, {
        arg freq = 45, decay = 1.5, amp = 0.7, pan = 0;
        var pitchEnv, body, noise, env, sig;
        pitchEnv = EnvGen.kr(Env([freq * 5, freq * 0.5], [0.12], \exp));
        body = SinOsc.ar(pitchEnv);
        noise = LPF.ar(WhiteNoise.ar, 800) *
                EnvGen.kr(Env.perc(0.001, 0.4));
        sig = body + (noise * 0.5);
        env = EnvGen.kr(Env.perc(0.002, decay, curve: -4), doneAction: 2);
        sig = sig * env;
        sig = (sig * 1.5).tanh;
        sig = LeakDC.ar(sig) * amp;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- Open hat (cymbale ouverte, decay long) -----
    SynthDef(\openHat, {
        arg hpf = 7000, decay = 0.4, amp = 0.18, pan = 0;
        var sig, env;
        sig = HPF.ar(WhiteNoise.ar, hpf);
        sig = BPF.ar(sig, 9000, 0.6);
        env = EnvGen.kr(Env.perc(0.001, decay, curve: -4), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;

    // ----- Crash cymbal -----
    SynthDef(\crash, {
        arg hpf = 4000, decay = 1.5, amp = 0.3, pan = 0;
        var sig, env;
        sig = HPF.ar(WhiteNoise.ar + (PinkNoise.ar * 0.5), hpf);
        sig = BPF.ar(sig, 7000, 0.4) + (sig * 0.3);
        env = EnvGen.kr(Env.perc(0.002, decay, curve: -3), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;

    // ----- Tom (drum tone melodique) -----
    SynthDef(\tom, {
        arg freq = 110, decay = 0.3, drive = 1.4, amp = 0.5, pan = 0;
        var pitchEnv, body, noise, sig, env;
        pitchEnv = EnvGen.kr(Env([freq * 1.8, freq], [0.04], -3));
        body = SinOsc.ar(pitchEnv) + (Saw.ar(pitchEnv) * 0.2);
        noise = HPF.ar(WhiteNoise.ar, 2000) * EnvGen.kr(Env.perc(0.001, 0.01));
        sig = body + (noise * 0.3);
        env = EnvGen.kr(Env.perc(0.003, decay, curve: -3), doneAction: 2);
        sig = (sig * drive).tanh;
        sig = LeakDC.ar(sig) * env * amp;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- Rim shot (clic metallique court) -----
    SynthDef(\rim, {
        arg freq = 1500, decay = 0.04, amp = 0.3, pan = 0;
        var sig, env;
        sig = SinOsc.ar(freq) + (HPF.ar(WhiteNoise.ar, 4000) * 0.5);
        sig = BPF.ar(sig, freq * 1.5, 0.3);
        env = EnvGen.kr(Env.perc(0.001, decay, curve: -5), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;

    // ----- Cowbell -----
    SynthDef(\cowbell, {
        arg freq = 800, decay = 0.2, amp = 0.3, pan = 0;
        var sig, env;
        sig = (Pulse.ar(freq, 0.5) * 0.5) + (Pulse.ar(freq * 1.501, 0.5) * 0.5);
        sig = BPF.ar(sig, freq * 1.3, 0.3) * 2;
        env = EnvGen.kr(Env.perc(0.001, decay, curve: -4), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;

    // ----- Reese bass (2 saws detunes filtres -- DnB / dubstep) -----
    SynthDef(\reese, {
        arg freq = 55, gate = 1, detune = 0.012, cutoff = 800, rq = 0.4,
            attack = 0.005, decay = 0.1, sustain = 0.7, release = 0.2,
            drive = 2.5, amp = 0.35, pan = 0,
            scBus = 0, scAmt = 0.4;
        var sig, env, duck;
        sig = (Saw.ar(freq * (1 - detune)) * 0.5) +
              (Saw.ar(freq * (1 + detune)) * 0.5) +
              (Saw.ar(freq * 0.5) * 0.3);   // sub
        sig = RLPF.ar(sig, cutoff, rq);
        sig = (sig * drive).tanh / drive.sqrt;
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        sig = LeakDC.ar(sig) * env * amp * duck;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- 808 bass (trap-style sub avec pitch glide) -----
    SynthDef(\bass808, {
        arg freq = 55, gate = 1, glide = 0.05,
            attack = 0.003, decay = 0.4, sustain = 0.8, release = 0.6,
            drive = 1.4, amp = 0.45, pan = 0,
            scBus = 0, scAmt = 0.5;
        var sig, env, duck, f;
        f = Lag.kr(freq, glide);
        sig = SinOsc.ar(f) + (SinOsc.ar(f * 0.5) * 0.5);
        sig = (sig * drive).tanh;
        env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
        duck = 1 - (In.kr(scBus, 1) * scAmt);
        sig = LeakDC.ar(sig) * env * amp * duck;
        Out.ar(0, Pan2.ar(sig, pan));
    }).add;

    // ----- Sweep down (l'inverse du riser, descend) -----
    SynthDef(\sweep, {
        arg dur = 4, startCutoff = 8000, endCutoff = 200,
            amp = 0.25, pan = 0;
        var noise, cutoff, env, sig;
        cutoff = Line.kr(startCutoff, endCutoff, dur);
        noise = WhiteNoise.ar + (PinkNoise.ar * 0.5);
        sig = LPF.ar(noise, cutoff);
        sig = BPF.ar(sig, cutoff * 1.2, 0.5);
        env = EnvGen.kr(Env.linen(0.05, dur - 0.1, 0.05), doneAction: 2);
        Out.ar(0, Pan2.ar(sig * env * amp, pan));
    }).add;

    // ----- Vinyl noise (texture continue, ambiance) -----
    SynthDef(\vinyl, {
        arg amp = 0.05, pan = 0;
        var sig, crackles;
        sig = PinkNoise.ar(0.3);
        crackles = Dust.ar(50, 0.4) + Dust.ar(20, 0.5);
        sig = sig + crackles;
        sig = HPF.ar(sig, 80);
        Out.ar(0, Pan2.ar(sig * amp, pan));
    }).add;

    // ----- Master limiter -----
    SynthDef(\masterLim, {
        var sig = In.ar(0, 2);
        sig = LeakDC.ar(sig);
        sig = Limiter.ar(sig, 0.95, 0.005);
        ReplaceOut.ar(0, sig);
    }).add;

    s.sync;

    // ----- Bus de sidechain (control) ----------------------------
    // Le kick ecrit son enveloppe sur ce bus, acid + lead lisent et
    // duckent leur sortie -> mix techno qui pompe sur le kick.
    ~scBus !? { ~scBus.free };
    ~scBus = Bus.control(s, 1);

    // ----- Master limiter en queue de groupe ---------------------
    ~masterLim !? { ~masterLim.free };
    ~masterLim = Synth.tail(s.defaultGroup, \masterLim);

    // ----- Patterns par defaut -----------------------------------
    ~bpm = 132;
    ~acidNotes   = [ 36, 36, 48, 36, 39, 36, 43, 39,
                     36, 41, 36, 39, 43, 36, 36, 41 ];
    ~acidAccents = [  1,  0,  0,  0,  1,  0,  1,  0,
                      0,  1,  0,  0,  1,  0,  0,  1 ];
    ~acidSlides  = [  0,  0,  1,  0,  0,  0,  0,  1,
                      0,  0,  0,  1,  0,  0,  0,  0 ];
    ~kickSteps   = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ];
    ~hatSteps    = [ 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0 ];
    ~snareSteps  = (0 ! 16);
    ~snareAmp    = 0.45;
    ~snareFreq   = 200; ~snareNoiseAmt = 0.6; ~snareDecay = 0.13;
    // Percussions secondaires
    ~clapSteps   = (0 ! 16); ~clapAmp = 0.35;
    ~percSteps   = (0 ! 16); ~percAmp = 0.25; ~percInst = \rim;     // \rim | \cowbell | \tom | \openHat
    ~tomFreq     = 110; ~cowbellFreq = 800;
    ~melodyNotes = [
        60,  0, 67,  0, 70,  0, 67, 65,
        63,  0, 60,  0,  0, 67, 70, 72,
        75,  0, 72, 70, 67,  0,  0, 65,
        63, 60,  0, 67, 70,  0, 72,  0
    ];

    // ----- Parametres de timbre ----------------------------------
    ~acidCutoff = 800; ~acidRq = 0.15; ~acidCutoffEnv = 3500;
    ~acidDrive  = 2.5; ~acidAmp = 0.32;
    ~kickAmp    = 0.5;
    ~kickFreq   = 55;     // frequence fondamentale (45=sub, 55=normal, 70=punchy)
    ~kickPitchAmt = 3.0;  // ratio du drop initial (2=soft, 3=normal, 5=snappy)
    ~kickDecay  = 0.32;   // duree (0.18=tight, 0.32=normal, 0.6=boomy)
    ~kickDrive  = 1.3;    // saturation (1.0=clean, 1.5=normal, 3.0=distort)
    ~kickClick  = 0.2;    // amplitude du click HF (0=rond, 0.4=claquant)
    ~hatAmp     = 0.18;
    ~melodyInst   = \lead;        // \lead | \pad | \pluck | \fmBell | \stab | \saw3
    ~melodyBoost  = 1.6;          // multiplicateur global du volume melodie
    ~melodyCutoff = 2400; ~melodyRq = 0.5; ~melodyAmp = 0.16;
    ~melodyDrive  = 1.2;  ~melodyAttack = 0.012; ~melodyRelease = 0.25;
    ~melodySawAmt = 0.6;  ~melodyDetune = 0.006;
    // Specifique fmBell dubstep
    ~melodyWobbleRate  = 4;       // Hz (4=1/8 a 120BPM, 8=1/16, 2=1/4)
    ~melodyWobbleDepth = 1800;    // ouverture du wobble en Hz
    ~melodyWobbleShape = 0;       // 0 = LFTri smooth, 1 = LFPulse chop
    ~melodySubAmt      = 0.85;    // sub fmBell (0.85 = MASSIF)

    // ----- 2e voix melodique (harmony / counter-melody) ----------
    ~harmonyInst   = \pad;        // synth pour la 2e voix
    ~harmonyNotes  = (0 ! 32);    // muet par defaut
    ~harmonyCutoff = 1800; ~harmonyRq = 0.6;
    ~harmonyAttack = 0.05; ~harmonyDecay = 0.15;
    ~harmonySustain = 0.6; ~harmonyRelease = 0.5;
    ~harmonyDrive  = 1.2;  ~harmonyAmp = 0.14;
    ~harmonyDur    = 0.25;        // 0.25 = 1/16 ; 0.5 = 1/8 ; 0.125 = 1/32
    ~harmonyDetune = 0.006; ~harmonySawAmt = 0.6;

    // Sidechain : amount par voix (0 = pas de duck, 1 = mute total sur kick)
    ~acidScAmt = 0.7;       // l'acid pompe fort sur le kick
    ~leadScAmt = 0.5;       // le lead pompe modere
    ~kickScShape = 0.18;    // duree de l'env sidechain (s)

    // ----- Reload : reconstruit les 4 Pdef depuis les variables --
    ~reload = {
        // Guards : les Pseq plantent si on leur passe nil/array vide.
        // On force une valeur par defaut pour chaque variable de pattern.
        if (~kickSteps.isNil    or: { ~kickSteps.isEmpty })    { ~kickSteps    = (0 ! 16) };
        if (~hatSteps.isNil     or: { ~hatSteps.isEmpty })     { ~hatSteps     = (0 ! 16) };
        if (~snareSteps.isNil   or: { ~snareSteps.isEmpty })   { ~snareSteps   = (0 ! 16) };
        if (~clapSteps.isNil    or: { ~clapSteps.isEmpty })    { ~clapSteps    = (0 ! 16) };
        if (~percSteps.isNil    or: { ~percSteps.isEmpty })    { ~percSteps    = (0 ! 16) };
        if (~acidNotes.isNil    or: { ~acidNotes.isEmpty })    { ~acidNotes    = [36] };
        if (~acidAccents.isNil  or: { ~acidAccents.isEmpty })  { ~acidAccents  = [0] };
        if (~acidSlides.isNil   or: { ~acidSlides.isEmpty })   { ~acidSlides   = [0] };
        if (~melodyNotes.isNil  or: { ~melodyNotes.isEmpty })  { ~melodyNotes  = (0 ! 32) };
        if (~harmonyNotes.isNil or: { ~harmonyNotes.isEmpty }) { ~harmonyNotes = (0 ! 32) };
        // Amps / params scalaires : default 0 evite NaN
        ~kickAmp     = ~kickAmp    ? 0;  ~hatAmp     = ~hatAmp    ? 0;
        ~snareAmp    = ~snareAmp   ? 0;  ~clapAmp    = ~clapAmp   ? 0;
        ~percAmp     = ~percAmp    ? 0;  ~acidAmp    = ~acidAmp   ? 0;
        ~melodyAmp   = ~melodyAmp  ? 0;  ~harmonyAmp = ~harmonyAmp ? 0;
        ~melodyBoost = ~melodyBoost ? 1; ~harmonyDur = ~harmonyDur ? 0.25;
        Pdef(\kickSeq, Pbind(
            \instrument, \kick, \dur, 0.25,
            \amp, Pseq(~kickSteps.collect { |s| s * ~kickAmp }, inf),
            \freq, ~kickFreq, \pitchAmt, ~kickPitchAmt,
            \decay, ~kickDecay, \drive, ~kickDrive, \click, ~kickClick,
            \scBus, ~scBus.index, \scShape, ~kickScShape,
        ));
        Pdef(\hatSeq, Pbind(
            \instrument, \hat, \dur, 0.25,
            \amp, Pseq(~hatSteps.collect { |s| s * ~hatAmp }, inf),
        ));
        Pdef(\snareSeq, Pbind(
            \instrument, \snare, \dur, 0.25,
            \amp, Pseq(~snareSteps.collect { |s| s * ~snareAmp }, inf),
            \freq, ~snareFreq, \noiseAmt, ~snareNoiseAmt, \decay, ~snareDecay,
        ));
        Pdef(\clapSeq, Pbind(
            \instrument, \clap, \dur, 0.25,
            \amp, Pseq(~clapSteps.collect { |s| s * ~clapAmp }, inf),
        ));
        Pdef(\percSeq, Pbind(
            \instrument, ~percInst, \dur, 0.25,
            \amp, Pseq(~percSteps.collect { |s| s * ~percAmp }, inf),
            \freq, if (~percInst == \tom) { ~tomFreq } { ~cowbellFreq },
        ));
        Pdef(\acidSeq, PmonoArtic(\acid,
            \dur,        0.25,
            \legato,     0.85,
            \midinote,   Pseq(~acidNotes, inf),
            \accent,     Pseq(~acidAccents, inf),
            \slideTime,  Pseq(~acidSlides.collect { |s| if(s == 1) {0.12} {0.005} }, inf),
            \cutoff,     ~acidCutoff,
            \cutoffEnv,  ~acidCutoffEnv,
            \rq,         ~acidRq,
            \drive,      ~acidDrive,
            \amp,        ~acidAmp,
            \scBus,      ~scBus.index,      // lit le sidechain
            \scAmt,      ~acidScAmt,
        ));
        Pdef(\melodySeq, Pbind(
            \instrument, ~melodyInst, \dur, 0.25,
            \legato,   0.9,
            \type,     Pseq(~melodyNotes.collect { |n| if(n > 0) { \note } { \rest } }, inf),
            \midinote, Pseq(~melodyNotes.collect { |n| if(n > 0) { n } { 60 } }, inf),
            \cutoff,   ~melodyCutoff,
            \rq,       ~melodyRq,
            \attack,   ~melodyAttack,
            \release,  ~melodyRelease,
            \drive,    ~melodyDrive,
            \sawAmt,   ~melodySawAmt,
            \detune,      ~melodyDetune,
            \wobbleRate,  ~melodyWobbleRate,    // pour fmBell
            \wobbleDepth, ~melodyWobbleDepth,
            \wobbleShape, ~melodyWobbleShape,
            \subAmt,      ~melodySubAmt,
            \amp,         ~melodyAmp * ~melodyBoost,
            \scBus,       ~scBus.index,
            \scAmt,       ~leadScAmt,
        ));
        // 2e voix : peut tourner en parallele avec une duree differente
        // (32th, 16th, 8th) pour creer du contrepoint / phasing
        Pdef(\harmonySeq, Pbind(
            \instrument, ~harmonyInst, \dur, ~harmonyDur,
            \legato,   0.9,
            \type,     Pseq(~harmonyNotes.collect { |n| if(n > 0) { \note } { \rest } }, inf),
            \midinote, Pseq(~harmonyNotes.collect { |n| if(n > 0) { n } { 60 } }, inf),
            \cutoff,   ~harmonyCutoff,
            \rq,       ~harmonyRq,
            \attack,   ~harmonyAttack,
            \decay,    ~harmonyDecay,
            \sustain,  ~harmonySustain,
            \release,  ~harmonyRelease,
            \drive,    ~harmonyDrive,
            \detune,   ~harmonyDetune,
            \sawAmt,   ~harmonySawAmt,
            \amp,      ~harmonyAmp * ~melodyBoost,
            \scBus,    ~scBus.index,
            \scAmt,    ~leadScAmt,
        ));
    };

    // ----- ~enableHarmony : voir palette/harmonics/presets.scd ---
    // ----- Scales + helpers : voir palette/scales.scd ------------
    //   (charges automatiquement par 00_load.scd > CHARGER TOUT)

    "=== setup OK -- lance le bloc PLAY ===".postln;
};
)

