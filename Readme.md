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

```bash
opam switch create . 5.0.0+options --no-install
opam update
opam install --deps-only . -y
dune build
dune exec src/main.exe
```

Execution
---------

Use the following command fo execute the main script which outputs the results of the analysis:

```bash
dune exec src/main.exe -- --json=DATA_FILE TEMPLATE_FILE
```

This package includes examples for you to review. You can evaluate them using the following command line.

```bash
dune exec src/main.exe -- --json=example.json example.md
```
