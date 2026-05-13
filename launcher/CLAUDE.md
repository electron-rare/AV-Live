# launcher — AVLiveLauncher

App menubar macOS (SwiftUI, SwiftPM, macOS 11+) qui démarre/arrête `sclang+scsynth`, le serveur web et `oscope-of`, log les sorties, et expose un mode picker.

## Build

```bash
cd launcher
./build.sh                            # script standard
# ou manuellement :
swift build -c release
.build/release/AVLiveLauncher
```

Cible : **macOS 11+**, Swift 5.7+. Package Swift, pas de Xcode project requis.

## Modules

| Fichier | Rôle |
|---------|------|
| `AVLiveLauncherApp.swift` | `@main`, scene menubar, app lifecycle |
| `MenuBarContent.swift` | UI du menu (start/stop, état des process) |
| `ModePickerWindow.swift` | Fenêtre picker de mode (data-only vs full vs ...) |
| `ProcessManager.swift` | Spawn / kill / monitor des process enfants |
| `OSCSender.swift` | Envoi OSC (typiquement vers `:57121` sclang, `:57123` oscope) |
| `LogView.swift` | UI live des logs stdout/stderr des process |
| `AV-Live-Body/` | Ressources / modèles annexes (body mesh assets) |

## Conventions

- Toute opération asynchrone : `Task { @MainActor in ... }` pour UI updates.
- Pas de bloc `DispatchQueue.main.sync` (deadlock garanti depuis MainActor).
- `ProcessManager` est `@MainActor` — interactions process via async/await, jamais `Process.waitUntilExit()` bloquant en main.
- Chemins absolus vers les binaires (sclang, node, oscope-of) résolus une fois au startup et stockés ; ne pas redécouvrir à chaque démarrage.
- Logs ring-buffer borné (pas de croissance illimitée dans `LogView`).

## Anti-patterns

- Ne pas committer `build/` ni `.build/`.
- Ne pas hardcoder un chemin utilisateur (`/Users/electron/...`) — passer par `FileManager` + chemins relatifs au repo ou bookmarks.
- Ne pas mélanger `Process.terminate()` et `kill -9` sans escalade (SIGTERM → wait → SIGKILL).
- Pas d'AppKit `NSApp.terminate` direct depuis un closure background — toujours hop sur MainActor.
- Ne pas dépendre d'un Xcode project : le SwiftPM `Package.swift` est la source de vérité.
