// =====================================================================
//  data_only/scene_pose_play.scd -- le corps joue de la musique.
//  Action -> mode, main D -> lead (geste), main G -> accord (arpege),
//  vitesse du corps -> tempo. Active via ~doScene.(\play).
// =====================================================================
(
// -- 1. Table des modes -------------------------------------------------
~bpModes = (
    ambient: (label: 1, name: "ambient",
        scale: [0,2,3,5,7,8,10], root: 45, tempoLo: 56, tempoHi: 80,
        kick: false, hatMul: 0.5),
    pulse:   (label: 0, name: "pulse",
        scale: [0,2,4,7,9],      root: 57, tempoLo: 88, tempoHi: 120,
        kick: true,  hatMul: 1.0),
    drive:   (label: 2, name: "drive",
        scale: [0,2,3,5,7,9,10], root: 55, tempoLo: 118, tempoHi: 150,
        kick: true,  hatMul: 1.6),
);

~bpModeForLabel = { |labelIdx|
    switch(labelIdx,
        0, \pulse, 1, \ambient, 2, \drive, \pulse);  // defaut pulse
};

// -- 2. Quantification sur l'echelle du mode ---------------------------
// pos01 (0..1) -> degre sur l'echelle, etale sur `octaves` octaves depuis
// la root du mode. Renvoie une midinote.
~bpScale = { |modeKey, pos01, octaves=2|
    var m = ~bpModes[modeKey];
    var scale = m[\scale];
    var nDeg = scale.size * octaves;
    var idx = (pos01.clip(0, 1) * (nDeg - 1)).round.asInteger;
    var oct = idx div: scale.size;
    var deg = idx % scale.size;
    m[\root] + (oct * 12) + scale[deg];
};

// -- 3. Mapping pose -> musique -- fonctions pures ----------------------
~bpMap = ();

~bpMap[\tempo] = { |modeKey, speed|
    var m = ~bpModes[modeKey];
    (speed ? 0).linlin(0.0, 0.6, m[\tempoLo], m[\tempoHi]).clip(m[\tempoLo], m[\tempoHi]);
};

~bpMap[\leadNote] = { |modeKey, hf|
    ~bpScale.(modeKey, (hf[\ry] ? 0), 2);
};

~bpMap[\leadTrig] = { |hf, lastTrigTime, now|
    ((hf[\rspeed] ? 0) > 0.12) and: { (now - lastTrigTime) > 0.09 };
};

// 4 triades diatoniques I/IV/V/vi construites sur l'echelle du mode.
~bpMap[\chordDegrees] = { |modeKey, hf|
    var m = ~bpModes[modeKey];
    var sc = m[\scale];
    var roots = [0, 3, 4, 5];                      // index de degre des 4 accords
    var ci = ((hf[\ly] ? 0).clip(0,1) * 3).round.asInteger;  // main G hauteur -> accord
    var base = roots[ci];
    var octShift = ((hf[\lopen] ? 0) > 0.5).if({ 12 }, { 0 });
    [0, 2, 4].collect { |step|
        var d = base + step;
        m[\root] + ((d div: sc.size) * 12) + sc[d % sc.size] + octShift;
    };
};

~bpMap[\density] = { |modeKey, speed|
    var m = ~bpModes[modeKey];
    (((speed ? 0).linlin(0.0, 0.6, 1, 4) * m[\hatMul]).round.asInteger).clip(1, 4);
};

// -- 5) Helpers corps unique -------------------------------------------
~bpFirstBody = {
    var kin = ~poseKin.notNil.if({ ~poseKin.values.detect { |v| v.notNil } });
    var st  = ~poseState.notNil.if({ ~poseState.values.detect { |v| v.notNil } });
    (kin: kin, state: st);
};

// -- 6) Le moteur -------------------------------------------------------
~bpCtlDur = 0.05;  // periode du tick de controle, en BEATS (la routine tourne sur le TempoClock)
~bpEngine = (
    running: false, clock: nil, mode: \pulse, verbose: false,
    pad: nil, chord: [57, 60, 64], lastLead: 0.0, arpStep: 0,
    modeCand: \pulse, modeStable: 0, tempoSm: 100.0, routine: nil,
    start: {
        if(~bpEngine[\running]) { "[bp] deja en cours".postln } {
            ~bpEngine[\running] = true;
            ~bpEngine[\clock] = TempoClock(100/60).permanent_(true);
            ~bpEngine[\pad] = Synth(\bp_pad, [\freq, ~bpModes[\pulse][\root].midicps, \amp, 0.0]);
            ~bpEngine[\routine] = Routine({
                var beatCount = 0;
                inf.do {
                    var b = ~bpFirstBody.value;
                    var hasBody = b[\kin].notNil;
                    var label = (b[\state] ? ()).at(\labelIdx);
                    var speed = (b[\kin] ? ()).at(\speed) ? 0;
                    var modeKey = ~bpModeForLabel.(label);
                    var m, now, hf, tgtTempo;
                    // -- mode stability guard + cross-fade --
                    if(modeKey == ~bpEngine[\modeCand]) {
                        ~bpEngine[\modeStable] = ~bpEngine[\modeStable] + 1;
                    } { ~bpEngine[\modeCand] = modeKey; ~bpEngine[\modeStable] = 0; };
                    if((~bpEngine[\modeStable] == 5) and: { modeKey != ~bpEngine[\mode] }) {
                        ~bpEngine[\mode] = modeKey;
                        ~bpEngine[\pad].set(\gate, 0);   // fade out ancien pad
                        ~bpEngine[\pad] = Synth(\bp_pad, [
                            \freq, ~bpModes[modeKey][\root].midicps, \amp, 0.18]);
                        if(~bpEngine[\verbose]) { ("[bp] mode -> " ++ modeKey).postln };
                    };
                    m = ~bpModes[~bpEngine[\mode]];
                    // -- tempo lisse (~2s) puis clock --
                    tgtTempo = ~bpMap[\tempo].(~bpEngine[\mode], speed);
                    ~bpEngine[\tempoSm] = ~bpEngine[\tempoSm]
                        + ((tgtTempo - ~bpEngine[\tempoSm]) * 0.03);
                    ~bpEngine[\clock].tempo = ~bpEngine[\tempoSm] / 60;
                    // -- pad: silence si pas de corps --
                    ~bpEngine[\pad].set(\amp, hasBody.if({ 0.18 }, { 0.06 }));
                    // -- lead (main D au geste) --
                    hf = ~handFeat ? ();
                    now = thisThread.seconds;
                    if(hasBody and: { ~bpMap[\leadTrig].(hf, ~bpEngine[\lastLead], now) }) {
                        ~bpEngine[\lastLead] = now;
                        Synth(\bp_lead, [
                            \freq, ~bpMap[\leadNote].(~bpEngine[\mode], hf).midicps,
                            \amp, (hf[\rspeed] ? 0).linlin(0.12, 0.6, 0.15, 0.4),
                            \cutoff, (hf[\ropen] ? 0).linexp(0, 1, 600, 5000),
                            \pan, (hf[\rx] ? 0.5).linlin(0, 1, -0.8, 0.8)]);
                    };
                    // -- accord courant (main G) --
                    if(hasBody) { ~bpEngine[\chord] = ~bpMap[\chordDegrees].(~bpEngine[\mode], hf) };
                    // -- sequence rythmique sur le beat (toutes les ~1 noire) --
                    if((beatCount % (0.25 / ~bpCtlDur).round.max(1)) == 0) {
                        var dens = ~bpMap[\density].(~bpEngine[\mode], speed);
                        if(hasBody) {
                            // arpege : note suivante de l'accord
                            ~bpEngine[\arpStep] = (~bpEngine[\arpStep] + 1) % ~bpEngine[\chord].size;
                            Synth(\bp_arp, [\freq, ~bpEngine[\chord][~bpEngine[\arpStep]].midicps]);
                            // hats selon densite
                            dens.do { |i| Synth(\bp_hat, [\amp, 0.18, \pan, 0.3.rand2]) };
                            // kick + bass selon le mode
                            if(m[\kick] and: { (beatCount % (1.0 / ~bpCtlDur).round.max(1)) == 0 }) {
                                Synth(\bp_kick);
                                Synth(\bp_bass, [\freq, (~bpEngine[\chord][0] - 12).midicps]);
                            };
                        };
                    };
                    beatCount = beatCount + 1;
                    ~bpCtlDur.wait;
                };
            }).play(~bpEngine[\clock]);
            "[bp] STARTED".postln;
        };
    },
    stop: {
        ~bpEngine[\routine] !? { |r| r.stop };
        ~bpEngine[\pad] !? { |p| p.set(\gate, 0) };
        ~bpEngine[\clock] !? { |c| c.stop };
        ~bpEngine[\clock] = nil;
        ~bpEngine[\running] = false;
        "[bp] STOPPED".postln;
    },
);

// -- 7) Enregistrement scene -------------------------------------------
~doScenePlay = { ~bpEngine[\start].(); ~doRegisterPriv.(\play, { ~bpEngine[\stop].() }) };

"[data-only/scene_pose_play] modes + scale ready".postln;
)
