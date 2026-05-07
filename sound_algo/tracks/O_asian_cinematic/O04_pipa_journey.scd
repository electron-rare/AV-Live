// =====================================================================
//  O04_pipa_journey.scd  --  Album O "PIPA JOURNEY", track 04/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O04 : "PIPA JOURNEY" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O04 0:00] intro -- pipa solo + perc taiko...".postln;
    ~bpm = 90;
    ~kickAmp = 0.52; ~hatAmp = 0.06; ~melodyAmp = 0.24;
    ~kickFreq = 52; ~kickPitchAmt = 2.9; ~kickDecay = 0.42;
    ~kickDrive = 1.2; ~kickClick = 0.1;
    ~melodyInst = \pipa;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3308;
    ~melodyNotes = [0,0,0,62,0,0,0,0,77,0,0,62,65,0,0,69,0,0,60,0,0,0,0,0,0,72,77,0,0,70,0,0];
    ~kickSteps = [0,0,0,0,1,0,0,0,1,0,0,0,1,1,0,1];
    ~hatSteps = [1,0,1,0,0,1,0,0,0,1,0,1,0,1,0,0];
    ~percInst = \taiko;
    ~percSteps = [1,1,1,0,1,0,0,0,0,0,0,0,0,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\cinematic);
    84.wait;

    "[O04 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 94; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,69,77,69,0,0,0,0,60,0,0,60,0,0,0,69,0,62,0,0,72,0,67,0,0,0,69,67,74,70,0,60];
    ~melodyCutoff = 3808;
    ~percSteps = [1,0,0,0,1,0,1,0,1,0,0,0,1,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1459, 4308); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O04 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 94; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.57;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [79,0,79,79,88,0,83,0,81,91,81,0,0,0,0,83,0,74,91,0,0,0,0,0,88,81,81,0,88,76,0,0];
    ~melodyAmp = 0.26;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleVietnam);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,0,0,1,0,1,0,1,0,0,0,1,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[O04 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 86; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \pipa;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4108;
    ~melodyNotes = [50,0,0,0,55,40,0,0,0,0,43,0,0,0,55,48,0,0,0,38,45,0,52,47,52,0,55,38,38,0,0,0];
    ~melodyAmp = 0.24;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.17, 1459, \sin, 3308) };
    ~vcfOn !? { ~vcfOn.(\moog, 1659, 0.4) };
    ~fxPreset !? { ~fxPreset.(\cosmic) };
    ~reload.value;
    96.wait;

    "[O04 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.24; ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3308);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O04 7:00] === fin PIPA JOURNEY ===".postln;
}).play;
"=== TRACK O04 : PIPA JOURNEY 7 min lancee ===".postln;
)
