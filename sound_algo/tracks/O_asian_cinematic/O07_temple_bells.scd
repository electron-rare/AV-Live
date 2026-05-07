// =====================================================================
//  O07_temple_bells.scd  --  Album O "TEMPLE BELLS", track 07/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O07 : "TEMPLE BELLS" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O07 0:00] intro -- handpan solo + perc tom...".postln;
    ~bpm = 95;
    ~kickAmp = 0.51; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 40; ~kickPitchAmt = 2.6; ~kickDecay = 0.29;
    ~kickDrive = 1.2; ~kickClick = 0.09;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2616;
    ~melodyNotes = [0,0,79,0,71,76,0,67,0,79,76,0,0,0,71,64,0,0,0,0,0,0,67,62,0,0,0,74,0,71,0,62];
    ~kickSteps = [0,0,0,1,0,0,0,0,0,1,0,0,0,0,0,0];
    ~hatSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0];
    ~percInst = \tom;
    ~percSteps = [1,1,1,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    60.wait;

    "[O07 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 99; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,64,76,0,0,0,69,0,0,0,0,0,69,79,67,0,64,71,67,79,0,0,64,69,0,0,76,0,71,0,79];
    ~melodyCutoff = 3116;
    ~percSteps = [1,1,1,1,0,1,1,0,0,0,0,0,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(912, 3616); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O07 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 93; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.56;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,79,0,72,0,77,0,0,0,72,82,0,77,84,84,0,0,79,82,84,70,0,0,79,75,82,0,87,70,82];
    ~melodyAmp = 0.24;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHirajoshi);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,1,0,1,1,0,0,0,0,0,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[O07 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 95; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3416;
    ~melodyNotes = [0,0,0,0,0,45,47,0,40,40,0,0,40,37,0,49,0,44,0,40,0,49,37,0,40,0,0,0,42,0,0,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.19, 912, \sin, 2616) };
    ~vcfOn !? { ~vcfOn.(\moog, 1112, 0.4) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    60.wait;

    "[O07 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.51;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2616);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O07 5:00] === fin TEMPLE BELLS ===".postln;
}).play;
"=== TRACK O07 : TEMPLE BELLS 5 min lancee ===".postln;
)
