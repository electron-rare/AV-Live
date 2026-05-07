// =====================================================================
//  L06_vocal_haze.scd  --  Album L "VOCAL HAZE", track 06/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L06 : "VOCAL HAZE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L06 0:00] intro -- vocalPad solo + perc rim...".postln;
    ~bpm = 134;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 60; ~kickPitchAmt = 2.5; ~kickDecay = 0.5;
    ~kickDrive = 1.2; ~kickClick = 0.09;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3383;
    ~melodyNotes = [64,71,0,62,0,0,62,74,59,0,67,0,0,0,0,0,0,59,69,0,0,0,67,69,0,0,0,0,0,0,0,59];
    ~kickSteps = [0,0,0,1,0,1,0,0,0,1,0,0,0,1,0,0];
    ~hatSteps = [0,0,0,0,0,0,0,1,1,0,0,0,0,1,0,1];
    ~percInst = \rim;
    ~percSteps = [1,0,0,0,1,1,0,0,1,1,1,0,1,1,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    72.wait;

    "[L06 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [59,66,71,0,64,64,64,0,74,0,67,59,71,74,0,71,67,64,0,0,0,59,64,0,74,64,0,0,0,62,66,0];
    ~melodyCutoff = 3883;
    ~percSteps = [1,1,0,1,0,1,0,0,1,1,1,0,1,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1115, 4383); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L06 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,83,0,0,76,88,86,0,0,0,0,0,0,0,0,0,0,74,0,74,0,86,0,91,0,0,91,0,0,0,91];
    ~melodyAmp = 0.24;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,1,0,1,0,0,1,1,1,0,1,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[L06 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4183;
    ~melodyNotes = [0,52,44,42,0,37,0,0,44,0,0,0,0,0,0,35,0,0,45,40,0,0,35,35,0,40,0,0,37,0,35,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.24, 1115, \sin, 3383) };
    ~vcfOn !? { ~vcfOn.(\moog, 1315, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    78.wait;

    "[L06 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3383);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L06 6:00] === fin VOCAL HAZE ===".postln;
}).play;
"=== TRACK L06 : VOCAL HAZE 6 min lancee ===".postln;
)
