// =====================================================================
//  L08_london_drizzle.scd  --  Album L "LONDON DRIZZLE", track 08/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK L08 : "LONDON DRIZZLE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[L08 0:00] intro -- pad solo + perc rim...".postln;
    ~bpm = 132;
    ~kickAmp = 0.5; ~hatAmp = 0.06; ~melodyAmp = 0.19;
    ~kickFreq = 41; ~kickPitchAmt = 2.3; ~kickDecay = 0.42;
    ~kickDrive = 1.2; ~kickClick = 0.15;
    ~melodyInst = \pad;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3611;
    ~melodyNotes = [0,0,65,0,70,0,0,70,0,0,67,67,77,0,0,62,0,77,62,74,70,0,0,69,65,67,0,0,74,72,0,0];
    ~kickSteps = [1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0];
    ~hatSteps = [0,0,0,1,0,1,0,1,1,0,0,1,0,1,1,0];
    ~percInst = \rim;
    ~percSteps = [0,0,1,1,0,0,0,0,1,0,0,0,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    72.wait;

    "[L08 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 130; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,60,0,60,70,0,0,77,0,74,70,0,0,65,65,62,0,77,62,0,0,62,60,0,0,70,72,67,72,62,0];
    ~melodyCutoff = 4111;
    ~percSteps = [1,1,0,0,0,0,1,0,1,1,0,1,0,0,0,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1246, 4611); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[L08 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.55;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,69,0,84,81,0,0,74,81,0,79,0,0,0,74,0,72,0,0,72,81,0,81,67,0,0,0,81,74,0,0,0];
    ~melodyAmp = 0.21;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,0,0,0,1,0,1,1,0,1,0,0,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[L08 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \pad;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4411;
    ~melodyNotes = [0,0,0,0,43,0,0,45,33,0,0,0,0,0,0,0,38,33,48,0,38,43,40,0,0,0,0,31,0,0,0,0];
    ~melodyAmp = 0.19;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.23, 1246, \sin, 3611) };
    ~vcfOn !? { ~vcfOn.(\moog, 1446, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    78.wait;

    "[L08 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.19; ~kickAmp = x * 0.5;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3611);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[L08 6:00] === fin LONDON DRIZZLE ===".postln;
}).play;
"=== TRACK L08 : LONDON DRIZZLE 6 min lancee ===".postln;
)
