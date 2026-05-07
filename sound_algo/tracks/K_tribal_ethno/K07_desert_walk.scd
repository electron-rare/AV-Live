// =====================================================================
//  K07_desert_walk.scd  --  Album K "DESERT WALK", track 07/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K07 : "DESERT WALK" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K07 0:00] intro -- didgeridoo solo + perc tom...".postln;
    ~bpm = 100;
    ~kickAmp = 0.54; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 52; ~kickPitchAmt = 3.6; ~kickDecay = 0.54;
    ~kickDrive = 1.2; ~kickClick = 0.26;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3585;
    ~melodyNotes = [71,0,0,0,0,76,0,0,0,74,0,0,0,0,0,0,72,0,64,62,0,0,0,69,79,0,0,0,0,0,76,0];
    ~kickSteps = [0,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [1,0,0,0,0,0,0,1,0,0,1,0,0,0,1,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\drone) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    60.wait;

    "[K07 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 100; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [62,62,0,71,67,0,74,76,0,62,0,0,62,74,0,71,0,0,76,0,0,0,67,0,0,72,0,67,62,74,79,69];
    ~melodyCutoff = 4085;
    ~percSteps = [0,0,1,1,0,1,1,0,0,0,0,0,1,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1487, 4585); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K07 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 100; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.59;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,89,0,81,86,0,0,0,86,0,82,0,82,77,89,0,81,0,0,0,81,0,0,0,77,89,0,0,86,84,0,0];
    ~melodyAmp = 0.23;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHigh);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,1,0,1,1,0,0,0,0,0,1,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[K07 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 96; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4385;
    ~melodyNotes = [0,0,0,0,0,0,0,0,52,35,35,52,0,0,42,42,49,0,44,35,0,40,49,0,0,35,49,47,0,0,0,0];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.21, 1487, \sin, 3585) };
    ~vcfOn !? { ~vcfOn.(\moog, 1687, 0.4) };
    ~fxPreset !? { ~fxPreset.(\drone) };
    ~reload.value;
    60.wait;

    "[K07 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.54;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3585);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K07 5:00] === fin DESERT WALK ===".postln;
}).play;
"=== TRACK K07 : DESERT WALK 5 min lancee ===".postln;
)
