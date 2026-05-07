// =========================================================
//  ~seqHipHopLoop -- 8 mesures de hip-hop avec petites variations -- extrait de sequences.scd
// =========================================================
(
~seqHipHopLoop = { |repeats = 1|
    ~seqLoop.value([
        [16, {
            ~kickSteps  = [1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
            ~kickAmp = 0.5; ~snareAmp = 0.4; ~hatAmp = 0.10;
            ~reload.value; "hip-hop 1: classic".postln;
        }],
        [16, {
            ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 0,0,0,0];
            ~hatSteps   = [1,0,1,1, 1,0,1,0, 1,0,1,1, 1,0,1,0];
            ~reload.value; "hip-hop 2: ghost kick".postln;
        }],
        [16, {
            ~kickSteps  = [1,0,0,0, 0,0,0,1, 1,0,0,0, 0,1,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1];
            ~reload.value; "hip-hop 3: trap shift".postln;
        }],
        [16, {
            ~kickSteps  = [1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1];
            ~hatSteps   = [1,0,1,0, 1,0,1,1, 1,0,1,0, 1,0,1,1];
            ~reload.value; "hip-hop 4: ghost snare".postln;
        }],
    ], repeats);
};
"=== ~seqHipHopLoop defini ===".postln;
)
