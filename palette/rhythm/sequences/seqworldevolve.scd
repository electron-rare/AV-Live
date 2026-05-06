// =========================================================
//  ~seqWorldEvolve -- ajout progressif de couches ethno world -- extrait de sequences.scd
// =========================================================
(
~seqWorldEvolve = {
    ~seqPlay.value([
        [16, {
            ~kickSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];
            ~hatSteps  = (0!16);
            ~clapSteps = (0!16);
            ~percSteps = (0!16);
            ~snareSteps = (0!16);
            ~kickAmp = 0.4;
            ~reload.value; "world 1: kick base".postln;
        }],
        [16, {
            ~percInst = \tom; ~tomFreq = 95;
            ~percSteps = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0];
            ~percAmp = 0.4;
            ~reload.value; "world 2: + congas".postln;
        }],
        [16, {
            ~hatSteps = [1,1,0,1, 1,0,1,1, 0,1,1,1, 1,0,1,1];
            ~hatAmp = 0.08;
            ~reload.value; "world 3: + shaker".postln;
        }],
        [16, {
            ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~clapAmp = 0.30;
            ~reload.value; "world 4: + clap".postln;
        }],
        [16, {
            ~kickSteps = [1,0,0,1, 0,1,0,0, 1,0,1,0, 0,1,0,0];
            ~kickAmp = 0.5;
            ~reload.value; "world 5: kick afrobeat".postln;
        }],
    ]);
};
"=== ~seqWorldEvolve defini ===".postln;
)
