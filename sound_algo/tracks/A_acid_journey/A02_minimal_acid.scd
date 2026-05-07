// =====================================================================
//  A02_minimal_acid.scd  --  Album A "Acid Journey", track 2/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A02 : "MINIMAL ACID" 4 minutes ---------------------------
//   0:00 sub pulse -> 1:00 303 enter -> 2:30 ride -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A02 0:00] sub pulse -- kick deep + pluck minimal...".postln;
    ~bpm = 120;
    ~kickFreq = 38; ~kickPitchAmt = 1.5; ~kickDecay = 0.6;
    ~kickDrive = 0.9; ~kickClick = 0.04; ~kickAmp = 0.55;
    ~hatAmp = 0.04;
    ~acidAmp = 0; ~acidCutoff = 350; ~acidRq = 0.3; ~acidDrive = 1.2;
    ~melodyInst = \pluck;
    ~melodyAttack = 0.002; ~melodyRelease = 0.4; ~melodyCutoff = 1200;
    ~melodyAmp = 0.10;
    ~melodyNotes = [60,0,0,0, 0,0,0,0, 67,0,0,0, 0,0,0,0,
                    0,0,0,0, 65,0,0,0, 0,0,0,0, 0,0,63,0];
    TempoClock.default.tempo = ~bpm/60;
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\off);
    60.wait;

    "[A02 1:00] 303 enter -- acid pattern subtil...".postln;
    ~acidAmp = 0.22; ~acidCutoff = 600; ~acidDrive = 1.8;
    ~acidNotes = [36,36,36,39, 41,36,43,36, 36,39,36,41, 36,43,36,36];
    ~acidSlides = [0,1,0,0, 0,0,1,0, 0,0,1,0, 0,0,0,1];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,1]; ~hatAmp = 0.10;
    ~reload.value;
    Pdef(\acidSeq).play;
    // 90s avec micro-mutations 303
    18.do { |k|
        if (0.30.coin) { ~acidCutoff = rrand(450, 900); ~reload.value };
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.35, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.12.coin) { ~acidSlides = ~genAcidSlides.(0.25); ~reload.value };
        5.wait;
    };

    "[A02 2:30] ride -- hat 16th + clap on 3...".postln;
    ~hatSteps = [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1]; ~hatAmp = 0.14;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
    ~acidCutoff = 1100; ~melodyAmp = 0.13;
    ~reload.value;
    Pdef(\clapSeq).play;
    // 60s
    12.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(800, 1500); ~reload.value };
        if (0.15.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2, ~scaleMinorPent);
            ~reload.value;
        };
        5.wait;
    };

    "[A02 3:30] outro -- 303 only fade...".postln;
    ~enableHarmony.(\off);
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.14; ~clapAmp = x * 0.5;
        ~melodyAmp = x * 0.13; ~acidAmp = x * 0.22;
        ~acidCutoff = 200 + (x * 900);
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \clapSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).stop };
    "[A02 4:00] === fin MINIMAL ACID ===".postln;
}).play;
"=== TRACK A02 : MINIMAL ACID 4 min lancee ===".postln;
)
