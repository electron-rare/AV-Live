// =====================================================================
//  N11_trap_phonk.scd  --  Album N "TRAP PHONK", track 11/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N11 : "TRAP PHONK" 7 minutes ----------------------
//   0:00 intro -> 1:24 build -> 3:09 drop -> 4:54 variation -> 6:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N11 0:00] intro -- bass808 solo + perc cowbell...".postln;
    ~bpm = 130;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.18;
    ~kickFreq = 64; ~kickPitchAmt = 3.1; ~kickDecay = 0.41;
    ~kickDrive = 1.2; ~kickClick = 0.27;
    ~melodyInst = \bass808;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2674;
    ~melodyNotes = [0,0,62,69,0,0,0,0,0,0,0,0,0,0,0,0,0,0,66,0,0,0,0,66,59,0,0,0,0,0,0,0];
    ~kickSteps = [0,0,0,0,0,0,0,0,1,1,0,1,0,0,0,0];
    ~hatSteps = [1,0,0,1,1,0,0,0,0,0,0,0,1,0,0,0];
    ~percInst = \cowbell;
    ~percSteps = [1,0,0,1,1,0,0,0,0,0,0,1,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    84.wait;

    "[N11 1:24] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 134; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,62,57,66,57,74,0,0,0,0,62,57,59,71,64,74,0,0,0,71,0,69,62,0,0,0,62,62,59,62,64,0];
    ~melodyCutoff = 3174;
    ~percSteps = [1,0,1,1,1,1,1,1,1,0,1,1,0,0,1,1]; ~percAmp = 0.36;
    ~reload.value;
    21.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(980, 3674); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N11 3:09] drop -- variation + ensemble dense...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [67,0,79,0,0,0,0,0,0,0,0,0,81,77,84,77,0,76,0,0,79,0,84,76,79,67,0,0,76,0,0,77];
    ~melodyAmp = 0.2;
    ~reload.value;
    17.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [1,0,1,1,1,1,1,1,1,0,1,1,0,0,1,1].scramble; ~reload.value };
        6.wait;
    };

    "[N11 4:54] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \bass808;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3474;
    ~melodyNotes = [48,0,38,36,0,0,0,48,0,43,53,0,0,41,0,0,0,0,0,50,36,50,53,0,0,0,0,0,38,0,0,46];
    ~melodyAmp = 0.18;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.31, 980, \sin, 2674) };
    ~vcfOn !? { ~vcfOn.(\moog, 1180, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    96.wait;

    "[N11 6:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.18; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2674);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N11 7:00] === fin TRAP PHONK ===".postln;
}).play;
"=== TRACK N11 : TRAP PHONK 7 min lancee ===".postln;
)
