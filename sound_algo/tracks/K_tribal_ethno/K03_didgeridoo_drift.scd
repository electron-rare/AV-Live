// =====================================================================
//  K03_didgeridoo_drift.scd  --  Album K "DIDGERIDOO DRIFT", track 03/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK K03 : "DIDGERIDOO DRIFT" 6 minutes ----------------------
//   0:00 intro -> 1:12 build -> 2:42 drop -> 4:12 variation -> 5:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[K03 0:00] intro -- didgeridoo solo + perc tom...".postln;
    ~bpm = 95;
    ~kickAmp = 0.52; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 43; ~kickPitchAmt = 2.1; ~kickDecay = 0.44;
    ~kickDrive = 1.2; ~kickClick = 0.26;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2789;
    ~melodyNotes = [0,0,65,0,0,72,65,0,0,0,0,63,0,60,0,0,70,0,65,0,70,63,0,0,0,0,0,68,70,0,0,63];
    ~kickSteps = [0,0,0,0,1,1,0,0,0,0,1,0,0,0,0,0];
    ~hatSteps = [1,1,0,0,1,1,0,0,0,0,0,0,1,1,0,0];
    ~percInst = \tom;
    ~percSteps = [0,0,1,0,0,0,1,1,1,0,0,1,0,1,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    72.wait;

    "[K03 1:12] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 93; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [75,0,72,75,0,72,0,0,0,58,0,58,0,70,68,0,60,60,0,0,60,0,68,70,70,0,68,75,68,0,0,63];
    ~melodyCutoff = 3289;
    ~percSteps = [0,1,1,1,0,1,1,0,0,1,1,1,1,0,0,0]; ~percAmp = 0.36;
    ~reload.value;
    18.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1034, 3789); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[K03 2:42] drop -- variation + ensemble dense...".postln;
    ~bpm = 95; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.57;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [80,80,84,0,0,70,72,82,80,70,0,0,72,70,0,0,0,84,75,0,75,0,0,0,72,75,0,0,79,0,72,77];
    ~melodyAmp = 0.23;
    ~reload.value;
    15.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,1,1,0,1,1,0,0,1,1,1,1,0,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[K03 4:12] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 101; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \didgeridoo;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3589;
    ~melodyNotes = [0,41,48,46,53,0,0,36,38,53,41,0,0,0,46,43,45,0,53,0,0,46,48,0,0,0,0,0,0,0,0,0];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.29, 1034, \sin, 2789) };
    ~vcfOn !? { ~vcfOn.(\moog, 1234, 0.4) };
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    78.wait;

    "[K03 5:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.52;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2789);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[K03 6:00] === fin DIDGERIDOO DRIFT ===".postln;
}).play;
"=== TRACK K03 : DIDGERIDOO DRIFT 6 min lancee ===".postln;
)
