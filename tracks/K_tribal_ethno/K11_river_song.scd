// =====================================================================
//  K11_river_song.scd  --  Album K "RIVER SONG", track 11/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K11 : "RIVER SONG" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K11 0:00] intro -- flute solo + perc tom...".postln;
    ~bpm = 98;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 42; ~kickPitchAmt = 3.4; ~kickDecay = 0.54;
    ~kickDrive = 1.2; ~kickClick = 0.17;
    ~melodyInst = \flute;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2640;
    ~melodyNotes = [0,0,70,0,0,0,65,60,68,0,0,72,0,0,0,65,65,0,72,0,75,0,0,67,63,0,72,0,0,75,0,0];
    ~kickSteps = [0,0,0,0,0,0,0,0,0,1,0,1,0,0,0,1];
    ~hatSteps = [0,0,0,0,0,1,0,0,0,0,1,1,1,1,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,0,0,0,0,0,1,0,1,1,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    84.wait;

    "[K11 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 94; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [65,65,0,75,67,65,70,0,0,0,0,58,0,75,63,0,0,75,60,0,63,0,0,75,67,0,0,0,65,68,63,0];
    ~melodyCutoff = 3140;
    ~percSteps = [1,1,1,0,1,0,1,1,1,1,1,1,0,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(941, 3640); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K11 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 96; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [82,0,0,87,70,0,77,70,0,0,84,77,87,0,0,77,0,75,79,79,0,84,0,0,0,79,0,0,0,75,87,77];
    ~melodyAmp = 0.25;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,0,1,0,1,1,1,1,1,1,0,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[K11 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 98; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \flute;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3440;
    ~melodyNotes = [38,0,0,40,43,0,0,0,31,36,33,40,36,0,0,0,0,48,0,38,0,36,31,0,0,33,0,0,38,0,41,43];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.16, 941, \sin, 2640) };
    ~vcfOn !? { ~vcfOn.(\moog, 1141, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    96.wait;

    "[K11 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2640);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K11 7:00] === fin RIVER SONG ===".postln;
}).play;
"=== TRACK K11 : RIVER SONG 7 min lancee ===".postln;
)
