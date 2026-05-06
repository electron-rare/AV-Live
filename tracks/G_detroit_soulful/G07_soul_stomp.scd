// =====================================================================
//  G07_soul_stomp.scd  --  Album G, track 7/15
// =====================================================================

// --- TRACK G07 : "SOUL STOMP" 5 minutes ------------------------------
//   0:00 kick punch -> 1:00 organ stomp -> 3:00 lead -> 4:30 outro
(
~track !? { ~track.stop };
~track = Routine({
    ~trackBegin !? { ~trackBegin.value };
    "[G07 0:00] kick punchy direct...".postln;
    ~bpm = 126;
    ~kickSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~kickAmp = 0.55;
    ~kickFreq = 55; ~kickPitchAmt = 3.5; ~kickDecay = 0.28; ~kickClick = 0.25;
    ~hatSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~hatAmp = 0.16;
    ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
    ~snareSteps=(0!16); ~percSteps=(0!16); ~acidAmp=0;
    ~melodyInst = \warmPad; ~melodyAmp = 0.14;
    ~melodyNotes = [60,0,0,0, 67,0,0,0, 70,0,0,0, 67,0,0,0,
                    63,0,0,0, 70,0,0,0, 65,0,0,0, 63,0,0,0];
    TempoClock.default.tempo = ~bpm/60;
    ~fxPreset !? { ~fxPreset.(\dub) };
    ~reload.value;
    ~playActive !? { ~playActive.value } ?? { ~allSeqs.do { |k| Pdef(k).play } };
    ~enableHarmony.(\fifth);
    60.wait;

    "[G07 1:00] organ stomp Detroit...".postln;
    ~melodyInst = \organLead;
    ~melodyAttack = 0.005; ~melodyRelease = 0.15; ~melodyCutoff = 4800;
    ~melodyAmp = 0.20;
    ~melodyNotes = [63,0,67,0, 70,0,72,0, 70,0,67,0, 63,0,60,0,
                    65,0,70,0, 72,0,75,0, 72,0,70,0, 65,0,63,0];
    ~reload.value;
    24.do { |k|
        if (0.20.coin) {
            ~melodyNotes = ~genMelody.(0.5, ~scaleMinor);
            ~reload.value;
        };
        if (0.10.coin) { ~melodyCutoff = rrand(3500, 5500); ~reload.value };
        5.wait;
    };

    "[G07 3:00] hardLead climax...".postln;
    ~melodyInst = \hardLead;
    ~melodyAttack = 0.003; ~melodyRelease = 0.25; ~melodyCutoff = 5000;
    ~melodyAmp = 0.18;
    ~vcfOn !? { ~vcfOn.(\moog, 2500, 0.45) };
    ~reload.value;
    90.wait;

    "[G07 4:30] outro...".postln;
    ~vcfOff !? { ~vcfOff.() };
    ~melodyInst = \warmPad;
    ~melodyAttack = 0.5; ~melodyRelease = 1.8;
    ~reload.value;
    30.do { |k|
        var x = 1 - ((k + 1) / 30);
        ~kickAmp = x * 0.55; ~hatAmp = x * 0.16; ~clapAmp = x * 0.35;
        ~melodyAmp = x * 0.18;
        ~reload.value; 1.wait;
    };
    [\kickSeq, \hatSeq, \snareSeq, \clapSeq, \percSeq, \acidSeq, \melodySeq, \harmonySeq].do { |k| Pdef(k).stop };
    ~fxPreset !? { ~fxPreset.(\dry) };
    "[G07 5:00] === fin SOUL STOMP ===".postln;
}).play;
"=== TRACK G07 : SOUL STOMP 5 min lancee ===".postln;
)
