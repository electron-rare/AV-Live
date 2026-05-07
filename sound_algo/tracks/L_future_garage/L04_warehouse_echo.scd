// =====================================================================
//  L04_warehouse_echo.scd  --  Album L "WAREHOUSE ECHO", track 04/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L04 : "WAREHOUSE ECHO" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L04 0:00] intro -- pad solo + perc rim...".postln;
    ~bpm = 138;
    ~kickAmp = 0.45; ~hatAmp = 0.06; ~melodyAmp = 0.24;
    ~kickFreq = 52; ~kickPitchAmt = 3.0; ~kickDecay = 0.44;
    ~kickDrive = 1.2; ~kickClick = 0.09;
    ~melodyInst = \pad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3010;
    ~melodyNotes = [0,74,0,64,0,0,64,0,74,62,0,74,0,0,0,62,0,0,57,57,0,67,74,0,0,0,74,74,71,62,0,74];
    ~kickSteps = [1,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1];
    ~hatSteps = [0,0,1,0,1,1,0,0,0,0,0,0,0,0,0,0];
    ~percInst = \rim;
    ~percSteps = [1,1,1,0,1,1,0,0,0,0,1,0,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    84.wait;

    "[L04 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [66,0,67,67,0,0,67,74,64,74,71,71,0,69,71,0,0,66,67,71,64,62,66,0,0,64,59,67,0,57,69,66];
    ~melodyCutoff = 3510;
    ~percSteps = [1,1,1,1,0,1,1,0,0,0,1,0,0,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1450, 4010); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L04 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.5;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,70,79,80,0,0,75,82,0,0,77,87,87,0,0,0,0,0,80,0,0,0,80,0,72,79,84,82,70,75,0];
    ~melodyAmp = 0.26;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,1,0,1,1,0,0,0,1,0,0,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[L04 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 144; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \pad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3810;
    ~melodyNotes = [0,0,0,33,0,47,0,0,50,0,0,0,0,0,0,0,47,0,42,0,0,42,33,0,0,0,0,0,0,40,0,0];
    ~melodyAmp = 0.24;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.21, 1450, \sin, 3010) };
    ~vcfOn !? { ~vcfOn.(\moog, 1650, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    96.wait;

    "[L04 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.24; ~kickAmp = x * 0.45;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3010);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L04 7:00] === fin WAREHOUSE ECHO ===".postln;
}).play;
"=== TRACK L04 : WAREHOUSE ECHO 7 min lancee ===".postln;
)
