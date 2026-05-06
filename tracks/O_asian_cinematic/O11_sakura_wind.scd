// =====================================================================
//  O11_sakura_wind.scd  --  Album O "SAKURA WIND", track 11/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O11 : "SAKURA WIND" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O11 0:00] intro -- koto solo + perc tom...".postln;
    ~bpm = 78;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 64; ~kickPitchAmt = 3.8; ~kickDecay = 0.3;
    ~kickDrive = 1.2; ~kickClick = 0.12;
    ~melodyInst = \koto;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2571;
    ~melodyNotes = [71,69,0,0,76,0,0,0,0,0,0,0,0,79,0,0,62,0,0,0,0,0,0,0,72,0,67,76,79,76,0,0];
    ~kickSteps = [0,0,0,0,0,0,0,0,1,0,0,0,0,0,1,0];
    ~hatSteps = [1,0,1,0,1,0,1,0,0,1,1,0,0,0,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,1,0,0,0,0,0,0,1,0,0,1,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    84.wait;

    "[O11 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 78; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [79,0,0,0,0,69,0,0,79,72,76,0,0,76,62,79,0,72,0,0,0,0,0,0,0,79,74,79,76,0,0,0];
    ~melodyCutoff = 3071;
    ~percSteps = [0,1,0,1,1,0,1,0,1,1,0,0,0,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1246, 3571); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O11 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 80; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [79,81,0,0,76,79,0,81,71,81,0,69,0,0,0,79,83,0,71,0,69,0,0,0,0,78,74,0,0,74,0,71];
    ~melodyAmp = 0.23;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHirajoshi);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,0,1,1,0,1,0,1,1,0,0,0,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[O11 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 82; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \koto;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3371;
    ~melodyNotes = [0,0,35,47,0,0,37,0,44,40,47,0,0,42,45,0,0,49,42,37,52,0,0,0,49,0,0,0,0,0,0,0];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.25, 1246, \sin, 2571) };
    ~vcfOn !? { ~vcfOn.(\moog, 1446, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    96.wait;

    "[O11 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2571);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O11 7:00] === fin SAKURA WIND ===".postln;
}).play;
"=== TRACK O11 : SAKURA WIND 7 min lancee ===".postln;
)
