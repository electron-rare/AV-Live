// =====================================================================
//  K05_tabla_groove.scd  --  Album K "TABLA GROOVE", track 05/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K05 : "TABLA GROOVE" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K05 0:00] intro -- tabla solo + perc tabla...".postln;
    ~bpm = 115;
    ~kickAmp = 0.55; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 56; ~kickPitchAmt = 3.0; ~kickDecay = 0.3;
    ~kickDrive = 1.2; ~kickClick = 0.16;
    ~melodyInst = \tabla;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2707;
    ~melodyNotes = [0,71,0,0,67,76,0,76,74,79,0,0,0,0,0,62,67,0,0,0,67,64,0,0,64,69,71,74,0,0,0,0];
    ~kickSteps = [0,0,0,0,0,0,0,1,0,1,0,0,0,0,0,0];
    ~hatSteps = [1,1,1,0,0,0,1,0,0,0,0,0,0,0,0,0];
    ~percInst = \tabla;
    ~percSteps = [0,0,1,1,0,1,1,1,0,1,0,1,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    96.wait;

    "[K05 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 111; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,62,0,69,0,0,0,0,64,0,64,69,76,0,71,0,69,0,69,0,71,0,0,0,69,79,0,0,0,0,62,64];
    ~melodyCutoff = 3207;
    ~percSteps = [0,1,1,0,0,0,1,0,0,1,1,1,1,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(940, 3707); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K05 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 119; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.6;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [77,70,82,0,0,0,0,0,0,0,82,82,0,84,79,0,0,79,0,0,70,87,0,82,0,0,0,75,75,0,87,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,0,0,0,1,0,0,1,1,1,1,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[K05 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 113; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \tabla;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3507;
    ~melodyNotes = [0,31,48,33,0,41,36,43,0,0,0,38,48,48,0,31,0,0,36,0,0,45,0,0,0,0,36,0,33,0,0,38];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.21, 940, \sin, 2707) };
    ~vcfOn !? { ~vcfOn.(\moog, 1140, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    114.wait;

    "[K05 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.55;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2707);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K05 8:00] === fin TABLA GROOVE ===".postln;
}).play;
"=== TRACK K05 : TABLA GROOVE 8 min lancee ===".postln;
)
