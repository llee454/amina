README
======

Amina is a modern templating language. Inspired by Mustache it reads a
JSON file, scans a text file for tags that contain either JSON path or
Scheme expressions, and replaces the tags with the values referenced
by the path expressions or the strings returned by the Scheme
expressions.

Initializing the Build Environment
----------------------------------

Note: the following are a hack solution to fix the fact that brew and opam are
out of sync and opam's owl-plplot library requires library versions that can no
longer be installed with brew.

```
opam switch create . 5.0.0+options --no-install
opam update
opam install --deps-only . -y
dune build
dune exec src/main.exe
dune exec src/test.exe
```

If you encounter issues with LibFFI or OpenBLAS, use something like the following:
```
opam reinstall conf-libffi
PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/Cellar/openblas/0.3.17/lib/pkgconfig/ opam reinstall conf-openblas
```

Execution
---------

Use the following command fo execute the main script which outputs the results of the analysis:

```
dune exec src/main.exe
```

Generate Report
---------------

To perform an end-to-end build (which will call the analysis script and update the final report) run:

```
dune build
```