// =====================================================================
//  M05_level_one.scd  --  Album M "LEVEL ONE", track 05/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M05 : "LEVEL ONE" 8 minutes ----------------------
//   0:00 intro -> 1:36 build -> 3:36 drop -> 5:36 variation -> 7:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M05 0:00] intro -- squareLead solo + perc tom...".postln;
    ~bpm = 155;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 49; ~kickPitchAmt = 2.9; ~kickDecay = 0.47;
    ~kickDrive = 1.2; ~kickClick = 0.18;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3722;
    ~melodyNotes = [0,62,0,67,0,0,0,0,0,57,0,0,0,66,67,0,57,0,0,0,67,69,0,62,0,66,0,66,62,0,67,0];
    ~kickSteps = [0,0,1,0,1,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,0,0,0,0,0,0,0,0,1,1,0,1,0];
    ~percInst = \tom;
    ~percSteps = [0,0,1,1,0,0,0,1,1,0,0,0,1,0,1,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    96.wait;

    "[M05 1:36] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 157; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [71,0,0,57,66,69,62,0,71,69,62,64,0,0,0,57,59,69,74,67,0,66,0,66,66,59,0,69,66,0,0,0];
    ~melodyCutoff = 4222;
    ~percSteps = [0,0,1,1,0,1,0,0,1,0,0,1,1,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    24.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1381, 4722); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M05 3:36] drop -- variation + ensemble dense...".postln;
    ~bpm = 153; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [79,80,0,0,70,75,0,75,75,0,0,80,0,75,0,77,0,0,0,79,0,0,79,72,75,0,70,75,82,87,80,87];
    ~melodyAmp = 0.21;
    ~reload.value;
    20.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,1,0,1,0,0,1,0,0,1,1,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[M05 5:36] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 153; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4522;
    ~melodyNotes = [52,0,55,0,0,0,0,0,50,52,45,0,0,38,47,0,50,0,45,40,0,0,0,0,43,0,0,0,47,40,0,55];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.28, 1381, \sin, 3722) };
    ~vcfOn !? { ~vcfOn.(\moog, 1581, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    114.wait;

    "[M05 7:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3722);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M05 8:00] === fin LEVEL ONE ===".postln;
}).play;
"=== TRACK M05 : LEVEL ONE 8 min lancee ===".postln;
)
