// =====================================================================
//  M06_game_over.scd  --  Album M "GAME OVER", track 06/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M06 : "GAME OVER" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M06 0:00] intro -- squareLead solo + perc tom...".postln;
    ~bpm = 140;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.2;
    ~kickFreq = 40; ~kickPitchAmt = 4.0; ~kickDecay = 0.53;
    ~kickDrive = 1.2; ~kickClick = 0.27;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3580;
    ~melodyNotes = [60,0,64,72,0,0,0,0,0,0,0,0,62,0,0,65,0,72,55,0,57,0,0,0,0,69,0,62,69,0,0,67];
    ~kickSteps = [1,0,0,0,0,0,0,0,1,1,0,0,0,1,0,0];
    ~hatSteps = [0,0,0,0,1,0,0,0,1,0,1,1,0,1,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,1,0,1,0,1,0,1,1,0,0,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    72.wait;

    "[M06 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 138; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [62,60,0,55,60,62,0,0,0,0,69,67,69,0,0,69,0,0,0,0,72,0,55,0,72,60,64,0,62,0,65,0];
    ~melodyCutoff = 4080;
    ~percSteps = [0,1,1,0,0,1,0,0,1,0,0,0,0,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1016, 4580); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M06 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 142; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,67,0,0,0,0,76,81,0,0,84,74,0,0,0,72,79,0,0,0,74,0,79,79,0,74,69,69,0,0,76];
    ~melodyAmp = 0.22;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,0,0,1,0,0,1,0,0,0,0,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[M06 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 140; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4380;
    ~melodyNotes = [0,0,0,47,0,0,0,49,0,0,42,0,0,40,0,0,0,35,42,44,0,0,37,0,37,0,0,0,42,0,0,0];
    ~melodyAmp = 0.2;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.28, 1016, \sin, 3580) };
    ~vcfOn !? { ~vcfOn.(\moog, 1216, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    78.wait;

    "[M06 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.2; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3580);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M06 6:00] === fin GAME OVER ===".postln;
}).play;
"=== TRACK M06 : GAME OVER 6 min lancee ===".postln;
)
