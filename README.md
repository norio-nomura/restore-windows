# Restore Windows

Restore windows on launching [Atom](http://atom.io).

## What is this?
Atom identifies *window* by *project's path* `atom.project.getPath()` and remembers every opened *project*'s states including *window*. **But Atom does not remember which *projects* were opened on quitting.**

This package remembers and opens them on launching instead of Atom.

## Installation

```sh
apm install restore-windows
```

Alternatively open `Preferences -> Packages` and search for `Restore Windows`.

## How does work this?
Atom loads packages to each of *windows* on every opening as their own instances. But `atom.config` is not usable for saving information from multiple instances in same time on closing *windows* by quitting Atom.

Instead of using `atom.config`, this package use following files:

- **opened directory** (`~/.atom/restore-windows/opened/`)

 Each instance save a file containing their *project path* on loading and remove it on `beforeunload`.

- **may be restored directory** (`~/.atom/restore-windows/mayBeRestored/`)

 Every instance save a file containing their *project path* on `beforeunload`.

This package restore *windows* as following steps:

1. If **opened directory** is not empty, another instance of Atom window is exists. Stop restoring.
2. Collect *project path* and *timestamp* from **may be restored directory**.  If *timestamp* is **near past (default: 5sec)** from latest, *project* should be opened.
3. Remove files from **may be restored directory** on enumeration.
4. Call `atom.open()` passing *project paths* for openeing windows.
5. Atom will restore all windows state on openeing it.

## License
MIT
