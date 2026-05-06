// =====================================================================
//  M10_hidden_stage.scd  --  Album M "HIDDEN STAGE", track 10/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M10 : "HIDDEN STAGE" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M10 0:00] intro -- stab solo + perc tom...".postln;
    ~bpm = 150;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.2;
    ~kickFreq = 59; ~kickPitchAmt = 2.5; ~kickDecay = 0.33;
    ~kickDrive = 1.2; ~kickClick = 0.14;
    ~melodyInst = \stab;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2805;
    ~melodyNotes = [0,60,0,0,0,70,0,0,67,0,0,0,63,0,0,67,0,0,0,0,67,0,0,0,0,68,0,0,0,0,0,65];
    ~kickSteps = [0,0,0,0,0,1,0,0,1,0,0,0,0,1,0,0];
    ~hatSteps = [0,0,0,1,0,0,1,0,0,1,0,0,0,0,1,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,1,0,1,0,1,1,0,0,0,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    96.wait;

    "[M10 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 150; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [75,0,0,58,65,63,0,68,0,70,72,67,0,68,0,0,75,0,65,0,0,0,0,75,72,0,68,72,0,0,0,65];
    ~melodyCutoff = 3305;
    ~percSteps = [0,0,0,1,0,1,1,0,0,1,0,1,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1455, 3805); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M10 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 146; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,0,0,74,0,0,0,67,0,72,69,0,0,79,0,0,72,77,0,0,0,0,0,84,0,84,0,74,0,0];
    ~melodyAmp = 0.22;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHigh);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,0,1,0,1,1,0,0,1,0,1,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[M10 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 148; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \stab;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3605;
    ~melodyNotes = [48,43,45,0,38,0,0,48,0,47,0,52,48,0,55,0,45,38,52,0,0,0,52,0,48,0,38,0,55,0,0,48];
    ~melodyAmp = 0.2;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.28, 1455, \sin, 2805) };
    ~vcfOn !? { ~vcfOn.(\moog, 1655, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    114.wait;

    "[M10 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.2; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2805);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M10 8:00] === fin HIDDEN STAGE ===".postln;
}).play;
"=== TRACK M10 : HIDDEN STAGE 8 min lancee ===".postln;
)
