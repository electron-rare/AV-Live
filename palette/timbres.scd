// =====================================================================
//  timbres.scd
//  Timbres melodie selectionnables via ~melodyInst (L1-L6 base + L7-L18 extra)
//
//  PREREQUIS : engine.scd evalue. Cmd+Entree sur un bloc pour l'appliquer.
// =====================================================================

// =====================================================================

// --- L1 : LEAD (defaut) -- saw+pulse detunes + chorus stereo ----------
( ~melodyInst = \lead; ~melodyAmp = 0.16; ~melodyAttack = 0.012; ~melodyRelease = 0.25;
  ~reload.value; "L1 lead".postln; )

// --- L2 : PAD -- super-saw 5 voix, attack/release longs ---------------
( ~melodyInst = \pad; ~melodyAmp = 0.14; ~melodyAttack = 0.4; ~melodyRelease = 1.5;
  ~melodyCutoff = 1800;
  ~reload.value; "L2 pad".postln; )

// --- L3 : PLUCK -- Karplus-Strong, decay naturel comme une corde ------
( ~melodyInst = \pluck; ~melodyAmp = 0.22; ~melodyAttack = 0.001; ~melodyRelease = 0.5;
  ~melodyCutoff = 5000;
  ~reload.value; "L3 pluck".postln; )

// --- L4 : FM BELL DUBSTEP -- wobble + sub MASSIF + saturation -------
( ~melodyInst = \fmBell; ~melodyAmp = 0.18;
  ~melodyAttack = 0.005; ~melodyRelease = 0.4;
  ~melodyCutoff = 400;
  ~melodyDrive = 3.5;
  ~melodyWobbleRate = 4; ~melodyWobbleDepth = 1800; ~melodyWobbleShape = 0;
  ~melodySubAmt = 0.85;            // SUB MASSIF
  ~reload.value; "L4 fmBell DUBSTEP sub massif".postln; )

// --- Wobble rate : 1/4 (slow) -> 1/16 (fast) ----------------------
( ~melodyWobbleRate = 2;  ~reload.value; "wobble 1/4".postln; )    // lent
( ~melodyWobbleRate = 4;  ~reload.value; "wobble 1/8".postln; )    // standard
( ~melodyWobbleRate = 8;  ~reload.value; "wobble 1/16".postln; )   // rapide
( ~melodyWobbleRate = 16; ~reload.value; "wobble 1/32".postln; )   // tres rapide

// --- Wobble shape : smooth (LFTri) vs chop (LFPulse) ---------------
( ~melodyWobbleShape = 0; ~reload.value; "wobble smooth".postln; )
( ~melodyWobbleShape = 1; ~reload.value; "wobble chop".postln; )

// --- Wobble depth : ouverture du filtre ---------------------------
( ~melodyWobbleDepth = 800;  ~reload.value; "wobble petit".postln; )
( ~melodyWobbleDepth = 1800; ~reload.value; "wobble normal".postln; )
( ~melodyWobbleDepth = 3500; ~reload.value; "wobble enorme".postln; )

// --- Sub level (poid du sub-bass dubstep) -------------------------
( ~melodySubAmt = 0.2; ~reload.value; "sub leger".postln; )
( ~melodySubAmt = 0.5; ~reload.value; "sub normal".postln; )
( ~melodySubAmt = 0.8; ~reload.value; "sub massif".postln; )

// --- L5 : STAB -- court et sature, parfait pour Detroit ---------------
( ~melodyInst = \stab; ~melodyAmp = 0.18; ~melodyAttack = 0.001; ~melodyRelease = 0.06;
  ~melodyCutoff = 1500; ~melodyDrive = 2.8;
  ~reload.value; "L5 stab".postln; )

// --- L6 : SAW3 -- 3 saws empilees, large -----------------------------
( ~melodyInst = \saw3; ~melodyAmp = 0.16; ~melodyAttack = 0.005; ~melodyRelease = 0.25;
  ~melodyCutoff = 2200; ~melodyDrive = 1.4;
  ~reload.value; "L6 saw3".postln; )

// --- TIMBRE ALEATOIRE ------------------------------------------------
(
~melodyInst = [\lead, \pad, \pluck, \fmBell, \stab, \saw3].choose;
~reload.value;
("L random : " ++ ~melodyInst).postln;
)

// --- ROTATION AUTOMATIQUE des timbres (toutes les 16s) ---------------
(
~lRotate !? { ~lRotate.stop };
~lRotate = Routine({
    var insts = [\lead, \pad, \pluck, \fmBell, \stab, \saw3];
    inf.do { |k|
        ~melodyInst = insts.wrapAt(k);
        ("L rotate -> " ++ ~melodyInst).postln;
        ~reload.value;
        16.wait;
    };
}).play;
"L rotate ON".postln;
)
( ~lRotate !? { ~lRotate.stop }; "L rotate OFF".postln; )





// =====================================================================
//  TIMBRES EXTRA (necessite synthdefs_extra.scd evalue)
// =====================================================================

// --- L7 : SQUARE LEAD (chiptune / 8-bit) ----------------------------
( ~melodyInst = \squareLead; ~melodyAmp = 0.16;
  ~melodyAttack = 0.005; ~melodyRelease = 0.25; ~melodyCutoff = 5000;
  ~reload.value; "L7 squareLead chiptune".postln; )

// --- L8 : FM LEAD (DX-style) ----------------------------------------
( ~melodyInst = \fmLead; ~melodyAmp = 0.16;
  ~melodyAttack = 0.003; ~melodyRelease = 0.4; ~melodyCutoff = 6000;
  ~reload.value; "L8 fmLead".postln; )

// --- L9 : ORGAN LEAD (Hammond drawbar) ------------------------------
( ~melodyInst = \organLead; ~melodyAmp = 0.14;
  ~melodyAttack = 0.005; ~melodyRelease = 0.15; ~melodyCutoff = 4500;
  ~reload.value; "L9 organLead".postln; )

// --- L10 : HARD LEAD (saw avec hard sync) ---------------------------
( ~melodyInst = \hardLead; ~melodyAmp = 0.16;
  ~melodyAttack = 0.002; ~melodyRelease = 0.25; ~melodyCutoff = 5500;
  ~reload.value; "L10 hardLead".postln; )

// --- L11 : WARM PAD (super-saw 7 voix lush) -------------------------
( ~melodyInst = \warmPad; ~melodyAmp = 0.13;
  ~melodyAttack = 0.6; ~melodyRelease = 2.0; ~melodyCutoff = 1800;
  ~reload.value; "L11 warmPad".postln; )

// --- L12 : STRINGS (ensemble orchestral) ----------------------------
( ~melodyInst = \strings; ~melodyAmp = 0.15;
  ~melodyAttack = 0.3; ~melodyRelease = 1.2; ~melodyCutoff = 3500;
  ~reload.value; "L12 strings".postln; )

// --- L13 : CHOIR (voix synthetiques avec formants) ------------------
( ~melodyInst = \choir; ~melodyAmp = 0.15;
  ~melodyAttack = 0.4; ~melodyRelease = 1.5; ~melodyCutoff = 2500;
  ~reload.value; "L13 choir".postln; )

// --- L14 : FM BASS (techno ratio 2:1) -------------------------------
( ~melodyInst = \fmBass; ~melodyAmp = 0.30;
  ~melodyAttack = 0.003; ~melodyRelease = 0.2; ~melodyCutoff = 1800;
  ~reload.value; "L14 fmBass".postln; )

// --- L15 : SUB BOOM (808 amplifie) ----------------------------------
( ~melodyInst = \subBoom; ~melodyAmp = 0.36;
  ~melodyAttack = 0.005; ~melodyRelease = 0.6;
  ~reload.value; "L15 subBoom".postln; )

// --- L16 : HANDPAN (steel drum) -------------------------------------
( ~melodyInst = \handpan; ~melodyAmp = 0.20;
  ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 5000;
  ~reload.value; "L16 handpan".postln; )

// --- L17 : FLUTE (bambou avec souffle) ------------------------------
( ~melodyInst = \flute; ~melodyAmp = 0.16;
  ~melodyAttack = 0.08; ~melodyRelease = 0.3; ~melodyCutoff = 3500;
  ~reload.value; "L17 flute".postln; )

// --- L18 : DRONE (note longue avec modulation) ---------------------
( ~melodyInst = \drone; ~melodyAmp = 0.16;
  ~melodyAttack = 1.5; ~melodyRelease = 3.0; ~melodyCutoff = 1800;
  ~reload.value; "L18 drone".postln; )


// =====================================================================
//  TIMBRES AUTHENTIQUES (L19-L28) -- necessite synthdefs/authentic.scd
// =====================================================================

// --- L19 : SUPERSAW (trance JP-8000 7-voice) -----------------------
( ~melodyInst = \supersaw; ~melodyAmp = 0.15;
  ~melodyAttack = 0.005; ~melodyRelease = 0.4; ~melodyCutoff = 4500;
  ~reload.value; "L19 supersaw trance".postln; )

// --- L20 : RHODES (Detroit DX7 e-piano) -----------------------------
( ~melodyInst = \rhodes; ~melodyAmp = 0.20;
  ~melodyAttack = 0.002; ~melodyRelease = 0.8; ~melodyCutoff = 4000;
  ~reload.value; "L20 rhodes Detroit".postln; )

// --- L21 : HOOVERBASS (Alpha Juno / gabber / trance) ---------------
( ~melodyInst = \hooverbass; ~melodyAmp = 0.22;
  ~melodyAttack = 0.001; ~melodyRelease = 0.2; ~melodyCutoff = 3500;
  ~reload.value; "L21 hooverbass".postln; )

// --- L22 : VOCAL PAD (formants vocaux ah/eh) -----------------------
( ~melodyInst = \vocalPad; ~melodyAmp = 0.18;
  ~melodyAttack = 0.4; ~melodyRelease = 1.5;
  ~reload.value; "L22 vocalPad".postln; )

// --- L23 : DIDGERIDOO (drone aborigene + growl) -------------------
( ~melodyInst = \didgeridoo; ~melodyAmp = 0.22;
  ~melodyAttack = 0.5; ~melodyRelease = 1.0;
  ~reload.value; "L23 didgeridoo".postln; )

// --- L24 : GUZHENG (harpe chinoise + bend) -------------------------
( ~melodyInst = \guzheng; ~melodyAmp = 0.22;
  ~melodyAttack = 0.001; ~melodyRelease = 1.5; ~melodyCutoff = 5500;
  ~reload.value; "L24 guzheng".postln; )

// --- L25 : SHAKUHACHI (flute japonaise + breath) -------------------
( ~melodyInst = \shakuhachi; ~melodyAmp = 0.18;
  ~melodyAttack = 0.12; ~melodyRelease = 0.4; ~melodyCutoff = 3000;
  ~reload.value; "L25 shakuhachi".postln; )

// --- L26 : REESE DnB (FM brutal hard DnB) --------------------------
( ~melodyInst = \reeseDnB; ~melodyAmp = 0.30;
  ~melodyAttack = 0.005; ~melodyRelease = 0.2; ~melodyCutoff = 800;
  ~melodyDrive = 4.0;
  ~reload.value; "L26 reeseDnB".postln; )

// --- TRACKS DE PERCUSSION SUPPLEMENTAIRES ------------------------
// Ces SynthDefs s'utilisent via Synth(\xxx) plutot que ~melodyInst :
 (Synth(\taiko, [\freq, 80, \amp, 0.5]);)
 (Synth(\tabla, [\freq, 220, \amp, 0.4]);)
 (Synth(\kickGabber, [\amp, 0.6]);)
 (Synth(\kick808,    [\freq, 35, \decay, 1, \amp, 0.7]);)
 (Synth(\snareGated, [\freq, 200, \decay, 0.2, \amp, 0.5]);)
 (Synth(\scratch,    [\dur, 0.3, \freq, 800, \amp, 0.4]);)
