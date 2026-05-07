// =====================================================================
//  L01_garage_opening.scd  --  Album L "GARAGE OPENING", track 01/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L01 : "GARAGE OPENING" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L01 0:00] intro -- warmPad solo + perc rim...".postln;
    ~bpm = 130;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 63; ~kickPitchAmt = 3.4; ~kickDecay = 0.53;
    ~kickDrive = 1.2; ~kickClick = 0.2;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3030;
    ~melodyNotes = [74,0,0,0,60,67,0,0,60,67,0,0,0,0,0,0,0,65,0,0,0,0,0,0,72,60,0,0,0,0,0,0];
    ~kickSteps = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,0,0,0,0,1,1,0,0,0,0,0,1,0];
    ~percInst = \rim;
    ~percSteps = [1,1,1,0,0,1,1,1,1,0,0,0,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    48.wait;

    "[L01 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,60,69,69,0,74,62,72,65,0,74,62,0,74,60,0,72,0,0,77,67,77,0,77,74,62,0,69,70,72,69,67];
    ~melodyCutoff = 3530;
    ~percSteps = [0,0,1,1,0,0,1,1,0,1,1,1,1,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1304, 4030); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L01 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,84,0,0,0,79,0,80,79,70,79,82,0,0,75,0,0,0,0,72,0,87,0,0,0,70,84,0,0,87,77,70];
    ~melodyAmp = 0.24;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,1,0,0,1,1,0,1,1,1,1,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[L01 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3830;
    ~melodyNotes = [0,0,0,42,40,0,0,0,44,0,0,52,0,40,0,0,0,0,0,42,0,45,0,35,0,40,0,40,45,0,49,52];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.3, 1304, \sin, 3030) };
    ~vcfOn !? { ~vcfOn.(\moog, 1504, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    42.wait;

    "[L01 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3030);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L01 4:00] === fin GARAGE OPENING ===".postln;
}).play;
"=== TRACK L01 : GARAGE OPENING 4 min lancee ===".postln;
)
