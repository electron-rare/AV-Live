// =====================================================================
//  M08_coin_rush.scd  --  Album M "COIN RUSH", track 08/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M08 : "COIN RUSH" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M08 0:00] intro -- squareLead solo + perc tom...".postln;
    ~bpm = 160;
    ~kickAmp = 0.49; ~hatAmp = 0.06; ~melodyAmp = 0.24;
    ~kickFreq = 40; ~kickPitchAmt = 2.5; ~kickDecay = 0.47;
    ~kickDrive = 1.2; ~kickClick = 0.29;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 3550;
    ~melodyNotes = [0,0,0,76,67,0,0,0,0,71,0,0,67,67,0,79,62,0,67,69,0,0,76,0,0,0,67,0,0,0,0,0];
    ~kickSteps = [0,0,0,0,0,0,1,0,0,0,0,1,1,0,0,0];
    ~hatSteps = [0,0,1,0,1,0,0,0,0,0,1,0,0,1,0,1];
    ~percInst = \tom;
    ~percSteps = [0,0,1,0,0,1,1,0,1,1,0,0,0,1,0,1]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    72.wait;

    "[M08 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 156; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [76,0,72,67,76,0,0,69,76,0,67,0,0,67,74,76,0,0,71,0,0,76,0,0,0,0,64,0,72,0,0,0];
    ~melodyCutoff = 4050;
    ~percSteps = [1,1,1,0,1,1,0,1,1,1,0,0,0,1,1,1]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1125, 4550); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M08 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 158; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.54;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [76,86,0,0,84,0,0,81,76,79,0,0,76,84,0,0,0,86,0,0,0,83,88,76,0,0,0,86,86,0,0,76];
    ~melodyAmp = 0.26;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinorPent);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,1,1,0,1,1,0,1,1,1,0,0,0,1,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[M08 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 164; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \squareLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 4350;
    ~melodyNotes = [0,0,33,36,0,0,38,0,48,48,0,0,43,36,0,0,0,48,43,0,0,0,0,0,0,36,0,0,31,41,0,0];
    ~melodyAmp = 0.24;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.22, 1125, \sin, 3550) };
    ~vcfOn !? { ~vcfOn.(\moog, 1325, 0.4) };
    ~fxPreset !? { ~fxPreset.(\retro) };
    ~reload.value;
    78.wait;

    "[M08 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.24; ~kickAmp = x * 0.49;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 3550);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M08 6:00] === fin COIN RUSH ===".postln;
}).play;
"=== TRACK M08 : COIN RUSH 6 min lancee ===".postln;
)
