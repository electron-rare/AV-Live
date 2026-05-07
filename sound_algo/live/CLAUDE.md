# live/ — API live performance

Helpers pour mixer, FX, scenes, loops, tweaks, melodies live.
Charges via `00_load.scd` puis SETUP bloc par bloc.

## Notation d'appel (CRITIQUE)

SuperCollider Event pseudo-method ne passe PAS les args :

```supercollider
~m.short.(50)         // FAUX : ~m est passe comme 1er arg, 50 perdu
~m[\short].(50)       // OK : notation indexee
~mShort.(50)          // OK : variable env directe (alias prefere)
~mm.(50)              // OK : alias court
```

Toute API exposee via `~xxx` doit avoir un wrapper env direct,
pas seulement une cle dans un dict.

## Patterns

- Chaque module expose un dict catalogue (`~m`, `~fx`, `~ch`, ...)
  ET des wrappers env directs (`~mShort`, `~fxRev`, ...).
- SETUP en commentaire en haut du fichier, exemples en bas.
- VCF/FX inserent via `ReplaceOut.ar(busIn, ...)` (chain in-place).
- Sidechain : duck = `1 - (In.kr(scBus, 1) * scAmt)`.

## 5 namespaces (cf `01_live.scd`)

| Dict | Wrappers directs | Domaine |
| --- | --- | --- |
| `~kk.(\genre)` | `~kPat`, `~kTim`, `~kList` | Kicks (techno/gabber/dub/...) |
| `~mm.(N)` | `~mLong`, `~mXlong`, `~mEpic`, `~mRnd`, `~mGen`, `~mNx`, `~mPv`, `~mInst`, `~mHarm`, `~mAmp`, `~mCut`, `~mDrive`, `~mOff` | Melodies |
| `~ff.(\preset)` | `~fxSnd`, `~fxSt`, `~fxFreeze`, `~fxDrop`, `~fxBreakdown`, `~fxBuildup`, `~fxGlitch`, `~fxStutter`, `~fxVcfOn`, `~fxLfo`, `~fxCut`, `~fxRq`, `~fxDrive`, `~fxComp`, `~fxSat` | FX presets + tricks |
| `~cc` | `~chIntro`, `~chDrop`, `~chBreakdown`, `~chBuildup`, `~chTechno`, `~chDnb`, `~chOutroFade`, `~chStop` | Chains/sequences |
| `~p` | `~pKit`, `~pGenre`, `~pHat`, `~pSnare`, `~pClap`, `~pPerc`, `~pList` | Patterns rythmiques |

Mixer : `~setVol`, `~mute`, `~solo`, `~mixPreset`, `~saveMix`, `~masterVol`, `~masterFade`.
LFO/VCF : `~lfoTo`, `~vcfOn`. Loops : `~loopOn`. Scenes : `~saveScene`, `~loadScene`.

## Convention de renommage (clefs courtes = collisions Object/Server)

Noms reserves SC (`s`=Server, `next`/`prev`/`set`/`send`/`tap`/`p`/`t`/`e`/`l`)
plantent comme cles d'Event. Renommages internes :

| Ancien | Nouveau |
| --- | --- |
| `.p` | `.pat` |
| `.t` | `.tim` |
| `.s` | `.short` |
| `.l` | `.long` |
| `.x` | `.xlong` |
| `.e` | `.epic` |
| `.r` | `.rnd` |
| `.next` / `.prev` | `.nx` / `.pv` |
| `.send` / `.set` / `.tap` | `.snd` / `.st` / `.tp` |

## Anti-patterns

- Ne pas appeler `~dict.key.(args)` -- les args sont avales
- Ne pas oublier le wrapper env direct (`~mShort`) en plus de la cle
- Ne pas charger live/*.scd avant `engine.scd` + `fx_bus.scd`
- Ne pas mute un `~xxx` sans `~reload.value` si lie a un Pdef
