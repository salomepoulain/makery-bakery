# makery-bakery

A make-based kitchen that hires Stations into a project to set up its development environment and expose its tasks.

## Language

### Where stations come from

**Registry**:
The place `bake` hires Stations from: a collection of `stations/<name>/` folders. A Registry is either online or offline.
_Avoid_: Store, Larder, agency

**Online registry**:
A Registry hosted on GitHub, reached over the network. The default is `salomepoulain/makery-stations`.

**Offline registry**:
A Registry that lives on disk at `~/.makery-bakery/stations/`, so hiring needs no network.
_Avoid_: Local store, cache

### Going offline

**Offline bake**:
A `bake` binary built to never touch the network. It hires only from the Offline registry and refuses commands that need GitHub.
_Avoid_: Safe bake, secure bake

**Safe** (verb):
To copy a Station from the Online registry into the Offline registry after checking that it doesn't reach the network. Done with `bake safe <name>`.
_Avoid_: Secure, stock, pack
