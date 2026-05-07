// =====================================================================
//  M15_credits_chip.scd  --  Album M "CREDITS CHIP", track 15/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M15 : "CREDITS CHIP" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M15 0:00] intro -- stab solo + perc tom...".postln;
    ~bpm = 150;
    ~kickAmp = 0.53; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 45; ~kickPitchAmt = 3.4; ~kickDecay = 0.45;
    ~kickDrive = 1.2; ~kickClick = 0.13;
    ~melodyInst = \stab;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2707;
    ~melodyNotes = [67,0,0,70,0,0,74,0,0,69,0,0,0,0,0,62,0,0,0,0,0,77,67,0,69,0,0,0,0,0,72,74];
    ~kickSteps = [0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0];
    ~hatSteps = [1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,0,0,1,1,1,1,0,0,1,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    72.wait;

    "[M15 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 146; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,0,0,0,60,77,62,62,69,65,74,0,0,0,77,0,65,0,60,0,0,0,0,70,62,0,0,77,0,0,0];
    ~melodyCutoff = 3207;
    ~percSteps = [1,0,0,0,0,0,1,1,0,0,1,1,0,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1435, 3707); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M15 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 152; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.58;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [86,0,74,0,0,84,77,74,0,0,82,0,0,0,86,0,0,79,77,0,72,0,0,89,0,0,0,0,0,0,0,77];
    ~melodyAmp = 0.21;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,0,0,0,0,1,1,0,0,1,1,0,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[M15 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 156; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \stab;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3507;
    ~melodyNotes = [52,0,0,52,0,0,0,0,44,0,0,0,0,0,49,45,0,42,42,0,0,0,0,37,37,0,0,0,0,47,49,0];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.29, 1435, \sin, 2707) };
    ~vcfOn !? { ~vcfOn.(\moog, 1635, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    78.wait;

    "[M15 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.53;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2707);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M15 6:00] === fin CREDITS CHIP ===".postln;
}).play;
"=== TRACK M15 : CREDITS CHIP 6 min lancee ===".postln;
)
