Ziel: MongoDB 5.0, 6.0, 7.0, 8.0 (und optional 8.2) laufen auf einem Intel Atom C2758 (Silvermont, SSE4.2/AES/PCLMUL, KEIN AVX/AVX2). Dazu je Version ein .deb fuer Ubuntu 24.04 (ubuntu2404/noble) und 26.04 (ubuntu2604/resolute) und ein Docker-Image auf Basis des offiziellen `mongo`-Images.

Repo: <DEIN-FORK> (Fork von mongodb/mongo mit allen Branches und Tags). Arbeite NUR in diesem Fork, nie in mongodb/mongo. Entwickle auf einem Branch pro Version, Branchnamen: `atom-c2758/5.0`, `atom-c2758/6.0`, `atom-c2758/7.0`, `atom-c2758/8.0`, `atom-c2758/8.2`, jeweils abgezweigt vom Tag unten. Kein PR, ausser ich sage es. Committe und pushe jeden Branch.

Ausgangstags (jeweils letzter Patch, vor Start per `git tag -l 'r5.0.*'` etc. gegenpruefen und bei neuerem Tag diesen nehmen):
- 5.0: r5.0.34 (SCons)
- 6.0: r6.0.29 (SCons)
- 7.0: r7.0.45 (SCons)
- 8.0: r8.0.34 (Bazel)
- 8.2: r8.2.12 (Bazel)

Ursache: Alle Tags bauen x86_64 mit `-march=sandybridge` (AVX) -> SIGILL auf C2758. 7.0 und 8.x haben zusaetzlich globales `-mavx2` in mozjs; dadurch gilt MOZILLA_PRESUME_AVX2 und die cpuid-Laufzeitpruefung wird umgangen. 5.0/6.0 haben kein AVX2 in mozjs.

Aenderungen pro Linie:

5.0 und 6.0 (SCons): Kein Quellpatch. Build-Flags: `--experimental-optimization=-sandybridge CCFLAGS="-march=silvermont -mtune=silvermont"`. Stelle sicher, dass der SConstruct-Default (nur wenn kein `-march=` in CCFLAGS/CFLAGS/CXXFLAGS) tatsaechlich nicht greift.

7.0 (SCons): Wie oben, zusaetzlich in `src/third_party/mozjs/SConscript` das `env.Append(CCFLAGS=['-mavx2'])` fuer x86_64 entfernen und in `extract/mozglue/misc/SIMD_avx2.cpp` AVX2 per Pragma nur fuer diese Datei aktivieren: nach den Includes `#pragma clang attribute push(__attribute__((target("avx2"))), apply_to = function)` bzw. fuer GCC `#pragma GCC push_options` + `#pragma GCC target("avx2")`, am Ende des AVX2-Zweigs (vor dem `#else` mit den Stubs) jeweils pop. Mit g++ und clang++ und `-march=silvermont` testkompilieren.

8.0 und 8.2 (Bazel):
- `bazel/toolchains/cc/mongo_linux/mongo_compiler_flags.bzl`: im `//bazel/config:linux_x86_64`-Zweig von MTUNE_MARCH_COPTS `-march=sandybridge -mtune=generic` durch `-march=silvermont -mtune=silvermont` ersetzen (ausser du findest die Toolchain-Feature-Variante aus master passend; Referenz: Commit auf Branch `claude/optimistic-dirac-a2j3x3` im Fork maltejk/mongo, Feature `x86_64_silvermont` + `--config=atom_c2758`).
- `src/third_party/mozjs/BUILD.bazel`: beide `-mavx2` (PLATFORM_COPTS und der select bei linux_x86_64/macos_x86_64) entfernen; Pragma in SIMD_avx2.cpp wie bei 7.0.
- Bazel-Version aus `.bazelversion` des jeweiligen Tags verwenden.

Packaging (alle Linien): `buildscripts/packager.py` kennt in 5.0/6.0/7.0 nur ubuntu2004/2204, in 8.0 nur bis ubuntu2404. Ergaenze `ubuntu2404` (noble) und `ubuntu2604` (resolute) an allen Stellen (Codename-Zuordnung, build_os-Listen). Pruefe 8.2 auf den Ist-Stand. Pruefe, ob debian/*.control, *.rules, postinst mit Ubuntu 24/26 funktionieren (systemd-Service, Abhaengigkeiten).

Skripte (aus Branch `claude/optimistic-dirac-a2j3x3` im Fork maltejk/mongo, Ordner `buildscripts/packaging/atom_c2758/`): `check_no_avx.sh`, `build_deb.sh`, `Dockerfile`, `build_image.sh`, README. Uebernehme sie pro Branch und passe an:
- SCons-Linien: statt `bazel build ... archive-dist-stripped` -> `python3 buildscripts/scons.py --release <Flags oben> archive-dist`; Tarball-Pfad entsprechend (5.0-7.0: `mongodb-dist.tgz` im Repo-Root laut evergreen/packager.py_run.sh, im Tag pruefen).
- Bazel-Linien: Target und Tarball-Pfad im Tag verifizieren (`archive-dist-stripped` existiert dort evtl. nicht).
- `check_no_avx.sh`: Funktionsnamen-Ausnahmen fuer mozjs gegen echte Binaries pruefen und ggf. korrigieren; Binaries von 5.0/6.0 haben keine AVX2-Ausnahme, dort darf gar kein VEX-Opcode vorkommen.
- Dockerfile: BASE_IMAGE je Linie `mongo:5.0`, `mongo:6.0`, `mongo:7.0`, `mongo:8.0`, `mongo:8.2`. Pruefe pro Image, dass mongod/mongos wirklich unter `/usr/bin` liegen, und passe die COPY-Pfade an. Tarball-Entpackung (`--strip-components`) gegen das reale Layout pruefen.

Toolchain-Hinweis: 5.0/6.0 sind fuer alte GCC/Python-Requirements gebaut. Auf Ubuntu 24/26 mit GCC 13+/Python 3.12 sind Compile-/pip-Fehler wahrscheinlich. Baue in einem Container mit passender Ubuntu-20.04/22.04-Basis; die fertigen Binaries muessen danach auf 24.04/26.04 laufen (glibc-Kompatibilitaet pruefen mit `objdump -T | grep GLIBC_`). Dokumentiere den verwendeten Build-Container (Dockerfile) im Branch.

Build-Umgebung: Ein C2758 ist zum Bauen zu schwach; baue auf einem AVX-faehigen x86_64-Host. Wenn in dieser Sandbox ein vollstaendiger Build nicht moeglich ist (Zeit, Platte, Netz), sage das explizit und liefere die Patches, Skripte und exakten Build-Befehle, behaupte aber nie Erfolg ohne tatsaechlich gelaufenen Build.

Verifikation pro Linie (nur berichten, was wirklich lief):
1. Patches angewendet, Syntax/Analyse ok (`bazel build --nobuild` bzw. `scons --help`/Dry-Run).
2. Build erfolgreich, `check_no_avx.sh` gruen.
3. .deb fuer ubuntu2404 und ubuntu2604 erzeugt (`dpkg-deb -I`, Architektur amd64).
4. Docker-Image gebaut; `docker run <image> mongod --version`.
5. Echter Lauftest auf C2758 kann nur ich machen; liste die Befehle, die ich dort ausfuehren soll (`mongod --version`, `grep -o -w avx /proc/cpuinfo` muss leer sein, kurzer Insert/Find-Test).

Abschlussbericht: Tabelle Version x (Patch angewendet / gebaut / deb 24.04 / deb 26.04 / Image / getestet) mit ehrlichem Status, plus offene Punkte.
