// =====================================================================
//  N09_midnight_chase.scd  --  Album N "MIDNIGHT CHASE", track 09/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N09 : "MIDNIGHT CHASE" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N09 0:00] intro -- subBoom solo + perc cowbell...".postln;
    ~bpm = 138;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 52; ~kickPitchAmt = 2.6; ~kickDecay = 0.26;
    ~kickDrive = 1.2; ~kickClick = 0.19;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2436;
    ~melodyNotes = [75,0,67,0,0,72,0,0,60,0,70,0,72,60,0,0,0,0,0,70,0,75,0,0,68,0,60,0,0,0,75,63];
    ~kickSteps = [0,0,0,0,0,1,1,0,0,1,0,0,0,0,0,0];
    ~hatSteps = [0,1,0,1,0,0,1,1,0,0,0,0,1,0,0,1];
    ~percInst = \cowbell;
    ~percSteps = [0,0,0,0,0,0,0,1,0,1,0,1,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    84.wait;

    "[N09 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,65,75,67,72,0,0,65,58,67,0,0,0,63,72,0,0,68,70,0,68,58,0,0,75,63,0,70,0,68,0];
    ~melodyCutoff = 2936;
    ~percSteps = [0,0,0,1,0,1,0,0,0,1,1,0,1,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1205, 3436); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N09 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 142; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [74,0,0,0,77,84,89,82,79,74,89,0,0,84,74,72,77,0,0,0,0,79,0,0,89,86,84,84,0,74,0,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,0,1,0,1,0,0,0,1,1,0,1,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[N09 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 138; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3236;
    ~melodyNotes = [0,0,43,52,43,0,0,0,50,50,50,0,38,0,0,0,0,48,47,38,45,0,47,55,47,50,45,45,0,0,0,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.3, 1205, \sin, 2436) };
    ~vcfOn !? { ~vcfOn.(\moog, 1405, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    96.wait;

    "[N09 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2436);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N09 7:00] === fin MIDNIGHT CHASE ===".postln;
}).play;
"=== TRACK N09 : MIDNIGHT CHASE 7 min lancee ===".postln;
)
