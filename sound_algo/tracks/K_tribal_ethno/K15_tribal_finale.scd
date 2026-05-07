// =====================================================================
//  K15_tribal_finale.scd  --  Album K "TRIBAL FINALE", track 15/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K15 : "TRIBAL FINALE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K15 0:00] intro -- handpan solo + perc taiko...".postln;
    ~bpm = 110;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.2;
    ~kickFreq = 53; ~kickPitchAmt = 2.3; ~kickDecay = 0.34;
    ~kickDrive = 1.2; ~kickClick = 0.25;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3360;
    ~melodyNotes = [58,58,0,0,0,0,70,0,0,67,0,0,65,0,0,0,0,0,0,0,0,0,0,65,67,63,67,0,0,63,0,58];
    ~kickSteps = [1,0,1,0,0,1,0,0,0,0,0,0,1,0,0,0];
    ~hatSteps = [0,1,0,0,0,0,0,0,0,0,1,1,0,0,0,0];
    ~percInst = \taiko;
    ~percSteps = [0,0,1,0,0,0,1,1,0,1,1,0,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    72.wait;

    "[K15 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 110; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [60,58,0,0,0,70,0,75,72,0,70,60,0,0,0,0,0,68,0,0,67,0,67,0,63,58,67,0,72,67,72,0];
    ~melodyCutoff = 3860;
    ~percSteps = [1,1,1,1,1,0,1,1,1,0,1,0,0,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1479, 4360); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K15 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 114; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,69,83,0,0,0,0,69,0,79,0,0,81,69,0,0,0,0,83,79,0,0,76,69,0,69,0,69,74,79];
    ~melodyAmp = 0.22;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,1,1,0,1,1,1,0,1,0,0,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[K15 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 108; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4160;
    ~melodyNotes = [43,0,36,0,0,46,0,0,36,0,0,0,0,0,45,50,43,48,0,0,48,0,0,0,53,0,0,0,0,0,0,0];
    ~melodyAmp = 0.2;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.29, 1479, \sin, 3360) };
    ~vcfOn !? { ~vcfOn.(\moog, 1679, 0.4) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    78.wait;

    "[K15 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.2; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3360);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K15 6:00] === fin TRIBAL FINALE ===".postln;
}).play;
"=== TRACK K15 : TRIBAL FINALE 6 min lancee ===".postln;
)
