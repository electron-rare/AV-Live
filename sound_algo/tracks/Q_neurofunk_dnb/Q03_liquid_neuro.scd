// =====================================================================
//  Q03_liquid_neuro.scd  --  Album Q "Neurofunk DnB", track 3/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
//  Sub-track : "Liquid Neuro" 6 min (360s)
// =====================================================================

// --- TRACK Q03 : "LIQUID NEURO" 6 minutes -------------
//   0:00 intro -> 1:22 groove -> 3:01 drop -> 4:23 variations -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[Q03 0:00] intro / atmosphere...".postln;
    ~bpm = 174;
    ~kickFreq = 55; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
    ~kickDrive = 1.8; ~kickClick = 0.35;
    ~kickSteps = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~hatSteps  = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1]; ~hatAmp = 0.13;
    ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,0]; ~snareAmp = 0.55;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~percInst = \rim;
    ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.30;
    ~melodyInst = \reese;
    ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 800;
    ~melodyAmp = 0.168;
    ~melodyNotes = ~genMelody.(0.45, ~scaleMinorPent);
    ~acidNotes = [36,0,48,0,36,0,43,0, 36,0,41,0,39,0,36,0];
    ~acidSlides = [0,0,1,0,0,0,0,1, 0,0,0,1,0,0,0,0];
    ~acidCutoff = 800; ~acidRq = 0.18; ~acidDrive = 2.5; ~acidAmp = 0.120;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    82.wait;

    "[Q03 1:22] build / groove...".postln;
    ~melodyAmp = 0.238;
    ~melodyNotes = ~genMelody.(0.55, ~scaleHarmonicMin);
    ~melodyCutoff = 1400;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.25);
            ~reload.value;
        };
        if (0.15.coin) {
            ~acidCutoff = rrand(500, 1800); ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~octavate.(~melodyNotes, 0.3); ~reload.value;
        };
        4.wait;
    };

    "[Q03 3:01] drop / climax...".postln;
    ~melodyAmp = 0.280;
    ~kickAmp = 0.600;
    ~melodyNotes = ~genMelody.(0.6, ~scalePhrygian);
    ~melodyCutoff = 2000;
    ~acidAmp = 0.200;
    ~acidCutoff = 1500; ~acidDrive = 3.2;
    ~reload.value;
    16.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~mutate.(~melodyNotes, 0.2);
            ~reload.value;
        };
        if (0.10.coin) {
            ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose);
            ~reload.value;
        };
        5.wait;
    };

    "[Q03 4:23] variations / second wave...".postln;
    ~melodyInst = \growl;
    ~melodyAttack = 0.005; ~melodyRelease = 0.35;
    ~melodyAmp = 0.252;
    ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
    ~melodyCutoff = 1600;
    ~vcfOn !? { ~vcfOn.(\moog, 1200, 0.5) };
    ~reload.value;
    67.wait;

    "[Q03 5:30] outro -- fade...".postln;
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.280;
        ~kickAmp = x * 0.550;
        ~hatAmp = x * 0.130;
        ~snareAmp = x * 0.550;
        ~clapAmp = x * 0.350;
        ~acidAmp = x * 0.200;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq]
        .do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[Q03 6:00] === fin LIQUID NEURO ===".postln;
}).play;
"=== TRACK Q03 : LIQUID NEURO 6 min lancee ===".postln;
)
