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
opam switch create . 5.1.0+options --no-install
eval $(opam env)
opam update
opam upgrade
opam install --deps-only . -y
dune build
dune runtest
dune exec src/main.exe
```

Once you have compiled Amina and tested any new changes you can install Amina to your local OPAM switch environment using:

```bash
dune install
```

Execution
---------

Use the following command fo execute the main script which outputs the results of the analysis:

```bash
amina.exe -- --template=TEMPLATE_FILE < JSON_FILE
```

This package includes examples for you to review. You can evaluate them using the following command line.

```bash
amina.exe -- --template=example.md < example.md
```

Details
-------

Amina template files are normal text files that contain tags. Amina recognizes
two types of tags: scalar tags and section tags.

Scalar tags have the following syntax `{TAGNAME: EXPR}`. There are two types of
scalar tags: JSON path expression tags and Scheme expression tags.

JSON path expression tags have the following syntax: `{data: EXPR}` where
EXPR is a JSON path expression. When Amina encounters a path expression
tag, it will read the JSON value that passed to it and replace the tag with the
subvalue referenced by the expression.

Scheme expression tags have the following syntax: `{expr: EXPR}` where
EXPR is a Scheme expression. When Amina encounters these tags, it passes
EXPR to Guile Scheme, which evaluates the expression, and replaces the tag
with the result.

Section tags have the following syntax `{#TAGNAME: EXPR} CONTENT {/TAGNAME}`.
When Amina encounters a section tag it may do two things. First, it may create a
new "local context" based on EXPR. Second, it may duplicate, hide, or display
the textual content contained within the tag, CONTENT.

Currently, there are two section tags recognized by Amina.

The `each` tag takes a JSON path expression. The path expression must refer to a
JSON array. It then expands CONTENT for every element within the array. For each
expansion, it sets the local JSON context to equal the associated JSON array
element.

For example: `{#each:root.example_array}Item {data:local}{/each}` will read the
JSON array "example_array" and, for each element of the array, print "Item: X",
where X is the associated array element.

The `each-expr` tag is similar to the `each` tag, but it takes a Scheme
expression instead of a JSON path expression. The Scheme expression has to
evaluate to a Scheme list. It expands CONTENT for every list element and sets
the local context to equal the element.

For example: `{#each-expr:(list 1 2 3)}Item {data:local} {/each-expr}` returns a
string like: "Item 1 Item 2 Item 3 ".

Amina's JSON path expressions use the following syntax:
`(root|local)(FIELD|INDEX)*` where FIELD represents a field reference and is a
simple string and INDEX is an array index having the form `[N]` (where N is an
integer).

For example: `root.example_array[0]` is a JSON path expression that references
the first element of the array stored in the field named "example_array".
