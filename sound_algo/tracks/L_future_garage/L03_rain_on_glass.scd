// =====================================================================
//  L03_rain_on_glass.scd  --  Album L "RAIN ON GLASS", track 03/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L03 : "RAIN ON GLASS" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L03 0:00] intro -- warmPad solo + perc hat...".postln;
    ~bpm = 135;
    ~kickAmp = 0.47; ~hatAmp = 0.06; ~melodyAmp = 0.24;
    ~kickFreq = 41; ~kickPitchAmt = 2.9; ~kickDecay = 0.3;
    ~kickDrive = 1.2; ~kickClick = 0.14;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3368;
    ~melodyNotes = [0,0,0,0,0,60,0,77,0,67,0,72,60,0,0,0,72,62,0,62,65,60,67,69,0,0,69,70,72,0,0,0];
    ~kickSteps = [0,0,0,0,0,1,0,0,0,0,1,0,0,1,0,0];
    ~hatSteps = [1,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0];
    ~percInst = \hat;
    ~percSteps = [0,0,0,0,0,0,0,0,0,0,0,1,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    72.wait;

    "[L03 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 135; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,67,0,0,77,62,72,0,0,70,62,65,67,70,72,0,65,0,67,72,65,0,67,77,69,0,0,70,65,0,0,0];
    ~melodyCutoff = 3868;
    ~percSteps = [0,1,1,0,1,1,1,1,1,0,1,0,1,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1469, 4368); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L03 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 139; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.52;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [74,69,81,0,0,0,76,0,0,77,67,0,0,0,77,84,76,72,0,79,0,0,0,0,69,67,67,79,0,0,0,0];
    ~melodyAmp = 0.26;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,0,1,1,1,1,1,0,1,0,1,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[L03 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 141; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4168;
    ~melodyNotes = [0,0,0,0,45,42,0,0,35,0,0,47,49,35,0,44,40,37,40,0,0,0,0,0,49,42,45,0,0,0,0,0];
    ~melodyAmp = 0.24;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.33, 1469, \sin, 3368) };
    ~vcfOn !? { ~vcfOn.(\moog, 1669, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    78.wait;

    "[L03 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.24; ~kickAmp = x * 0.47;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3368);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L03 6:00] === fin RAIN ON GLASS ===".postln;
}).play;
"=== TRACK L03 : RAIN ON GLASS 6 min lancee ===".postln;
)
