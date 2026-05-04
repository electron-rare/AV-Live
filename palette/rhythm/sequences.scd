// =====================================================================
//  sequences.scd  --  Sequences de patterns automatiques (macros temps)
//
//  CONCEPT
//    Une sequence est une Routine qui change ~kickSteps / ~melodyNotes /
//    etc. a intervalles reguliers. 1 step = ~stepDur (defaut 0.25 = 1/16).
//    Donc 16 steps = 1 mesure 4/4 a 0.25 dur.
//
//  PREREQUIS
//    engine.scd evalue (definit ~kickSteps, ~reload, etc.).
//    palette/kicks.scd evalue le bloc STOCKAGE pour avoir ~kK1..~kK25.
//    palette/percussions.scd evalue le bloc STOCKAGE pour ~clC*, ~pcP*.
//
//  HELPERS exposes
//    ~seqPlay.(actions)              joue [[steps, action], ...]
//    ~seqStop.()                     stoppe la sequence courante
//    ~seqLoop.(actions, repeats)     enchaine actions en boucle N fois
//    ~seqEvolve.(steps, mutator)     mute progressivement toutes N steps
//    ~beatChainPlay.(presets)        enchaine plusieurs presets nommes
//    ~stepDur                        duree d'un step (defaut 0.25)
//
//  SEQUENCES PRE-CONSTRUITES (~seqXxx.())
//    seqIntro     seqBuildup    seqBreakdown  seqDrop
//    seqOutro     seqTechnoLoop seqAcidEvolve seqDubstepDrop
//    seqTrance16  seqDnBSwitch  seqHipHopLoop seqWorldEvolve
// =====================================================================



// =====================================================================
//  HELPERS DE BASE -- evaluer ce bloc une fois pour exposer les helpers
// =====================================================================
(
~stepDur = 0.25;     // duree d'un step en battement (1/16 a 4/4)
~currentSeq = nil;   // Routine en cours


// --- ~seqPlay.([[steps, action], ...]) ------------------------------
//   Joue une suite d'actions a intervalles donnes en steps.
//   Stoppe toute sequence precedente avant de demarrer.
~seqPlay = { |actions|
    ~seqStop.value;
    ~currentSeq = Routine({
        actions.do { |entry|
            var steps = entry[0];
            var action = entry[1];
            action.value;
            (steps * ~stepDur).wait;
        };
        ~currentSeq = nil;
    }).play(TempoClock.default);
    "=== seqPlay : % steps en cours ===".format(actions.collect(_[0]).sum).postln;
};


// --- ~seqStop.() ----------------------------------------------------
~seqStop = {
    ~currentSeq !? { ~currentSeq.stop; ~currentSeq = nil; "=== seqStop ===".postln };
};


// --- ~seqLoop.(actions, repeats) ------------------------------------
//   Enchaine la liste d'actions en boucle N fois (defaut 1).
~seqLoop = { |actions, repeats = 1|
    var expanded = Array.new(actions.size * repeats);
    repeats.do { actions.do { |a| expanded.add(a) } };
    ~seqPlay.value(expanded);
    "=== seqLoop : % cycles ===".format(repeats).postln;
};


// --- ~seqEvolve.(steps, mutator) ------------------------------------
//   Appelle 'mutator' en boucle toutes les 'steps' steps. La routine
//   tourne jusqu'a seqStop.
~seqEvolve = { |stepsBetween = 16, mutator|
    ~seqStop.value;
    ~currentSeq = Routine({
        inf.do { |i|
            mutator.value(i);
            (stepsBetween * ~stepDur).wait;
        };
    }).play(TempoClock.default);
    "=== seqEvolve : mutator chaque % steps ===".format(stepsBetween).postln;
};


// --- ~beatChainPlay.(presets) ---------------------------------------
//   Enchaine plusieurs presets sous forme de [stepsToHold, action].
//   Equivalent a ~seqPlay mais sucre syntaxique pour chains de drumkits.
~beatChainPlay = { |presets|
    ~seqPlay.value(presets);
};

"=== sequences helpers : ~seqPlay ~seqStop ~seqLoop ~seqEvolve ~beatChainPlay ===".postln;
)



// =====================================================================
//  SEQUENCES PRE-CONSTRUITES
//  Evaluer chaque bloc pour DEFINIR la sequence (variable ~seqXxx).
//  Ensuite l'invoquer : ~seqIntro.value
// =====================================================================



// =====================================================================
//  ~seqIntro -- monte progressive sur 64 steps (4 mesures)
//    mesure 1 : kick seul
//    mesure 2 : kick + hat
//    mesure 3 : kick + hat + clap
//    mesure 4 : tout (kick + hat + clap + perc)
// =====================================================================
(
~seqIntro = {
    ~seqPlay.value([
        [16, {
            ~kickSteps  = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
            ~hatSteps   = (0!16);
            ~clapSteps  = (0!16);
            ~percSteps  = (0!16);
            ~reload.value;
            "intro 1/4 : kick seul".postln;
        }],
        [16, {
            ~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
            ~reload.value;
            "intro 2/4 : + hat".postln;
        }],
        [16, {
            ~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~clapAmp = 0.35;
            ~reload.value;
            "intro 3/4 : + clap".postln;
        }],
        [16, {
            ~percSteps  = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
            ~percAmp = 0.25;
            ~reload.value;
            "intro 4/4 : tout".postln;
        }],
    ]);
};
"=== ~seqIntro defini ===".postln;
)


// =====================================================================
//  ~seqBuildup -- crescendo trance (riser + cutoff sweep + clap denser)
//    Argument optionnel : duree totale en mesures (defaut 4)
// =====================================================================
(
~seqBuildup = { |bars = 4|
    var stepsPerBar = 16;
    ~seqPlay.value([
        [stepsPerBar, {
            ~hatSteps   = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];
            ~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~clapAmp    = 0.30;
            ~reload.value;
            "buildup 1: hat + clap".postln;
        }],
        [stepsPerBar, {
            ~hatSteps   = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];
            ~clapSteps  = [0,0,0,0, 1,0,0,0, 0,0,1,0, 1,0,0,0];
            ~clapAmp    = 0.36;
            ~reload.value;
            "buildup 2: hat 8th + clap dense".postln;
        }],
        [stepsPerBar, {
            ~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~clapSteps  = [0,0,1,0, 1,0,1,0, 0,1,0,1, 1,0,1,0];
            ~clapAmp    = 0.40;
            ~reload.value;
            "buildup 3: hat 16th + clap dense".postln;
        }],
        [stepsPerBar * (bars - 3).max(1), {
            ~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~snareSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~snareAmp   = 0.5;
            ~reload.value;
            "buildup 4: snare roll TENSION".postln;
        }],
    ]);
};
"=== ~seqBuildup defini ===".postln;
)


// =====================================================================
//  ~seqBreakdown -- reduit a melody seule, puis revient
// =====================================================================
(
~seqBreakdown = {
    var saveKick, saveHat, saveClap, savePerc, saveSnare;
    saveKick = ~kickSteps.copy;
    saveHat  = ~hatSteps.copy;
    saveClap = ~clapSteps.copy;
    savePerc = ~percSteps.copy;
    saveSnare = ~snareSteps.copy;
    ~seqPlay.value([
        [32, {
            ~kickSteps  = (0!16);
            ~hatSteps   = (0!16);
            ~clapSteps  = (0!16);
            ~percSteps  = (0!16);
            ~snareSteps = (0!16);
            ~reload.value;
            "breakdown : melody seule".postln;
        }],
        [16, {
            ~kickSteps  = saveKick;
            ~hatSteps   = saveHat;
            ~clapSteps  = saveClap;
            ~percSteps  = savePerc;
            ~snareSteps = saveSnare;
            ~reload.value;
            "breakdown : retour".postln;
        }],
    ]);
};
"=== ~seqBreakdown defini ===".postln;
)


// =====================================================================
//  ~seqDrop -- 4 steps silence + 1 step impact + reprise
// =====================================================================
(
~seqDrop = {
    var saveKick, saveHat, saveClap, savePerc, saveSnare;
    saveKick = ~kickSteps.copy;
    saveHat  = ~hatSteps.copy;
    saveClap = ~clapSteps.copy;
    savePerc = ~percSteps.copy;
    saveSnare = ~snareSteps.copy;
    ~seqPlay.value([
        [4, {
            ~kickSteps  = (0!16);
            ~hatSteps   = (0!16);
            ~clapSteps  = (0!16);
            ~percSteps  = (0!16);
            ~snareSteps = (0!16);
            ~reload.value;
            "drop : SILENCE".postln;
        }],
        [1, {
            // impact one-shot via clap fort
            ~clapSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
            ~clapAmp = 0.7;
            ~reload.value;
            "drop : IMPACT".postln;
        }],
        [16, {
            ~kickSteps  = saveKick;
            ~hatSteps   = saveHat;
            ~clapSteps  = saveClap;  ~clapAmp = 0.35;
            ~percSteps  = savePerc;
            ~snareSteps = saveSnare;
            ~reload.value;
            "drop : DROP !!!".postln;
        }],
    ]);
};
"=== ~seqDrop defini ===".postln;
)


// =====================================================================
//  ~seqOutro -- fade-out progressif sur 32 steps (2 mesures)
// =====================================================================
(
~seqOutro = {
    ~seqPlay.value([
        [8, {
            ~percSteps = (0!16);
            ~reload.value;
            "outro 1 : perc out".postln;
        }],
        [8, {
            ~clapSteps = (0!16);
            ~reload.value;
            "outro 2 : clap out".postln;
        }],
        [8, {
            ~hatSteps = (0!16);
            ~snareSteps = (0!16);
            ~reload.value;
            "outro 3 : hat + snare out".postln;
        }],
        [8, {
            ~kickSteps = [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
            ~reload.value;
            "outro 4 : kick minimal".postln;
        }],
    ]);
};
"=== ~seqOutro defini ===".postln;
)


// =====================================================================
//  ~seqTechnoLoop.(repeats) -- enchaine 4 patterns techno mute par mesure
//  Necessite kicks.scd STOCKAGE evalue (~kK1..~kK25 dispo)
// =====================================================================
(
~seqTechnoLoop = { |repeats = 4|
    ~seqLoop.value([
        [16, {
            ~kickSteps = ~kK1 ? [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
            ~reload.value; "techno A : 4/4".postln;
        }],
        [16, {
            ~kickSteps = ~kK9 ? [1,0,0,0, 1,0,0,1, 1,0,0,0, 1,0,1,0];
            ~reload.value; "techno B : ghost".postln;
        }],
        [16, {
            ~kickSteps = ~kK16 ? [1,0,0,0, 1,0,0,0, 1,0,0,1, 1,0,0,0];
            ~reload.value; "techno C : minimal".postln;
        }],
        [16, {
            ~kickSteps = ~kK10 ? [1,0,1,0, 1,0,0,1, 1,0,1,0, 1,0,1,1];
            ~reload.value; "techno D : syncope".postln;
        }],
    ], repeats);
};
"=== ~seqTechnoLoop defini ===".postln;
)


// =====================================================================
//  ~seqAcidEvolve -- acid pattern qui mute progressivement
//  Note: lit ~acidNotes / ~acidAccents / ~acidSlides du moteur
// =====================================================================
(
~seqAcidEvolve = {
    ~seqPlay.value([
        [16, {
            ~acidNotes = [36,36,36,36, 36,36,36,36, 36,36,36,36, 36,36,36,36];
            ~acidAccents = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];
            ~acidSlides  = [0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0];
            ~reload.value; "acid 1: drone tonic".postln;
        }],
        [16, {
            ~acidNotes = [36,0,39,0, 36,0,43,0, 36,0,39,0, 36,0,43,0];
            ~acidAccents = [1,0,0,0, 1,0,1,0, 1,0,0,0, 1,0,1,0];
            ~reload.value; "acid 2: minor 3rd".postln;
        }],
        [16, {
            ~acidNotes = [36,39,43,36, 39,43,48,43, 36,39,43,48, 43,39,36,43];
            ~acidAccents = [1,0,0,1, 0,1,0,0, 1,0,0,1, 0,0,1,0];
            ~acidSlides  = [0,1,0,0, 1,0,1,0, 0,0,1,0, 1,1,0,0];
            ~reload.value; "acid 3: arpege".postln;
        }],
        [16, {
            ~acidNotes = [36,43,39,48, 36,46,43,48, 39,43,48,46, 43,39,48,36];
            ~acidAccents = [1,0,1,1, 0,1,0,1, 1,0,1,0, 0,1,1,0];
            ~acidSlides  = [1,1,0,1, 0,0,1,1, 0,1,0,1, 1,0,1,0];
            ~reload.value; "acid 4: full chaos".postln;
        }],
    ]);
};
"=== ~seqAcidEvolve defini ===".postln;
)


// =====================================================================
//  ~seqDubstepDrop -- pre-drop / drop / breakdown
// =====================================================================
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


// =====================================================================
//  ~seqTrance16 -- 16 mesures de trance avec build implicite
// =====================================================================
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


// =====================================================================
//  ~seqDnBSwitch -- alterne 4 patterns DnB toutes les 32 steps
// =====================================================================
(
~seqDnBSwitch = { |repeats = 2|
    ~seqLoop.value([
        [32, {
            ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,1];
            ~hatSteps   = [1,1,1,1, 0,1,1,1, 1,1,1,1, 0,1,1,1];
            ~kickAmp = 0.55; ~snareAmp = 0.5; ~hatAmp = 0.12;
            ~reload.value; "DnB A: amen".postln;
        }],
        [32, {
            ~kickSteps  = [1,0,0,1, 0,0,1,0, 0,0,1,0, 1,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,1,1];
            ~hatSteps   = [1,1,0,1, 1,0,1,1, 1,1,0,1, 1,0,1,1];
            ~reload.value; "DnB B: jungle".postln;
        }],
        [32, {
            ~kickSteps  = [1,0,0,0, 0,1,1,0, 0,0,1,0, 0,1,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,1,0];
            ~hatSteps   = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];
            ~reload.value; "DnB C: jump-up".postln;
        }],
        [32, {
            ~kickSteps  = [1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0];
            ~snareSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];
            ~hatSteps   = [1,0,1,1, 0,1,0,1, 1,0,1,1, 0,1,0,1];
            ~reload.value; "DnB D: liquid".postln;
        }],
    ], repeats);
};
"=== ~seqDnBSwitch defini ===".postln;
)


// =====================================================================
//  ~seqHipHopLoop -- 8 mesures de hip-hop avec petites variations
// =====================================================================
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


// =====================================================================
//  ~seqWorldEvolve -- ajout progressif de couches ethno world
// =====================================================================
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



// =====================================================================
//  EXEMPLES D'INVOCATION (a evaluer manuellement)
// =====================================================================

// Lance l'intro :
   ~seqIntro.value
// Buildup 4 mesures :
 ~seqBuildup.value(4)
// Drop dubstep complet :
   ~seqDubstepDrop.value
// Stop la sequence en cours :
//   ~seqStop.value

// --- Chaine plusieurs sections via beatChainPlay --------------------
  ~beatChainPlay.value([
       [64, { ~seqIntro.value }],         // ne marche PAS dans une seq
       [64, { ~kickSteps = ~kK1; ~reload.value }],
   ]);

// Note : ne pas imbriquer ~seqXxx.value dans une sequence. Pour chainer
//        des sections complexes, utilise des Routine externes ou enchaine
//        plusieurs ~seqLoop.value successifs apres un ~seqStop.value.



