// =====================================================================
//  O09_silk_road.scd  --  Album O "SILK ROAD", track 09/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O09 : "SILK ROAD" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O09 0:00] intro -- pipa solo + perc taiko...".postln;
    ~bpm = 100;
    ~kickAmp = 0.47; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 54; ~kickPitchAmt = 2.9; ~kickDecay = 0.29;
    ~kickDrive = 1.2; ~kickClick = 0.17;
    ~melodyInst = \pipa;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3719;
    ~melodyNotes = [62,0,0,0,0,55,60,55,0,72,0,62,0,62,0,60,0,0,0,0,0,0,0,0,0,0,0,0,55,0,0,67];
    ~kickSteps = [0,0,1,0,0,0,0,1,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,1,0,0,0,0,0,0,0,1,0,1,0,1];
    ~percInst = \taiko;
    ~percSteps = [0,0,1,0,0,1,0,0,0,1,1,0,0,1,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    84.wait;

    "[O09 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 96; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,60,72,65,0,0,65,0,67,0,57,64,72,0,67,0,72,0,0,0,0,0,64,55,0,0,0,57,0,0,0];
    ~melodyCutoff = 4219;
    ~percSteps = [1,1,0,1,0,1,0,0,1,0,0,0,1,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1249, 4719); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O09 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 104; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.52;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [91,84,0,0,0,0,0,84,88,0,0,0,0,76,0,88,0,84,86,0,0,84,88,0,0,88,0,76,0,86,0,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleVietnam);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,1,0,1,0,0,1,0,0,0,1,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[O09 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 104; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \pipa;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4519;
    ~melodyNotes = [0,0,0,0,0,0,0,43,43,0,0,0,50,0,0,0,0,43,0,42,47,38,0,0,0,0,40,0,50,0,47,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.29, 1249, \sin, 3719) };
    ~vcfOn !? { ~vcfOn.(\moog, 1449, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    96.wait;

    "[O09 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.47;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3719);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O09 7:00] === fin SILK ROAD ===".postln;
}).play;
"=== TRACK O09 : SILK ROAD 7 min lancee ===".postln;
)
