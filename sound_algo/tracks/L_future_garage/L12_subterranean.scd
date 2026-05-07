// =====================================================================
//  L12_subterranean.scd  --  Album L "SUBTERRANEAN", track 12/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L12 : "SUBTERRANEAN" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L12 0:00] intro -- warmPad solo + perc hat...".postln;
    ~bpm = 136;
    ~kickAmp = 0.45; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 65; ~kickPitchAmt = 2.9; ~kickDecay = 0.34;
    ~kickDrive = 1.2; ~kickClick = 0.12;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3051;
    ~melodyNotes = [0,77,69,62,0,0,0,0,0,0,74,0,0,0,0,0,0,0,0,0,0,0,74,0,0,0,0,0,0,0,62,0];
    ~kickSteps = [0,0,0,0,0,0,0,0,0,1,1,0,1,0,0,0];
    ~hatSteps = [1,1,1,0,0,1,0,0,1,1,0,0,1,1,1,0];
    ~percInst = \hat;
    ~percSteps = [0,1,0,1,1,0,0,0,0,0,0,0,0,1,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    60.wait;

    "[L12 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,69,0,0,70,72,0,0,0,60,67,72,67,0,62,69,0,77,0,62,0,72,69,67,0,0,0,60,77,69,0,77];
    ~melodyCutoff = 3551;
    ~percSteps = [0,0,0,1,1,0,0,0,1,1,1,1,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1349, 4051); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L12 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.5;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,0,0,0,84,0,76,74,0,0,72,76,0,67,79,0,84,76,0,0,69,0,0,0,84,72,84,0,0,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,0,1,1,0,0,0,1,1,1,1,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[L12 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3851;
    ~melodyNotes = [0,0,33,31,0,0,0,0,0,0,0,0,38,48,0,45,0,0,41,0,0,0,0,0,0,0,0,0,0,0,48,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 1349, \sin, 3051) };
    ~vcfOn !? { ~vcfOn.(\moog, 1549, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    60.wait;

    "[L12 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.45;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3051);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L12 5:00] === fin SUBTERRANEAN ===".postln;
}).play;
"=== TRACK L12 : SUBTERRANEAN 5 min lancee ===".postln;
)
