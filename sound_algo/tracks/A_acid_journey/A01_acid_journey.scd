// =====================================================================
//  A01_acid_journey.scd  --  Album A "Acid Journey", track 1/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  PREREQUIS : engine.scd evalue (les SynthDef + helpers doivent exister).
// =====================================================================

// --- TRACK A01 : "ACID JOURNEY" 8 minutes ---------------------------
//   0:00 minimal -> 2:00 acid rave -> 4:00 detroit -> 5:30 hard -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A01 0:00] minimal -- kick T5 sub + melody PAD...".postln;
    ~bpm = 124; ~acidCutoff = 500; ~acidRq = 0.25; ~acidDrive = 1.5; ~acidAmp = 0.3;
    ~kickAmp = 0.5; ~hatAmp = 0.08; ~melodyAmp = 0.14;
    ~kickFreq = 42; ~kickPitchAmt = 2.0; ~kickDecay = 0.5;
    ~kickDrive = 1.0; ~kickClick = 0.05;             // T5 sub deep
    ~melodyInst = \pad;                              // PAD pour l'intro
    ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 1500;
    ~melodyNotes = [60,0,0,0,0,0,0,0, 67,0,0,0,0,0,0,0,
                    60,0,0,0,0,0,0,0, 65,0,0,0,0,0,0,0];
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    120.wait;

    "[A01 2:00] acid rave -- kick T1 + melody LEAD + variations...".postln;
    ~bpm = 132; ~acidCutoff = 800; ~acidRq = 0.15; ~acidDrive = 2.5;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.18;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
    ~kickDrive = 1.3; ~kickClick = 0.2;
    ~melodyInst = \lead;                             // LEAD pour le drop
    ~melodyAttack = 0.012; ~melodyRelease = 0.25; ~melodyCutoff = 2400;
    ~melodyAmp = 0.16;
    ~acidNotes = [36,36,48,36,39,36,43,39, 36,41,36,39,43,36,36,41];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~melodyNotes = [60,0,67,0,70,0,67,65, 63,0,60,0,0,67,70,72,
                    75,0,72,70,67,0,0,65, 63,60,0,67,70,0,72,0];
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    // 120s avec micro-variations toutes les 4s
    30.do { |k|
        if (0.25.coin) { ~acidCutoff = rrand(600, 1400); ~reload.value };
        // Melodie : alterne entre genMelody + mutate de l'existant
        if (0.20.coin) {
            if (0.5.coin) {
                // 50% : nouveau pattern dans une scale aleatoire
                ~melodyNotes = ~genMelody.(0.55,
                    [~scaleMinorPent, ~scaleMinor, ~scaleDorian, ~scaleHigh].choose);
            } {
                // 50% : mutation legere du pattern existant
                ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
            };
            ~reload.value;
        };
        if (0.10.coin) { ~acidSlides = ~genAcidSlides.(0.3); ~reload.value };
        // 5% chance d'octavate la melodie
        if (0.05.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.25); ~reload.value };
        4.wait;
    };

    "[A01 4:00] detroit stabs -- kick T2 + melody STAB...".postln;
    ~bpm = 128; ~acidCutoff = 700; ~acidDrive = 2.2;
    ~kickFreq = 65; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
    ~kickDrive = 1.8; ~kickClick = 0.45;
    ~melodyInst = \stab;                             // STAB style Detroit
    ~melodyDrive = 2.8; ~melodyCutoff = 1500;
    ~melodyNotes = [63,0,0,0,70,0,67,0, 65,0,0,0,70,0,72,0,
                    63,0,0,0,67,0,70,0, 65,0,60,0,67,0,0,0];
    ~melodyAttack = 0.001; ~melodyRelease = 0.06;
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    // 90s avec stabs qui mutent (Detroit = Cm avec variations chromatiques)
    18.do { |k|
        if (0.3.coin) {
            ~melodyNotes = ~genMelody.(0.35,
                [~scaleMinor, ~scaleDorian, ~scaleHarmonicMin].choose);
            ~reload.value;
        };
        if (0.2.coin) { ~acidCutoff = rrand(500, 1500); ~reload.value };
        if (0.15.coin) { ~kickClick = rrand(0.2, 0.55); ~reload.value };
        // Transposition aleatoire (-5/+5 semi-tons) toutes les ~30s
        if (0.07.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose);
            ~reload.value;
            "  -> melodie transposee".postln;
        };
        5.wait;
    };

    "[A01 5:30] hard push -- kick T4 distordu...".postln;
    ~bpm = 140; ~acidCutoff = 1500; ~acidRq = 0.08; ~acidDrive = 3.8;
    ~kickSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
    ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
    ~kickDrive = 3.5; ~kickClick = 0.3;              // T4 distordu
    ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    60.wait;
    "[A01 6:30] new -- supersaw + ml1 long melody + vcf moog + dub fx...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.005; ~melodyRelease = 0.35; ~melodyCutoff = 2200;
    ~melodyAmp = 0.16;
    ~melodyNotes = (~ml1 ? [60,0,67,0,70,0,67,65, 63,0,60,0,0,67,70,72]).copy;
    ~vcfOn !? { ~vcfOn.(\moog, 1200, 0.45) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    45.wait;

    "[A01 7:15] new -- guzheng + acid evolve...".postln;
    ~melodyInst = \guzheng;
    ~melodyAttack = 0.001; ~melodyRelease = 0.6; ~melodyCutoff = 4000;
    ~melodyAmp = 0.18;
    ~vcfOff !? { ~vcfOff.() };
    ~stutter !? { ~stutter.(8, 1.5) };
    ~fxPreset !? { ~fxPreset.(\space) };
    TempoClock.default.tempo = ~bpm/60; ~reload.value;
    30.wait;


    "[A01 7:45] outro -- melody PAD qui s'efface...".postln;
    ~melodyInst = \pad;                              // PAD doux pour finir
    ~melodyAttack = 0.5; ~melodyRelease = 2.0; ~melodyAmp = 0.12;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~acidCutoff = 200 + (x * 1300);
        ~acidAmp = x * 0.32; ~kickAmp = x * 0.5; ~hatAmp = x * 0.16;
        ~melodyAmp = x * 0.12;
        ~reload.value;
        1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    "[A01 8:15] === fin ACID JOURNEY ===".postln;
}).play;
"=== TRACK A : ACID JOURNEY 7 min lancee ===".postln;
)


// =====================================================================
//  TWEAKS LIVE -- voir palette/tweaks_template.scd (charge dans 00_load)
//                 Ouvrir tweaks_template.scd et Cmd+Entree sur une ligne.
// =====================================================================

// =====================================================================
//  SECTIONS / JUMP TO -- voir jump.scd
//  Ouvrir jump.scd, evaluer SETUP JUMP, puis le bloc TRACK X correspondant,
//  puis Cmd+Entree sur la ligne ~jumpTo.('X', 'slug').
// =====================================================================
