// =====================================================================
//  K10_forest_ritual.scd  --  Album K "FOREST RITUAL", track 10/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K10 : "FOREST RITUAL" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K10 0:00] intro -- handpan solo + perc tom...".postln;
    ~bpm = 102;
    ~kickAmp = 0.54; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 49; ~kickPitchAmt = 2.3; ~kickDecay = 0.53;
    ~kickDrive = 1.2; ~kickClick = 0.14;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3610;
    ~melodyNotes = [66,0,0,59,0,0,0,0,0,71,0,0,0,0,67,0,0,0,74,0,74,64,57,0,0,0,71,0,0,0,0,62];
    ~kickSteps = [0,0,0,1,0,0,0,0,0,0,0,1,0,0,1,0];
    ~hatSteps = [0,0,1,1,0,1,0,0,1,0,0,0,1,0,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    96.wait;

    "[K10 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 104; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [69,64,66,71,67,71,59,0,64,64,71,0,0,67,57,57,59,74,0,74,67,74,67,64,0,0,71,59,59,71,0,0];
    ~melodyCutoff = 4110;
    ~percSteps = [0,1,1,1,1,1,0,0,0,0,1,0,0,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1107, 4610); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K10 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 98; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.59;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,71,0,0,0,76,0,79,78,78,0,78,0,71,0,0,0,0,0,0,83,0,0,0,0,0,86,0,0,0,0,71];
    ~melodyAmp = 0.25;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,1,1,1,0,0,0,0,1,0,0,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[K10 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 106; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4410;
    ~melodyNotes = [0,40,0,40,35,37,0,0,0,0,0,35,0,40,0,0,52,45,40,0,42,0,0,0,49,0,0,0,0,0,0,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.28, 1107, \sin, 3610) };
    ~vcfOn !? { ~vcfOn.(\moog, 1307, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    114.wait;

    "[K10 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.54;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3610);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K10 8:00] === fin FOREST RITUAL ===".postln;
}).play;
"=== TRACK K10 : FOREST RITUAL 8 min lancee ===".postln;
)
