// =====================================================================
//  N02_memphis_drift.scd  --  Album N "MEMPHIS DRIFT", track 02/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N02 : "MEMPHIS DRIFT" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N02 0:00] intro -- subBoom solo + perc cowbell...".postln;
    ~bpm = 132;
    ~kickAmp = 0.53; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 42; ~kickPitchAmt = 2.5; ~kickDecay = 0.53;
    ~kickDrive = 1.2; ~kickClick = 0.11;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3411;
    ~melodyNotes = [59,74,67,0,0,0,74,0,66,0,0,0,67,59,0,0,0,0,64,0,0,64,0,74,0,0,0,0,0,0,0,0];
    ~kickSteps = [0,1,0,1,0,0,0,0,0,0,1,0,0,0,1,0];
    ~hatSteps = [0,1,0,0,0,0,0,1,0,0,0,0,1,1,0,0];
    ~percInst = \cowbell;
    ~percSteps = [0,1,0,0,0,0,0,1,1,0,0,0,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    60.wait;

    "[N02 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [64,0,0,0,69,0,0,67,62,66,59,0,67,0,0,74,0,66,0,0,0,0,64,0,67,71,0,71,62,59,66,0];
    ~melodyCutoff = 3911;
    ~percSteps = [0,1,1,0,0,1,0,0,1,0,1,1,1,0,0,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1300, 4411); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N02 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.58;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [84,0,0,74,77,74,69,0,67,72,69,0,81,0,74,0,0,0,77,0,0,74,0,0,74,79,79,69,0,0,0,0];
    ~melodyAmp = 0.21;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,0,0,1,0,0,1,0,1,1,1,0,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[N02 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4211;
    ~melodyNotes = [0,52,44,0,0,52,0,0,0,40,0,52,37,0,52,0,47,0,47,0,0,44,37,0,0,49,0,49,0,35,45,0];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.23, 1300, \sin, 3411) };
    ~vcfOn !? { ~vcfOn.(\moog, 1500, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    60.wait;

    "[N02 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.53;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3411);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N02 5:00] === fin MEMPHIS DRIFT ===".postln;
}).play;
"=== TRACK N02 : MEMPHIS DRIFT 5 min lancee ===".postln;
)
