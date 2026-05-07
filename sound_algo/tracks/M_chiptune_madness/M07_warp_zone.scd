// =====================================================================
//  M07_warp_zone.scd  --  Album M "WARP ZONE", track 07/15
//  Track autonome -- Cmd+Entree sur le bloc (...) pour la lancer.
// =====================================================================

// --- TRACK M07 : "WARP ZONE" 5 minutes ----------------------
//   0:00 intro -> 1:00 build -> 2:15 drop -> 3:30 variation -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[M07 0:00] intro -- fmLead solo + perc tom...".postln;
    ~bpm = 175;
    ~kickAmp = 0.51; ~hatAmp = 0.06; ~melodyAmp = 0.23;
    ~kickFreq = 52; ~kickPitchAmt = 2.6; ~kickDecay = 0.31;
    ~kickDrive = 1.2; ~kickClick = 0.13;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.05; ~melodyRelease = 0.8; ~melodyCutoff = 2858;
    ~melodyNotes = [72,0,0,79,72,0,0,0,76,74,0,0,0,0,0,0,0,0,0,0,71,0,0,0,79,0,0,0,0,69,0,0];
    ~kickSteps = [0,0,0,0,0,0,1,1,1,0,1,0,1,1,0,0];
    ~hatSteps = [0,0,0,0,0,1,1,0,0,0,1,0,0,1,1,0];
    ~percInst = \tom;
    ~percSteps = [0,0,0,1,1,1,0,1,0,0,0,0,0,0,1,0]; ~percAmp = 0.32;
    ~snareSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
    ~acidAmp = 0;
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\arp);
    60.wait;

    "[M07 1:00] build -- kick + hat + melody plus dense...".postln;
    ~bpm = 175; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0];
    ~hatSteps = [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0]; ~hatAmp = 0.10;
    ~melodyNotes = [67,0,64,0,0,64,67,0,0,64,0,64,0,64,79,76,0,74,0,79,0,79,67,76,0,76,79,79,79,0,0,0];
    ~melodyCutoff = 3358;
    ~percSteps = [0,0,0,1,1,1,0,1,1,1,1,1,1,1,1,0]; ~percAmp = 0.36;
    ~reload.value;
    15.do { |k|
        if (0.20.coin) { ~melodyNotes = ~mutate.(~melodyNotes, 0.2); ~reload.value };
        if (0.15.coin) { ~melodyCutoff = rrand(1481, 3858); ~reload.value };
        if (0.10.coin) { ~melodyNotes = ~octavate.(~melodyNotes, 0.2); ~reload.value };
        5.wait;
    };

    "[M07 2:15] drop -- variation + ensemble dense...".postln;
    ~bpm = 173; TempoClock.default.tempo = ~bpm/60;
    ~kickSteps = [1,0,0,0,0,0,1,0,0,0,0,0,1,0,1,0]; ~kickAmp = 0.56;
    ~clapSteps = [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0]; ~clapAmp = 0.32;
    ~melodyNotes = [84,0,81,0,74,0,74,0,0,0,0,67,81,74,72,0,0,67,0,84,76,0,0,0,77,67,0,0,0,79,0,76];
    ~melodyAmp = 0.25;
    ~reload.value;
    12.do { |k|
        if (0.25.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scalePhrygian);
            ~reload.value;
        };
        if (0.20.coin) { ~melodyNotes = ~transpose.(~melodyNotes, [-5, -3, 3, 5, 7].choose); ~reload.value };
        if (0.15.coin) { ~percSteps = [0,0,0,1,1,1,0,1,1,1,1,1,1,1,1,0].scramble; ~reload.value };
        6.wait;
    };

    "[M07 3:30] variation -- timbre nouveau + fx evolve...".postln;
    ~bpm = 179; TempoClock.default.tempo = ~bpm/60;
    ~melodyInst = \fmLead;
    ~melodyAttack = 0.01; ~melodyRelease = 0.5; ~melodyCutoff = 3658;
    ~melodyNotes = [0,0,0,33,0,40,40,33,0,0,38,0,38,0,0,48,45,0,0,43,40,0,0,0,45,0,0,0,0,43,0,36];
    ~melodyAmp = 0.23;
    ~lfoTo !? { ~lfoTo.(\melodyCutoff, 0.26, 1481, \sin, 2858) };
    ~vcfOn !? { ~vcfOn.(\moog, 1681, 0.4) };
    ~fxPreset !? { ~fxPreset.(\space) };
    ~reload.value;
    60.wait;

    "[M07 4:30] outro -- fade global...".postln;
    ~lfoStopVar !? { ~lfoStopVar.(\melodyCutoff) };
    ~vcfOff !? { ~vcfOff.() };
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~melodyAmp = x * 0.23; ~kickAmp = x * 0.51;
        ~hatAmp = x * 0.10; ~percAmp = x * 0.32; ~clapAmp = x * 0.32;
        ~melodyCutoff = 250 + (x * 2858);
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[M07 5:00] === fin WARP ZONE ===".postln;
}).play;
"=== TRACK M07 : WARP ZONE 5 min lancee ===".postln;
)
