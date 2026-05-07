// =====================================================================
//  L07_step_two.scd  --  Album L "STEP TWO", track 07/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L07 : "STEP TWO" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L07 0:00] intro -- warmPad solo + perc hat...".postln;
    ~bpm = 136;
    ~kickAmp = 0.46; ~hatAmp = 0.06; ~melodyAmp = 0.24;
    ~kickFreq = 51; ~kickPitchAmt = 2.6; ~kickDecay = 0.38;
    ~kickDrive = 1.2; ~kickClick = 0.15;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3572;
    ~melodyNotes = [0,0,0,0,0,0,77,62,0,60,0,60,0,0,0,0,0,72,0,77,0,0,70,0,0,0,65,0,0,67,0,0];
    ~kickSteps = [0,0,0,0,0,0,0,1,0,0,0,0,0,1,1,0];
    ~hatSteps = [0,0,0,0,1,1,0,0,0,1,0,1,1,1,0,0];
    ~percInst = \hat;
    ~percSteps = [0,0,0,0,1,0,0,0,0,0,1,1,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    60.wait;

    "[L07 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 138; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [72,65,67,70,0,0,0,69,69,0,0,62,0,62,0,77,0,0,0,67,65,74,0,72,67,70,0,62,60,0,67,0];
    ~melodyCutoff = 4072;
    ~percSteps = [1,1,1,1,1,1,1,0,1,1,0,0,1,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1063, 4572); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L07 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 138; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.51;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,79,84,0,74,77,0,0,86,0,0,0,0,0,79,0,74,72,0,84,79,86,74,0,82,77,0,0,89,0,0,79];
    ~melodyAmp = 0.26;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,1,1,1,1,0,1,1,0,0,1,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[L07 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4372;
    ~melodyNotes = [0,0,40,45,0,35,0,0,0,0,0,49,40,0,35,0,0,0,45,0,44,0,40,44,40,0,0,44,0,42,45,45];
    ~melodyAmp = 0.24;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.31, 1063, \sin, 3572) };
    ~vcfOn !? { ~vcfOn.(\moog, 1263, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    60.wait;

    "[L07 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.24; ~kickAmp = x * 0.46;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3572);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L07 5:00] === fin STEP TWO ===".postln;
}).play;
"=== TRACK L07 : STEP TWO 5 min lancee ===".postln;
)
