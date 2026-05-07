// =====================================================================
//  M09_speedrun.scd  --  Album M "SPEEDRUN", track 09/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M09 : "SPEEDRUN" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M09 0:00] intro -- saw3 solo + perc tom...".postln;
    ~bpm = 180;
    ~kickAmp = 0.54; ~hatAmp = 0.06; ~melodyAmp = 0.24;
    ~kickFreq = 41; ~kickPitchAmt = 3.2; ~kickDecay = 0.28;
    ~kickDrive = 1.2; ~kickClick = 0.27;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3747;
    ~melodyNotes = [0,0,0,0,0,0,0,0,69,0,0,0,0,60,0,0,0,57,0,0,62,0,0,0,0,67,0,0,67,67,60,62];
    ~kickSteps = [0,0,0,1,0,0,1,0,0,1,0,0,0,0,1,0];
    ~hatSteps = [0,0,0,1,0,0,0,0,0,0,0,1,0,0,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,1,0,1,0,0,0,0,0,0,0,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    84.wait;

    "[M09 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 178; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [67,69,0,67,67,0,55,62,0,65,62,60,69,72,62,0,0,0,72,0,64,0,64,65,62,57,72,0,0,55,69,69];
    ~melodyCutoff = 4247;
    ~percSteps = [1,0,1,0,1,1,0,1,1,1,0,1,0,0,0,0]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1293, 4747); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M09 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 176; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.59;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,89,0,0,0,89,81,0,82,0,72,0,0,89,77,0,0,0,0,84,0,0,79,0,0,0,0,72,0,82,0,0];
    ~melodyAmp = 0.26;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,0,1,1,0,1,1,1,0,1,0,0,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[M09 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 178; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4547;
    ~melodyNotes = [0,42,45,0,0,0,0,40,40,0,40,0,0,0,40,35,0,0,0,0,0,0,0,0,0,0,43,33,35,40,0,0];
    ~melodyAmp = 0.24;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.16, 1293, \sin, 3747) };
    ~vcfOn !? { ~vcfOn.(\moog, 1493, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    96.wait;

    "[M09 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.24; ~kickAmp = x * 0.54;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3747);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M09 7:00] === fin SPEEDRUN ===".postln;
}).play;
"=== TRACK M09 : SPEEDRUN 7 min lancee ===".postln;
)
