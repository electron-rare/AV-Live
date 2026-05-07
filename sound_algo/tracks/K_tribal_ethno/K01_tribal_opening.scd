// =====================================================================
//  K01_tribal_opening.scd  --  Album K "TRIBAL OPENING", track 01/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K01 : "TRIBAL OPENING" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K01 0:00] intro -- handpan solo + perc tom...".postln;
    ~bpm = 100;
    ~kickAmp = 0.51; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 50; ~kickPitchAmt = 3.9; ~kickDecay = 0.31;
    ~kickDrive = 1.2; ~kickClick = 0.24;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3058;
    ~melodyNotes = [64,0,0,0,72,62,55,0,0,0,0,0,0,60,0,72,64,69,72,69,0,0,0,0,0,0,0,0,0,0,0,0];
    ~kickSteps = [0,1,1,0,0,0,0,0,0,1,0,0,0,0,1,0];
    ~hatSteps = [0,1,1,0,0,0,0,1,0,0,0,0,0,1,0,1];
    ~percInst = \tom;
    ~percSteps = [0,1,0,0,1,0,0,0,0,0,0,0,1,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    48.wait;

    "[K01 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 104; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [65,0,0,0,0,57,0,69,67,0,0,64,65,72,55,69,0,0,60,0,62,69,57,57,64,55,72,0,65,0,57,60];
    ~melodyCutoff = 3558;
    ~percSteps = [1,0,1,0,1,0,1,0,1,1,0,0,1,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(983, 4058); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K01 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 96; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.56;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,79,0,77,72,0,0,0,77,0,0,84,87,75,0,0,70,0,0,82,0,0,84,0,0,0,0,84,0,84,0,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,0,1,0,1,0,1,1,0,0,1,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[K01 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 106; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3858;
    ~melodyNotes = [36,38,33,0,0,0,33,0,31,0,0,31,0,0,0,45,0,0,41,36,0,41,36,36,0,41,33,40,0,0,0,33];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.2, 983, \sin, 3058) };
    ~vcfOn !? { ~vcfOn.(\moog, 1183, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    42.wait;

    "[K01 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.51;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3058);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K01 4:00] === fin TRIBAL OPENING ===".postln;
}).play;
"=== TRACK K01 : TRIBAL OPENING 4 min lancee ===".postln;
)
