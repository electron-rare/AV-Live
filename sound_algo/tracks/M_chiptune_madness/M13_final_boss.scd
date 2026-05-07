// =====================================================================
//  M13_final_boss.scd  --  Album M "FINAL BOSS", track 13/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M13 : "FINAL BOSS" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M13 0:00] intro -- saw3 solo + perc tom...".postln;
    ~bpm = 175;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.2;
    ~kickFreq = 58; ~kickPitchAmt = 3.8; ~kickDecay = 0.35;
    ~kickDrive = 1.2; ~kickClick = 0.1;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2861;
    ~melodyNotes = [0,0,0,0,0,62,0,0,71,69,0,72,69,0,67,0,0,62,0,67,0,79,0,79,0,0,0,71,72,74,0,62];
    ~kickSteps = [0,0,1,0,1,0,1,1,0,0,1,1,1,0,0,0];
    ~hatSteps = [0,0,0,0,0,0,0,0,0,1,1,0,0,0,1,1];
    ~percInst = \tom;
    ~percSteps = [0,1,0,1,0,0,0,0,0,0,1,0,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    48.wait;

    "[M13 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 177; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,74,0,0,0,0,67,0,0,71,64,0,67,64,64,62,0,79,79,0,62,69,0,0,0,0,0,0,0,0,74];
    ~melodyCutoff = 3361;
    ~percSteps = [1,0,0,1,1,0,0,0,1,1,1,1,1,0,1,0]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1500, 3861); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M13 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 173; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,86,86,0,0,89,72,0,0,86,77,86,0,84,86,0,0,84,84,0,84,77,0,0,0,0,0,0,0,0,0];
    ~melodyAmp = 0.22;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,0,1,1,0,0,0,1,1,1,1,1,0,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[M13 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 179; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3661;
    ~melodyNotes = [0,0,40,0,0,0,44,42,40,35,45,0,0,49,0,49,0,0,0,0,0,35,47,37,45,0,0,0,0,0,35,49];
    ~melodyAmp = 0.2;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.22, 1500, \sin, 2861) };
    ~vcfOn !? { ~vcfOn.(\moog, 1700, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    42.wait;

    "[M13 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.2; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2861);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M13 4:00] === fin FINAL BOSS ===".postln;
}).play;
"=== TRACK M13 : FINAL BOSS 4 min lancee ===".postln;
)
