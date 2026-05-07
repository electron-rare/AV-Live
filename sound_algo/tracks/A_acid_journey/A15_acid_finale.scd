// =====================================================================
//  A15_acid_finale.scd  --  Album A "Acid Journey", track 15/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  Cloture de l'album : voyage Hijaz oriental + 303 + ethereal outro.
// =====================================================================

// --- TRACK A15 : "ACID FINALE (Hijaz)" 6 minutes --------------------
//   0:00 hijaz prelude -> 1:00 303 oriental -> 2:30 supersaw climb -> 4:00 peak -> 5:00 ethereal
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A15 0:00] hijaz prelude -- guzheng intro arabe...".postln;
    ~bpm = 150;
    ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
    ~kickDrive = 2.0; ~kickClick = 0.25; ~kickAmp = 0.55;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatAmp = 0;
    ~acidAmp = 0;
    ~melodyInst = \guzheng;
    ~melodyAttack = 0.001; ~melodyRelease = 1.2; ~melodyCutoff = 3000;
    ~melodyAmp = 0.16;
    ~melodyNotes = [60,0,61,0, 64,0,65,0, 67,0,68,0, 70,0,72,0,
                    68,0,67,0, 65,0,64,0, 61,0,60,0, 0,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    Pdef(\harmonySeq).play;
    60.wait;

    "[A15 1:00] 303 oriental -- hijaz acid line...".postln;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,1]; ~hatAmp = 0.14;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.50;
    ~acidAmp = 0.28; ~acidCutoff = 800; ~acidRq = 0.16; ~acidDrive = 2.4;
    ~acidNotes = [36,37,40,41, 36,43,44,46, 41,40,37,36, 44,43,41,40];
    ~acidSlides = [0,0,1,0, 0,0,0,1, 0,1,0,0, 0,0,0,1];
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    // 90s 303 hijaz evolution
    18.do { |k|
        ~acidCutoff = 700 + (k * 30);
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.55, ~scaleHijaz);
            ~reload.value;
        };
        if (0.20.coin) {
            ~acidNotes = ~genMelody.(0.75, ~scaleHijaz);
            ~acidSlides = ~genAcidSlides.(0.35);
            ~reload.value;
        };
        ~reload.value;
        5.wait;
    };

    "[A15 2:30] supersaw climb -- big anthem lead...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.012; ~melodyRelease = 0.55; ~melodyCutoff = 2800;
    ~melodyAmp = 0.20;
    ~melodyNotes = [72,0,73,0, 76,0,77,0, 79,0,80,77, 76,73,72,0,
                    77,0,80,0, 82,80,77,76, 73,72,70,72, 73,76,77,0];
    ~enableHarmony.(\third);
    ~reload.value;
    Pdef(\melodySeq).play;
    ~fxPreset !? { ~fxPreset.(\trance) };
    // 90s climb supersaw
    18.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.60, ~scaleHijaz);
            ~reload.value;
        };
        if (0.18.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.20);
            ~reload.value;
        };
        if (0.15.coin) { ~melodyCutoff = rrand(2400, 3400); ~reload.value };
        5.wait;
    };

    "[A15 4:00] peak -- everything erupts...".postln;
    ~kickDrive = 2.8; ~acidCutoff = 1500; ~acidDrive = 3.0;
    ~melodyAmp = 0.22;
    ~hatSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~hatAmp = 0.16;
    ~vcfOn !? { ~vcfOn.(\moog, 1700, 0.45) };
    ~reload.value;
    60.wait;

    "[A15 5:00] ethereal -- outro koto + drone vanish...".postln;
    ~vcfOff !? { ~vcfOff.() };
    [\kickSeq, \hatSeq, \clapSeq, \acidSeq].do { |k| Pdef(k).stop };
    ~melodyInst = \koto;
    ~melodyAttack = 0.001; ~melodyRelease = 2.5; ~melodyCutoff = 3200;
    ~enableHarmony.(\arp);
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~melodyAmp = x * 0.22;
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.40, ~scaleHijaz);
            ~reload.value;
        };
        ~reload.value;
        1.wait;
    };
    [\melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[A15 6:00] === fin ACID FINALE -- album A complete ===".postln;
}).play;
"=== TRACK A15 : ACID FINALE 6 min lancee ===".postln;
)
