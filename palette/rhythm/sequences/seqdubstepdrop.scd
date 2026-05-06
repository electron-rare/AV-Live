// =========================================================
//  ~seqDubstepDrop -- pre-drop / drop / breakdown -- extrait de sequences.scd
// =========================================================
(
~seqDubstepDrop = {
    ~seqPlay.value([
        [16, {
            ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~hatAmp = 0.06;
            ~kickAmp = 0.4; ~snareAmp = 0.35;
            ~reload.value; "dubstep 1: pre-drop tension".postln;
        }],
        [4, {
            ~kickSteps = (0!16); ~snareSteps = (0!16); ~hatSteps = (0!16);
            ~reload.value; "dubstep 2: SILENCE".postln;
        }],
        [32, {
            ~kickSteps  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
            ~kickAmp = 0.65; ~snareAmp = 0.55; ~hatAmp = 0.10;
            ~reload.value; "dubstep 3: DROP !!!".postln;
        }],
        [16, {
            ~kickSteps = (0!16); ~hatSteps = (0!16);
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~snareAmp = 0.4;
            ~reload.value; "dubstep 4: breakdown".postln;
        }],
    ]);
};
"=== ~seqDubstepDrop defini ===".postln;
)
