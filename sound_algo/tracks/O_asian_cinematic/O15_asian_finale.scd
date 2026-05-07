// =====================================================================
//  O15_asian_finale.scd  --  Album O "ASIAN FINALE", track 15/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O15 : "ASIAN FINALE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O15 0:00] intro -- erhu solo + perc tom...".postln;
    ~bpm = 85;
    ~kickAmp = 0.51; ~hatAmp = 0.06; ~melodyAmp = 0.24;
    ~kickFreq = 58; ~kickPitchAmt = 3.6; ~kickDecay = 0.38;
    ~kickDrive = 1.2; ~kickClick = 0.17;
    ~melodyInst = \erhu;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2632;
    ~melodyNotes = [0,0,0,0,67,0,62,0,72,0,0,76,69,0,0,0,0,74,0,0,0,0,0,0,0,0,0,0,76,0,0,76];
    ~kickSteps = [0,0,0,0,0,0,0,1,0,0,1,0,0,0,1,1];
    ~hatSteps = [0,1,0,0,0,0,0,0,0,1,0,1,0,0,1,1];
    ~percInst = \tom;
    ~percSteps = [0,0,1,1,0,0,0,0,1,0,0,0,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    72.wait;

    "[O15 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 89; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,62,0,0,71,64,0,0,0,0,0,0,62,64,0,76,0,74,0,0,0,0,64,0,79,0,71,0,0,62,79,0];
    ~melodyCutoff = 3132;
    ~percSteps = [1,0,1,1,0,1,1,1,1,0,1,1,0,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1224, 3632); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O15 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 83; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.56;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [77,0,0,0,0,84,0,0,79,0,75,79,0,87,0,84,84,0,0,72,0,84,87,77,80,0,80,0,0,0,0,84];
    ~melodyAmp = 0.26;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleJapanese);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,1,0,1,1,1,1,0,1,1,0,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[O15 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 91; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \erhu;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3432;
    ~melodyNotes = [48,0,43,0,38,0,0,0,52,47,40,45,0,0,0,0,55,40,52,0,0,0,48,0,43,0,0,0,0,0,0,50];
    ~melodyAmp = 0.24;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.29, 1224, \sin, 2632) };
    ~vcfOn !? { ~vcfOn.(\moog, 1424, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    78.wait;

    "[O15 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.24; ~kickAmp = x * 0.51;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2632);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O15 6:00] === fin ASIAN FINALE ===".postln;
}).play;
"=== TRACK O15 : ASIAN FINALE 6 min lancee ===".postln;
)
