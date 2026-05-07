// =====================================================================
//  K02_handpan_dawn.scd  --  Album K "HANDPAN DAWN", track 02/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K02 : "HANDPAN DAWN" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K02 0:00] intro -- handpan solo + perc tom...".postln;
    ~bpm = 105;
    ~kickAmp = 0.46; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 54; ~kickPitchAmt = 2.4; ~kickDecay = 0.33;
    ~kickDrive = 1.2; ~kickClick = 0.15;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2371;
    ~melodyNotes = [0,0,0,67,70,0,74,0,0,0,60,0,0,0,0,60,67,0,67,0,0,72,0,0,72,0,65,77,0,74,0,0];
    ~kickSteps = [1,1,0,0,0,0,0,0,0,0,0,0,0,1,0,0];
    ~hatSteps = [0,0,1,0,0,1,0,0,1,0,0,1,1,0,1,1];
    ~percInst = \tom;
    ~percSteps = [0,1,0,1,0,0,0,0,1,0,0,0,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    60.wait;

    "[K02 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 107; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [62,0,65,69,74,0,69,74,0,0,0,0,70,0,60,0,69,0,69,0,0,0,74,0,70,67,65,0,62,70,70,72];
    ~melodyCutoff = 2871;
    ~percSteps = [0,1,0,0,0,1,1,1,1,0,0,0,0,0,0,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(927, 3371); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K02 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 109; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.51;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,70,70,75,82,82,87,84,70,80,87,70,0,0,0,87,84,0,0,82,0,0,82,0,87,0,0,0,70,0,80];
    ~melodyAmp = 0.24;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleDorian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,0,0,0,1,1,1,1,0,0,0,0,0,0,1].scramble; ~reload.value };
        6.wait;
    };

    "[K02 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 111; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3171;
    ~melodyNotes = [0,0,0,0,0,35,0,0,0,0,47,43,0,43,38,35,0,0,0,0,0,0,50,38,0,0,0,0,33,0,0,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.24, 927, \sin, 2371) };
    ~vcfOn !? { ~vcfOn.(\moog, 1127, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    60.wait;

    "[K02 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.46;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2371);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K02 5:00] === fin HANDPAN DAWN ===".postln;
}).play;
"=== TRACK K02 : HANDPAN DAWN 5 min lancee ===".postln;
)
