// =====================================================================
//  N10_cursed_bells.scd  --  Album N "CURSED BELLS", track 10/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N10 : "CURSED BELLS" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N10 0:00] intro -- warmPad solo + perc cowbell...".postln;
    ~bpm = 134;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 60; ~kickPitchAmt = 3.3; ~kickDecay = 0.45;
    ~kickDrive = 1.2; ~kickClick = 0.24;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3671;
    ~melodyNotes = [0,0,0,69,0,67,0,74,0,0,0,0,0,66,0,0,62,0,0,0,0,69,0,0,0,0,0,0,0,57,64,57];
    ~kickSteps = [0,0,1,1,0,1,0,0,0,0,0,0,1,1,0,1];
    ~hatSteps = [0,1,1,1,0,0,0,0,0,1,1,0,1,0,1,0];
    ~percInst = \cowbell;
    ~percSteps = [0,1,0,0,0,1,1,0,1,1,0,0,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    96.wait;

    "[N10 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [62,57,59,59,71,62,0,0,0,0,57,57,0,0,66,0,59,0,0,67,74,67,69,66,67,66,69,0,64,62,59,0];
    ~melodyCutoff = 4171;
    ~percSteps = [1,0,0,0,0,1,1,0,1,1,0,1,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1144, 4671); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N10 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [78,0,0,71,0,83,0,0,69,0,0,0,0,78,0,0,0,0,0,0,74,81,69,86,81,0,78,0,0,79,0,76];
    ~melodyAmp = 0.23;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,0,0,0,1,1,0,1,1,0,1,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[N10 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 140; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4471;
    ~melodyNotes = [0,0,0,50,46,38,0,0,0,0,53,0,38,0,50,46,0,0,0,46,0,0,45,50,0,0,43,0,36,0,0,0];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.21, 1144, \sin, 3671) };
    ~vcfOn !? { ~vcfOn.(\moog, 1344, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    114.wait;

    "[N10 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3671);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N10 8:00] === fin CURSED BELLS ===".postln;
}).play;
"=== TRACK N10 : CURSED BELLS 8 min lancee ===".postln;
)
