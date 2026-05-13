// =====================================================================
//  data_only/scenes.scd  --  Bibliotheque de scenes du patch data-only.
//
//  Prerequis :
//    - engine.scd + synthdefs.scd charges
//    - control/data_feeds.scd actif (~feeds, ~feedSub, ~poseKp...)
//
//  Selecteur :  ~doScene.(\name)
//
//  Scenes disponibles :
//    \cavity   Schumann x Netzfrequenz x Foudre
//    \geo      Kp x flares solaires x USGS magnitude
//    \body     pose YOLO : poignets/epaules pilotent filtre + grain
//    \weather  vent solaire pilote drone FM + Bz module reverb
//    \flight   chaque avion = voix FM courte (max ~max_planes)
//    \pulse    Bluesky rate -> kick, lightning -> snare, github -> hat
//    \quiet    drone Schumann seul, fade long (transition)
//    \all      cavity + geo + body (defaut audio)
//    \full     toutes les scenes empilees (max densite)
//    \stop     coupe tout
//
//  OSC :    /control/doScene <name>
// =====================================================================
(
// -- Etat global -----------------------------------------------
~doActivePriv = ~doActivePriv ? IdentityDictionary.new;

~doStopAll = {
    ~doActivePriv.keysValuesDo { |k, v| v.value };
    ~doActivePriv = IdentityDictionary.new;
};

// -- Helper : enregistre une scene avec sa fonction de cleanup --
~doRegisterPriv = { |name, killFn|
    ~doActivePriv[name] = killFn;
};

// =================================================================
//  SCENE : cavity
// =================================================================
~doSceneCavity = {
    var d, fmR, strikeSub;
    d = Synth(\do_drone, [\freq, 7.83, \amp, 0.22, \rev, 0.4]);
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
            Synth(\do_strike, [
                \freq, lat.linlin(-90, 90, 200, 3000),
                \pan,  lon.linlin(-180, 180, -1, 1),
                \amp,  mult.linlin(1, 10, 0.4, 0.8),
                \dur,  mult.linlin(1, 10, 0.2, 0.7),
                \rev,  0.6,
            ]);
        };
    });
    ~doRegisterPriv.(\cavity, {
        d.release(2); fmR.stop;
        ~feedUnsub.(\lightning_last, strikeSub);
    });
    "[scene] cavity ON".postln;
};

// =================================================================
//  SCENE : geo
// =================================================================
~doSceneGeo = {
    var g, kpR, flareSub, quakeSub;
    g = Synth(\do_geo, [\amp, 0.25]);
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
            "[scene] *** solar flare ***".postln;
        };
    });
    quakeSub = ~feedSub.(\usgs_last_mag, { |mag|
        Synth(\do_quake_sub, [
            \freq, mag.linexp(2, 7, 30, 120),
            \dur,  mag.linlin(2, 7, 1, 5),
            \amp,  mag.linlin(2, 7, 0.4, 0.85),
        ]);
    });
    ~doRegisterPriv.(\geo, {
        g.release(2); kpR.stop;
        ~feedUnsub.(\swpc_flare_norm, flareSub);
        ~feedUnsub.(\usgs_last_mag, quakeSub);
    });
    "[scene] geo ON".postln;
};

// =================================================================
//  SCENE : body (pose YOLO)
// =================================================================
~doSceneBody = {
    var drone, gran, r;
    drone = Synth(\do_body_drone, [\amp, 0.0]);
    gran  = Synth(\do_body_gran,  [\amp, 0.0]);
    r = Routine({
        inf.do {
            var wr = ~poseKp.(\wri_r);
            var wl = ~poseKp.(\wri_l);
            var sl = ~poseKp.(\sho_l), sR = ~poseKp.(\sho_r);
            var shoY, hasPerson = (~feedGet.(\pose_count, 0) >= 1);
            if(wr.notNil and: { wr.c > 0.3 }) {
                drone.set(\cutoff, wr.x.linexp(0, 1, 200, 6000));
                drone.set(\amp, if(hasPerson) {
                    (1 - wr.y).linlin(0, 1, 0.05, 0.4)
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
    ~doRegisterPriv.(\body, { drone.release(2); gran.release(1); r.stop });
    "[scene] body ON".postln;
};

// =================================================================
//  SCENE : weather (vent solaire + Bz)
// =================================================================
~doSceneWeather = {
    var w, r;
    w = Synth(\do_weather, [\freq, 110, \amp, 0.25, \pan, 0]);
    r = Routine({
        inf.do {
            var speed = ~feedGet.(\swpc_wind_speed, 400);
            var dens  = ~feedGet.(\swpc_wind_dens,  5);
            var bz    = ~feedGet.(\swpc_bz, 0);
            w.set(\freq, speed.linexp(280, 800, 55, 220));
            w.set(\mod,  dens.linlin(0, 30, 0.8, 3.5));
            w.set(\amp,  0.2 + (dens.linlin(0, 30, 0, 0.2)));
            // Bz negatif (orage geomag potentiel) -> plus de reverb
            w.set(\rev,  bz.linlin(-15, 15, 0.85, 0.25).clip(0.1, 0.95));
            2.0.wait;
        };
    }).play(AppClock);
    ~doRegisterPriv.(\weather, { w.release(3); r.stop });
    "[scene] weather ON".postln;
};

// =================================================================
//  SCENE : flight (chaque avion = note)
// =================================================================
~doSceneFlight = {
    var planeSub, count = 0, maxConcurrent = 8;
    planeSub = ~feedSub.(\aviation_last, { |val|
        var icao = val[0], lon = val[1], lat = val[2],
            alt = val[3], vel = val[4], head = val[5];
        var midinote, pan;
        if(count < maxConcurrent) {
            count = count + 1;
            // alt -> note ; vel -> modIdx ; lon -> pan ; heading -> dur
            midinote = alt.linlin(0, 12000, 36, 84).clip(24, 96);
            pan = lon.linlin(4.6, 5.2, -1, 1).clip(-1, 1);
            Synth(\do_plane, [
                \freq,   midinote.midicps,
                \pan,    pan,
                \modIdx, vel.linlin(50, 300, 0.5, 4),
                \dur,    head.linlin(0, 360, 1.0, 3.5),
                \amp,    vel.linlin(50, 300, 0.1, 0.25),
            ]);
            AppClock.sched(3.5, { count = count - 1; nil });
        };
    });
    ~doRegisterPriv.(\flight, { ~feedUnsub.(\aviation_last, planeSub) });
    "[scene] flight ON".postln;
};

// =================================================================
//  SCENE : pulse (Bluesky + lightning + github)
// =================================================================
~doScenePulse = {
    var kickR, lastKick = 0, lightningSub, ghSub;
    // Kick si pic de posts (>5 posts/s)
    kickR = Routine({
        inf.do {
            var rate = ~feedGet.(\social_rate_s, 0);
            var now = SystemClock.seconds;
            if((rate > 5) and: { (now - lastKick) > 0.5 }) {
                Synth(\do_kick, [\amp, rate.linlin(5, 50, 0.4, 0.8)]);
                lastKick = now;
            };
            0.25.wait;
        };
    }).play(AppClock);
    // Lightning multiplicity -> snare-like via strike avec rev haut
    lightningSub = ~feedSub.(\lightning_last, { |val|
        var mult = val[3];
        if(mult >= 2) {
            Synth(\do_strike, [
                \freq, 1800, \pan, 0,
                \amp,  0.4, \dur, 0.15, \rev, 0.85,
            ]);
        };
    });
    // GitHub events -> hat
    ghSub = ~feedSub.(\gh_last_type, { |v|
        Synth(\do_hat, [
            \amp, 0.2,
            \pan, (v / 65535 * 2 - 1).clip(-1, 1),
        ]);
    });
    ~doRegisterPriv.(\pulse, {
        kickR.stop;
        ~feedUnsub.(\lightning_last, lightningSub);
        ~feedUnsub.(\gh_last_type, ghSub);
    });
    "[scene] pulse ON".postln;
};

// =================================================================
//  SCENE : quiet (drone seul, fade long)
// =================================================================
~doSceneQuiet = {
    var d = Synth(\do_drone, [\freq, 7.83, \amp, 0.12, \rev, 0.8]);
    ~doRegisterPriv.(\quiet, { d.release(8) });
    "[scene] quiet ON".postln;
};

// =================================================================
//  SCENE : live_pose
//  Pilotee par le pont sonore de data_only_viz (/pose/*).
//  Hauteur du nez -> pitch, poignets -> cutoff/grain, envergure -> verb
// =================================================================
~doSceneLivePose = {
    var voice, gran, pulse, kickR, lastKick = 0;
    var subCenter, subHead, subWristL, subWristR, subSpan, subShoSpan;
    voice = Synth(\do_weather, [\freq, 110, \amp, 0.0, \rev, 0.5]);
    gran  = Synth(\do_body_gran, [\dens, 8, \rate, 1.0, \amp, 0.0]);

    // /pose/head <pid> <x> <y> <c> -> voix : y -> pitch, x -> pan
    subHead = ~feedSub.(\pose_head, { |val|
        var pid = val[0], x = val[1], y = val[2], c = val[3];
        voice.set(
            \freq, y.linexp(0, 1, 440, 65),
            \pan,  x.linlin(0, 1, -1, 1),
            \amp,  c.linlin(0, 1, 0, 0.25),
        );
    });
    // /pose/wrist <pid> <l|r> <x> <y> -> filtre + grain
    subWristL = ~feedSub.(\pose_wrist_l, { |val|
        var pid = val[0], x = val[1], y = val[2];
        gran.set(\dens, (1 - y).linexp(0, 1, 3, 80));
        gran.set(\amp, 0.18);
    });
    subWristR = ~feedSub.(\pose_wrist_r, { |val|
        var pid = val[0], x = val[1], y = val[2];
        voice.set(\mod, (1 - y).linlin(0, 1, 0.5, 3.5));
        gran.set(\rate, x.linlin(0, 1, 0.5, 2.5));
    });
    // /pose/limb_span -> envoi reverb
    subSpan = ~feedSub.(\pose_limb_span, { |val|
        var pid = val[0], span = val[1];
        voice.set(\rev, span.linlin(0, 1.2, 0.2, 0.85));
    });
    // /pose/sho_span -> proxy distance camera (large = proche)
    subShoSpan = ~feedSub.(\pose_sho_span, { |val|
        var pid = val[0], dx = val[1];
        voice.set(\amp, dx.linlin(0.05, 0.35, 0.10, 0.35));
    });
    // /pose/count -> kick aux apparitions
    subCenter = ~feedSub.(\pose_count, { |n|
        var now = SystemClock.seconds;
        if((n > 0) and: { (now - lastKick) > 1.0 }) {
            Synth(\do_kick, [\amp, n.linlin(1, 4, 0.3, 0.7)]);
            lastKick = now;
        };
    });

    ~doRegisterPriv.(\live_pose, {
        voice.release(2); gran.release(1);
        ~feedUnsub.(\pose_head, subHead);
        ~feedUnsub.(\pose_wrist_l, subWristL);
        ~feedUnsub.(\pose_wrist_r, subWristR);
        ~feedUnsub.(\pose_limb_span, subSpan);
        ~feedUnsub.(\pose_sho_span, subShoSpan);
        ~feedUnsub.(\pose_count, subCenter);
    });
    "[scene] live_pose ON  (drive par /pose/*)".postln;
};

// =================================================================
//  Selecteur
// =================================================================
~doScene = { |name|
    var n = name.asSymbol;
    ~doStopAll.value;
    switch(n,
        \stop,    { "[scene] all stopped".postln },
        \cavity,  { ~doSceneCavity.value },
        \geo,     { ~doSceneGeo.value },
        \body,    { ~doSceneBody.value },
        \weather, { ~doSceneWeather.value },
        \flight,  { ~doSceneFlight.value },
        \pulse,   { ~doScenePulse.value },
        \quiet,   { ~doSceneQuiet.value },
        \live_pose, { ~doSceneLivePose.value },
        \all,     {
            ~doSceneCavity.value;
            ~doSceneGeo.value;
            ~doSceneBody.value;
        },
        \full,    {
            ~doSceneCavity.value;
            ~doSceneGeo.value;
            ~doSceneBody.value;
            ~doSceneWeather.value;
            ~doSceneFlight.value;
            ~doScenePulse.value;
        },
        { ("[scene] unknown: " ++ name).warn }
    );
    // Notifie le visualizer oF du nom de scene courant (overlay HUD)
    NetAddr("127.0.0.1", 57123).sendMsg("/sync/album", n.asString);
};

// -- OSC remote -----------------------------------------------
OSCdef(\do_scene).free;
OSCdef(\do_scene, { |msg|
    var name = msg[1] ? \all;
    AppClock.sched(0, { ~doScene.(name); nil });
}, '/control/doScene');

"[data-only/scenes] 9 scenes available : \\cavity \\geo \\body \\weather \\flight \\pulse \\quiet \\all \\full \\stop".postln;
"[data-only/scenes] OSC : /control/doScene <\\name>".postln;
)
