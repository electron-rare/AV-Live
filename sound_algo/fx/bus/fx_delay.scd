// =====================================================================
//  fx/bus/fx_delay.scd  --  SynthDef \fxDelay
//  Extracted from fx_bus.scd during v2 reorganization.
// =====================================================================
(
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
)
