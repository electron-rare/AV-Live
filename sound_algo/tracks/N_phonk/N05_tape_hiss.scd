// =====================================================================
//  N05_tape_hiss.scd  --  Album N "TAPE HISS", track 05/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N05 : "TAPE HISS" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N05 0:00] intro -- bass808 solo + perc cowbell...".postln;
    ~bpm = 130;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 42; ~kickPitchAmt = 3.8; ~kickDecay = 0.53;
    ~kickDrive = 1.2; ~kickClick = 0.1;
    ~melodyInst = \bass808;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3331;
    ~melodyNotes = [74,0,0,67,0,74,0,72,64,64,72,0,71,76,69,0,0,0,76,0,69,0,67,0,0,0,72,0,62,64,0,0];
    ~kickSteps = [0,0,0,0,0,1,0,0,0,0,1,0,1,0,0,0];
    ~hatSteps = [1,0,0,1,0,1,0,0,0,0,0,0,0,0,0,1];
    ~percInst = \cowbell;
    ~percSteps = [0,0,0,1,1,1,0,0,1,0,1,1,0,0,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    96.wait;

    "[N05 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [79,72,0,0,64,71,76,74,0,79,0,0,67,74,64,62,0,0,76,79,79,64,79,76,79,62,72,0,0,0,0,0];
    ~melodyCutoff = 3831;
    ~percSteps = [1,0,0,1,0,1,1,1,1,0,1,1,1,1,0,1]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1167, 4331); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N05 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [71,0,0,81,78,0,0,0,0,0,0,79,69,0,0,0,71,79,78,78,0,0,0,83,0,0,71,69,0,0,0,0];
    ~melodyAmp = 0.21;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,0,1,0,1,1,1,1,0,1,1,1,1,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[N05 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \bass808;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4131;
    ~melodyNotes = [36,0,0,38,45,40,0,38,45,0,0,0,0,38,0,40,38,0,0,31,0,0,41,0,0,33,36,48,0,0,0,0];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.28, 1167, \sin, 3331) };
    ~vcfOn !? { ~vcfOn.(\moog, 1367, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    114.wait;

    "[N05 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3331);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N05 8:00] === fin TAPE HISS ===".postln;
}).play;
"=== TRACK N05 : TAPE HISS 8 min lancee ===".postln;
)
