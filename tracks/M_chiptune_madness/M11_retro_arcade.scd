// =====================================================================
//  M11_retro_arcade.scd  --  Album M "RETRO ARCADE", track 11/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M11 : "RETRO ARCADE" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M11 0:00] intro -- squareLead solo + perc tom...".postln;
    ~bpm = 145;
    ~kickAmp = 0.52; ~hatAmp = 0.06; ~melodyAmp = 0.24;
    ~kickFreq = 43; ~kickPitchAmt = 3.9; ~kickDecay = 0.49;
    ~kickDrive = 1.2; ~kickClick = 0.24;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2480;
    ~melodyNotes = [76,0,0,0,67,0,0,0,0,67,0,62,69,0,74,64,71,67,67,62,0,0,72,74,0,76,0,72,69,0,69,76];
    ~kickSteps = [0,1,1,0,0,0,0,1,0,0,0,0,0,1,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,0,1,0,0,0,1];
    ~percInst = \tom;
    ~percSteps = [1,0,1,1,0,1,0,1,1,1,1,0,0,1,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    84.wait;

    "[M11 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 147; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,0,79,0,76,0,79,0,74,0,67,71,0,72,0,62,0,0,0,67,0,69,0,0,0,0,0,0,0,69,0];
    ~melodyCutoff = 2980;
    ~percSteps = [0,1,1,1,0,1,1,0,1,1,1,1,0,0,0,1]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(988, 3480); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M11 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 147; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.57;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,69,0,0,77,0,77,81,81,0,77,84,81,0,81,0,0,84,76,0,84,0,0,0,0,74,84,0,69,0,0,0];
    ~melodyAmp = 0.26;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,1,0,1,1,0,1,1,1,1,0,0,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[M11 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 145; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3280;
    ~melodyNotes = [0,38,0,0,0,0,36,0,40,0,31,0,0,48,0,43,45,0,0,0,45,0,0,0,0,0,0,0,0,0,0,0];
    ~melodyAmp = 0.24;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.19, 988, \sin, 2480) };
    ~vcfOn !? { ~vcfOn.(\moog, 1188, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    96.wait;

    "[M11 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.24; ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2480);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M11 7:00] === fin RETRO ARCADE ===".postln;
}).play;
"=== TRACK M11 : RETRO ARCADE 7 min lancee ===".postln;
)
