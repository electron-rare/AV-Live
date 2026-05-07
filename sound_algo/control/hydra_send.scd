// SC → Hydra OSC bridge demo
// 1. Lance le bridge dans un terminal: hydra-sc-bridge
// 2. Ouvre https://hydra.ojack.xyz/ et colle hydra_patch.js
// 3. Évalue ce code dans scide

(
s.waitForBoot {
    SynthDef(\hydraSend, {
        var in, fft, rms, centroid, flatness;
        in = SoundIn.ar(0) + WhiteNoise.ar(0.1);
        fft = FFT(LocalBuf(2048), in);
        rms = Amplitude.kr(in, 0.01, 0.3);
        centroid = SpecCentroid.kr(fft).cpsmidi.linlin(20, 127, 0, 1);
        flatness = SpecFlatness.kr(fft);
        SendReply.kr(Impulse.kr(30), '/hydra', [rms, centroid, flatness]);
        Out.ar(0, in.dup);
    }).add;

    s.sync;

    // Forward SendReply → OSC bridge (default port 8000)
    OSCdef(\hydraFwd, { |msg|
        NetAddr("127.0.0.1", 8000).sendMsg("/rms", msg[3], msg[4], msg[5]);
    }, '/hydra');

    Synth(\hydraSend);
    "=> SC → Hydra bridge actif".postln;
};
)
