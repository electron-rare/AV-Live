// =====================================================================
//  K04_taiko_war.scd  --  Album K "TAIKO WAR", track 04/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K04 : "TAIKO WAR" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K04 0:00] intro -- taiko solo + perc taiko...".postln;
    ~bpm = 110;
    ~kickAmp = 0.53; ~hatAmp = 0.06; ~melodyAmp = 0.18;
    ~kickFreq = 46; ~kickPitchAmt = 3.2; ~kickDecay = 0.49;
    ~kickDrive = 1.2; ~kickClick = 0.13;
    ~melodyInst = \taiko;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2620;
    ~melodyNotes = [0,65,0,67,0,0,0,60,0,58,68,0,0,0,0,75,58,63,70,0,0,0,0,0,0,58,0,0,0,0,75,75];
    ~kickSteps = [0,0,0,0,0,0,1,0,0,0,0,0,0,0,1,0];
    ~hatSteps = [1,0,0,0,1,1,0,0,0,0,1,0,0,0,1,0];
    ~percInst = \taiko;
    ~percSteps = [1,0,0,0,0,0,0,1,0,1,0,0,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    84.wait;

    "[K04 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 110; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [60,0,0,67,63,72,0,0,58,0,67,67,70,75,0,0,0,0,72,0,0,58,65,70,0,0,65,0,0,67,0,0];
    ~melodyCutoff = 3120;
    ~percSteps = [0,0,1,0,1,0,1,1,1,1,0,1,0,0,0,1]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1478, 3620); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K04 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 108; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.58;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [72,81,77,0,0,0,74,0,77,0,0,79,0,0,0,0,67,69,0,0,84,0,0,84,0,84,0,0,0,84,72,0];
    ~melodyAmp = 0.2;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,0,1,0,1,1,1,1,0,1,0,0,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[K04 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 108; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \taiko;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3420;
    ~melodyNotes = [0,0,0,0,52,48,0,0,0,0,0,0,0,0,40,52,0,50,55,47,0,0,38,0,0,40,0,52,0,0,48,0];
    ~melodyAmp = 0.18;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.3, 1478, \sin, 2620) };
    ~vcfOn !? { ~vcfOn.(\moog, 1678, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    96.wait;

    "[K04 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18; ~kickAmp = x * 0.53;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2620);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K04 7:00] === fin TAIKO WAR ===".postln;
}).play;
"=== TRACK K04 : TAIKO WAR 7 min lancee ===".postln;
)
