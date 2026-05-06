// =========================================================
//  ~seqTrance16 -- 16 mesures de trance avec build implicite -- extrait de sequences.scd
// =========================================================
(
~seqTrance16 = {
    ~seqPlay.value([
        [64, {
            ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
            ~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
            ~clapSteps  = (0!16);
            ~reload.value; "trance 1-4 : kick + offbeat hat".postln;
        }],
        [64, {
            ~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~clapAmp    = 0.35;
            ~reload.value; "trance 5-8 : + clap 2/4".postln;
        }],
        [64, {
            ~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
            ~percSteps  = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
            ~percAmp    = 0.20;
            ~reload.value; "trance 9-12 : + hat 8th + perc".postln;
        }],
        [64, {
            ~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~snareSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~snareAmp   = 0.45;
            ~reload.value; "trance 13-16 : SNARE ROLL final".postln;
        }],
    ]);
};
"=== ~seqTrance16 defini ===".postln;
)
