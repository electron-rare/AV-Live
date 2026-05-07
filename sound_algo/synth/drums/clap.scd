// =====================================================================
//  synth/drums/clap.scd  --  SynthDef \clap
//  Extracted from engine.scd during v2 reorganization.
// =====================================================================
(
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
)
