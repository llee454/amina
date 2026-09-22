Guile Scheme Extension
======================

This package defines a Guile Scheme extension that exposes some of the
functions defined by Amina, such as the JSON parser.

The Guile extension is a shared object file named `guile_amina.so`. 

Compiling
---------

A Guile Scheme extension is a standard shared object file (guile_amina.so
in Linux). To compile this shared object file, simply run `dune` from the
this project's root directory.

```bash
opam switch create . 5.3.0+options --no-install
eval $(opam env)
opam update
opam upgrade
dune build amina.opam # to generate OPAM package file
opam install --deps-only . -y

# compile the extension and other libraries.
dune build
```

By default, `dune` will generate the shared object in
`_build/default/guile/guile_amina.so`. It will then promote this file into
the `guile` source directory.

When you rune `dune clean`, Dune will delete this file. To use this extension,
copy it into your Guile program's extension folder. For example, on my
(unconventional) machine:
`cp guile/guile_amina.so /usr/local/guile-3.0.10/lib/guile/3.0/extensions/`

Using the Extension
-------------------

To use this extension, you can load the shared object using the
`load-extension` function in Guile Scheme. For example:

```bash
$ GUILE_EXTENSIONS_PATH='/usr/lib/x86_64-linux-gnu:guile' GUILE_LOAD_PATH='./guile' rlwrap guile
> (use-modules ((amina) #:prefix amina:))
```

alternately you can use the R6RS import syntax

```scheme
(import (prefix (amina) amina:))
```

You may now call functions defined in this module, for example:

```scheme
(import (prefix (amina) amina:))
(amina:get-data "local.pi" (amina:parse-json "{pi: 3.14159}"))
```

You can also pass a load path to Guile in Guile:

```
> (add-to-load-path "./guile")
```

Overview and Structure
----------------------

The Guile Amina is a Guile package. Guile packages consist of Scheme files
and extensions. When installed the Scheme files should be copied to Guile's
site directory (/usr/share/guile/site/3.0) and the extensions should be
installed in the extensions directory.

The Guile Amina extension is a shared object file named
guile/guile_amina.so. It defines a set of Scheme procedures that represent
the functions provided by Amina. You can call all of the Scheme functions 
that Amina provides through its template language. However, the extension
provides an additional function

```
(rewrite-string str)
```
