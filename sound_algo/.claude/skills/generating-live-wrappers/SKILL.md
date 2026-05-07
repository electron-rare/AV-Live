---
name: generating-live-wrappers
description: Use when the user asks to "add a live wrapper", "expose dict X to live API", "ajouter une API live", or creates a new dict catalogue (`~newDict = ()`) that needs a live entry. Generates the dual API pattern used across the 5 sound_algo namespaces (`~kk`, `~mm`, `~ff`, `~cc`, `~p`): a dict for catalogue access AND env-direct wrappers for actual calls. Pseudo-method `~dict.key.(args)` is broken in SC (Event passes ~dict as 1st arg, real args lost — empirical bug on SC 3.14.1, see `live/melodies.scd`). Without env-direct wrappers, the live API is unusable.
---

# Generating live wrappers

## The problem this solves

```supercollider
// FAUX -- args lost, ~m passed as 1st arg
~m.short.(50)

// OK
~m[\short].(50)         // bracket notation
~mShort.(50)            // env-direct wrapper (PREFERRED)
~mm.(50)                // short alias
```

Toute API live exposée via dict DOIT avoir des wrappers env directs, sinon
les utilisateurs se retrouvent à taper de la bracket-notation lourdingue.

## Reserved-name collisions

Ces clefs explosent silencieusement à cause de méthodes Object/Server :

| Réservé | Renommer en |
| --- | --- |
| `.s` | `.short` |
| `.l` | `.long` |
| `.x` | `.xlong` |
| `.e` | `.epic` |
| `.r` | `.rnd` |
| `.p` | `.pat` |
| `.t` | `.tim` |
| `.next` | `.nx` |
| `.prev` | `.pv` |
| `.send` | `.snd` |
| `.set` | `.st` |
| `.tap` | `.tp` |
| `.value` | (interdit -- méthode Function) |

## Template (1 dict + N wrappers)

```supercollider
(
// --- Dict catalogue ----------------------------------------------
~<dict> = (
    \<key1>: { |arg1, arg2| /* impl */ },
    \<key2>: { |arg1| /* impl */ },
    \list:  { ~<dict>.keys.asArray.sort.do(_.postln) }
);

// --- Env-direct wrappers (API utilisateur primaire) -------------
~<dictPrefix><Key1>  = { |arg1, arg2| ~<dict>[\<key1>].(arg1, arg2) };
~<dictPrefix><Key2>  = { |arg1|       ~<dict>[\<key2>].(arg1) };
~<dictPrefix>List    = { ~<dict>[\list].() };

// --- Alias court (optionnel) -------------------------------------
~<short> = ~<dictPrefix><Key1>;       // ~mm = ~mShort, ~kk = ~kkTechno

"[OK] <dictPrefix> API ready".postln;
)
```

## Naming conventions

- **Dict** : `~<2-letter-name>` ou `~<short-word>` (ex: `~m`, `~kk`, `~ff`, `~ch`, `~p`)
- **Wrapper prefix** : same letters + Capitalized key (ex: `~mShort`, `~kkTechno`, `~fxDrop`, `~chIntro`, `~pHat`)
- **Short alias** : single 2-letter env var (ex: `~mm`, `~kk`, `~ff`, `~cc`)

## Mandatory invariants

| Rule | Why |
| --- | --- |
| Dict + env-direct wrappers (both) | Pseudo-method broken |
| Dict keys avoid reserved names | Crashes silently otherwise |
| Wrappers call `~dict[\key].()` not `~dict.key.()` | Same trap |
| Print `[OK] <name> API ready` at end | User sees confirmation |
| Wrapped in `(...)` single block | `.load` compatibility |
| Comment in French at top | Project convention |

## Concrete example (extracted from `live/melodies.scd`)

```supercollider
(
~m = (
    \short:  { |n| (~useMelody !? { ~useMelody.(("m"++n).asSymbol) }) ? nil },
    \long:   { |n| (~useMelody !? { ~useMelody.(("ml"++n).asSymbol) }) ? nil },
    \rnd:    { ~useMelodyRandom.value },
    \nx:     { ~melodyNext.value },
    \pv:     { ~melodyPrev.value }
);
~mShort = { |n| ~m[\short].(n) };
~mLong  = { |n| ~m[\long].(n) };
~mRnd   = { ~m[\rnd].() };
~mNx    = { ~m[\nx].() };
~mPv    = { ~m[\pv].() };
~mm     = ~mShort;            // alias court
"[OK] melody API ready".postln;
)
```

## After generation

1. Run `validating-scd-files` on the host file (P:0 B:0, TLB depends on file).
2. Add an example block in `01_live.scd` so users can discover the API.
3. Document the 5-namespace mapping at top of `live/CLAUDE.md` if a new
   namespace is introduced.

## Anti-patterns

- **Dict only, no env-direct wrappers** : forces users into bracket notation,
  breaks the `01_live.scd` cheat-sheet pattern.
- **Wrapper using `~dict.key.()`** : same bug it was meant to fix.
- **Reserved-name keys** : `.set`, `.send`, `.tap`, `.value`, `.s`, `.l`, ...
- **No `.list` key** : users can't discover available keys.
- **No `[OK] ... ready` log** : user can't tell if SETUP succeeded.
- **Wrapper that mutates global state without `~reload.value`** : Pdef stale.
