// =====================================================================
//  L02_midnight_dub.scd  --  Album L "MIDNIGHT DUB", track 02/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L02 : "MIDNIGHT DUB" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L02 0:00] intro -- vocalPad solo + perc rim...".postln;
    ~bpm = 132;
    ~kickAmp = 0.53; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 51; ~kickPitchAmt = 2.6; ~kickDecay = 0.41;
    ~kickDrive = 1.2; ~kickClick = 0.23;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3271;
    ~melodyNotes = [74,72,0,0,71,0,69,0,69,0,0,0,0,0,0,0,0,0,0,0,0,0,0,69,79,0,0,0,76,0,0,0];
    ~kickSteps = [1,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1];
    ~hatSteps = [1,1,0,0,1,0,1,0,0,1,0,0,0,1,0,1];
    ~percInst = \rim;
    ~percSteps = [0,0,1,0,0,1,0,1,1,0,0,0,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\dubBass);
    60.wait;

    "[L02 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,74,76,71,76,74,72,72,72,0,72,0,0,69,69,0,0,0,0,67,0,76,74,62,72,0,62,0,62,76,71,69];
    ~melodyCutoff = 3771;
    ~percSteps = [1,0,1,0,1,0,0,1,0,1,0,1,1,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(900, 4271); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L02 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 132; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.58;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,80,77,82,82,72,0,79,0,84,87,79,0,0,0,0,0,0,0,0,79,0,87,0,0,0,0,0,0,70];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,0,1,0,0,1,0,1,0,1,1,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[L02 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \vocalPad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4071;
    ~melodyNotes = [0,45,0,50,0,0,0,52,38,0,43,0,48,0,0,0,0,52,0,0,0,0,50,0,0,0,0,0,0,0,0,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.25, 900, \sin, 3271) };
    ~vcfOn !? { ~vcfOn.(\moog, 1100, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    60.wait;

    "[L02 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.53;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3271);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L02 5:00] === fin MIDNIGHT DUB ===".postln;
}).play;
"=== TRACK L02 : MIDNIGHT DUB 5 min lancee ===".postln;
)
