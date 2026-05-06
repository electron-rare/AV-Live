// =====================================================================
//  N13_ghost_drift.scd  --  Album N "GHOST DRIFT", track 13/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N13 : "GHOST DRIFT" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N13 0:00] intro -- warmPad solo + perc cowbell...".postln;
    ~bpm = 136;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 53; ~kickPitchAmt = 3.6; ~kickDecay = 0.51;
    ~kickDrive = 1.2; ~kickClick = 0.19;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3569;
    ~melodyNotes = [69,70,0,0,0,0,0,0,0,77,74,69,0,0,69,69,0,0,0,60,0,0,0,0,0,0,0,62,60,0,62,0];
    ~kickSteps = [0,0,0,0,0,1,1,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,0,0,0,1,1,0,1,0,0,1,0,1,0];
    ~percInst = \cowbell;
    ~percSteps = [0,0,0,0,0,1,1,1,0,0,1,0,0,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    48.wait;

    "[N13 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,72,0,0,0,0,72,60,67,0,69,0,60,0,62,69,69,70,0,65,60,0,60,60,72,60,69,62,0,70,0];
    ~melodyCutoff = 4069;
    ~percSteps = [1,1,1,1,0,0,1,0,1,1,0,1,0,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(923, 4569); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N13 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [81,0,72,86,0,0,0,77,0,0,0,0,0,0,81,0,0,0,82,0,0,72,0,77,0,0,79,0,0,84,79,0];
    ~melodyAmp = 0.21;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,1,0,0,1,0,1,1,0,1,0,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[N13 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4369;
    ~melodyNotes = [31,0,0,0,40,0,36,33,48,0,36,43,0,45,31,40,0,0,40,0,0,0,36,40,0,36,0,33,41,31,0,36];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.34, 923, \sin, 3569) };
    ~vcfOn !? { ~vcfOn.(\moog, 1123, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    42.wait;

    "[N13 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3569);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N13 4:00] === fin GHOST DRIFT ===".postln;
}).play;
"=== TRACK N13 : GHOST DRIFT 4 min lancee ===".postln;
)
