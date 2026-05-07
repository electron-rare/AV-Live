// =====================================================================
//  M02_eight_bit_run.scd  --  Album M "EIGHT BIT RUN", track 02/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M02 : "EIGHT BIT RUN" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M02 0:00] intro -- squareLead solo + perc tom...".postln;
    ~bpm = 150;
    ~kickAmp = 0.55; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 58; ~kickPitchAmt = 3.5; ~kickDecay = 0.34;
    ~kickDrive = 1.2; ~kickClick = 0.21;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2460;
    ~melodyNotes = [0,0,0,69,62,72,0,0,69,0,70,60,0,0,0,0,0,0,0,67,0,67,0,0,77,0,0,0,62,0,0,77];
    ~kickSteps = [1,0,0,0,0,0,0,0,0,1,1,0,0,0,0,1];
    ~hatSteps = [0,0,0,0,0,1,0,1,0,1,1,0,0,1,0,0];
    ~percInst = \tom;
    ~percSteps = [1,0,0,0,1,1,0,0,1,1,0,0,1,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    60.wait;

    "[M02 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 148; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,65,0,65,0,0,62,0,70,0,0,0,67,0,0,67,70,0,77,72,60,0,72,0,0,0,0,74,0,70,0];
    ~melodyCutoff = 2960;
    ~percSteps = [0,0,0,1,0,0,1,0,0,0,0,1,1,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1276, 3460); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M02 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 146; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.6;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [79,76,0,74,0,84,0,0,81,76,76,0,77,72,0,0,84,74,0,79,74,81,77,0,0,72,72,0,0,77,0,67];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,0,1,0,0,1,0,0,0,0,1,1,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[M02 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 156; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3260;
    ~melodyNotes = [0,0,0,0,53,50,0,0,0,0,41,0,0,0,53,0,0,43,0,46,38,0,0,50,50,0,0,0,0,38,0,0];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.19, 1276, \sin, 2460) };
    ~vcfOn !? { ~vcfOn.(\moog, 1476, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    60.wait;

    "[M02 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.55;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2460);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M02 5:00] === fin EIGHT BIT RUN ===".postln;
}).play;
"=== TRACK M02 : EIGHT BIT RUN 5 min lancee ===".postln;
)
