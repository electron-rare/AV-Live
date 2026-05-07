// =====================================================================
//  K08_polyrhythm_storm.scd  --  Album K "POLYRHYTHM STORM", track 08/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K08 : "POLYRHYTHM STORM" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K08 0:00] intro -- handpan solo + perc tabla...".postln;
    ~bpm = 120;
    ~kickAmp = 0.46; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 63; ~kickPitchAmt = 3.7; ~kickDecay = 0.27;
    ~kickDrive = 1.2; ~kickClick = 0.16;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3121;
    ~melodyNotes = [0,0,0,58,58,0,68,58,68,75,60,67,58,0,60,0,70,63,0,68,0,0,0,0,67,0,75,0,70,0,65,0];
    ~kickSteps = [0,0,0,1,1,0,0,1,0,0,0,0,0,1,0,0];
    ~hatSteps = [0,0,1,1,0,0,0,0,1,0,1,0,0,0,0,0];
    ~percInst = \tabla;
    ~percSteps = [1,0,0,0,0,1,0,0,0,1,0,0,1,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\counter);
    72.wait;

    "[K08 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 120; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [60,0,60,0,58,68,0,60,0,0,72,0,0,0,75,0,65,65,67,68,75,70,0,63,72,0,65,67,58,0,0,0];
    ~melodyCutoff = 3621;
    ~percSteps = [1,0,1,1,1,1,1,1,0,1,1,1,1,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(980, 4121); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K08 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 118; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.51;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,80,79,0,0,0,70,0,0,0,0,0,0,0,0,0,0,77,70,0,70,84,0,80,0,0,0,75,0,0];
    ~melodyAmp = 0.25;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHungarian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,1,1,1,1,1,0,1,1,1,1,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[K08 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 120; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \handpan;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3921;
    ~melodyNotes = [0,33,0,36,36,0,0,45,0,0,38,0,0,40,0,0,0,0,0,0,48,31,45,31,40,0,36,0,0,0,0,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.27, 980, \sin, 3121) };
    ~vcfOn !? { ~vcfOn.(\moog, 1180, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    78.wait;

    "[K08 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.46;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3121);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K08 6:00] === fin POLYRHYTHM STORM ===".postln;
}).play;
"=== TRACK K08 : POLYRHYTHM STORM 6 min lancee ===".postln;
)
