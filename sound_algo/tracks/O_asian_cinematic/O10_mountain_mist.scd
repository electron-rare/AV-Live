// =====================================================================
//  O10_mountain_mist.scd  --  Album O "MOUNTAIN MIST", track 10/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O10 : "MOUNTAIN MIST" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O10 0:00] intro -- flute solo + perc tom...".postln;
    ~bpm = 70;
    ~kickAmp = 0.53; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 50; ~kickPitchAmt = 2.6; ~kickDecay = 0.26;
    ~kickDrive = 1.2; ~kickClick = 0.19;
    ~melodyInst = \flute;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3434;
    ~melodyNotes = [0,65,0,74,0,0,0,74,60,0,65,0,0,0,0,69,70,65,0,67,0,77,0,0,69,0,70,0,69,0,0,0];
    ~kickSteps = [0,0,0,0,0,1,0,0,0,0,1,0,1,0,0,0];
    ~hatSteps = [0,0,0,1,0,1,1,1,0,1,1,0,0,1,0,1];
    ~percInst = \tom;
    ~percSteps = [1,0,0,0,0,0,0,0,0,0,0,0,1,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    96.wait;

    "[O10 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 74; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [69,0,0,70,74,0,70,0,69,0,0,70,0,0,72,62,0,0,0,74,70,67,65,67,0,0,60,62,0,60,0,0];
    ~melodyCutoff = 3934;
    ~percSteps = [1,0,0,1,0,0,1,0,0,0,1,1,1,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1018, 4434); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O10 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 70; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.58;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [74,71,86,69,69,0,0,76,0,0,0,0,0,0,0,86,0,81,79,0,0,0,0,78,0,0,0,0,78,78,0,0];
    ~melodyAmp = 0.21;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleJapanese);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,0,1,0,0,1,0,0,0,1,1,1,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[O10 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 68; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \flute;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4234;
    ~melodyNotes = [0,0,47,0,47,38,0,35,0,40,0,35,43,47,33,0,0,0,38,0,50,38,0,50,35,0,47,0,0,47,40,0];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.3, 1018, \sin, 3434) };
    ~vcfOn !? { ~vcfOn.(\moog, 1218, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    114.wait;

    "[O10 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.53;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3434);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O10 8:00] === fin MOUNTAIN MIST ===".postln;
}).play;
"=== TRACK O10 : MOUNTAIN MIST 8 min lancee ===".postln;
)
