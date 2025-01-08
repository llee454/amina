Version: 2.1.0

Usage: amina.exe [options] --template=FILENAME

Amina is a modern templating language. It takes a text file, called a "template"
file, that contains "tags" and reads a JSON value from STDIN. The tags within
the template file contain JSON path expressions and Scheme expressions. Amina
evaluates these expressions and replaces the tags with values taken from the
JSON stream. You can use Amina to generate text files that report data taken
from a JSON stream.

Options
-------

  -h | --help
  Displays this message.

  -v | --version
  Displays the current version of Amina that has been installed.

  -t | --template FILENAME
  Tells Amina to read FILENAME and to replace the tags contained within it using
  the JSON data passed through STDIN.

  -d | --json FILENAME
  Tells Amina to read FILENAME instead of STDIN to get the JSON data that it
  will use to replace tags in the template file.

  -n | --no-json
  Tells Amina that you will not provide JSON data. Thus, Amina will not wait for
  input via STDIN, but will expand the given template file in an empty data
  context.

  -s | --init FILENAME
  Tells Amina to read FILENAME, which must contain valid Scheme code, and to
  evaluate it before processing data. Note: if you need to include
  Scheme files that are not included in the standard Guile search
  path, use the GUILE_LOAD_PATH environment variable.

  -w | --warn
  Tells Amina to print out warnings whenever it detects that you are
  doing something that may be a mistake. For example, whenever Amina
  references a null value in a data expression, it will print a
  warning to STDERR.

  -x | --debug
  Tells Amina to print out contexts and paths when evaluating
  expressions. You can use this option to debug templates, however it
  should not be enabled during production as this output will change
  over time.

Details
-------

Amina template files are normal text files that contain tags. Amina recognizes
two types of tags: scalar tags and section tags.

Scalar tags have the following syntax `{{TAGNAME: EXPR}}`. There are two types of
scalar tags: JSON path expression tags and Scheme expression tags.

JSON path expression tags have the following syntax: `{{data: EXPR}}` where
EXPR is a JSON path expression. When Amina encounters a path expression
tag, it will read the JSON value that passed to it and replace the tag with the
subvalue referenced by the expression.

Scheme expression tags have the following syntax: `{{expr: EXPR}}` where
EXPR is a Scheme expression. When Amina encounters these tags, it passes
EXPR to Guile Scheme, which evaluates the expression, and replaces the tag
with the result.

Include tags use the following syntax: `{{include:PATH}}` where `PATH` is a
file path. When `PATH` is a relative filepath, it is evaluated relative to
the directory in which Amina has been called. When Amina encounters this tag,
it loads the referenced file and replaces the tag with the file's content.

Section tags have the following syntax `{{#TAGNAME: EXPR}} CONTENT {{/TAGNAME}}`.
When Amina encounters a section tag it may do two things. First, it may create a
new "local context" based on EXPR. Second, it may duplicate, hide, or display
the textual content contained within the tag, CONTENT.

Currently, there are three section tags recognized by Amina.

The `each` tag takes a JSON path expression. When the path expression refers to
a JSON array, it expands CONTENT for every element within the array. For each
expansion, it sets the local JSON context to equal the associated JSON array
element.

For example: `{{#each:root.example_array}}Item {{data:local}}{{/each}}` will read
the JSON array "example_array" and, for each element of the array, print "Item: X",
where X is the associated array element.

If the JSON path expression does not refer to a JSON array, it sets the local
JSON context equal to the referenced JSON value and expands CONTENT once using
the JSON value.

The `each-expr` tag is similar to the `each` tag, but it takes a Scheme
expression instead of a JSON path expression. When the Scheme expression
evaluates to a Scheme list. It expands CONTENT for every list element and sets
the local context to equal the element.

For example: `{{#each-expr:(list 1 2 3)}}Item {{data:local}} {{/each-expr}}`
returns a string like: "Item 1 Item 2 Item 3 ".

If the JSON path expression does not evaluate to a list, it sets the local
context equal to the referenced JSON value and expands CONTENT once.

For example: `{{#each-expr:3.14159}}Item {{data:local}}{{/each-expr}}` returns a
string like: "Item 3.14159".

The `eval` tag is special. It tells Amina to expand its content and then
double back and expand the result again. This can be useful when you have
an Amina expression that generates Amina code.

For example, imagine that we call Amina with the following JSON and template
files. Amina will expand the example string and then double back to expand
the nested Amina expression.

```json
{
  "pi": 3.14159,
  "example": "PI equals {{data:root.pi}}"
}
```

```
{{#eval}}The following tag generates Amina code: {{data:root.example}}{{/eval}}
```

Amina's JSON path expressions use the following syntax:
`(root|local)(FIELD|INDEX)*` where FIELD represents a field reference and is a
simple string and INDEX is an array index having the form `[N]` (where N is an
integer).

For example: `root.example_array[0]` is a JSON path expression that references
the first element of the array stored in the field named "example_array".

Note that you can escape curly braces by using `\{`.

Scheme Functions
----------------

Amina defines a set of Scheme functions that can be used within Scheme
expression tags.

### get-data

`(get-data <path> [json])` accepts one string argument `<path>` that must
represent a JSON path expression and an optional argument `[json]` that must be
a JSON object; and returns the JSON value referenced by `<path>`. If `[json]` is
passed, local JSON path expressions will refer to `[json]`.

Examples:

```
{{expr:(get-data "root.authors[0].name")}}
```

```
{{expr:(get-data "local.name" (get-data "root.authors[0]"))}}
```

### num->string

`(num->string <number> [decimals])` accepts two arguments: `<number>` a
floating point number; and `[decimals]` and optional integer; and returns a
string that represents `<number>`. If `[decimals]` is given, the string will
display the given number of decimal point values. When appropriate, this
function will round the given number.

Example:

`(num->string 3.14159 2)`

### string->num

`(string->num <string>)` accepts one argument: `<string>` a string
that represents a real number such as "-1,234.59"; and returns it as a
Scheme real number. We recommend using this function instead of
Guile's built in `string->number` function.

Example:

`(string->num "-1,234.59")`

### call-with-local-context

`(call-with-local-context <function> <json>)` accepts two arguments:
`<function>` a function that does not accept any arguments; and `<json>` a JSON
object; sets the Local JSON context to equal `<json>` and calls `<function>` in
that context.

Example:

```lisp
(call-with-local-context
  (lambda () (get-data "local.email"))
  (get-data "root.authors[0]"))
```

### parse-path

`(parse-path <path>)` accepts a string argument `<path>` that must be a JSON
path expression and parses it.

Example: `(parse-path "root.authors[0].name")`

Examples
--------

* amina.exe --version
  Displays the current version of Amina.

* amina.exe --template=example.md < example.json
  Reads the file "example.json" file and replaces the tags contained in
  "example.md" using it.

* sqlite data.sqlite3 -init query.sql | amina.exe --template=example.md
  Executes a database query and passes the JSON formatted result to Amina.

Authors
-------

* Larry D. Lee Jr.