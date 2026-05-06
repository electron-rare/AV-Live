// =====================================================================
//  O01_asian_opening.scd  --  Album O "ASIAN OPENING", track 01/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O01 : "ASIAN OPENING" 4 minutes ----------------------
//   0:00 intro -> 0:48 build -> 1:48 drop -> 2:48 variation -> 3:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O01 0:00] intro -- koto solo + perc tom...".postln;
    ~bpm = 80;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 59; ~kickPitchAmt = 3.8; ~kickDecay = 0.54;
    ~kickDrive = 1.2; ~kickClick = 0.26;
    ~melodyInst = \koto;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2564;
    ~melodyNotes = [64,72,0,0,0,0,0,0,55,55,0,0,60,0,0,0,0,55,0,0,0,67,0,69,0,0,0,62,57,0,0,0];
    ~kickSteps = [0,0,0,1,0,0,0,0,0,0,0,0,0,0,1,0];
    ~hatSteps = [1,0,0,0,1,0,0,1,0,0,0,0,1,0,0,1];
    ~percInst = \tom;
    ~percSteps = [0,1,0,1,1,0,0,0,1,1,1,1,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    48.wait;

    "[O01 0:48] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 80; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,57,64,55,72,55,0,0,57,62,0,57,55,55,72,64,0,55,0,60,0,55,64,0,0,67,0,0,0,0,69,0];
    ~melodyCutoff = 3064;
    ~percSteps = [1,0,1,0,1,1,1,1,1,1,1,0,0,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    12.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1194, 3564); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O01 1:48] drop -- variation + ensemble dense...".postln;
    ~bpm = 80; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,76,69,83,0,78,0,86,83,0,0,79,0,69,0,0,0,0,79,0,0,0,86,76,0,0,83,0,0,83,78,79];
    ~melodyAmp = 0.23;
    ~reload.value;
    10.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleJapanese);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,0,1,1,1,1,1,1,1,0,0,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[O01 2:48] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 86; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \koto;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3364;
    ~melodyNotes = [0,38,0,0,38,55,43,0,0,55,0,0,52,0,0,50,48,45,0,0,0,45,0,0,48,0,0,0,43,52,50,50];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.24, 1194, \sin, 2564) };
    ~vcfOn !? { ~vcfOn.(\moog, 1394, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dream) };
    ~reload.value;
    42.wait;

    "[O01 3:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2564);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O01 4:00] === fin ASIAN OPENING ===".postln;
}).play;
"=== TRACK O01 : ASIAN OPENING 4 min lancee ===".postln;
)
