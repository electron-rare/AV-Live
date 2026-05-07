// =====================================================================
//  A06_ambient_acid.scd  --  Album A "Acid Journey", track 6/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A06 : "AMBIENT ACID" 8 minutes ---------------------------
//   0:00 drone bed -> 1:30 acid whisper -> 3:30 koto float -> 5:30 climax -> 7:00 dissolve
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A06 0:00] drone bed -- pad infini, no kick...".postln;
    ~bpm = 100;
    ~kickAmp = 0; ~hatAmp = 0; ~clapAmp = 0;
    ~acidAmp = 0;
    ~melodyInst = \drone;
    ~melodyAttack = 1.5; ~melodyRelease = 4.0; ~melodyCutoff = 900;
    ~melodyAmp = 0.13;
    ~melodyNotes = [60,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
                    0,0,0,0,0,0,0,0, 65,0,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    Pdef(\melodySeq).play;
    ~enableHarmony.(\fifth);
    Pdef(\harmonySeq).play;
    90.wait;

    "[A06 1:30] acid whisper -- 303 tres doux dans le lointain...".postln;
    ~acidAmp = 0.10; ~acidCutoff = 400; ~acidRq = 0.40; ~acidDrive = 0.8;
    ~acidNotes = [36,0,0,0, 0,0,39,0, 0,0,0,0, 0,0,0,41,
                  0,0,36,0, 0,0,0,0, 39,0,0,0, 0,0,0,0];
    ~acidSlides = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,1,0];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 120s evolution lente
    24.do { |k|
        if (0.18.coin) { ~acidCutoff = rrand(350, 700); ~reload.value };
        if (0.15.coin) {
            ~melodyNotes = ~genMelody.(0.20, ~scaleHirajoshi);
            ~reload.value;
        };
        5.wait;
    };

    "[A06 3:30] koto float -- pizz cristallin...".postln;
    ~melodyInst = \koto;
    ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 3500;
    ~melodyAmp = 0.16;
    ~melodyNotes = [72,0,0,0, 75,0,0,72, 0,77,0,0, 72,0,75,0,
                    79,0,0,0, 0,75,0,72, 0,0,77,0, 0,72,0,75];
    ~enableHarmony.(\arp);
    ~reload.value;
    // 120s koto evolue
    24.do { |k|
        if (0.30.coin) {
            ~melodyNotes = ~genMelody.(0.45, ~scaleJapanese);
            ~reload.value;
        };
        if (0.18.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25, ~scaleHirajoshi);
            ~reload.value;
        };
        5.wait;
    };

    "[A06 5:30] climax -- kick brushed entre...".postln;
    ~kickAmp = 0.30; ~kickFreq = 40; ~kickDecay = 0.7; ~kickDrive = 0.7;
    ~kickSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 1,0,0,0];
    ~hatAmp = 0.05; ~hatSteps = [0,0,1,0, 0,0,0,0, 0,0,1,0, 0,0,0,0];
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    90.wait;

    "[A06 7:00] dissolve -- tout fond dans le drone...".postln;
    [\kickSeq, \hatSeq, \acidSeq].do { |k| Pdef(k).stop };
    ~melodyInst = \drone;
    ~melodyAttack = 2.0; ~melodyRelease = 5.0;
    ~enableHarmony.(\fifth);
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~melodyAmp = x * 0.16;
        ~melodyCutoff = 200 + (x * 700);
        ~reload.value;
        1.wait;
    };
    [\melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[A06 8:00] === fin AMBIENT ACID ===".postln;
}).play;
"=== TRACK A06 : AMBIENT ACID 8 min lancee ===".postln;
)
