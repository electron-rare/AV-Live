// =====================================================================
//  L15_garage_finale.scd  --  Album L "GARAGE FINALE", track 15/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L15 : "GARAGE FINALE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L15 0:00] intro -- warmPad solo + perc rim...".postln;
    ~bpm = 135;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.2;
    ~kickFreq = 54; ~kickPitchAmt = 2.1; ~kickDecay = 0.41;
    ~kickDrive = 1.2; ~kickClick = 0.12;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2677;
    ~melodyNotes = [62,0,0,76,72,0,69,64,0,0,0,76,0,0,64,0,0,0,0,0,0,0,64,0,0,79,71,0,67,67,0,64];
    ~kickSteps = [0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,1,0,0,1,0,0,0,0,1,0,1,0,0,0];
    ~percInst = \rim;
    ~percSteps = [0,0,0,0,0,1,1,0,0,1,0,1,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    72.wait;

    "[L15 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 131; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [76,67,74,74,0,62,72,74,0,71,69,72,72,76,0,0,0,0,0,0,71,0,72,79,0,79,0,67,0,0,0,71];
    ~melodyCutoff = 3177;
    ~percSteps = [0,1,1,1,1,1,0,1,0,1,1,0,1,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1110, 3677); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L15 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 137; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [74,0,78,0,0,0,76,0,0,0,86,0,0,0,0,0,83,0,0,0,0,0,0,0,0,79,0,79,86,0,0,69];
    ~melodyAmp = 0.22;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,1,1,1,0,1,0,1,1,0,1,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[L15 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 135; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3477;
    ~melodyNotes = [45,38,43,0,0,0,0,0,0,55,40,45,45,38,0,0,0,0,45,38,48,0,50,47,0,0,0,0,50,52,0,0];
    ~melodyAmp = 0.2;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.32, 1110, \sin, 2677) };
    ~vcfOn !? { ~vcfOn.(\moog, 1310, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    78.wait;

    "[L15 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.2; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2677);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L15 6:00] === fin GARAGE FINALE ===".postln;
}).play;
"=== TRACK L15 : GARAGE FINALE 6 min lancee ===".postln;
)
