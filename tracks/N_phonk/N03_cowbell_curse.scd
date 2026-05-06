// =====================================================================
//  N03_cowbell_curse.scd  --  Album N "COWBELL CURSE", track 03/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N03 : "COWBELL CURSE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N03 0:00] intro -- fmBass solo + perc cowbell...".postln;
    ~bpm = 135;
    ~kickAmp = 0.54; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 53; ~kickPitchAmt = 2.3; ~kickDecay = 0.41;
    ~kickDrive = 1.2; ~kickClick = 0.23;
    ~melodyInst = \fmBass;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2676;
    ~melodyNotes = [0,0,0,69,0,0,0,0,64,69,0,0,76,0,0,74,64,0,64,0,69,76,64,0,0,0,0,0,74,0,0,74];
    ~kickSteps = [0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [1,0,1,0,0,0,0,0,0,1,0,0,0,0,1,0];
    ~percInst = \cowbell;
    ~percSteps = [1,1,0,0,0,1,1,0,0,0,0,1,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    72.wait;

    "[N03 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 135; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,69,0,64,79,0,64,0,0,62,0,0,69,0,0,0,0,72,79,0,0,64,0,0,79,0,0,0,0,71,76,79];
    ~melodyCutoff = 3176;
    ~percSteps = [0,1,0,1,1,0,1,1,0,1,0,1,0,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1238, 3676); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N03 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 139; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.59;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,83,79,74,81,0,69,0,0,86,0,0,71,0,69,0,0,81,76,0,71,0,0,71,71,0,0,0,76,81];
    ~melodyAmp = 0.23;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,0,1,1,0,1,1,0,1,0,1,0,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[N03 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 135; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \fmBass;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3476;
    ~melodyNotes = [0,0,0,0,0,40,40,0,0,0,0,47,0,50,45,0,0,43,0,33,45,43,0,0,43,0,0,45,38,0,0,0];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.21, 1238, \sin, 2676) };
    ~vcfOn !? { ~vcfOn.(\moog, 1438, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    78.wait;

    "[N03 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.54;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2676);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N03 6:00] === fin COWBELL CURSE ===".postln;
}).play;
"=== TRACK N03 : COWBELL CURSE 6 min lancee ===".postln;
)
