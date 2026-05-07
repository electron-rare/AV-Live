// =====================================================================
//  L11_ghost_clap.scd  --  Album L "GHOST CLAP", track 11/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L11 : "GHOST CLAP" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L11 0:00] intro -- vocalPad solo + perc rim...".postln;
    ~bpm = 134;
    ~kickAmp = 0.52; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 57; ~kickPitchAmt = 3.9; ~kickDecay = 0.36;
    ~kickDrive = 1.2; ~kickClick = 0.17;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2861;
    ~melodyNotes = [0,0,0,0,0,55,0,0,0,0,0,0,57,0,0,0,0,62,0,0,64,0,0,0,0,0,62,0,0,0,0,0];
    ~kickSteps = [1,0,0,0,0,0,0,0,1,1,1,0,1,0,1,0];
    ~hatSteps = [0,0,0,0,0,1,0,1,0,1,1,0,0,0,0,0];
    ~percInst = \rim;
    ~percSteps = [1,0,1,0,1,0,1,0,1,1,1,0,1,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    84.wait;

    "[L11 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,0,0,0,69,55,0,60,0,0,57,0,72,67,62,65,64,0,0,0,57,0,64,0,0,0,72,72,0,0,0];
    ~melodyCutoff = 3361;
    ~percSteps = [1,1,1,0,1,0,1,0,1,1,0,1,0,0,0,0]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1189, 3861); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L11 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.57;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [72,0,0,0,0,0,76,84,0,81,74,67,69,0,0,77,79,69,84,0,0,0,77,84,0,79,69,0,69,69,81,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,0,1,0,1,0,1,1,0,1,0,0,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[L11 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3661;
    ~melodyNotes = [48,0,0,0,45,0,48,0,43,38,0,55,0,38,47,38,0,40,52,0,0,52,47,0,0,52,0,50,0,0,52,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.19, 1189, \sin, 2861) };
    ~vcfOn !? { ~vcfOn.(\moog, 1389, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    96.wait;

    "[L11 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2861);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L11 7:00] === fin GHOST CLAP ===".postln;
}).play;
"=== TRACK L11 : GHOST CLAP 7 min lancee ===".postln;
)
