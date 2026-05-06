// =====================================================================
//  A10_cosmic_acid.scd  --  Album A "Acid Journey", track 10/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK A10 : "COSMIC ACID (Psy-Trance)" 8 minutes ---------------
//   0:00 launch -> 1:30 303 wide -> 3:30 supersaw -> 5:30 storm -> 7:00 atmos
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[A10 0:00] launch -- offbeat bass + riser...".postln;
    ~bpm = 132;
    ~kickFreq = 55; ~kickPitchAmt = 2.5; ~kickDecay = 0.32;
    ~kickDrive = 1.8; ~kickClick = 0.20; ~kickAmp = 0.58;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.13;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.50;
    ~acidAmp = 0; ~melodyAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    Pdef(\harmonySeq).play;
    90.wait;

    "[A10 1:30] 303 wide -- octave -1 a +1 acid...".postln;
    ~acidAmp = 0.32; ~acidCutoff = 800; ~acidRq = 0.15; ~acidDrive = 2.5;
    ~acidNotes = [24,36,36,48, 39,36,51,36, 24,43,36,48, 36,41,36,39];
    ~acidSlides = [0,0,1,0, 0,1,0,0, 0,0,0,1, 0,0,0,1];
    ~reload.value;
    Pdef(\acidSeq).play;
    // 120s acid evolue
    24.do { |k|
        ~acidCutoff = 600 + ((k % 12) * 60);
        if (0.25.coin) { ~acidRq = rrand(0.10, 0.20); };
        if (0.20.coin) {
            ~acidNotes = ~genMelody.(0.75, ~scaleAcidWide);
            ~acidSlides = ~genAcidSlides.(0.40);
        };
        ~reload.value;
        5.wait;
    };

    "[A10 3:30] supersaw -- big lead...".postln;
    ~melodyInst = \supersaw;
    ~melodyAttack = 0.008; ~melodyRelease = 0.40; ~melodyCutoff = 2800;
    ~melodyAmp = 0.18;
    ~melodyNotes = [60,0,67,0, 70,67,72,0, 75,0,72,70, 67,72,75,0,
                    72,0,79,75, 70,67,72,0, 75,72,70,67, 72,0,0,0];
    ~enableHarmony.(\third);
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    // 120s supersaw evolution
    24.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.18.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.25);
            ~reload.value;
        };
        if (0.15.coin) { ~melodyCutoff = rrand(2200, 3400); ~reload.value };
        5.wait;
    };

    "[A10 5:30] storm -- vcf moog + hat 16th...".postln;
    ~vcfOn !? { ~vcfOn.(\moog, 1500, 0.4) };
    ~hatSteps = [1,0,1,1, 1,0,1,1, 1,0,1,1, 1,0,1,1]; ~hatAmp = 0.15;
    ~reload.value;
    90.wait;

    "[A10 7:00] atmos -- bass cuts, supersaw flies...".postln;
    ~vcfOff !? { ~vcfOff.() };
    [\kickSeq, \hatSeq, \clapSeq, \acidSeq].do { |k| Pdef(k).stop };
    ~melodyAttack = 0.05; ~melodyRelease = 1.5;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    60.do { |k|
        var x = 1 - ((k + 1) / 60);
        ~melodyAmp = x * 0.18;
        ~melodyCutoff = 600 + (x * 2200);
        ~reload.value;
        1.wait;
    };
    [\melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[A10 8:00] === fin COSMIC ACID ===".postln;
}).play;
"=== TRACK A10 : COSMIC ACID 8 min lancee ===".postln;
)
