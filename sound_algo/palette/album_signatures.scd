// =====================================================================
//  album_signatures.scd  --  Caractere distinctif par album
//
//  Plutot que reecrire les 225 .scd des albums utilises dans les demos,
//  on definit une "signature" qui s'applique au moment ou l'album est
//  lance. Une signature combine :
//    - humanize tunables (timing/vel/detune)
//    - rotation des SynthDefs (on + pool restreint si voulu)
//    - auto layer (timbres + amp + octaves)
//    - tweaks globaux (drive, swing, etc.)
//
//  Appel : ~applyAlbumSig.(\letter)  avant ou pendant le playAlbum.
//
//  Le wrapping de ~playAlbum hook automatiquement les signatures
//  (cf. fin du fichier).
//
// =====================================================================

(
~albumSigs = (
    // === A : ACID JOURNEY -- 303 brut, leger swing, rotation acid_v ===
    'A': {
        ~humanizeOn = true; ~humanizeTiming = 0.0040;
        ~humanizeVelocity = 0.12; ~humanizeDetune = 0.04;
        ~rotPoolAcid = (1..19).collect { |i| ("acid_v" ++ i).asSymbol };
        ~rotationEvery = 16; ~setRotationOn.(true);
        ~layerAcidInst = \sub_boom; ~layerAcidAmp = 0.18; ~layerAcidOctave = -1;
        ~layerMelodyInst = \pluck; ~layerMelodyAmp = 0.15; ~layerMelodyOctave = -1;
        ~setAutoLayer.(true);
        "[sig:A] ACID JOURNEY -- 303 + sub_boom layer".postln;
    },
    // === H : ACID TRANCE -- plus de drive, swing 8 notes ===
    'H': {
        ~humanizeOn = true; ~humanizeTiming = 0.0050;
        ~humanizeVelocity = 0.15; ~humanizeDetune = 0.05;
        ~rotationEvery = 8; ~setRotationOn.(true);
        ~layerMelodyInst = \supersaw; ~layerMelodyAmp = 0.22; ~layerMelodyOctave = 0;
        ~setAutoLayer.(true);
        "[sig:H] ACID TRANCE -- supersaw layer + swing".postln;
    },
    // === M : CHIPTUNE MADNESS -- timing serre, square + pluck ===
    'M': {
        ~humanizeOn = true; ~humanizeTiming = 0.0020;  // 8-bit = tighter
        ~humanizeVelocity = 0.08; ~humanizeDetune = 0.02;
        ~rotPoolLead = [\squareLead, \square_lead, \pluck];
        ~rotationEvery = 4; ~setRotationOn.(true);
        ~layerMelodyInst = \pluck; ~layerMelodyAmp = 0.30; ~layerMelodyOctave = 1;
        ~setAutoLayer.(true);
        "[sig:M] CHIPTUNE -- square + pluck octave +1".postln;
    },
    // === G : DETROIT SOULFUL -- warm pad, rhodes, rotation lead ===
    'G': {
        ~humanizeOn = true; ~humanizeTiming = 0.0045;
        ~humanizeVelocity = 0.13; ~humanizeDetune = 0.04;
        ~rotPoolLead = (1..19).collect { |i| ("lead_v" ++ i).asSymbol };
        ~rotationEvery = 12; ~setRotationOn.(true);
        ~layerMelodyInst = \rhodes; ~layerMelodyAmp = 0.28; ~layerMelodyOctave = -1;
        ~layerHarmonyInst = \warmPad; ~layerHarmonyAmp = 0.32;
        ~setAutoLayer.(true);
        "[sig:G] DETROIT SOULFUL -- rhodes + warm pad".postln;
    },
    // === L : FUTURE GARAGE -- swung, vocal pad layer ===
    'L': {
        ~humanizeOn = true; ~humanizeTiming = 0.0060;  // garage = swingy
        ~humanizeVelocity = 0.12; ~humanizeDetune = 0.03;
        ~rotationEvery = 16; ~setRotationOn.(true);
        ~layerMelodyInst = \vocalPad; ~layerMelodyAmp = 0.25;
        ~layerHarmonyInst = \warmPad; ~layerHarmonyAmp = 0.20;
        ~setAutoLayer.(true);
        "[sig:L] FUTURE GARAGE -- vocalPad + warmPad".postln;
    },
    // === P : INDUSTRIAL -- saturation, layer hard ===
    'P': {
        ~humanizeOn = true; ~humanizeTiming = 0.0030;
        ~humanizeVelocity = 0.10; ~humanizeDetune = 0.02;
        ~rotPoolBass = (1..19).collect { |i| ("bass808_v" ++ i).asSymbol };
        ~rotationEvery = 8; ~setRotationOn.(true);
        ~layerAcidInst = \growl; ~layerAcidAmp = 0.30;
        ~layerMelodyInst = \hardLead; ~layerMelodyAmp = 0.25;
        ~setAutoLayer.(true);
        "[sig:P] INDUSTRIAL -- growl + hardLead".postln;
    },
    // === J : AMBIENT CINEMATIC -- doux, choir + drone, peu de timing ===
    'J': {
        ~humanizeOn = true; ~humanizeTiming = 0.0060;  // un peu plus lache
        ~humanizeVelocity = 0.18; ~humanizeDetune = 0.06;
        ~rotPoolPad = (1..19).collect { |i| ("pad_v" ++ i).asSymbol };
        ~rotationEvery = 32; ~setRotationOn.(true);  // change rarement
        ~layerMelodyInst = \choir; ~layerMelodyAmp = 0.40; ~layerMelodyOctave = 0;
        ~layerHarmonyInst = \drone; ~layerHarmonyAmp = 0.35;
        ~setAutoLayer.(true);
        "[sig:J] AMBIENT -- choir + drone wash".postln;
    },
    // === I : LIQUID DNB -- rolling, plucks ===
    'I': {
        ~humanizeOn = true; ~humanizeTiming = 0.0045;
        ~humanizeVelocity = 0.13; ~humanizeDetune = 0.03;
        ~rotPoolPluck = (1..19).collect { |i| ("pluck_v" ++ i).asSymbol };
        ~rotationEvery = 8; ~setRotationOn.(true);
        ~layerMelodyInst = \pluck; ~layerMelodyAmp = 0.30; ~layerMelodyOctave = 1;
        ~setAutoLayer.(true);
        "[sig:I] LIQUID DNB -- pluck + rolling".postln;
    },
    // === Q : NEUROFUNK DNB -- reese hard, glitchy ===
    'Q': {
        ~humanizeOn = true; ~humanizeTiming = 0.0035;
        ~humanizeVelocity = 0.10; ~humanizeDetune = 0.03;
        ~rotPoolBass = [\reese, \reeseDnB, \reeseHard, \bass808];
        ~rotationEvery = 4; ~setRotationOn.(true);
        ~layerAcidInst = \reeseHard; ~layerAcidAmp = 0.25; ~layerAcidOctave = 0;
        ~setAutoLayer.(true);
        "[sig:Q] NEUROFUNK -- reese rotation".postln;
    },
    // === T : HARDCORE GABBER -- saturation max, kick gabber ===
    'T': {
        ~humanizeOn = true; ~humanizeTiming = 0.0020;  // ultra-tight
        ~humanizeVelocity = 0.08; ~humanizeDetune = 0.01;
        ~rotPoolKick = [\kick, \kickGabber, \kick_gabber];
        ~rotationEvery = 4; ~setRotationOn.(true);
        ~layerMelodyInst = \hooverbass; ~layerMelodyAmp = 0.35;
        ~layerAcidInst = \growl; ~layerAcidAmp = 0.30;
        ~setAutoLayer.(true);
        "[sig:T] HARDCORE GABBER -- hoover + growl".postln;
    },
    // === V : GLITCH IDM -- detune fort, rotation rapide ===
    'V': {
        ~humanizeOn = true; ~humanizeTiming = 0.0080;  // glitch = jitter
        ~humanizeVelocity = 0.20; ~humanizeDetune = 0.10;
        ~rotationEvery = 2; ~setRotationOn.(true);  // change ultra-souvent
        ~layerMelodyInst = \fmBell; ~layerMelodyAmp = 0.20;
        ~layerHarmonyInst = \stab; ~layerHarmonyAmp = 0.20;
        ~setAutoLayer.(true);
        "[sig:V] GLITCH IDM -- fmBell + stab + rotation rapide".postln;
    },
    // === U : VOCAL TRANCE -- choir, vocal pad, doux ===
    'U': {
        ~humanizeOn = true; ~humanizeTiming = 0.0050;
        ~humanizeVelocity = 0.12; ~humanizeDetune = 0.04;
        ~rotationEvery = 16; ~setRotationOn.(true);
        ~layerMelodyInst = \choir; ~layerMelodyAmp = 0.35;
        ~layerHarmonyInst = \vocalPad; ~layerHarmonyAmp = 0.30;
        ~setAutoLayer.(true);
        "[sig:U] VOCAL TRANCE -- choir + vocalPad".postln;
    },
    // === R : SYNTHWAVE -- rhodes, vintage, slow swing ===
    'R': {
        ~humanizeOn = true; ~humanizeTiming = 0.0055;
        ~humanizeVelocity = 0.14; ~humanizeDetune = 0.04;
        ~rotPoolLead = [\lead, \squareLead, \organLead, \fmLead];
        ~rotationEvery = 12; ~setRotationOn.(true);
        ~layerMelodyInst = \rhodes; ~layerMelodyAmp = 0.32;
        ~layerHarmonyInst = \warmPad; ~layerHarmonyAmp = 0.25;
        ~setAutoLayer.(true);
        "[sig:R] SYNTHWAVE -- rhodes + warmPad vintage".postln;
    },
    // === S : DRONE DOOM -- low slow, drone + sub_boom ===
    'S': {
        ~humanizeOn = true; ~humanizeTiming = 0.0080;
        ~humanizeVelocity = 0.20; ~humanizeDetune = 0.08;
        ~rotationEvery = 64; ~setRotationOn.(true);  // change tres lent
        ~layerMelodyInst = \drone; ~layerMelodyAmp = 0.40; ~layerMelodyOctave = -1;
        ~layerAcidInst = \sub_boom; ~layerAcidAmp = 0.40; ~layerAcidOctave = -2;
        ~setAutoLayer.(true);
        "[sig:S] DRONE DOOM -- drone + sub_boom -2oct".postln;
    },
    // === F : TRANCE UPLIFTER -- supersaw, plein air ===
    'F': {
        ~humanizeOn = true; ~humanizeTiming = 0.0035;
        ~humanizeVelocity = 0.11; ~humanizeDetune = 0.03;
        ~rotPoolLead = [\lead, \supersaw, \fmLead, \squareLead];
        ~rotationEvery = 16; ~setRotationOn.(true);
        ~layerMelodyInst = \supersaw; ~layerMelodyAmp = 0.30;
        ~layerHarmonyInst = \pad; ~layerHarmonyAmp = 0.25;
        ~setAutoLayer.(true);
        "[sig:F] TRANCE UPLIFTER -- supersaw + pad".postln;
    },
);

~applyAlbumSig = { |letter|
    var sig = ~albumSigs[letter.asSymbol];
    if (sig.notNil) {
        sig.value;
        // Reapplique les Pdef avec les nouveaux Pfunc factories
        ~reload !? { ~reload.value };
    } {
        ("[sig] no signature for album " ++ letter ++ " - default humanize only").postln;
    }
};

// Wrap ~playAlbum pour appliquer la signature avant le lancement.
~playAlbum_orig = ~playAlbum_orig ?? ~playAlbum;
~playAlbum = { |letter, gap|
    ~applyAlbumSig.(letter);
    ~playAlbum_orig.(letter, gap);
};

"[album_signatures] loaded - 15 signatures (A H M G L P J I Q T V U R S F)".postln;
)
