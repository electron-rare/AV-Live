// =====================================================================
//  synth/drums/kick.scd  --  SynthDef \kick
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
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
)
