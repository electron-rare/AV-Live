// =====================================================================
//  M04_save_point.scd  --  Album M "SAVE POINT", track 04/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M04 : "SAVE POINT" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M04 0:00] intro -- stab solo + perc tom...".postln;
    ~bpm = 145;
    ~kickAmp = 0.54; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 42; ~kickPitchAmt = 3.0; ~kickDecay = 0.41;
    ~kickDrive = 1.2; ~kickClick = 0.29;
    ~melodyInst = \stab;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3489;
    ~melodyNotes = [0,75,0,72,0,0,75,0,0,0,65,0,0,65,0,68,0,63,70,0,0,0,0,0,0,0,0,0,0,0,0,0];
    ~kickSteps = [0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,1,1,1,0,1,0,0,1,1,0,0,0,1,1];
    ~percInst = \tom;
    ~percSteps = [0,0,1,0,0,0,0,0,0,1,0,0,1,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    84.wait;

    "[M04 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 149; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,0,0,0,0,58,0,60,0,0,0,68,72,0,63,75,65,68,0,0,0,60,68,75,70,0,0,63,0,0,0];
    ~melodyCutoff = 3989;
    ~percSteps = [0,0,1,0,0,1,1,1,0,0,1,0,1,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1359, 4489); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M04 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 145; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.59;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [75,0,84,84,0,84,87,0,70,0,72,82,87,84,79,0,72,0,79,87,80,82,87,84,0,80,0,0,0,72,0,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHigh);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,0,0,1,1,1,0,0,1,0,1,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[M04 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 145; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \stab;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4289;
    ~melodyNotes = [0,48,0,0,0,38,0,0,45,0,0,45,0,0,33,33,48,40,0,43,0,0,0,48,38,0,0,40,40,0,41,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.31, 1359, \sin, 3489) };
    ~vcfOn !? { ~vcfOn.(\moog, 1559, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    96.wait;

    "[M04 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.54;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3489);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M04 7:00] === fin SAVE POINT ===".postln;
}).play;
"=== TRACK M04 : SAVE POINT 7 min lancee ===".postln;
)
