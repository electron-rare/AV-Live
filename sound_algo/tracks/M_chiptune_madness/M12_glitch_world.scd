// =====================================================================
//  M12_glitch_world.scd  --  Album M "GLITCH WORLD", track 12/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M12 : "GLITCH WORLD" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M12 0:00] intro -- fmLead solo + perc tom...".postln;
    ~bpm = 170;
    ~kickAmp = 0.46; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 56; ~kickPitchAmt = 3.4; ~kickDecay = 0.49;
    ~kickDrive = 1.2; ~kickClick = 0.29;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3354;
    ~melodyNotes = [0,55,0,69,0,62,0,0,55,0,0,60,72,0,65,64,0,57,65,0,55,0,0,62,0,0,0,67,0,0,69,0];
    ~kickSteps = [0,0,1,0,0,0,1,0,1,0,1,0,0,0,0,1];
    ~hatSteps = [0,0,0,0,0,1,0,0,0,0,1,0,0,0,1,1];
    ~percInst = \tom;
    ~percSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,1,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    60.wait;

    "[M12 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 170; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,67,0,0,0,72,0,67,62,0,0,0,57,72,57,0,0,72,0,0,57,0,0,67,72,69,69,57,67,0,65,60];
    ~melodyCutoff = 3854;
    ~percSteps = [1,1,0,1,0,1,0,1,1,0,1,1,1,0,0,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1280, 4354); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M12 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 174; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.51;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [86,78,0,0,83,69,74,0,83,0,0,0,0,0,79,0,0,79,78,0,79,0,74,74,0,0,0,0,81,79,0,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHungarian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,1,0,1,0,1,1,0,1,1,1,0,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[M12 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 170; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4154;
    ~melodyNotes = [42,0,52,47,0,35,0,0,0,35,0,52,47,0,0,0,37,47,0,0,52,52,0,0,0,0,40,0,0,0,0,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.22, 1280, \sin, 3354) };
    ~vcfOn !? { ~vcfOn.(\moog, 1480, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    60.wait;

    "[M12 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.46;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3354);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M12 5:00] === fin GLITCH WORLD ===".postln;
}).play;
"=== TRACK M12 : GLITCH WORLD 5 min lancee ===".postln;
)
