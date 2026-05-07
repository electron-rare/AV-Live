// =====================================================================
//  L14_bassline_dub.scd  --  Album L "BASSLINE DUB", track 14/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L14 : "BASSLINE DUB" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L14 0:00] intro -- subBoom solo + perc hat...".postln;
    ~bpm = 130;
    ~kickAmp = 0.53; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 44; ~kickPitchAmt = 2.9; ~kickDecay = 0.43;
    ~kickDrive = 1.2; ~kickClick = 0.14;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3395;
    ~melodyNotes = [0,76,0,0,0,0,67,69,62,0,79,0,0,0,0,62,0,0,0,0,0,0,64,0,0,0,67,0,0,0,0,0];
    ~kickSteps = [0,0,0,0,0,1,0,0,1,0,0,0,0,0,0,0];
    ~hatSteps = [0,1,1,1,0,0,1,1,0,0,0,0,1,0,0,1];
    ~percInst = \hat;
    ~percSteps = [0,1,0,1,0,0,1,0,0,0,0,1,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[L14 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [72,0,67,62,0,79,0,0,0,0,0,62,0,76,0,0,0,76,64,0,71,0,64,67,0,64,0,69,64,0,79,0];
    ~melodyCutoff = 3895;
    ~percSteps = [1,1,0,1,0,1,0,0,1,1,0,1,1,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1218, 4395); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L14 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.58;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [81,0,0,0,86,0,82,0,0,0,0,84,0,74,0,74,0,0,82,0,0,84,0,0,0,0,0,0,0,81,0,82];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,1,0,1,0,0,1,1,0,1,1,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[L14 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \subBoom;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4195;
    ~melodyNotes = [0,0,43,0,0,0,38,0,55,0,0,52,0,0,38,0,43,0,50,0,0,55,45,0,0,0,55,0,0,52,45,55];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.34, 1218, \sin, 3395) };
    ~vcfOn !? { ~vcfOn.(\moog, 1418, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    60.wait;

    "[L14 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.53;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3395);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L14 5:00] === fin BASSLINE DUB ===".postln;
}).play;
"=== TRACK L14 : BASSLINE DUB 5 min lancee ===".postln;
)
