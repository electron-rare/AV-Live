// =====================================================================
//  O06_guzheng_river.scd  --  Album O "GUZHENG RIVER", track 06/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O06 : "GUZHENG RIVER" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O06 0:00] intro -- guzheng solo + perc tom...".postln;
    ~bpm = 85;
    ~kickAmp = 0.52; ~hatAmp = 0.06; ~melodyAmp = 0.18;
    ~kickFreq = 48; ~kickPitchAmt = 3.4; ~kickDecay = 0.36;
    ~kickDrive = 1.2; ~kickClick = 0.28;
    ~melodyInst = \guzheng;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3120;
    ~melodyNotes = [71,74,0,0,79,62,62,0,0,0,0,0,0,76,69,64,0,0,62,0,0,0,0,0,0,67,76,0,0,0,64,0];
    ~kickSteps = [0,0,0,0,0,0,1,0,0,0,0,1,1,0,0,0];
    ~hatSteps = [0,0,0,1,0,1,0,1,0,0,0,0,0,0,0,1];
    ~percInst = \tom;
    ~percSteps = [1,0,0,1,0,0,0,1,1,0,1,1,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    72.wait;

    "[O06 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 87; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [72,69,0,0,79,0,71,0,0,0,0,72,69,69,0,0,79,0,72,0,62,0,0,0,71,69,72,67,62,79,67,0];
    ~melodyCutoff = 3620;
    ~percSteps = [0,1,1,0,0,1,0,0,0,1,0,0,0,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(976, 4120); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O06 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 85; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.57;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,0,0,0,77,0,0,89,0,82,0,86,0,0,72,0,0,72,0,84,86,0,0,82,0,0,0,0,0,84];
    ~melodyAmp = 0.2;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleJapanese);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,0,0,1,0,0,0,1,0,0,0,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[O06 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 91; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \guzheng;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3920;
    ~melodyNotes = [0,0,0,0,36,0,48,0,0,0,36,0,45,38,0,0,0,0,0,33,0,43,0,0,0,31,0,0,0,40,48,33];
    ~melodyAmp = 0.18;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.17, 976, \sin, 3120) };
    ~vcfOn !? { ~vcfOn.(\moog, 1176, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    78.wait;

    "[O06 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18; ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3120);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O06 6:00] === fin GUZHENG RIVER ===".postln;
}).play;
"=== TRACK O06 : GUZHENG RIVER 6 min lancee ===".postln;
)
