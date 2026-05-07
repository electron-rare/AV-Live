// =====================================================================
//  engine.scd  --  Moteur (SynthDef + helpers + Pdef + master limiter)
//
//  USAGE
//    1. Cmd+Entree sur le bloc SETUP (une fois par session)
//    2. Cmd+Entree sur le bloc PLAY pour lancer le beat
//    3. Charger separement : presets.scd, tweaks.scd, tracks/*.scd
//    4. Cmd+Entree sur STOP en bas pour couper
// =====================================================================

//  1. SETUP -- evalue UNE FOIS au demarrage de la session
// =====================================================================
(
s.waitForBoot {

    // ----- Acid 303 -----
    // Env ADSR sur l'amp avec doneAction:2 -- garanti pas de fuite
    // memoire meme si on l'utilise dans un Pbind classique. Avec
    // PmonoArtic legato<1, le release (50ms) ne finit jamais avant
    // le retrigger -> le synth reste vivant et le slide fonctionne.
    

    // ----- Kick (rond, sub-charge, click discret + sidechain out) -----
    

    // ----- Hi-hat -----
    

    // ----- Lead melody (saw+pulse detunes + chorus stereo + LPF) -----
    

    // ----- Pad (super-saw 5 voix detunes + chorus + LPF) -----
    

    // ----- Pluck (Karplus-Strong, decay naturel) -----
    

    // ----- FM Bell DUBSTEP -- wobble + sub + detune + saturation -----
    // Inspire des growl/wobble dubstep : RLPF resonant module par LFTri
    // (wobble), 2 voix detunees, sub-bass parallele, distortion lourde.
    

    // ----- Stab (court, saw + saturation pour Detroit) -----
    

    // ----- Saw3 (3 saws empilees, octaves -1/0/+1) -----
    

    // ----- Snare (tone + bruit blanc filtre) -----
    

    // ----- Clap (4 attaques rapides puis tail) -----
    

    // ----- Riser (bruit qui monte sur N secondes) -----
    //  Courbe \sin (qui supporte zero) -- \exp + valeur 0 = NaN
    //  qui silenciait tout le bus.
    

    // ----- Impact (boom + reverse hit, marque les drops) -----
    

    // ----- Open hat (cymbale ouverte, decay long) -----
    

    // ----- Crash cymbal -----
    

    // ----- Tom (drum tone melodique) -----
    

    // ----- Rim shot (clic metallique court) -----
    

    // ----- Cowbell -----
    

    // ----- Reese bass (2 saws detunes filtres -- DnB / dubstep) -----
    

    // ----- 808 bass (trap-style sub avec pitch glide) -----
    

    // ----- Sweep down (l'inverse du riser, descend) -----
    

    // ----- Vinyl noise (texture continue, ambiance) -----
    

    // ----- Master limiter -----
    

    s.sync;

    // ----- Bus de sidechain (control) ----------------------------
    // Le kick ecrit son enveloppe sur ce bus, acid + lead lisent et
    // duckent leur sortie -> mix techno qui pompe sur le kick.
    ~scBus !? { ~scBus.free };
    ~scBus = Bus.control(s, 1);

    // ----- Master limiter en queue de groupe ---------------------
    ~masterLim !? { ~masterLim.free };
    ~masterLim = Synth.tail(s.defaultGroup, \masterLim);

    // ----- Patterns par defaut -----------------------------------
    ~bpm = 132;
    ~acidNotes   = [ 36, 36, 48, 36, 39, 36, 43, 39,
                     36, 41, 36, 39, 43, 36, 36, 41 ];
    ~acidAccents = [  1,  0,  0,  0,  1,  0,  1,  0,
                      0,  1,  0,  0,  1,  0,  0,  1 ];
    ~acidSlides  = [  0,  0,  1,  0,  0,  0,  0,  1,
                      0,  0,  0,  1,  0,  0,  0,  0 ];
    ~kickSteps   = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ];
    ~hatSteps    = [ 0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0 ];
    ~snareSteps  = (0 ! 16);
    ~snareAmp    = 0.45;
    ~snareFreq   = 200; ~snareNoiseAmt = 0.6; ~snareDecay = 0.13;
    // Percussions secondaires
    ~clapSteps   = (0 ! 16); ~clapAmp = 0.35;
    ~percSteps   = (0 ! 16); ~percAmp = 0.25; ~percInst = \rim;     // \rim | \cowbell | \tom | \openHat
    ~tomFreq     = 110; ~cowbellFreq = 800;
    ~melodyNotes = [
        60,  0, 67,  0, 70,  0, 67, 65,
        63,  0, 60,  0,  0, 67, 70, 72,
        75,  0, 72, 70, 67,  0,  0, 65,
        63, 60,  0, 67, 70,  0, 72,  0
    ];

    // ----- Parametres de timbre ----------------------------------
    ~acidCutoff = 800; ~acidRq = 0.15; ~acidCutoffEnv = 3500;
    ~acidDrive  = 2.5; ~acidAmp = 0.32;
    ~kickAmp    = 0.5;
    ~kickFreq   = 55;     // frequence fondamentale (45=sub, 55=normal, 70=punchy)
    ~kickPitchAmt = 3.0;  // ratio du drop initial (2=soft, 3=normal, 5=snappy)
    ~kickDecay  = 0.32;   // duree (0.18=tight, 0.32=normal, 0.6=boomy)
    ~kickDrive  = 1.3;    // saturation (1.0=clean, 1.5=normal, 3.0=distort)
    ~kickClick  = 0.2;    // amplitude du click HF (0=rond, 0.4=claquant)
    ~hatAmp     = 0.18;
    ~melodyInst   = \lead;        // \lead | \pad | \pluck | \fmBell | \stab | \saw3
    ~melodyBoost  = 1.6;          // multiplicateur global du volume melodie
    ~melodyCutoff = 2400; ~melodyRq = 0.5; ~melodyAmp = 0.16;
    ~melodyDrive  = 1.2;  ~melodyAttack = 0.012; ~melodyRelease = 0.25;
    ~melodySawAmt = 0.6;  ~melodyDetune = 0.006;
    // Specifique fmBell dubstep
    ~melodyWobbleRate  = 4;       // Hz (4=1/8 a 120BPM, 8=1/16, 2=1/4)
    ~melodyWobbleDepth = 1800;    // ouverture du wobble en Hz
    ~melodyWobbleShape = 0;       // 0 = LFTri smooth, 1 = LFPulse chop
    ~melodySubAmt      = 0.85;    // sub fmBell (0.85 = MASSIF)

    // ----- 2e voix melodique (harmony / counter-melody) ----------
    ~harmonyInst   = \pad;        // synth pour la 2e voix
    ~harmonyNotes  = (0 ! 32);    // muet par defaut
    ~harmonyCutoff = 1800; ~harmonyRq = 0.6;
    ~harmonyAttack = 0.05; ~harmonyDecay = 0.15;
    ~harmonySustain = 0.6; ~harmonyRelease = 0.5;
    ~harmonyDrive  = 1.2;  ~harmonyAmp = 0.14;
    ~harmonyDur    = 0.25;        // 0.25 = 1/16 ; 0.5 = 1/8 ; 0.125 = 1/32
    ~harmonyDetune = 0.006; ~harmonySawAmt = 0.6;

    // Sidechain : amount par voix (0 = pas de duck, 1 = mute total sur kick)
    ~acidScAmt = 0.7;       // l'acid pompe fort sur le kick
    ~leadScAmt = 0.5;       // le lead pompe modere
    ~kickScShape = 0.18;    // duree de l'env sidechain (s)

    // ----- Reload : reconstruit les 4 Pdef depuis les variables --
    ~reload = {
        // Guards : les Pseq plantent si on leur passe nil/array vide.
        // On force une valeur par defaut pour chaque variable de pattern.
        if (~kickSteps.isNil    or: { ~kickSteps.isEmpty })    { ~kickSteps    = (0 ! 16) };
        if (~hatSteps.isNil     or: { ~hatSteps.isEmpty })     { ~hatSteps     = (0 ! 16) };
        if (~snareSteps.isNil   or: { ~snareSteps.isEmpty })   { ~snareSteps   = (0 ! 16) };
        if (~clapSteps.isNil    or: { ~clapSteps.isEmpty })    { ~clapSteps    = (0 ! 16) };
        if (~percSteps.isNil    or: { ~percSteps.isEmpty })    { ~percSteps    = (0 ! 16) };
        if (~acidNotes.isNil    or: { ~acidNotes.isEmpty })    { ~acidNotes    = [36] };
        if (~acidAccents.isNil  or: { ~acidAccents.isEmpty })  { ~acidAccents  = [0] };
        if (~acidSlides.isNil   or: { ~acidSlides.isEmpty })   { ~acidSlides   = [0] };
        if (~melodyNotes.isNil  or: { ~melodyNotes.isEmpty })  { ~melodyNotes  = (0 ! 32) };
        if (~harmonyNotes.isNil or: { ~harmonyNotes.isEmpty }) { ~harmonyNotes = (0 ! 32) };
        // Amps / params scalaires : default 0 evite NaN
        ~kickAmp     = ~kickAmp    ? 0;  ~hatAmp     = ~hatAmp    ? 0;
        ~snareAmp    = ~snareAmp   ? 0;  ~clapAmp    = ~clapAmp   ? 0;
        ~percAmp     = ~percAmp    ? 0;  ~acidAmp    = ~acidAmp   ? 0;
        ~melodyAmp   = ~melodyAmp  ? 0;  ~harmonyAmp = ~harmonyAmp ? 0;
        ~melodyBoost = ~melodyBoost ? 1; ~harmonyDur = ~harmonyDur ? 0.25;
        // Pan defaults (utilises par ~autoPan -- Pfunc dynamique ci-dessous)
        ~acidPan    = ~acidPan    ? 0;
        ~melodyPan  = ~melodyPan  ? 0;
        ~harmonyPan = ~harmonyPan ? 0;
        // Humanize subtil : variations naturelles de timing + velocity +
        // micro-detune pour eviter le rendu robotique. Toggle via ~humanizeOn.
        // Niveaux subtils (cf. user choice) : timing 1.5%, vel 10%, detune 3c.
        ~humanizeOn       = ~humanizeOn       ? true;
        ~humanizeTiming   = ~humanizeTiming   ? 0.0035; // +/- 3.5ms sur dur 0.25s = 1.4%
        ~humanizeVelocity = ~humanizeVelocity ? 0.10;   // +/- 10%
        ~humanizeDetune   = ~humanizeDetune   ? 0.03;   // +/- 3 cents (0.03 semitone)
        // Pfunc renvoie un offset de timing pour chaque note, ou 0 si OFF.
        ~hTime = { Pfunc { if (~humanizeOn) { rrand(~humanizeTiming.neg, ~humanizeTiming) } { 0 } } };
        ~hVel  = { Pfunc { if (~humanizeOn) { 1 + rrand(~humanizeVelocity.neg, ~humanizeVelocity) } { 1 } } };
        ~hDet  = { Pfunc { if (~humanizeOn) { rrand(~humanizeDetune.neg, ~humanizeDetune) } { 0 } } };
        Pdef(\kickSeq, Pbind(
            \instrument, \kick, \dur, 0.25,
            \timingOffset, ~hTime.value,
            \amp, Pseq(~kickSteps.collect { |s| s * ~kickAmp }, inf) * ~hVel.value,
            \freq, Pfunc { ~kickFreq }, \pitchAmt, Pfunc { ~kickPitchAmt },
            \decay, Pfunc { ~kickDecay }, \drive, Pfunc { ~kickDrive }, \click, Pfunc { ~kickClick },
            \scBus, ~scBus.index, \scShape, Pfunc { ~kickScShape },
        ));
        Pdef(\hatSeq, Pbind(
            \instrument, \hat, \dur, 0.25,
            \timingOffset, ~hTime.value,
            \amp, Pseq(~hatSteps.collect { |s| s * ~hatAmp }, inf) * ~hVel.value,
        ));
        Pdef(\snareSeq, Pbind(
            \instrument, \snare, \dur, 0.25,
            \timingOffset, ~hTime.value,
            \amp, Pseq(~snareSteps.collect { |s| s * ~snareAmp }, inf) * ~hVel.value,
            \freq, Pfunc { ~snareFreq }, \noiseAmt, Pfunc { ~snareNoiseAmt }, \decay, Pfunc { ~snareDecay },
        ));
        Pdef(\clapSeq, Pbind(
            \instrument, \clap, \dur, 0.25,
            \timingOffset, ~hTime.value,
            \amp, Pseq(~clapSteps.collect { |s| s * ~clapAmp }, inf) * ~hVel.value,
        ));
        Pdef(\percSeq, Pbind(
            \instrument, ~percInst, \dur, 0.25,
            \timingOffset, ~hTime.value,
            \amp, Pseq(~percSteps.collect { |s| s * ~percAmp }, inf) * ~hVel.value,
            \freq, Pfunc { if (~percInst == \tom) { ~tomFreq } { ~cowbellFreq } },
        ));
        Pdef(\acidSeq, PmonoArtic(\acid,
            \dur,         0.25,
            \timingOffset,~hTime.value,
            \legato,      0.85,
            \midinote,    Pseq(~acidNotes, inf) + ~hDet.value,
            \accent,      Pseq(~acidAccents, inf),
            \slideTime,   Pseq(~acidSlides.collect { |s| if(s == 1) {0.12} {0.005} }, inf),
            \cutoff,      Pfunc { ~acidCutoff },
            \cutoffEnv,   Pfunc { ~acidCutoffEnv },
            \rq,          Pfunc { ~acidRq },
            \drive,       Pfunc { ~acidDrive },
            \amp,         Pfunc { ~acidAmp } * ~hVel.value,
            \pan,         Pfunc { ~acidPan ? 0 },
            \scBus,       ~scBus.index,      // lit le sidechain
            \scAmt,       Pfunc { ~acidScAmt },
        ));
        Pdef(\melodySeq, Pbind(
            \instrument, ~melodyInst, \dur, 0.25,
            \timingOffset, ~hTime.value,
            \legato,   0.9,
            \type,     Pseq(~melodyNotes.collect { |n| if(n > 0) { \note } { \rest } }, inf),
            \midinote, Pseq(~melodyNotes.collect { |n| if(n > 0) { n } { 60 } }, inf) + ~hDet.value,
            \cutoff,   Pfunc { ~melodyCutoff },
            \rq,       Pfunc { ~melodyRq },
            \attack,   Pfunc { ~melodyAttack },
            \release,  Pfunc { ~melodyRelease },
            \drive,    Pfunc { ~melodyDrive },
            \sawAmt,   Pfunc { ~melodySawAmt },
            \detune,      Pfunc { ~melodyDetune },
            \wobbleRate,  Pfunc { ~melodyWobbleRate },    // pour fmBell
            \wobbleDepth, Pfunc { ~melodyWobbleDepth },
            \wobbleShape, Pfunc { ~melodyWobbleShape },
            \subAmt,      Pfunc { ~melodySubAmt },
            \amp,         Pfunc { ~melodyAmp * ~melodyBoost } * ~hVel.value,
            \pan,         Pfunc { ~melodyPan ? 0 },
            \scBus,       ~scBus.index,
            \scAmt,       Pfunc { ~leadScAmt },
        ));
        // 2e voix : peut tourner en parallele avec une duree differente
        // (32th, 16th, 8th) pour creer du contrepoint / phasing
        Pdef(\harmonySeq, Pbind(
            \instrument, ~harmonyInst, \dur, Pfunc { ~harmonyDur },
            \timingOffset, ~hTime.value,
            \legato,   0.9,
            \type,     Pseq(~harmonyNotes.collect { |n| if(n > 0) { \note } { \rest } }, inf),
            \midinote, Pseq(~harmonyNotes.collect { |n| if(n > 0) { n } { 60 } }, inf) + ~hDet.value,
            \cutoff,   Pfunc { ~harmonyCutoff },
            \rq,       Pfunc { ~harmonyRq },
            \attack,   Pfunc { ~harmonyAttack },
            \decay,    Pfunc { ~harmonyDecay },
            \sustain,  Pfunc { ~harmonySustain },
            \release,  Pfunc { ~harmonyRelease },
            \drive,    Pfunc { ~harmonyDrive },
            \detune,   Pfunc { ~harmonyDetune },
            \sawAmt,   Pfunc { ~harmonySawAmt },
            \amp,      Pfunc { ~harmonyAmp * ~melodyBoost } * ~hVel.value,
            \pan,      Pfunc { ~harmonyPan ? 0 },
            \scBus,    ~scBus.index,
            \scAmt,    Pfunc { ~leadScAmt },
        ));
    };

    // ----- ~enableHarmony : voir palette/harmonics/presets.scd ---
    // ----- Scales + helpers : voir palette/scales.scd ------------
    //   (charges automatiquement par 00_load.scd > CHARGER TOUT)

    "=== setup OK -- lance le bloc PLAY ===".postln;
};
)

