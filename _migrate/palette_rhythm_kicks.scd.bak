// =====================================================================
//  kicks.scd
//  ~25 patterns kick (K1-K25) + ~12 timbres kick (T1-T12)
//
//  PREREQUIS : engine.scd evalue. Cmd+Entree sur un bloc pour l'appliquer.
//
//  En plus des blocs auto-applicants, chaque pattern est stocke dans
//  ~kK1..~kK25 (tableau 16 steps brut, sans appliquer). Util pour
//  ~seqPlay.([[16, { ~kickSteps = ~kK3; ~reload.value }], ...])
//  cf. palette/sequences.scd.
// =====================================================================



// =====================================================================
//  STOCKAGE (variables ~kK1..~kK25) -- evaluer ce bloc une fois pour
//  enregistrer tous les patterns sous forme de variables reutilisables
//  par sequences.scd.
// =====================================================================
(
// --- 4-on-floor classique -------------------------------------------
~kK1  = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ];
// --- techno syncope (8th deplaces) ----------------------------------
~kK2  = [ 1,0,0,0, 1,0,0,1, 1,0,0,0, 1,0,1,0 ];
// --- gabber double-temps (toutes 8th notes) -------------------------
~kK3  = [ 1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0 ];
// --- dembow / latin (1 + 1+e + 3 + 3+e) -----------------------------
~kK4  = [ 1,0,0,1, 0,0,1,0, 1,0,0,1, 0,0,1,0 ];
// --- half-time (1 et 9 -- dubstep / phonk / hip-hop) ----------------
~kK5  = [ 1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0 ];
// --- breakbeat amen-like --------------------------------------------
~kK6  = [ 1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0 ];
// --- techno triplet feel (3 over 4) ---------------------------------
~kK7  = [ 1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,1 ];
// --- minimal -- 1 kick par mesure (downtempo) -----------------------
~kK8  = [ 1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0 ];

// --- 4-on-floor + ghost offbeat (techno minimal) --------------------
~kK9  = [ 1,0,0,0, 1,0,0,1, 1,0,0,0, 1,0,1,0 ];
// --- 4-on-floor syncope avancee -------------------------------------
~kK10 = [ 1,0,1,0, 1,0,0,1, 1,0,1,0, 1,0,1,1 ];
// --- double-time (1, 5, 9, 13 + 3, 7, 11, 15) -----------------------
~kK11 = [ 1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0 ];
// --- breakbeat (drum'n'bass / jungle base) --------------------------
~kK12 = [ 1,0,0,1, 0,0,0,0, 0,0,1,0, 0,0,1,0 ];
// --- amen break kick pattern (jungle origine) -----------------------
~kK13 = [ 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 ];
// --- gabber dense (kick sur tous 16th) ------------------------------
~kK14 = [ 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1 ];
// --- hardstyle (kick + reverse + tail simulee) ----------------------
~kK15 = [ 1,0,0,0, 1,0,0,1, 1,0,0,0, 1,1,0,0 ];
// --- techno minimal kick fantome ------------------------------------
~kK16 = [ 1,0,0,0, 1,0,0,0, 1,0,0,1, 1,0,0,0 ];
// --- trance gros kick (4/4 punchy + ghost 16) -----------------------
~kK17 = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,1 ];
// --- house classique (kick 4/4 + offbeat hat impl) ------------------
~kK18 = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ];
// --- electro syncope ------------------------------------------------
~kK19 = [ 1,0,0,1, 0,0,0,0, 1,0,0,0, 0,0,1,0 ];
// --- trip-hop lazy --------------------------------------------------
~kK20 = [ 1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0 ];
// --- jungle rapid breakbeat -----------------------------------------
~kK21 = [ 1,0,0,1, 0,1,0,0, 1,0,0,1, 0,1,0,0 ];
// --- reggae / dub one-drop (kick sur 3) -----------------------------
~kK22 = [ 0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0 ];
// --- afrobeat (kick polyrhythmique) ---------------------------------
~kK23 = [ 1,0,0,1, 0,1,0,0, 1,0,1,0, 0,1,0,0 ];
// --- garage 2-step --------------------------------------------------
~kK24 = [ 1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0 ];
// --- footwork / juke (160 BPM, kick triple) -------------------------
~kK25 = [ 1,0,0,1, 1,0,0,0, 1,0,1,1, 0,0,1,0 ];
"=== kicks : 25 patterns stockes dans ~kK1..~kK25 ===".postln;
)



// =====================================================================
//  PATTERNS RYTHMIQUES (blocs auto-applicants)
// =====================================================================

// --- K1 : 4-on-the-floor (defaut) -----------------------------------
( ~kickSteps = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ]; ~reload.value; "K1 4/4".postln; )

// --- K2 : techno syncope (8th notes deplaces) -----------------------
( ~kickSteps = [ 1,0,0,0, 1,0,0,1, 1,0,0,0, 1,0,1,0 ]; ~reload.value; "K2 syncope".postln; )

// --- K3 : gabber double-temps (toutes les 2 doubles-croches) --------
( ~kickSteps = [ 1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0 ]; ~reload.value; "K3 gabber".postln; )

// --- K4 : dembow / latin (1 + 1+e + 3 + 3+e) ------------------------
( ~kickSteps = [ 1,0,0,1, 0,0,1,0, 1,0,0,1, 0,0,1,0 ]; ~reload.value; "K4 dembow".postln; )

// --- K5 : half-time (kick 1 et 9 -- dubstep/phonk/hip-hop) ----------
( ~kickSteps = [ 1,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0 ]; ~reload.value; "K5 half-time".postln; )

// --- K6 : breakbeat (Amen-like) -------------------------------------
( ~kickSteps = [ 1,0,0,0, 0,0,1,0, 0,0,1,0, 1,0,0,0 ]; ~reload.value; "K6 breakbeat".postln; )

// --- K7 : techno triplet feel (3 over 4) ----------------------------
( ~kickSteps = [ 1,0,0,1, 0,0,1,0, 0,1,0,0, 1,0,0,1 ]; ~reload.value; "K7 triplet feel".postln; )

// --- K8 : minimal -- 1 kick par mesure (downtempo) -----------------
( ~kickSteps = [ 1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0 ]; ~reload.value; "K8 minimal".postln; )

// --- K9 : 4-on-floor + ghost offbeat (techno minimaliste) ----------
( ~kickSteps = [ 1,0,0,0, 1,0,0,1, 1,0,0,0, 1,0,1,0 ]; ~reload.value; "K9 minimal ghost".postln; )

// --- K10 : 4-on-floor syncope avance (drive +) ---------------------
( ~kickSteps = [ 1,0,1,0, 1,0,0,1, 1,0,1,0, 1,0,1,1 ]; ~reload.value; "K10 syncope avance".postln; )

// --- K11 : double-time (8th sur tous les temps) --------------------
( ~kickSteps = [ 1,0,1,0, 1,0,1,0, 1,0,1,0, 1,0,1,0 ]; ~reload.value; "K11 double-time".postln; )

// --- K12 : breakbeat irregulier (DnB / jungle) ---------------------
( ~kickSteps = [ 1,0,0,1, 0,0,0,0, 0,0,1,0, 0,0,1,0 ]; ~reload.value; "K12 breakbeat irreg".postln; )

// --- K13 : amen break kick pattern (jungle classique) --------------
( ~kickSteps = [ 1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1 ]; ~reload.value; "K13 amen break".postln; )

// --- K14 : gabber tres dense (kick partout) ------------------------
( ~kickSteps = [ 1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1 ]; ~reload.value; "K14 gabber dense".postln; )

// --- K15 : hardstyle (kick + reverse + tail simulee) ---------------
( ~kickSteps = [ 1,0,0,0, 1,0,0,1, 1,0,0,0, 1,1,0,0 ]; ~reload.value; "K15 hardstyle".postln; )

// --- K16 : techno minimaliste avec kick fantome --------------------
( ~kickSteps = [ 1,0,0,0, 1,0,0,0, 1,0,0,1, 1,0,0,0 ]; ~reload.value; "K16 techno minimal".postln; )

// --- K17 : trance kick gros + ghost 16 ------------------------------
( ~kickSteps = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,1 ]; ~reload.value; "K17 trance".postln; )

// --- K18 : house 4/4 classique --------------------------------------
( ~kickSteps = [ 1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,0,0 ]; ~reload.value; "K18 house".postln; )

// --- K19 : electro syncope ------------------------------------------
( ~kickSteps = [ 1,0,0,1, 0,0,0,0, 1,0,0,0, 0,0,1,0 ]; ~reload.value; "K19 electro".postln; )

// --- K20 : trip-hop lazy kick ---------------------------------------
( ~kickSteps = [ 1,0,0,0, 0,0,0,0, 0,0,1,0, 0,0,0,0 ]; ~reload.value; "K20 trip-hop".postln; )

// --- K21 : jungle rapid breakbeat -----------------------------------
( ~kickSteps = [ 1,0,0,1, 0,1,0,0, 1,0,0,1, 0,1,0,0 ]; ~reload.value; "K21 jungle".postln; )

// --- K22 : reggae / dub one-drop (kick sur 3) -----------------------
( ~kickSteps = [ 0,0,0,0, 0,0,0,0, 1,0,0,0, 0,0,0,0 ]; ~reload.value; "K22 one-drop".postln; )

// --- K23 : afrobeat polyrythmique -----------------------------------
( ~kickSteps = [ 1,0,0,1, 0,1,0,0, 1,0,1,0, 0,1,0,0 ]; ~reload.value; "K23 afrobeat".postln; )

// --- K24 : garage 2-step --------------------------------------------
( ~kickSteps = [ 1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0 ]; ~reload.value; "K24 2-step".postln; )

// --- K25 : footwork / juke (160 BPM, kick triple) -------------------
( ~kickSteps = [ 1,0,0,1, 1,0,0,0, 1,0,1,1, 0,0,1,0 ]; ~reload.value; "K25 footwork".postln; )



// =====================================================================
//  VARIATIONS DE TIMBRE (T1..T12)
// =====================================================================

// --- T1 : kick rond (defaut) -- techno classique --------------------
( ~kickFreq = 55; ~kickPitchAmt = 3.0; ~kickDecay = 0.32;
  ~kickDrive = 1.3; ~kickClick = 0.2;
  ~reload.value; "T1 rond".postln; )

// --- T2 : kick claquant -- snare-like, drive plus haut --------------
( ~kickFreq = 65; ~kickPitchAmt = 4.0; ~kickDecay = 0.18;
  ~kickDrive = 1.8; ~kickClick = 0.45;
  ~reload.value; "T2 claquant".postln; )

// --- T3 : kick boomy -- queue longue, sub fort, peu de click --------
( ~kickFreq = 48; ~kickPitchAmt = 2.5; ~kickDecay = 0.6;
  ~kickDrive = 1.2; ~kickClick = 0.08;
  ~reload.value; "T3 boomy".postln; )

// --- T4 : kick distordu -- gabber/hardcore --------------------------
( ~kickFreq = 60; ~kickPitchAmt = 5.0; ~kickDecay = 0.28;
  ~kickDrive = 3.5; ~kickClick = 0.3;
  ~reload.value; "T4 distordu".postln; )

// --- T5 : kick sub deep -- pour dub / techno minimal ----------------
( ~kickFreq = 42; ~kickPitchAmt = 2.0; ~kickDecay = 0.5;
  ~kickDrive = 1.0; ~kickClick = 0.05;
  ~reload.value; "T5 sub deep".postln; )

// --- T6 : kick punchy -- tres tight, snappy attack ------------------
( ~kickFreq = 70; ~kickPitchAmt = 3.5; ~kickDecay = 0.22;
  ~kickDrive = 2.0; ~kickClick = 0.35;
  ~reload.value; "T6 punchy".postln; )

// --- T7 : clap-style (melange kick + snare body) -------------------
( ~kickFreq = 75; ~kickPitchAmt = 4.5; ~kickDecay = 0.16;
  ~kickDrive = 1.5; ~kickClick = 0.55;
  ~reload.value; "T7 clap-style".postln; )

// --- T8 : 909 vintage (long decay, soft click) ---------------------
( ~kickFreq = 52; ~kickPitchAmt = 2.8; ~kickDecay = 0.45;
  ~kickDrive = 1.1; ~kickClick = 0.12;
  ~reload.value; "T8 909 vintage".postln; )

// --- T9 : 808 boom (ultra sub, decay tres long) --------------------
( ~kickFreq = 38; ~kickPitchAmt = 1.8; ~kickDecay = 0.85;
  ~kickDrive = 1.0; ~kickClick = 0.04;
  ~reload.value; "T9 808 boom".postln; )

// --- T10 : gabber distorded (drive max + click) --------------------
( ~kickFreq = 62; ~kickPitchAmt = 5.5; ~kickDecay = 0.22;
  ~kickDrive = 4.5; ~kickClick = 0.5;
  ~reload.value; "T10 gabber distorded".postln; )

// --- T11 : breakcore (tres court, metallique) ---------------------
( ~kickFreq = 80; ~kickPitchAmt = 4.0; ~kickDecay = 0.10;
  ~kickDrive = 2.5; ~kickClick = 0.6;
  ~reload.value; "T11 breakcore".postln; )

// --- T12 : dub kick (long sub tail, peu de click) ------------------
( ~kickFreq = 40; ~kickPitchAmt = 1.5; ~kickDecay = 0.95;
  ~kickDrive = 1.0; ~kickClick = 0.03;
  ~reload.value; "T12 dub kick".postln; )



