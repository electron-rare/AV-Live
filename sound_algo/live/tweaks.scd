// =====================================================================
//  tweaks.scd  --  Tweaks live (cutoff, drive, mute, tempo, sidechain,
//                 wobble dubstep, sub, melody boost, randomize, sweep)
//
//  PREREQUIS : engine.scd evalue + PLAY actif (ou une track en cours).
//  USAGE     : Cmd+Entree sur la ligne du tweak.
// =====================================================================

//  6. TWEAKS LIVE -- modifie une seule chose
// =====================================================================

// --- Cutoff acid ----------------------------------------
( ~acidCutoff = 200;  ~reload.value; )
( ~acidCutoff = 600;  ~reload.value; )
( ~acidCutoff = 1200; ~reload.value; )
( ~acidCutoff = 2500; ~reload.value; )

// --- Resonance acid -------------------------------------
( ~acidRq = 0.05; ~reload.value; )         // EXTREME
( ~acidRq = 0.15; ~reload.value; )         // normal
( ~acidRq = 0.4;  ~reload.value; )         // doux

// --- Drive acid -----------------------------------------
( ~acidDrive = 1.0; ~reload.value; )
( ~acidDrive = 2.5; ~reload.value; )
( ~acidDrive = 4.5; ~reload.value; )

// --- Tempo en live --------------------------------------
( TempoClock.default.tempo = 110/60; )
( TempoClock.default.tempo = 132/60; )
( TempoClock.default.tempo = 145/60; )

// --- Boost global du volume melodie (multiplicateur) ----
( ~melodyBoost = 1.0; ~reload.value; "melody boost x1.0".postln; )
( ~melodyBoost = 1.6; ~reload.value; "melody boost x1.6 (defaut)".postln; )
( ~melodyBoost = 2.2; ~reload.value; "melody boost x2.2 (en avant)".postln; )
( ~melodyBoost = 3.0; ~reload.value; "melody boost x3.0 (devant tout)".postln; )

// --- Niveau du kick (le rendre plus / moins present) ---
( ~kickAmp = 0.3; ~reload.value; )         // discret
( ~kickAmp = 0.5; ~reload.value; )         // normal
( ~kickAmp = 0.7; ~reload.value; )         // fort

// --- Mute / Unmute par piste ---------------------------
( ~kickAmp = 0;    ~reload.value; )
( ~kickAmp = 0.5;  ~reload.value; )
( ~hatAmp = 0;     ~reload.value; )
( ~hatAmp = 0.18;  ~reload.value; )
( ~acidAmp = 0;    ~reload.value; )
( ~acidAmp = 0.32; ~reload.value; )
( ~melodyAmp = 0;    ~reload.value; )
( ~melodyAmp = 0.16; ~reload.value; )

// --- Sidechain : amount de pompage par voix --------------
( ~acidScAmt = 0;    ~reload.value; )      // pas de duck acid
( ~acidScAmt = 0.4;  ~reload.value; )      // duck leger
( ~acidScAmt = 0.7;  ~reload.value; )      // duck normal (default)
( ~acidScAmt = 0.95; ~reload.value; )      // duck extreme (acid disparait sur kick)
( ~leadScAmt = 0;    ~reload.value; )      // pas de duck lead
( ~leadScAmt = 0.5;  ~reload.value; )      // duck normal (default)
( ~leadScAmt = 0.85; ~reload.value; )      // duck fort

// --- Sidechain : duree de la queue de duck ---------------
( ~kickScShape = 0.08; ~reload.value; )    // tres court (peu perceptible)
( ~kickScShape = 0.18; ~reload.value; )    // normal
( ~kickScShape = 0.35; ~reload.value; )    // long (style french touch)

// --- ALEATOIRE -- regenere les patterns sans toucher au tempo --------
( ~melodyNotes = ~genMelody.(0.55, ~scaleMinorPent); ~reload.value; "melody random".postln; )
( ~melodyNotes = ~genMelody.(0.35, ~scaleMinor); ~reload.value; "melody sparse".postln; )
( ~acidNotes = ~genAcidNotes.value;
  ~acidAccents = ~genAcidAccents.(0.4);
  ~acidSlides = ~genAcidSlides.(0.3);
  ~reload.value; "acid random".postln; )
( ~kickSteps = ~genKickPattern.(0.3); ~reload.value; "kick random ghosts".postln; )
( ~hatSteps = ~genKickPattern.(0.6); ~reload.value; "hat random".postln; )

// --- TOUT random d'un coup -----------------------------------------
(
~melodyNotes = ~genMelody.(0.55);
~acidNotes = ~genAcidNotes.value;
~acidAccents = ~genAcidAccents.(0.4);
~acidSlides = ~genAcidSlides.(0.3);
~kickSteps = ~genKickPattern.(0.25);
~hatSteps = ~genKickPattern.(0.5);
~acidCutoff = rrand(500, 2000);
~acidRq = rrand(0.08, 0.25);
~melodyCutoff = rrand(1500, 3500);
~reload.value;
"=== TOUT randomise ===".postln;
)

// --- Boucle de tweaks aleatoires (toutes les 4s) -------------------
(
~randomLoop !? { ~randomLoop.stop };
~randomLoop = Routine({
    inf.do {
        ~randomTweak.(0.35);
        4.wait;
    };
}).play;
"random tweaks ON".postln;
)
( ~randomLoop !? { ~randomLoop.stop }; "random tweaks OFF".postln; )

// --- Filtre sweep auto sur l'acid (Routine 8s) ----------
(
~filterSweep !? { ~filterSweep.stop };
~filterSweep = Routine({
    inf.do { |k|
        var x = ((k / 32) * 2 * pi).sin.abs;
        ~acidCutoff = 200 + (x * 2300);
        ~reload.value;
        0.25.wait;
    };
}).play;
"sweep auto demarre".postln;
)
( ~filterSweep !? { ~filterSweep.stop }; "sweep stoppe".postln; )



// =====================================================================


// =====================================================================
//  RECORDING -- enregistre la sortie audio dans ~/Music/SuperCollider Recordings/
// =====================================================================
( s.record; "=== RECORDING ===".postln; )
( s.stopRecording; "=== RECORD STOP ===".postln; )
( s.recordPaused = true; "=== PAUSE record ===".postln; )
( s.recordPaused = false; "=== RESUME record ===".postln; )

// Path du recording courant
( s.recHeaderFormat = "WAV"; s.recSampleFormat = "int24"; "format WAV 24bit".postln; )
