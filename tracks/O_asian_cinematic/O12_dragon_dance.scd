// =====================================================================
//  O12_dragon_dance.scd  --  Album O "DRAGON DANCE", track 12/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O12 : "DRAGON DANCE" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O12 0:00] intro -- pipa solo + perc taiko...".postln;
    ~bpm = 110;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 49; ~kickPitchAmt = 3.0; ~kickDecay = 0.52;
    ~kickDrive = 1.2; ~kickClick = 0.1;
    ~melodyInst = \pipa;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2554;
    ~melodyNotes = [62,74,0,67,0,67,74,0,64,0,0,0,0,74,59,0,71,62,71,64,0,67,0,0,59,62,66,57,64,0,0,0];
    ~kickSteps = [0,0,0,0,0,0,0,0,1,0,0,0,1,0,1,0];
    ~hatSteps = [0,0,1,0,1,0,0,0,1,1,1,0,0,0,1,1];
    ~percInst = \taiko;
    ~percSteps = [1,0,0,0,0,0,0,1,0,0,0,0,0,1,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    60.wait;

    "[O12 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 106; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,59,0,0,0,62,0,74,0,57,64,0,59,69,66,0,71,0,59,59,0,64,71,0,0,0,0,57,69,0,0];
    ~melodyCutoff = 3054;
    ~percSteps = [1,1,0,0,1,1,1,0,0,1,1,1,0,0,1,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(996, 3554); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O12 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 108; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [79,0,0,0,0,78,76,74,71,0,83,0,0,0,0,76,0,71,74,0,0,0,81,0,83,0,0,76,78,0,0,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleVietnam);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,0,1,1,1,0,0,1,1,1,0,0,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[O12 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 108; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \pipa;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3354;
    ~melodyNotes = [38,0,52,0,45,55,0,0,55,0,48,0,38,0,50,40,0,0,38,0,0,0,40,47,52,0,38,0,52,40,0,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.22, 996, \sin, 2554) };
    ~vcfOn !? { ~vcfOn.(\moog, 1196, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    60.wait;

    "[O12 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2554);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O12 5:00] === fin DRAGON DANCE ===".postln;
}).play;
"=== TRACK O12 : DRAGON DANCE 5 min lancee ===".postln;
)
