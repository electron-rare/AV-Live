// =====================================================================
//  O14_imperial_court.scd  --  Album O "IMPERIAL COURT", track 14/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O14 : "IMPERIAL COURT" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O14 0:00] intro -- guzheng solo + perc taiko...".postln;
    ~bpm = 95;
    ~kickAmp = 0.51; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 42; ~kickPitchAmt = 4.0; ~kickDecay = 0.32;
    ~kickDrive = 1.2; ~kickClick = 0.26;
    ~melodyInst = \guzheng;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3413;
    ~melodyNotes = [79,62,74,71,0,0,0,71,67,71,0,79,67,62,62,0,0,72,62,0,67,74,0,0,64,69,0,0,0,64,0,0];
    ~kickSteps = [0,0,1,0,0,0,0,1,0,0,0,0,0,0,1,0];
    ~hatSteps = [0,1,0,0,0,1,1,1,1,0,0,1,0,0,0,0];
    ~percInst = \taiko;
    ~percSteps = [1,0,0,1,0,1,0,0,0,1,0,0,1,1,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    60.wait;

    "[O14 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 97; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [72,76,0,0,76,0,76,69,0,0,64,0,0,0,64,0,64,0,0,0,71,67,72,69,74,0,74,67,74,0,0,0];
    ~melodyCutoff = 3913;
    ~percSteps = [1,1,0,0,0,1,0,1,1,0,1,1,1,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1066, 4413); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O14 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 97; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.56;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,86,0,83,88,0,76,91,0,83,79,84,0,0,79,86,0,74,88,84,0,81,0,0,0,76,0,0,88,83,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleVietnam);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,0,0,1,0,1,1,0,1,1,1,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[O14 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 99; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \guzheng;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4213;
    ~melodyNotes = [0,0,48,47,0,0,40,47,0,0,50,0,0,52,0,0,52,50,52,52,45,0,52,0,0,43,0,0,45,40,40,52];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.18, 1066, \sin, 3413) };
    ~vcfOn !? { ~vcfOn.(\moog, 1266, 0.4) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    60.wait;

    "[O14 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.51;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3413);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O14 5:00] === fin IMPERIAL COURT ===".postln;
}).play;
"=== TRACK O14 : IMPERIAL COURT 5 min lancee ===".postln;
)
