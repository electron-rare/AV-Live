// =====================================================================
//  fx/bus/fx_tape.scd  --  SynthDef \fxTape
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
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
)
