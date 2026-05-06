// =====================================================================
//  fx/trick/scratch.scd  --  SynthDef \scratch
//  Extracted from authentic.scd during v2 reorganization.
// =====================================================================
(
SynthDef(\scratch, {
    arg dur = 0.5, freq = 800, sweepDir = 1, amp = 0.3, pan = 0;
    var sig, env, sweepFreq;
    sweepFreq = Select.kr(sweepDir > 0, [
        Line.kr(freq * 2, freq * 0.5, dur),
        Line.kr(freq * 0.5, freq * 2, dur)
    ]);
    sig = (SinOsc.ar(sweepFreq) * 0.5) +
          (HPF.ar(WhiteNoise.ar, sweepFreq * 0.8) * 0.3);
    sig = sig * LFPulse.kr(20).range(0.3, 1);   // stutter
    env = EnvGen.kr(Env.linen(0.005, dur, 0.02), doneAction: 2);
    Out.ar(0, Pan2.ar(sig * env * amp, pan));
}).add;
)
