// =====================================================================
//  K13_mountain_call.scd  --  Album K "MOUNTAIN CALL", track 13/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K13 : "MOUNTAIN CALL" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K13 0:00] intro -- didgeridoo solo + perc taiko...".postln;
    ~bpm = 95;
    ~kickAmp = 0.45; ~hatAmp = 0.06; ~melodyAmp = 0.18;
    ~kickFreq = 63; ~kickPitchAmt = 2.5; ~kickDecay = 0.46;
    ~kickDrive = 1.2; ~kickClick = 0.16;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2590;
    ~melodyNotes = [0,0,0,64,71,0,0,79,79,71,0,69,62,0,74,0,0,62,0,71,69,0,0,74,0,0,0,64,0,0,79,79];
    ~kickSteps = [0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [1,1,0,0,0,0,0,0,1,1,0,0,0,0,1,1];
    ~percInst = \taiko;
    ~percSteps = [0,0,0,0,1,0,1,0,0,0,1,0,1,1,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\drone) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    48.wait;

    "[K13 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 95; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [76,0,64,0,0,74,64,0,0,0,74,0,76,79,0,64,79,0,0,0,0,71,62,62,0,72,0,67,64,76,0,64];
    ~melodyCutoff = 3090;
    ~percSteps = [1,1,1,1,0,0,1,0,0,1,1,1,1,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1443, 3590); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K13 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 91; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.5;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,79,76,0,76,0,83,0,81,91,84,0,0,0,91,0,0,0,0,0,83,0,86,0,0,0,0,91,0,0,86];
    ~melodyAmp = 0.2;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,1,0,0,1,0,0,1,1,1,1,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[K13 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 95; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3390;
    ~melodyNotes = [0,0,45,52,0,0,45,0,50,0,0,50,38,0,0,0,0,0,0,0,0,0,0,55,0,0,0,0,0,48,0,0];
    ~melodyAmp = 0.18;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.18, 1443, \sin, 2590) };
    ~vcfOn !? { ~vcfOn.(\moog, 1643, 0.4) };
    ~fxPreset !? { ~fxPreset.(\drone) };
    ~reload.value;
    42.wait;

    "[K13 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18; ~kickAmp = x * 0.45;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2590);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K13 4:00] === fin MOUNTAIN CALL ===".postln;
}).play;
"=== TRACK K13 : MOUNTAIN CALL 4 min lancee ===".postln;
)
