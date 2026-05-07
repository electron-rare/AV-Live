// =====================================================================
//  percussions.scd
//  ~25 patterns clap + perc + ~12 timbres perc selectionnable
//
//  PREREQUIS : engine.scd evalue. Cmd+Entree sur un bloc pour l'appliquer.
//
//  SynthDef percussion disponibles dans engine.scd :
//      \rim, \cowbell, \tom, \openHat
//  (\crash existe aussi mais hors selecteur ~percInst standard)
//  SynthDef percussion bonus dans synth/_index.scd :
//      \taiko, \tabla         (utilisable via ~percInst = \taiko;)
//
//  Storage :
//    ~clC1..~clC12 = patterns clap
//    ~pcP1..~pcP15 = patterns perc generale
//    Util par sequences.scd pour sequencer les changements automatiques.
// =====================================================================



// =====================================================================
//  STOCKAGE -- evaluer ce bloc une fois pour enregistrer toutes les
//  variables reutilisables.
// =====================================================================
(
// --- Patterns clap (~clC1..~clC12) ----------------------------------
~clC1  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];          // backbeat 2 et 4
~clC2  = [0,0,0,0, 0,0,0,0, 0,0,0,0, 1,0,0,0];          // techno minimal : 4 seul
~clC3  = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];          // offbeat (entre beats)
~clC4  = [1,1,1,0, 0,0,0,0, 1,1,1,0, 0,0,0,0];          // roll/flam (3 claps)
~clC5  = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,0,1];          // house ghost
~clC6  = [0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];          // dubstep gros (sur 3)
~clC7  = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0];          // trance fort 2/4
~clC8  = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0];          // reggae 1 et 3
~clC9  = [0,0,0,0, 1,0,0,0, 0,0,0,1, 1,0,0,0];          // garage shuffled
~clC10 = [0,0,1,0, 1,0,0,1, 0,0,1,0, 1,0,0,1];          // dense funk
~clC11 = [0,0,0,1, 1,0,0,0, 0,0,0,1, 1,0,0,0];          // stutter trap
~clC12 = (0 ! 16);                                       // mute

// --- Patterns perc generale (~pcP1..~pcP15) -------------------------
~pcP1  = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];          // offbeat techno
~pcP2  = [1,0,1,1, 0,0,1,0, 1,1,0,1, 0,1,1,0];          // trap ghosts
~pcP3  = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0];          // tribal congas
~pcP4  = [1,0,0,1, 0,0,1,0, 0,0,1,0, 0,0,0,0];          // clave 3-2
~pcP5  = [0,0,1,0, 0,0,1,0, 1,0,0,1, 0,0,1,0];          // clave 2-3
~pcP6  = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0];          // tambourine 8th
~pcP7  = [1,0,0,0, 0,1,0,0, 1,0,0,1, 0,1,0,0];          // cowbell tribal
~pcP8  = [0,0,1,0, 0,1,0,0, 0,0,1,0, 0,1,0,0];          // rim shot offbeat
~pcP9  = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0];          // open hat techno
~pcP10 = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1];          // closed hat 16th
~pcP11 = [1,1,0,1, 1,0,1,1, 0,1,1,1, 1,1,0,1];          // shaker rapide
~pcP12 = [1,0,1,0, 0,1,0,1, 1,0,0,1, 0,1,0,1];          // bongo polyrythme
~pcP13 = [0,0,0,0, 0,0,0,0, 0,0,0,0, 1,1,1,1];          // tom roll fill
~pcP14 = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0];          // perc sur le beat
~pcP15 = (0 ! 16);                                       // mute
"=== percussions : 12 claps + 15 perc patterns stockes ===".postln;
)



// =====================================================================
//  CLAP PATTERNS (blocs auto-applicants)
// =====================================================================

// --- C1 : clap backbeat (5+13) ---- classique ------------------------
( ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.35;
  ~reload.value; "C1 clap backbeat 2/4".postln; )

// --- C2 : clap techno minimal (sur 4 seul) --------------------------
( ~clapSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.4;
  ~reload.value; "C2 clap minimal sur 4".postln; )

// --- C3 : clap offbeat (entre les beats) ----------------------------
( ~clapSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~clapAmp = 0.3;
  ~reload.value; "C3 clap offbeat".postln; )

// --- C4 : clap roll/flam (3 claps rapides) --------------------------
( ~clapSteps = [1,1,1,0, 0,0,0,0, 1,1,1,0, 0,0,0,0]; ~clapAmp = 0.32;
  ~reload.value; "C4 clap roll/flam".postln; )

// --- C5 : clap house ghost (2/4 + ghost) ----------------------------
( ~clapSteps = [0,0,0,0, 1,0,0,1, 0,0,0,0, 1,0,0,1]; ~clapAmp = 0.34;
  ~reload.value; "C5 clap house".postln; )

// --- C6 : clap dubstep (sur 3, gros) --------------------------------
( ~clapSteps = [0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~clapAmp = 0.5;
  ~reload.value; "C6 clap dubstep".postln; )

// --- C7 : clap trance (fort 2 et 4) ---------------------------------
( ~clapSteps = [0,0,0,0, 1,0,0,0, 0,0,0,0, 1,0,0,0]; ~clapAmp = 0.42;
  ~reload.value; "C7 clap trance".postln; )

// --- C8 : clap reggae (sur 1 et 3) ----------------------------------
( ~clapSteps = [1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0]; ~clapAmp = 0.30;
  ~reload.value; "C8 clap reggae".postln; )

// --- Clap mute ------------------------------------------------------
( ~clapSteps = (0 ! 16); ~reload.value; "clap mute".postln; )



// =====================================================================
//  SELECTEUR D'INSTRUMENT PERC (~percInst)
//  SynthDef disponibles : \rim \cowbell \tom \openHat
//  Bonus si authentic.scd charge : \taiko, \tabla
// =====================================================================

( ~percInst = \rim;     ~reload.value; "perc = rim".postln; )
( ~percInst = \cowbell; ~reload.value; "perc = cowbell".postln; )
( ~percInst = \tom;     ~reload.value; "perc = tom".postln; )
( ~percInst = \openHat; ~reload.value; "perc = openHat".postln; )
// --- Bonus (si synth/_index.scd evalue) ------------------------------
( ~percInst = \taiko;   ~reload.value; "perc = taiko (authentic)".postln; )
( ~percInst = \tabla;   ~reload.value; "perc = tabla (authentic)".postln; )



// =====================================================================
//  PATTERNS PERCUSSION GENERALE (utilise ~percInst courant)
// =====================================================================

// --- P1 : offbeat techno (defaut) -----------------------------------
( ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.25;
  ~reload.value; "P1 perc offbeat".postln; )

// --- P2 : trap ghosts ----------------------------------------------
( ~percSteps = [1,0,1,1, 0,0,1,0, 1,1,0,1, 0,1,1,0]; ~percAmp = 0.18;
  ~reload.value; "P2 perc trap ghosts".postln; )

// --- P3 : tribal congas (utiliser ~percInst = \tom) ----------------
( ~percInst = \tom; ~tomFreq = 90;
  ~percSteps = [1,0,0,1, 0,0,1,0, 1,0,0,0, 0,1,0,0]; ~percAmp = 0.4;
  ~reload.value; "P3 tribal congas (tom)".postln; )

// --- P4 : clave 3-2 (afro-cubain classique) ------------------------
( ~percInst = \rim;
  ~percSteps = [1,0,0,1, 0,0,1,0, 0,0,1,0, 0,0,0,0]; ~percAmp = 0.35;
  ~reload.value; "P4 clave 3-2 (rim)".postln; )

// --- P5 : clave 2-3 (variation) ------------------------------------
( ~percInst = \rim;
  ~percSteps = [0,0,1,0, 0,0,1,0, 1,0,0,1, 0,0,1,0]; ~percAmp = 0.35;
  ~reload.value; "P5 clave 2-3 (rim)".postln; )

// --- P6 : tambourine sur 8th notes ---------------------------------
( ~percInst = \rim;
  ~percSteps = [1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0]; ~percAmp = 0.22;
  ~reload.value; "P6 tambourine 8th".postln; )

// --- P7 : cowbell tribal -------------------------------------------
( ~percInst = \cowbell; ~cowbellFreq = 800;
  ~percSteps = [1,0,0,0, 0,1,0,0, 1,0,0,1, 0,1,0,0]; ~percAmp = 0.32;
  ~reload.value; "P7 cowbell tribal".postln; )

// --- P8 : rim shot offbeat -----------------------------------------
( ~percInst = \rim;
  ~percSteps = [0,0,1,0, 0,1,0,0, 0,0,1,0, 0,1,0,0]; ~percAmp = 0.30;
  ~reload.value; "P8 rim offbeat".postln; )

// --- P9 : open hat sur offbeat (techno) ----------------------------
( ~percInst = \openHat;
  ~percSteps = [0,0,1,0, 0,0,1,0, 0,0,1,0, 0,0,1,0]; ~percAmp = 0.25;
  ~reload.value; "P9 openHat offbeat".postln; )

// --- P10 : closed hat 16th (perc layer) ----------------------------
( ~percInst = \rim;
  ~percSteps = [1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]; ~percAmp = 0.12;
  ~reload.value; "P10 hat 16th (rim layer)".postln; )

// --- P11 : shaker rapide -------------------------------------------
( ~percInst = \rim;
  ~percSteps = [1,1,0,1, 1,0,1,1, 0,1,1,1, 1,1,0,1]; ~percAmp = 0.15;
  ~reload.value; "P11 shaker rapide (rim)".postln; )

// --- P12 : bongo polyrythme (3:4 contre kick) ----------------------
( ~percInst = \tom; ~tomFreq = 110;
  ~percSteps = [1,0,1,0, 0,1,0,1, 1,0,0,1, 0,1,0,1]; ~percAmp = 0.32;
  ~reload.value; "P12 bongo polyrythme (tom)".postln; )

// --- P13 : tom roll fill (4 dernieres steps) -----------------------
( ~percInst = \tom; ~tomFreq = 100;
  ~percSteps = [0,0,0,0, 0,0,0,0, 0,0,0,0, 1,1,1,1]; ~percAmp = 0.45;
  ~reload.value; "P13 tom roll fill".postln; )

// --- P14 : perc sur le beat (renforce kick) ------------------------
( ~percInst = \cowbell; ~cowbellFreq = 600;
  ~percSteps = [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0]; ~percAmp = 0.20;
  ~reload.value; "P14 perc on beat".postln; )

// --- Perc mute -----------------------------------------------------
( ~percSteps = (0 ! 16); ~reload.value; "perc mute".postln; )



