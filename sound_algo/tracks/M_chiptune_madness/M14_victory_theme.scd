// =====================================================================
//  M14_victory_theme.scd  --  Album M "VICTORY THEME", track 14/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M14 : "VICTORY THEME" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M14 0:00] intro -- squareLead solo + perc tom...".postln;
    ~bpm = 160;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.2;
    ~kickFreq = 54; ~kickPitchAmt = 3.7; ~kickDecay = 0.4;
    ~kickDrive = 1.2; ~kickClick = 0.2;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2854;
    ~melodyNotes = [0,62,69,57,0,0,0,0,0,0,0,0,69,0,0,0,65,0,0,0,0,0,0,0,55,67,0,0,0,64,69,0];
    ~kickSteps = [0,0,0,0,0,0,1,0,1,0,0,0,0,0,1,0];
    ~hatSteps = [0,0,1,0,1,0,0,0,0,1,1,1,0,0,0,1];
    ~percInst = \tom;
    ~percSteps = [0,0,0,0,0,0,0,1,0,0,0,0,1,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    60.wait;

    "[M14 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 164; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [62,64,0,64,64,64,62,65,65,55,0,57,62,72,0,0,0,0,0,0,64,64,69,0,0,0,72,69,60,64,0,69];
    ~melodyCutoff = 3354;
    ~percSteps = [1,1,0,0,1,1,1,1,1,1,0,0,0,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1248, 3854); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M14 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 156; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,89,0,0,82,84,86,81,84,74,89,89,0,0,0,79,0,77,81,0,74,89,77,84,0,74,0,0,0,0,0,81];
    ~melodyAmp = 0.22;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleHigh);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,0,0,1,1,1,1,1,1,0,0,0,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[M14 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 160; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3654;
    ~melodyNotes = [0,0,40,47,0,0,33,0,0,0,45,35,0,47,47,0,0,45,47,0,0,38,0,38,0,42,40,42,0,0,35,0];
    ~melodyAmp = 0.2;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.18, 1248, \sin, 2854) };
    ~vcfOn !? { ~vcfOn.(\moog, 1448, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    60.wait;

    "[M14 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.2; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2854);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M14 5:00] === fin VICTORY THEME ===".postln;
}).play;
"=== TRACK M14 : VICTORY THEME 5 min lancee ===".postln;
)
