// =====================================================================
//  M03_boss_battle.scd  --  Album M "BOSS BATTLE", track 03/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M03 : "BOSS BATTLE" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M03 0:00] intro -- saw3 solo + perc tom...".postln;
    ~bpm = 165;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.22;
    ~kickFreq = 61; ~kickPitchAmt = 3.0; ~kickDecay = 0.3;
    ~kickDrive = 1.2; ~kickClick = 0.11;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3176;
    ~melodyNotes = [0,0,0,70,65,0,0,72,0,0,0,0,65,0,67,62,0,72,0,0,0,70,0,0,65,0,0,0,0,69,0,0];
    ~kickSteps = [0,1,0,0,0,0,0,0,0,0,1,0,0,0,0,1];
    ~hatSteps = [1,0,1,0,0,0,0,0,0,1,0,0,0,0,0,1];
    ~percInst = \tom;
    ~percSteps = [1,0,0,0,1,1,0,0,1,0,1,1,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\third);
    72.wait;

    "[M03 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 169; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [62,0,0,60,0,70,0,67,65,0,0,69,0,62,69,70,0,67,0,0,77,0,65,62,65,60,0,0,0,0,65,77];
    ~melodyCutoff = 3676;
    ~percSteps = [1,1,0,0,0,1,1,0,1,1,1,1,1,0,1,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1312, 4176); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M03 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 169; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,0,77,0,0,0,72,77,77,0,0,0,72,77,0,72,0,0,79,77,0,0,0,75,70,0,0,70,0,0];
    ~melodyAmp = 0.24;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHarmonicMin);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,0,0,1,1,0,1,1,1,1,1,0,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[M03 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 171; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \saw3;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3976;
    ~melodyNotes = [46,0,0,45,38,0,45,0,0,48,0,43,0,36,41,41,0,0,0,0,0,0,0,0,0,36,0,0,0,41,48,0];
    ~melodyAmp = 0.22;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.23, 1312, \sin, 3176) };
    ~vcfOn !? { ~vcfOn.(\moog, 1512, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    78.wait;

    "[M03 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.22; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3176);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M03 6:00] === fin BOSS BATTLE ===".postln;
}).play;
"=== TRACK M03 : BOSS BATTLE 6 min lancee ===".postln;
)
