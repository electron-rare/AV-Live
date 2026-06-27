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

"[data-only/scene_pose_play] modes + scale ready".postln;
)
