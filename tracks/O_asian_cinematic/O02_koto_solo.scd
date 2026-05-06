// =====================================================================
//  O02_koto_solo.scd  --  Album O "KOTO SOLO", track 02/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK O02 : "KOTO SOLO" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[O02 0:00] intro -- koto solo + perc tom...".postln;
    ~bpm = 75;
    ~kickAmp = 0.52; ~hatAmp = 0.06; ~melodyAmp = 0.18;
    ~kickFreq = 55; ~kickPitchAmt = 2.2; ~kickDecay = 0.54;
    ~kickDrive = 1.2; ~kickClick = 0.11;
    ~melodyInst = \koto;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3162;
    ~melodyNotes = [0,63,70,0,68,68,65,0,0,63,60,68,0,0,0,0,70,0,0,0,0,0,0,0,0,0,60,0,0,0,75,63];
    ~kickSteps = [0,1,1,0,0,1,0,0,0,1,1,1,1,0,0,0];
    ~hatSteps = [0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,1,1,0,1,0,1,0,0,1,0,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    60.wait;

    "[O02 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 73; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [58,0,0,0,65,67,0,0,67,65,67,0,0,0,0,63,0,75,67,58,63,60,65,0,67,0,72,72,0,67,63,65];
    ~melodyCutoff = 3662;
    ~percSteps = [0,0,1,0,0,1,0,0,0,0,1,1,1,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1325, 4162); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[O02 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 71; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.57;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,0,0,0,0,0,69,0,0,0,0,71,0,79,0,0,0,0,0,78,79,0,0,0,0,0,0,0,0,69,78];
    ~melodyAmp = 0.2;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHirajoshi);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,1,0,0,1,0,0,0,0,1,1,1,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[O02 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 81; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \koto;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3962;
    ~melodyNotes = [45,0,31,31,0,38,0,0,0,0,48,36,0,43,0,0,0,0,33,0,0,0,40,0,45,33,0,0,0,45,31,0];
    ~melodyAmp = 0.18;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.16, 1325, \sin, 3162) };
    ~vcfOn !? { ~vcfOn.(\moog, 1525, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    60.wait;

    "[O02 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18; ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3162);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[O02 5:00] === fin KOTO SOLO ===".postln;
}).play;
"=== TRACK O02 : KOTO SOLO 5 min lancee ===".postln;
)
