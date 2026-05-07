// =====================================================================
//  live/patterns.scd  --  RHYTHM PRESETS LIVE (API ultra-courte)
//
//  ATTENTION SC -- la notation `~p.kit.(\name)` NE marche PAS :
//  SC passe l'event ~p comme 1er arg et perd les vrais args.
//  Utiliser ~p[\kit].(\name) ou les variables ~pKit.(\name).
//
//  ~p                                // dict catalogue
//  ~p[\kit].(\name)                  // applique un kit complet
//  ~p[\genre].(\name)                // applique un preset rythmique
//  ~p[\kick].(N|\name)               // raccourci -> ~k[\go]
//  ~p[\hat] / [\snare] / [\clap] / [\perc] / [\list]
//
//  RACCOURCIS env (API utilisateur primaire) :
//    ~pKit, ~pGenre, ~pKick
//    ~pHat, ~pSnare, ~pClap, ~pPerc
//    ~pList
//
//  KITS DISPO (extraits de drum_kits.scd) :
//    \techno \dubstep \dnb \trap \house \breakbeat \hardstyle \jungle
//    \garage \trap808 \phonk \footwork \liquidDnB \synthwave \industrial
//    \tribalWorld \hardcore \lofiHipHop \futureGarage \detroitDeep
//
//  GENRES DISPO (extraits de patterns_genre.scd) :
//    \hardTechno \acidHouse \trance138 \psyTrance \hardstyle \handsUp
//    \liquidDnB \neurofunk \jungle165 \dnbJumpup \futureBass \deepHouse
//    \techHouse \progHouse \tribalTechno \industrialV2 \breakcore
//    \footwork \idm \glitchHop
//
//  HAT/SNARE/CLAP/PERC presets : voir blocs ci-dessous.
//
//  PREREQUIS : engine.scd evalue. Les valeurs sont dupliquees ici donc
//  ~p est utilisable independamment des fichiers palette/rhythm/*.
// =====================================================================

(
~p = ();

// --- KITS COMPLETS (duplique les valeurs canoniques de drum_kits.scd)
//   Chaque kit est un Event de variables a appliquer + ~reload.
//
//  NOTE : on utilise la notation `~p[\key]` partout en interne pour
//  eviter toute collision pseudo-methode. Les sous-cles `kit`, `genre`,
//  `kick`, `hat`, `snare`, `clap`, `perc`, `list` sont assez longues
//  pour ne pas collisionner avec les methodes Object SC.
~p[\kits] = (
    \techno: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.55,
        kickFreq:55, kickPitchAmt:3.0, kickDecay:0.32, kickDrive:1.3, kickClick:0.2,
        hatSteps: [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], hatAmp:0.18,
        snareSteps:(0!16), clapSteps:(0!16), percSteps:(0!16)
    ),
    \dubstep: (
        kickSteps:[1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0], kickAmp:0.6,
        kickFreq:48, kickPitchAmt:3.5, kickDecay:0.5, kickDrive:1.5, kickClick:0.15,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], snareAmp:0.5,
        snareFreq:220, snareNoiseAmt:0.65, snareDecay:0.16,
        hatSteps:[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], hatAmp:0.10,
        clapSteps:(0!16), percSteps:(0!16)
    ),
    \dnb: (
        kickSteps:[1,0,0,0,0,0,1,0,0,0,1,0,1,0,0,0], kickAmp:0.55,
        kickFreq:55, kickPitchAmt:4.0, kickDecay:0.18, kickDrive:1.5, kickClick:0.3,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,1], snareAmp:0.5,
        snareFreq:240, snareNoiseAmt:0.7, snareDecay:0.10,
        hatSteps:[1,1,1,1,0,1,1,1,1,1,1,1,0,1,1,1], hatAmp:0.12,
        clapSteps:(0!16), percSteps:(0!16)
    ),
    \trap: (
        kickSteps:[1,0,0,0,0,0,0,1,1,0,0,0,0,1,0,0], kickAmp:0.55,
        kickFreq:42, kickPitchAmt:2.5, kickDecay:0.6, kickDrive:1.2, kickClick:0.08,
        hatSteps:[1,0,1,1,0,1,1,0,1,0,1,1,0,1,1,0], hatAmp:0.10,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.3,
        percInst:\rim, percSteps:[0,0,1,0,0,1,0,0,1,0,1,0,0,1,0,1], percAmp:0.2,
        snareSteps:(0!16)
    ),
    \house: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.55,
        kickFreq:50, kickPitchAmt:2.8, kickDecay:0.35, kickDrive:1.2, kickClick:0.12,
        hatSteps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], hatAmp:0.15,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.35,
        snareSteps:(0!16), percSteps:(0!16)
    ),
    \hardstyle: (
        kickSteps:[1,0,0,0,1,0,0,1,1,0,0,0,1,1,0,0], kickAmp:0.65,
        kickFreq:62, kickPitchAmt:5.5, kickDecay:0.30, kickDrive:4.0, kickClick:0.45,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], snareAmp:0.55,
        snareFreq:230, snareNoiseAmt:0.7, snareDecay:0.18,
        hatSteps:[0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1], hatAmp:0.12,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.45,
        percInst:\rim, percSteps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,1], percAmp:0.22
    ),
    \jungle: (
        kickSteps:[1,0,0,1,0,1,0,0,1,0,0,1,0,1,0,0], kickAmp:0.55,
        kickFreq:55, kickPitchAmt:3.5, kickDecay:0.20, kickDrive:1.6, kickClick:0.32,
        snareSteps:[0,0,0,0,1,0,1,0,0,0,0,1,1,0,0,1], snareAmp:0.55,
        snareFreq:220, snareNoiseAmt:0.7, snareDecay:0.10,
        hatSteps:[1,1,0,1,1,0,1,1,1,1,0,1,1,0,1,1], hatAmp:0.12,
        clapSteps:(0!16),
        percInst:\rim, percSteps:[0,0,1,0,0,1,0,0,0,0,1,0,0,1,0,0], percAmp:0.30
    ),
    \garage: (
        kickSteps:[1,0,0,0,0,0,1,0,0,0,0,0,1,0,0,0], kickAmp:0.5,
        kickFreq:50, kickPitchAmt:2.8, kickDecay:0.35, kickDrive:1.2, kickClick:0.15,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,0,1,0,0], snareAmp:0.4,
        snareFreq:200, snareNoiseAmt:0.55, snareDecay:0.20,
        hatSteps:[0,1,1,0,1,1,0,1,0,1,1,0,1,1,0,1], hatAmp:0.11,
        clapSteps:[0,0,0,0,1,0,0,1,0,0,0,0,1,0,0,0], clapAmp:0.32,
        percInst:\rim, percSteps:(0!16)
    ),
    \trap808: (
        kickSteps:[1,0,0,0,0,0,0,1,1,0,0,0,0,1,0,0], kickAmp:0.6,
        kickFreq:38, kickPitchAmt:1.8, kickDecay:0.85, kickDrive:1.0, kickClick:0.05,
        snareSteps:(0!16),
        hatSteps:[1,1,1,0,1,1,1,1,1,1,1,0,1,1,1,1], hatAmp:0.09,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.35,
        percInst:\rim, percSteps:[0,0,1,1,0,1,0,0,1,0,1,0,0,1,1,0], percAmp:0.18
    ),
    \phonk: (
        kickSteps:[1,0,0,0,0,0,0,1,1,0,0,0,0,1,0,0], kickAmp:0.6,
        kickFreq:40, kickPitchAmt:2.0, kickDecay:0.7, kickDrive:1.2, kickClick:0.08,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], snareAmp:0.45,
        snareFreq:280, snareNoiseAmt:0.65, snareDecay:0.14,
        hatSteps:[1,0,1,1,0,1,1,0,1,0,1,1,0,1,1,0], hatAmp:0.11,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.30,
        percInst:\cowbell, cowbellFreq:800,
        percSteps:[0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0], percAmp:0.32
    ),
    \footwork: (
        kickSteps:[1,0,0,1,1,0,0,0,1,0,1,1,0,0,1,0], kickAmp:0.55,
        kickFreq:42, kickPitchAmt:2.4, kickDecay:0.5, kickDrive:1.3, kickClick:0.10,
        snareSteps:(0!16),
        hatSteps:[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], hatAmp:0.10,
        clapSteps:[0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0], clapAmp:0.32,
        percInst:\rim, percSteps:[0,0,1,1,0,1,1,0,1,0,1,1,0,1,0,1], percAmp:0.22
    ),
    \industrial: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.6,
        kickFreq:60, kickPitchAmt:5.0, kickDecay:0.28, kickDrive:3.5, kickClick:0.4,
        snareSteps:[0,0,0,0,1,0,0,1,0,0,0,0,1,0,1,0], snareAmp:0.55,
        snareFreq:260, snareNoiseAmt:0.8, snareDecay:0.10,
        hatSteps:[0,1,0,1,1,1,0,1,0,1,0,1,1,1,0,1], hatAmp:0.13,
        clapSteps:(0!16),
        percInst:\rim, percSteps:[1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1], percAmp:0.4
    ),
    \hardcore: (
        kickSteps:[1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0], kickAmp:0.65,
        kickFreq:60, kickPitchAmt:5.0, kickDecay:0.20, kickDrive:4.0, kickClick:0.35,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,1], snareAmp:0.55,
        snareFreq:240, snareNoiseAmt:0.85, snareDecay:0.10,
        hatSteps:[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], hatAmp:0.12,
        clapSteps:[0,0,0,0,1,0,0,1,0,0,0,0,1,0,1,0], clapAmp:0.42,
        percSteps:(0!16)
    ),
    \detroitDeep: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,1,1,0,0,0], kickAmp:0.5,
        kickFreq:52, kickPitchAmt:2.8, kickDecay:0.32, kickDrive:1.3, kickClick:0.16,
        snareSteps:(0!16),
        hatSteps:[0,1,1,0,1,1,0,1,0,1,1,0,1,1,0,1], hatAmp:0.13,
        clapSteps:[0,0,0,0,1,0,0,1,0,0,0,0,1,0,1,0], clapAmp:0.32,
        percInst:\rim, percSteps:[0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0], percAmp:0.18
    ),
    \lofiHipHop: (
        kickSteps:[1,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0], kickAmp:0.45,
        kickFreq:45, kickPitchAmt:2.0, kickDecay:0.55, kickDrive:1.0, kickClick:0.04,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], snareAmp:0.40,
        snareFreq:190, snareNoiseAmt:0.45, snareDecay:0.15,
        hatSteps:[1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0], hatAmp:0.08,
        clapSteps:(0!16),
        percInst:\rim, percSteps:[0,0,1,0,0,0,0,1,0,0,1,0,0,1,0,0], percAmp:0.14
    ),
    \tribalWorld: (
        kickSteps:[1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0], kickAmp:0.4,
        kickFreq:48, kickPitchAmt:2.2, kickDecay:0.4, kickDrive:1.0, kickClick:0.06,
        snareSteps:(0!16),
        hatSteps:[1,1,0,1,1,0,1,1,0,1,1,1,1,0,1,1], hatAmp:0.08,
        clapSteps:(0!16),
        percInst:\tom, tomFreq:95,
        percSteps:[1,0,0,1,0,0,1,0,1,0,0,0,0,1,0,0], percAmp:0.4
    )
);

// --- GENRES (extraits de patterns_genre.scd) -----------------------
~p[\genres] = (
    \hardTechno: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.6,
        kickFreq:60, kickPitchAmt:4.5, kickDecay:0.28, kickDrive:3.0, kickClick:0.32,
        hatSteps:[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], hatAmp:0.14,
        snareSteps:[0,0,0,0,1,0,0,1,0,0,0,0,1,0,1,0], snareAmp:0.5,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.4,
        percSteps:(0!16)
    ),
    \acidHouse: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.55,
        kickFreq:50, kickPitchAmt:2.8, kickDecay:0.35, kickDrive:1.2, kickClick:0.12,
        hatSteps:[0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1], hatAmp:0.13,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.35,
        snareSteps:(0!16), percSteps:(0!16)
    ),
    \trance138: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.55,
        kickFreq:55, kickPitchAmt:3.2, kickDecay:0.28, kickDrive:1.5, kickClick:0.20,
        hatSteps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], hatAmp:0.16,
        snareSteps:(0!16),
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.35,
        percSteps:(0!16)
    ),
    \psyTrance: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.6,
        kickFreq:55, kickPitchAmt:4.0, kickDecay:0.22, kickDrive:1.6, kickClick:0.28,
        hatSteps:[0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1], hatAmp:0.14,
        snareSteps:(0!16),
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.30,
        percInst:\rim, percSteps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], percAmp:0.20
    ),
    \hardstyle: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.65,
        kickFreq:62, kickPitchAmt:5.0, kickDecay:0.32, kickDrive:3.8, kickClick:0.42,
        hatSteps:[0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1], hatAmp:0.13,
        snareSteps:(0!16),
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.45,
        percSteps:(0!16)
    ),
    \handsUp: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.55,
        kickFreq:58, kickPitchAmt:3.5, kickDecay:0.30, kickDrive:1.6, kickClick:0.25,
        hatSteps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], hatAmp:0.18,
        snareSteps:(0!16),
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.40,
        percSteps:(0!16)
    ),
    \liquidDnB: (
        kickSteps:[1,0,0,0,0,0,1,0,0,0,1,0,1,0,0,0], kickAmp:0.5,
        kickFreq:50, kickPitchAmt:3.0, kickDecay:0.25, kickDrive:1.3, kickClick:0.20,
        hatSteps:[1,0,1,1,0,1,0,1,1,0,1,1,0,1,0,1], hatAmp:0.10,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], snareAmp:0.45,
        clapSteps:(0!16),
        percInst:\openHat, percSteps:[0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,0], percAmp:0.18
    ),
    \neurofunk: (
        kickSteps:[1,0,0,0,0,0,1,0,0,0,1,0,1,0,0,1], kickAmp:0.6,
        kickFreq:58, kickPitchAmt:4.5, kickDecay:0.16, kickDrive:1.8, kickClick:0.4,
        hatSteps:[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], hatAmp:0.12,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,1,1,0,1,1], snareAmp:0.55,
        clapSteps:(0!16), percSteps:(0!16)
    ),
    \jungle165: (
        kickSteps:[1,0,0,1,0,1,0,0,1,0,0,1,0,1,0,0], kickAmp:0.55,
        kickFreq:55, kickPitchAmt:3.5, kickDecay:0.20, kickDrive:1.6, kickClick:0.32,
        snareSteps:[0,0,0,0,1,0,1,0,0,0,0,1,1,0,0,1], snareAmp:0.55,
        hatSteps:[1,1,0,1,1,0,1,1,1,1,0,1,1,0,1,1], hatAmp:0.12,
        clapSteps:(0!16),
        percInst:\rim, percSteps:[0,0,1,0,0,1,0,0,0,0,1,0,0,1,0,0], percAmp:0.30
    ),
    \dnbJumpup: (
        kickSteps:[1,0,0,0,0,0,1,1,0,0,1,0,1,0,0,0], kickAmp:0.6,
        kickFreq:55, kickPitchAmt:4.0, kickDecay:0.18, kickDrive:1.7, kickClick:0.35,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], snareAmp:0.55,
        hatSteps:[1,1,1,0,1,1,0,1,1,1,1,0,1,1,0,1], hatAmp:0.12,
        clapSteps:(0!16), percSteps:(0!16)
    ),
    \futureBass: (
        kickSteps:[1,0,0,0,0,0,0,0,1,0,0,0,0,0,0,0], kickAmp:0.55,
        kickFreq:50, kickPitchAmt:3.0, kickDecay:0.4, kickDrive:1.3, kickClick:0.20,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], snareAmp:0.5,
        hatSteps:[0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1], hatAmp:0.13,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.35,
        percSteps:(0!16)
    ),
    \deepHouse: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.5,
        kickFreq:48, kickPitchAmt:2.5, kickDecay:0.40, kickDrive:1.2, kickClick:0.10,
        hatSteps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], hatAmp:0.12,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.30,
        snareSteps:(0!16), percSteps:(0!16)
    ),
    \techHouse: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.55,
        kickFreq:52, kickPitchAmt:3.0, kickDecay:0.30, kickDrive:1.3, kickClick:0.18,
        hatSteps:[0,1,0,1,0,1,0,1,0,1,0,1,0,1,0,1], hatAmp:0.13,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.35,
        snareSteps:(0!16),
        percInst:\rim, percSteps:[0,0,1,0,0,0,0,0,0,0,1,0,0,0,0,1], percAmp:0.20
    ),
    \progHouse: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.5,
        kickFreq:50, kickPitchAmt:2.8, kickDecay:0.35, kickDrive:1.2, kickClick:0.15,
        hatSteps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], hatAmp:0.14,
        clapSteps:[0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0], clapAmp:0.32,
        snareSteps:(0!16), percSteps:(0!16)
    ),
    \tribalTechno: (
        kickSteps:[1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0], kickAmp:0.55,
        kickFreq:54, kickPitchAmt:3.0, kickDecay:0.30, kickDrive:1.4, kickClick:0.18,
        hatSteps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], hatAmp:0.10,
        snareSteps:(0!16), clapSteps:(0!16),
        percInst:\tom, tomFreq:90,
        percSteps:[1,0,0,1,0,0,1,0,1,0,0,1,0,0,1,0], percAmp:0.35
    ),
    \industrialV2: (
        kickSteps:[1,0,0,0,1,0,0,1,1,0,0,0,1,0,1,0], kickAmp:0.6,
        kickFreq:62, kickPitchAmt:5.0, kickDecay:0.25, kickDrive:3.5, kickClick:0.40,
        hatSteps:[1,1,0,1,1,1,0,1,1,1,0,1,1,1,0,1], hatAmp:0.12,
        snareSteps:[0,0,0,0,1,0,0,1,0,0,0,0,1,0,1,1], snareAmp:0.55,
        clapSteps:(0!16),
        percInst:\rim, percSteps:[1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,1], percAmp:0.4
    ),
    \breakcore: (
        kickSteps:[1,0,1,1,0,1,1,0,1,1,0,1,1,0,1,1], kickAmp:0.6,
        kickFreq:60, kickPitchAmt:3.0, kickDecay:0.12, kickDrive:2.0, kickClick:0.5,
        hatSteps:[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], hatAmp:0.13,
        snareSteps:[0,1,0,1,1,0,1,0,0,1,1,0,1,1,0,1], snareAmp:0.55,
        clapSteps:(0!16), percSteps:(0!16)
    ),
    \footwork: (
        kickSteps:[1,0,0,1,1,0,0,0,1,0,1,1,0,0,1,0], kickAmp:0.55,
        kickFreq:42, kickPitchAmt:2.4, kickDecay:0.5, kickDrive:1.3, kickClick:0.10,
        hatSteps:[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], hatAmp:0.10,
        clapSteps:[0,0,0,1,1,0,0,0,0,0,0,1,1,0,0,0], clapAmp:0.32,
        snareSteps:(0!16),
        percInst:\rim, percSteps:[0,0,1,1,0,1,1,0,1,0,1,1,0,1,0,1], percAmp:0.22
    ),
    \idm: (
        kickSteps:[1,0,1,0,0,1,0,1,1,0,0,1,0,1,0,0], kickAmp:0.5,
        kickFreq:55, kickPitchAmt:3.0, kickDecay:0.20, kickDrive:1.5, kickClick:0.30,
        hatSteps:[1,0,1,1,0,1,0,1,1,1,0,1,0,1,1,0], hatAmp:0.12,
        snareSteps:[0,0,1,0,1,0,0,1,0,0,1,0,1,0,1,0], snareAmp:0.45,
        clapSteps:(0!16), percSteps:(0!16)
    ),
    \glitchHop: (
        kickSteps:[1,0,0,0,0,0,1,0,1,0,0,0,0,1,0,0], kickAmp:0.55,
        kickFreq:50, kickPitchAmt:2.8, kickDecay:0.32, kickDrive:1.3, kickClick:0.20,
        hatSteps:[1,0,1,1,0,1,1,0,1,0,1,1,0,1,1,0], hatAmp:0.11,
        snareSteps:[0,0,0,0,1,0,0,0,0,0,0,1,1,0,0,0], snareAmp:0.45,
        clapSteps:(0!16),
        percInst:\rim, percSteps:[0,0,1,0,0,0,0,1,0,0,1,0,0,1,0,0], percAmp:0.18
    )
);

// --- helper interne : applique un Event de variables sur env --------
//  Appele directement via [\key] (pas via pseudo-method), donc pas de self.
~p[\applyVars] = { |vars|
    vars.keysValuesDo { |k, v| currentEnvironment[k] = v };
    ~reload !? { ~reload.value };
};

// --- API kit / genre / kick (appelees via ~p[\key].(args)) ----------
~p[\kit] = { |name|
    var k = ~p[\kits][name];
    if (k.isNil) {
        ("[p.kit] kit '" ++ name ++ "' inconnu. Liste : "
            ++ ~p[\kits].keys.asArray.sort).postln;
    } {
        ~p[\applyVars].(k);
        ("[p.kit] " ++ name).postln;
    };
};

~p[\genre] = { |name|
    var g = ~p[\genres][name];
    if (g.isNil) {
        ("[p.genre] genre '" ++ name ++ "' inconnu. Liste : "
            ++ ~p[\genres].keys.asArray.sort).postln;
    } {
        ~p[\applyVars].(g);
        ("[p.genre] " ++ name).postln;
    };
};

~p[\kick] = { |name|
    if (~k.notNil) {
        if (name.isInteger) { ~k[\pat].(name) } { ~k[\go].(name) };
    } {
        "[p.kick] kicks.scd non charge".postln;
    };
};

// --- HAT presets ----------------------------------------------------
~p[\hatPresets] = (
    \off:    (0!16),
    \four:   [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0],   // 2 & 4 (kick 4/4)
    \off2:   [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0],   // offbeat 8th
    \eighth: [1,0,1,0,1,0,1,0,1,0,1,0,1,0,1,0],   // 8ths
    \sixteen:[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],   // 16ths
    \shuffle:[1,0,1,1,0,1,1,0,1,0,1,1,0,1,1,0]    // shuffle
);
~p[\hat] = { |name = \off2|
    var h = ~p[\hatPresets][name];
    if (h.isNil) {
        ("[p.hat] inconnu : " ++ ~p[\hatPresets].keys.asArray.sort).postln;
    } {
        ~hatSteps = h; ~reload !? { ~reload.value };
        ("[p.hat] " ++ name).postln;
    };
};

// --- SNARE presets --------------------------------------------------
~p[\snarePresets] = (
    \off:   (0!16),
    \two4:  [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0],
    \roll:  [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,1],
    \ghost: [0,0,1,0,1,0,0,1,0,0,1,0,1,0,0,1]
);
~p[\snare] = { |name = \two4|
    var s = ~p[\snarePresets][name];
    if (s.isNil) {
        ("[p.snare] inconnu : " ++ ~p[\snarePresets].keys.asArray.sort).postln;
    } {
        ~snareSteps = s; ~reload !? { ~reload.value };
        ("[p.snare] " ++ name).postln;
    };
};

// --- CLAP presets ---------------------------------------------------
~p[\clapPresets] = (
    \off:     (0!16),
    \two4:    [0,0,0,0,1,0,0,0,0,0,0,0,1,0,0,0],
    \offbeat: [0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0],
    \dub:     [0,0,0,0,1,0,0,1,0,0,0,0,1,0,0,1],
    \trance:  [0,0,0,0,1,0,0,0,0,0,0,0,1,0,1,0]
);
~p[\clap] = { |name = \two4|
    var c = ~p[\clapPresets][name];
    if (c.isNil) {
        ("[p.clap] inconnu : " ++ ~p[\clapPresets].keys.asArray.sort).postln;
    } {
        ~clapSteps = c; ~reload !? { ~reload.value };
        ("[p.clap] " ++ name).postln;
    };
};

// --- PERC presets (steps + percInst) -------------------------------
~p[\percPresets] = (
    \off:    ( steps:(0!16), inst: \rim ),
    \rim:    ( steps:[0,0,1,0,0,1,0,0,1,0,1,0,0,1,0,0], inst: \rim ),
    \tom:    ( steps:[1,0,0,1,0,0,1,0,1,0,0,1,0,0,1,0], inst: \tom ),
    \cowbell:( steps:[0,0,1,0,0,1,0,0,1,0,0,1,0,0,1,0], inst: \cowbell ),
    \openHat:( steps:[0,0,1,0,0,0,1,0,0,0,1,0,0,0,1,0], inst: \openHat )
);
~p[\perc] = { |name = \rim|
    var pp = ~p[\percPresets][name];
    if (pp.isNil) {
        ("[p.perc] inconnu : " ++ ~p[\percPresets].keys.asArray.sort).postln;
    } {
        ~percSteps = pp[\steps]; ~percInst = pp[\inst];
        ~reload !? { ~reload.value };
        ("[p.perc] " ++ name ++ " (inst=" ++ pp[\inst] ++ ")").postln;
    };
};

// --- LISTE ----------------------------------------------------------
~p[\list] = {
    "=== ~p -- RHYTHM PRESETS ===".postln;
    "  kits   : ".post; ~p[\kits].keys.asArray.sort.postln;
    "  genres : ".post; ~p[\genres].keys.asArray.sort.postln;
    "  hat    : ".post; ~p[\hatPresets].keys.asArray.sort.postln;
    "  snare  : ".post; ~p[\snarePresets].keys.asArray.sort.postln;
    "  clap   : ".post; ~p[\clapPresets].keys.asArray.sort.postln;
    "  perc   : ".post; ~p[\percPresets].keys.asArray.sort.postln;
    "  USAGE  : ~pKit.(\\techno) | ~pGenre.(\\hardTechno) | ~pHat.(\\eighth)".postln;
};

// --- API utilisateur : variables d'env top-level --------------------
~pKit   = { |name|              ~p[\kit].(name) };
~pGenre = { |name|              ~p[\genre].(name) };
~pKick  = { |name|              ~p[\kick].(name) };
~pHat   = { |name = \off2|      ~p[\hat].(name) };
~pSnare = { |name = \two4|      ~p[\snare].(name) };
~pClap  = { |name = \two4|      ~p[\clap].(name) };
~pPerc  = { |name = \rim|       ~p[\perc].(name) };
~pList  = { ~p[\list].() };

"=== ~p pret -- ~pKit.(\\techno) | ~pGenre.(\\hardTechno) | ~pList.() ===".postln;
)



// =====================================================================
//  EXEMPLES (Cmd+Entree)
// =====================================================================

// --- KITS complets ---
// ( ~pKit.(\techno); )
// ( ~pKit.(\dubstep); )
// ( ~pKit.(\dnb); )
// ( ~pKit.(\trap); )
// ( ~pKit.(\house); )
// ( ~pKit.(\hardstyle); )
// ( ~pKit.(\jungle); )
// ( ~pKit.(\garage); )
// ( ~pKit.(\trap808); )
// ( ~pKit.(\phonk); )
// ( ~pKit.(\footwork); )
// ( ~pKit.(\industrial); )
// ( ~pKit.(\hardcore); )
// ( ~pKit.(\detroitDeep); )
// ( ~pKit.(\lofiHipHop); )
// ( ~pKit.(\tribalWorld); )

// --- GENRES rythmiques ---
// ( ~pGenre.(\hardTechno); )
// ( ~pGenre.(\acidHouse); )
// ( ~pGenre.(\trance138); )
// ( ~pGenre.(\psyTrance); )
// ( ~pGenre.(\hardstyle); )
// ( ~pGenre.(\handsUp); )
// ( ~pGenre.(\liquidDnB); )
// ( ~pGenre.(\neurofunk); )
// ( ~pGenre.(\jungle165); )
// ( ~pGenre.(\dnbJumpup); )
// ( ~pGenre.(\futureBass); )
// ( ~pGenre.(\deepHouse); )
// ( ~pGenre.(\techHouse); )
// ( ~pGenre.(\progHouse); )
// ( ~pGenre.(\tribalTechno); )
// ( ~pGenre.(\industrialV2); )
// ( ~pGenre.(\breakcore); )
// ( ~pGenre.(\footwork); )
// ( ~pGenre.(\idm); )
// ( ~pGenre.(\glitchHop); )

// --- KICK seul (raccourci kicks.scd) ---
// ( ~pKick.(\techno); )
// ( ~pKick.(7); )

// --- composants individuels ---
// ( ~pHat.(\eighth); )
// ( ~pHat.(\sixteen); )
// ( ~pHat.(\off); )
// ( ~pSnare.(\two4); )
// ( ~pSnare.(\ghost); )
// ( ~pClap.(\trance); )
// ( ~pClap.(\off); )
// ( ~pPerc.(\rim); )
// ( ~pPerc.(\tom); )

// --- liste ---
// ( ~pList.(); )
