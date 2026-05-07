// =====================================================================
//  L13_neon_droplets.scd  --  Album L "NEON DROPLETS", track 13/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L13 : "NEON DROPLETS" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L13 0:00] intro -- rhodes solo + perc rim...".postln;
    ~bpm = 132;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 43; ~kickPitchAmt = 2.1; ~kickDecay = 0.32;
    ~kickDrive = 1.2; ~kickClick = 0.21;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3045;
    ~melodyNotes = [60,0,77,0,0,0,0,0,0,69,0,0,0,74,69,0,0,69,0,60,0,0,0,0,0,0,74,72,0,0,77,0];
    ~kickSteps = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,0,0,1,0,1,0,0,1,0,1,0,0,1];
    ~percInst = \rim;
    ~percSteps = [0,1,1,0,1,0,0,0,0,0,0,1,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    48.wait;

    "[L13 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [60,0,0,74,0,0,70,0,60,69,60,67,72,69,60,0,72,0,0,65,0,60,65,0,0,65,70,0,0,0,0,0];
    ~melodyCutoff = 3545;
    ~percSteps = [0,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1045, 4045); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L13 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,81,0,0,0,86,0,83,0,83,0,86,0,74,78,0,83,0,69,0,81,0,0,0,0,0,0,78,78,0,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHigh);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,1,1,1,1,1,1,1,1,1,0,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[L13 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \rhodes;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3845;
    ~melodyNotes = [0,0,0,0,0,44,0,42,0,0,47,44,47,0,37,44,52,47,0,37,35,40,0,0,0,0,0,0,0,0,0,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 1045, \sin, 3045) };
    ~vcfOn !? { ~vcfOn.(\moog, 1245, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    42.wait;

    "[L13 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3045);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L13 4:00] === fin NEON DROPLETS ===".postln;
}).play;
"=== TRACK L13 : NEON DROPLETS 4 min lancee ===".postln;
)
