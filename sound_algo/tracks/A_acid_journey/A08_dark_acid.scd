// =====================================================================
//  A08_dark_acid.scd  --  Album A "Acid Journey", track 8/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A08 : "DARK ACID (Psy)" 6 minutes ------------------------
//   0:00 dark intro -> 1:00 303 evil -> 2:30 hard lead -> 4:00 break -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A08 0:00] dark intro -- low pad + sparse kick...".postln;
    ~bpm = 130;
    ~kickFreq = 48; ~kickPitchAmt = 2.2; ~kickDecay = 0.45;
    ~kickDrive = 2.0; ~kickClick = 0.20; ~kickAmp = 0.55;
    ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
    ~hatAmp = 0;
    ~acidAmp = 0;
    ~melodyInst = \drone;
    ~melodyAttack = 0.5; ~melodyRelease = 3.0; ~melodyCutoff = 700;
    ~melodyAmp = 0.12;
    ~melodyNotes = [48,0,0,0,0,0,0,0, 49,0,0,0,0,0,0,0,
                    0,0,0,0,0,0,0,0, 53,0,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~vcfOn !? { ~vcfOn.(\ladder, 600, 0.6) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    Pdef(\harmonySeq).play;
    60.wait;

    "[A08 1:00] 303 evil -- phrygian acid sub...".postln;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.10;
    ~acidAmp = 0.30; ~acidCutoff = 600; ~acidRq = 0.14; ~acidDrive = 2.8;
    ~acidNotes = [36,36,37,36, 41,36,48,37, 36,49,36,41, 37,36,43,36];
    ~acidSlides = [0,0,1,0, 0,0,0,1, 0,0,0,0, 1,0,0,0];
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    // 90s acid sombre
    18.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(450, 1000); ~reload.value };
        if (0.20.coin) {
            ~acidNotes = ~genMelody.(0.7, ~scaleAcid);
            ~reload.value;
        };
        5.wait;
    };

    "[A08 2:30] hard lead -- square + cutoff modulation...".postln;
    ~melodyInst = \hard_lead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.20; ~melodyCutoff = 1800;
    ~melodyAmp = 0.16; ~melodyDrive = 3.0;
    ~melodyNotes = [60,0,0,61, 0,63,0,0, 65,0,68,0, 67,0,63,0,
                    61,0,60,0, 0,67,0,63, 0,68,0,65, 67,0,0,0];
    ~enableHarmony.(\off);
    ~reload.value;
    Pdef(\melodySeq).play;
    Pdef(\harmonySeq).stop;
    // 90s lead evolution
    18.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.55, ~scalePhrygian);
            ~reload.value;
        };
        if (0.15.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.3, ~scalePhrygian);
            ~reload.value;
        };
        5.wait;
    };

    "[A08 4:00] break -- kick out, 303 alone screams...".postln;
    ~kickAmp = 0; ~hatAmp = 0; ~melodyAmp = 0;
    ~acidCutoff = 1800; ~acidDrive = 3.8;
    ~reload.value;
    30.wait;

    "[A08 4:30] outro -- back in hard then fade...".postln;
    ~kickAmp = 0.55; ~hatAmp = 0.10; ~melodyAmp = 0.16;
    ~reload.value;
    ~vcfOff !? { ~vcfOff.() };
    90.do { |k|
        var x = 1 - ((k + 1) / 90);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.10;
        ~melodyAmp = x * 0.16; ~acidAmp = x * 0.30;
        ~acidCutoff = 200 + (x * 1500);
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \acidSeq, \melodySeq].do { |k| Pdef(k).stop };
    "[A08 6:00] === fin DARK ACID ===".postln;
}).play;
"=== TRACK A08 : DARK ACID 6 min lancee ===".postln;
)
