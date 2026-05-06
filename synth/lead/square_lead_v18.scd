// synth/lead/square_lead_v18.scd  --  SynthDef \square_lead_v18  // variation square_lead pulse PWM
(
SynthDef(\square_lead_v18, {
    arg freq = 220, gate = 1, pwmRate = 6.0, pwmDepth = 0.2,
        cutoff = 4000, rq = 0.6,
        attack = 0.01, decay = 0.3, sustain = 0.7, release = 0.5,
        drive = 1.5, amp = 0.18, pan = 0,
        scBus = 0, scAmt = 0.4;
    var sig, env, pwm, duck;
    pwm = SinOsc.kr(pwmRate).range(0.5 - pwmDepth, 0.5 + pwmDepth);
    sig = Pulse.ar(freq.clip(20, 8000), pwm);
    sig = RLPF.ar(sig, cutoff, rq);
    env = EnvGen.kr(Env.adsr(attack, decay, sustain, release), gate, doneAction: 2);
    sig = (sig * drive).tanh / drive.sqrt;
    duck = 1 - (In.kr(scBus, 1) * scAmt);
    Out.ar(0, Pan2.ar(sig * env * amp * duck, pan));
}).add;
)
