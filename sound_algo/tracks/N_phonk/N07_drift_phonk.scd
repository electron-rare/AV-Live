// =====================================================================
//  N07_drift_phonk.scd  --  Album N "DRIFT PHONK", track 07/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK N07 : "DRIFT PHONK" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[N07 0:00] intro -- fmBass solo + perc cowbell...".postln;
    ~bpm = 132;
    ~kickAmp = 0.48; ~hatAmp = 0.06; ~melodyAmp = 0.21;
    ~kickFreq = 57; ~kickPitchAmt = 3.3; ~kickDecay = 0.3;
    ~kickDrive = 1.2; ~kickClick = 0.13;
    ~melodyInst = \fmBass;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2412;
    ~melodyNotes = [75,0,0,63,0,63,0,67,0,0,65,0,0,72,0,75,65,0,0,0,0,0,65,0,0,70,63,0,0,68,0,68];
    ~kickSteps = [0,0,0,0,0,0,1,0,0,0,1,0,0,0,0,0];
    ~hatSteps = [0,0,1,1,0,0,0,0,0,0,0,0,0,0,0,0];
    ~percInst = \cowbell;
    ~percSteps = [0,0,1,0,0,0,0,0,1,1,1,0,0,0,0,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\bassline);
    60.wait;

    "[N07 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [0,0,72,75,70,75,0,63,60,65,0,67,67,70,72,67,0,0,68,70,70,60,0,0,75,65,65,0,0,70,0,0];
    ~melodyCutoff = 2912;
    ~percSteps = [0,1,0,0,1,1,0,0,0,0,0,0,0,1,0,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1432, 3412); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[N07 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 136; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.53;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [0,0,79,0,86,79,84,0,0,91,0,0,83,0,0,0,0,0,0,81,0,0,0,0,0,0,91,0,0,88,84,0];
    ~melodyAmp = 0.23;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,1,0,0,1,1,0,0,0,0,0,0,0,1,0,0].scramble; ~reload.value };
        6.wait;
    };

    "[N07 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 128; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \fmBass;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3212;
    ~melodyNotes = [0,48,0,41,0,48,0,0,0,0,41,0,0,43,46,0,0,0,41,0,0,0,43,53,38,0,0,41,0,43,0,0];
    ~melodyAmp = 0.21;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.29, 1432, \sin, 2412) };
    ~vcfOn !? { ~vcfOn.(\moog, 1632, 0.4) };
    ~fxPreset !? { ~fxPreset.(\industrial) };
    ~reload.value;
    60.wait;

    "[N07 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.21; ~kickAmp = x * 0.48;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2412);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[N07 5:00] === fin DRIFT PHONK ===".postln;
}).play;
"=== TRACK N07 : DRIFT PHONK 5 min lancee ===".postln;
)
