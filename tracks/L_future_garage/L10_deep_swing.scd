// =====================================================================
//  L10_deep_swing.scd  --  Album L "DEEP SWING", track 10/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L10 : "DEEP SWING" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L10 0:00] intro -- subBoom solo + perc rim...".postln;
    ~bpm = 138;
    ~kickAmp = 0.55; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 65; ~kickPitchAmt = 3.9; ~kickDecay = 0.36;
    ~kickDrive = 1.2; ~kickClick = 0.24;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3172;
    ~melodyNotes = [0,74,74,0,69,0,0,0,0,0,0,0,0,59,69,0,66,62,0,0,66,0,0,64,0,0,0,0,0,59,0,71];
    ~kickSteps = [0,0,0,1,0,0,0,1,1,0,0,0,0,0,0,0];
    ~hatSteps = [1,1,0,1,0,0,1,0,0,1,0,0,1,1,0,0];
    ~percInst = \rim;
    ~percSteps = [0,0,0,0,0,1,0,0,1,0,0,0,0,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    96.wait;

    "[L10 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,62,0,74,0,59,74,62,57,0,0,0,74,74,64,0,57,0,0,66,74,74,0,69,62,0,71,62,0,0,74,71];
    ~melodyCutoff = 3672;
    ~percSteps = [0,1,0,0,0,0,0,1,1,1,1,1,0,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1333, 4172); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L10 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 138; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.6;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [75,0,82,0,0,82,79,84,87,0,0,72,0,0,87,77,0,80,70,0,0,82,87,77,0,0,75,87,0,0,0,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,0,0,0,0,0,1,1,1,1,1,0,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[L10 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 144; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3972;
    ~melodyNotes = [0,0,31,0,38,0,43,0,0,48,31,0,0,36,0,0,33,33,31,0,0,0,0,0,41,40,43,0,0,0,0,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.31, 1333, \sin, 3172) };
    ~vcfOn !? { ~vcfOn.(\moog, 1533, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    114.wait;

    "[L10 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.55;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3172);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L10 8:00] === fin DEEP SWING ===".postln;
}).play;
"=== TRACK L10 : DEEP SWING 8 min lancee ===".postln;
)
