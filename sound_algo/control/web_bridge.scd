// =====================================================================
//  control/web_bridge.scd
//
//  Pont OSC bidirectionnel SC <-> web data-only.
//
//   Web (data_only_viz/web)
//      |
//      |  /control/master_gain f   /control/cutoff f   /control/reso f
//      |  /control/reverb_mix  f   /control/delay_time f
//      |  /control/delay_feedback f /control/tempo i
//      |  /scene/play  s     (cavity|geo|body|...|stop)
//      |  /xy/x  f           /xy/y  f
//      v
//   sclang (ici) -> applique sur ~dataScene + Server params + ~xyControl
//
//   sclang (tick 4 Hz) ->
//      /sync/bpm    f
//      /sync/beat   i
//      /sync/rms    f
//      /sync/voices i
//      ->  vers webOSC (127.0.0.1:57125)
//
//  Charge depuis boot.data-only.scd apres data_feeds.scd.
// =====================================================================
(
"[web_bridge] starting".postln;

// ---- destination web pour sync ----
~webOSC = NetAddr("127.0.0.1", 57125);

// ---- helpers --------------------------------------------------------
~webBridgeDef = { |key, path, fn|
    OSCdef(key).free;
    OSCdef(key, fn, path);
};

// ---- state shared with dataScene / synths ---------------------------
~webState = (
    masterGain: 0.8,
    cutoff: 1200.0,
    reso: 0.3,
    reverbMix: 0.25,
    delayTime: 0.3,
    delayFeedback: 0.4,
    tempo: 120.0,
    xyX: 0.5,
    xyY: 0.5,
);

// Applique master gain sur le main out group si dispo
~applyMasterGain = { |g|
    ~webState[\masterGain] = g;
    if(~mainGroup.notNil) {
        ~mainGroup.set(\amp, g);
    };
    if(s.notNil and: { s.serverRunning }) {
        s.volume.volume = (g.linlin(0, 1, -60, 6));
    };
};

~applyCutoff = { |hz|
    ~webState[\cutoff] = hz;
    if(~fxGroup.notNil) {
        ~fxGroup.set(\lpf, hz);
    };
};

~applyReso = { |q|
    ~webState[\reso] = q;
    if(~fxGroup.notNil) {
        ~fxGroup.set(\reso, q);
    };
};

~applyReverbMix = { |mix|
    ~webState[\reverbMix] = mix;
    if(~fxGroup.notNil) {
        ~fxGroup.set(\reverbMix, mix);
    };
};

~applyDelayTime = { |sec|
    ~webState[\delayTime] = sec;
    if(~fxGroup.notNil) {
        ~fxGroup.set(\delayTime, sec);
    };
};

~applyDelayFeedback = { |fb|
    ~webState[\delayFeedback] = fb;
    if(~fxGroup.notNil) {
        ~fxGroup.set(\delayFeedback, fb);
    };
};

~applyTempo = { |bpm|
    ~webState[\tempo] = bpm;
    if(TempoClock.default.notNil) {
        TempoClock.default.tempo_(bpm / 60.0);
    };
};

~applyXY = {
    var x = ~webState[\xyX], y = ~webState[\xyY];
    // Mappings par defaut :
    //   x -> filter cutoff modulation (additive autour de la valeur slider)
    //   y -> reverb mix modulation
    if(~fxGroup.notNil) {
        ~fxGroup.set(\xyMod, x * 1.0 + y * 0.0,
                     \xyMod2, y);
    };
};

// ---- /control/* : sliders synth + mix -------------------------------
~webBridgeDef.(\webMasterGain,  "/control/master_gain",
    { |m| ~applyMasterGain.(m[1].asFloat) });
~webBridgeDef.(\webCutoff,      "/control/cutoff",
    { |m| ~applyCutoff.(m[1].asFloat) });
~webBridgeDef.(\webReso,        "/control/reso",
    { |m| ~applyReso.(m[1].asFloat) });
~webBridgeDef.(\webReverbMix,   "/control/reverb_mix",
    { |m| ~applyReverbMix.(m[1].asFloat) });
~webBridgeDef.(\webDelayTime,   "/control/delay_time",
    { |m| ~applyDelayTime.(m[1].asFloat) });
~webBridgeDef.(\webDelayFeedback,"/control/delay_feedback",
    { |m| ~applyDelayFeedback.(m[1].asFloat) });
~webBridgeDef.(\webTempo,       "/control/tempo",
    { |m| ~applyTempo.(m[1].asFloat) });

// ---- /scene/play : bascule scene audio ------------------------------
~webBridgeDef.(\webScenePlay,   "/scene/play",
    { |m|
        var name = m[1].asSymbol;
        ("[web_bridge] /scene/play " ++ name).postln;
        if(~dataScene.notNil) {
            ~dataScene.(name);
        };
    });

// ---- /xy/* : pad XY pour FX modulation ------------------------------
~webBridgeDef.(\webXyX, "/xy/x",
    { |m| ~webState[\xyX] = m[1].asFloat; ~applyXY.() });
~webBridgeDef.(\webXyY, "/xy/y",
    { |m| ~webState[\xyY] = m[1].asFloat; ~applyXY.() });

// ---- Sync SC -> web : pousse BPM / beat / RMS / voices toutes 250 ms
~webSyncRoutine.stop;
~webSyncRoutine = Routine({
    var beat = 0;
    inf.do {
        var bpm = TempoClock.default.tempo * 60.0;
        ~webOSC.sendMsg("/sync/bpm", bpm);
        ~webOSC.sendMsg("/sync/beat", beat);
        // RMS courant : si ~rmsBus dispo on lit, sinon 0
        if(~rmsLevel.notNil) {
            ~webOSC.sendMsg("/sync/rms", ~rmsLevel.value.asFloat);
        };
        // Voices actives : taille du group main (best-effort)
        if(~mainGroup.notNil) {
            // SC ne donne pas un count direct, on utilise ~activeVoiceCount
            // si defini ailleurs
            ~webOSC.sendMsg("/sync/voices",
                            (~activeVoiceCount.value ? 0).asInteger);
        };
        beat = beat + 1;
        0.25.wait;
    };
}).play(AppClock);

"[web_bridge] OSCdef installes : /control/* /scene/* /xy/*".postln;
"[web_bridge] sync push -> 127.0.0.1:57125 a 4 Hz".postln;
)
