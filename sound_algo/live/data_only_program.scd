// =====================================================================
//  live/data_only_program.scd  --  Programme musical pilote ENTIEREMENT
//  par les flux data_feeds (open-data + pose YOLO). Pas de tracks Pdef,
//  pas d'album : la musique est generee en reaction aux signaux du
//  monde reel.
//
//  Prerequis (deja faits par boot.data-only.scd) :
//    - engine + setupAll
//    - control/data_feeds.scd charge (OSCdef + dict ~feeds)
//    - pont Python data_feeds en train d'emettre
//
//  Scenes disponibles :
//    ~dataScene.(\cavity)    -- Schumann x Netzfrequenz x Foudre
//    ~dataScene.(\geo)       -- Kp x flares x USGS earthquakes
//    ~dataScene.(\body)      -- pose YOLO : poignets + epaules
//    ~dataScene.(\all)       -- les trois empilees (defaut)
//    ~dataScene.(\stop)      -- coupe tout
//
//  OSC entrant compris :
//    /control/dataScene <name>  -- bascule de scene
//
//  Le fichier est idempotent : on peut le recharger sans accumuler.
// =====================================================================
(
// -- Liberation propre des etats precedents --------------------------
~dataStopAll = ~dataStopAll ? { };
~dataStopAll.value;
~dataStopAll = {
    ~dataActivePriv ? IdentityDictionary.new
        keysValuesDo: { |k, v| v.value };
    ~dataActivePriv = IdentityDictionary.new;
};
~dataActivePriv = ~dataActivePriv ? IdentityDictionary.new;

// -- SynthDefs dedies ------------------------------------------------
SynthDef(\dop_drone, { |out=0, freq=7.83, amp=0.22, fm=0, pan=0|
    var harm = freq * [1, 2, 3, 4, 5];
    var amps = [1, 0.5, 0.33, 0.25, 0.2];
    var sig = SinOsc.ar(harm + fm.lag(0.05), 0, amps).sum;
    sig = sig + (LFTri.ar(freq * 0.5) * 0.1);
    sig = LeakDC.ar(sig).tanh * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

SynthDef(\dop_strike, { |out=0, freq=400, amp=0.5, pan=0, dur=0.4|
    var env = EnvGen.kr(Env.perc(0.001, dur), doneAction: 2);
    var sig = WhiteNoise.ar * env;
    sig = BPF.ar(sig, freq, 0.05) * 6;
    sig = sig + (SinOsc.ar(freq, 0, env * 0.5));
    Out.ar(out, Pan2.ar(sig.tanh * amp, pan));
}).add;

SynthDef(\dop_geo, { |out=0, freq=200, amp=0.25, bw=0.4|
    var sig = Mix(Saw.ar([55, 110, 165]));
    sig = BPF.ar(sig, freq.lag(0.3).clip(80, 6000), bw.lag(0.3).clip(0.05, 1));
    sig = sig * 1.5;
    Out.ar(out, Splay.ar([sig, DelayN.ar(sig, 0.05, 0.03)]) * amp);
}).add;

SynthDef(\dop_quake_sub, { |out=0, freq=40, amp=0.7, dur=2|
    var env = EnvGen.kr(Env.perc(0.05, dur, 1, -2), doneAction: 2);
    var sig = SinOsc.ar(freq) * env;
    sig = sig + (LFTri.ar(freq * 0.5) * env * 0.3);
    sig = sig.tanh * amp;
    Out.ar(out, Pan2.ar(sig, 0));
}).add;

SynthDef(\dop_body_drone, { |out=0, freq=80, amp=0.25, cutoff=800, q=0.4, pan=0|
    var sig = Saw.ar(freq * [1, 1.005, 0.503]);
    sig = RLPF.ar(sig, cutoff.lag(0.05).clip(80, 8000), q);
    sig = sig.sum * amp;
    Out.ar(out, Pan2.ar(sig, pan));
}).add;

SynthDef(\dop_body_gran, { |out=0, dens=10, rate=1.0, amp=0.3|
    var trig = Impulse.kr(dens);
    var grain = SinOsc.ar(
        TRand.kr(200, 1200, trig) * rate.lag(0.1),
        0,
        EnvGen.kr(Env.perc(0.005, 0.05), trig)
    );
    Out.ar(out, Pan2.ar(grain * amp, TRand.kr(-1, 1, trig)));
}).add;

// -- Scene CAVITY ----------------------------------------------------
~dataSceneCavity = {
    var d, fmR, strikeSub, kill;
    d = Synth(\dop_drone, [\freq, 7.83, \amp, 0.22]);
    fmR = Routine({
        inf.do {
            var dev = ~feedGet.(\netz_dev, 0);
            d.set(\fm, dev * 80);
            0.1.wait;
        };
    }).play(AppClock);
    strikeSub = ~feedSub.(\lightning_last, { |val|
        var lat = val[0], lon = val[1], age = val[2], mult = val[3];
        if(age < 30) {
            Synth(\dop_strike, [
                \freq, lat.linlin(-90, 90, 200, 3000),
                \pan,  lon.linlin(-180, 180, -1, 1),
                \amp,  mult.linlin(1, 10, 0.4, 0.9),
                \dur,  mult.linlin(1, 10, 0.2, 0.8),
            ]);
        };
    });
    kill = {
        d.release(2); fmR.stop;
        ~feedUnsub.(\lightning_last, strikeSub);
    };
    ~dataActivePriv[\cavity] = kill;
    "[data-only] cavity ON".postln;
};

// -- Scene GEO -------------------------------------------------------
~dataSceneGeo = {
    var g, kpR, flareSub, quakeSub, kill;
    g = Synth(\dop_geo, [\amp, 0.25]);
    kpR = Routine({
        inf.do {
            var kp = ~feedGet.(\swpc_kp, 2);
            g.set(\freq, kp.linexp(0, 9, 200, 3000));
            g.set(\bw,   kp.linlin(0, 9, 0.5, 0.05));
            5.0.wait;
        };
    }).play(AppClock);
    flareSub = ~feedSub.(\swpc_flare_norm, { |v|
        if(v > 0.5) {
            g.set(\amp, 0.6);
            AppClock.sched(3.0, { g.set(\amp, 0.25); nil });
            "[data-only] *** solar flare ***".postln;
        };
    });
    quakeSub = ~feedSub.(\usgs_last_mag, { |mag|
        Synth(\dop_quake_sub, [
            \freq, mag.linexp(2, 7, 30, 120),
            \dur,  mag.linlin(2, 7, 1, 5),
            \amp,  mag.linlin(2, 7, 0.4, 0.9),
        ]);
    });
    kill = {
        g.release(2); kpR.stop;
        ~feedUnsub.(\swpc_flare_norm, flareSub);
        ~feedUnsub.(\usgs_last_mag, quakeSub);
    };
    ~dataActivePriv[\geo] = kill;
    "[data-only] geo ON".postln;
};

// -- Scene BODY (pose YOLO) -----------------------------------------
~dataSceneBody = {
    var drone, gran, r, kill;
    drone = Synth(\dop_body_drone, [\amp, 0.0]);
    gran  = Synth(\dop_body_gran,  [\amp, 0.0]);
    r = Routine({
        inf.do {
            var wr = ~poseKp.(\wri_r);
            var wl = ~poseKp.(\wri_l);
            var sl = ~poseKp.(\sho_l), sR = ~poseKp.(\sho_r);
            var shoY, hasPerson = (~feedGet.(\pose_count, 0) >= 1);
            if(wr.notNil and: { wr.c > 0.3 }) {
                drone.set(\cutoff, wr.x.linexp(0, 1, 200, 6000));
                drone.set(\amp, if(hasPerson) {
                    (1 - wr.y).linlin(0, 1, 0.05, 0.45)
                } { 0 });
            };
            if(wl.notNil and: { wl.c > 0.3 }) {
                drone.set(\freq, wl.y.linexp(0, 1, 220, 55));
            };
            if(sl.notNil and: { sR.notNil }) {
                shoY = (sl.y + sR.y) * 0.5;
                gran.set(\dens, (1 - shoY).linexp(0, 1, 2, 80));
                gran.set(\rate, (1 - shoY).linlin(0, 1, 0.5, 2.5));
                gran.set(\amp, if(hasPerson) { 0.15 } { 0 });
            };
            0.05.wait;
        };
    }).play(AppClock);
    kill = { drone.release(2); gran.release(1); r.stop };
    ~dataActivePriv[\body] = kill;
    "[data-only] body ON".postln;
};

// -- Selecteur ------------------------------------------------------
~dataScene = { |name|
    var n = name.asSymbol;
    ~dataStopAll.value;
    switch(n,
        \stop,   { "[data-only] all scenes stopped".postln },
        \cavity, { ~dataSceneCavity.value },
        \geo,    { ~dataSceneGeo.value },
        \body,   { ~dataSceneBody.value },
        \all,    { ~dataSceneCavity.value; ~dataSceneGeo.value; ~dataSceneBody.value },
        { ("[data-only] scene inconnue : " ++ name).warn }
    );
};

// -- OSC remote control --------------------------------------------
OSCdef(\dop_scene).free;
OSCdef(\dop_scene, { |msg|
    var name = msg[1];
    if(name.isNil) { name = \all };
    AppClock.sched(0, { ~dataScene.(name); nil });
}, '/control/dataScene');

// -- HUD periodique : statut des flux + son ------------------------
~dataStatusRPriv !? { ~dataStatusRPriv.stop };
~dataStatusRPriv = Routine({
    inf.do {
        var alive = ~feedAlive.value;
        ("[data-only] bridge=" ++ if(alive) {"OK"} {"DOWN"} ++
            "  kp=" ++ ~feedGet.(\swpc_kp, 0).round(0.1).asString ++
            "  netz_dev=" ++ ~feedGet.(\netz_dev, 0).round(0.001).asString ++
            "  lightning/min=" ++ ~feedGet.(\lightning_rate_min, 0).round(0.1).asString ++
            "  planes=" ++ ~feedGet.(\aviation_count, 0).asInteger.asString ++
            "  pose=" ++ ~feedGet.(\pose_count, 0).asInteger.asString
        ).postln;
        15.0.wait;
    };
}).play(AppClock);

"[data-only] program loaded. Scenes: \\cavity \\geo \\body \\all \\stop".postln;
"[data-only] OSC remote : /control/dataScene <\\all|\\cavity|...>".postln;
)
