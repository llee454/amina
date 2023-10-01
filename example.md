<center><h1>Amina Example</h1></center>
<center>Larry D. Lee Jr.</center>
<center>September 30, 2023</center>

## Introduction

Amina is a modern templating language. It takes a JSON file and a text file, called a "template file," that contains tags and replaces these tags with values either drawn from the JSON file or calculated.

Amina's syntax is similar to Mustache's. There are three types of tags: scalar tags and section tags. Scalar tags contain either JSON path expressions such as: `\{data:root.example_array[1]}`; or Scheme expressions such as `\{expr:(* 3 7)}`. When Amina encounters a JSON path expression, it reads the JSON file, finds the JSON value referenced by the path expression, and replaces the tag with the JSON value. When Amina encounters a Scheme expression, it calls Guile, a Scheme interpreter, evaluates the expression, and replaces the tag with the calculated value.

JSON path expressions have the following syntax:

```
<path> := <base>(<field>|<index>)*
<base> := "root" | "local"
<field> := "." <field name>
<index> := "[" <integer> "]"
```

For example: `root.example_array[0]` is a valid JSON path expression. Every path expression starts with a "base" reference. As Amina scans the template file it maintains two JSON values. "Root" is the JSON value represented by the JSON file. "Local" refers to the JSON value associated with the current section. When Amina encounters tags, such as the `#each:<path>` tag it will find the JSON value referenced by `<path>` and will set local to refer to the value or, if the value is an array, the value's elements.

The remaining elements of the path are either field references or array indices. If you have a JSON object `.<field name>` will reference the named field. If you have an array `[n]` will refer to the n-th element. So, the example given above tells Amina to take the root JSON value, find the field named "example_array," and return its first element.

I've touched on sections. Sections have the form: `\{#tag:<expression>}<content>\{/tag}`. These tags have two effects. First, they define a "local context," Amina will evaluate `<expression>` and assign the local JSON value to the result. All JSON path references to "local" will refer to either this JSON value or, if its an array, one of its elements. Secondly, if the result is an array value, Amina may duplicate `<content>` for each element in the array.

### Motivation

I wrote Amina to help me generate and maintain scientific reports. I found myself having to calculate and report on a large number of numbers. I would write code to generate these numbers, however, occasionally I would find a bug or have a new updated dataset. Manually hunting down and updating all of the numbers contained in a report is tedious and error prone. So, I switched to using Mustache instead. Mustache allowed me to insert variables that reference numbers instead of numbers themselves. If I then updated the numbers, the Mustache would automatically detect the update and insert the correct values. This approach reduced the tedium of maintaining reports and reduced errors. Additionally, it boosted accountability as I could trace the origin of every number contained in my reports.

Over time however, I grew frustrated with Mustache's limited syntax. Hence Amina was born. You can use Amina for similar use cases.

## Examples

This file is an example template. It contains Markdown interspersed with Amina tags.  You can pass this file to Amina along with its accompanying JSON file and it will return a new file in which the tags have been evaluated and replaced.

### Data Reference Example

For example, Amina will replace the following tag with the value of the root JSON value, which will equal the JSON file's JSON value.

```json
{data:root}
```

As shown above, you can reference specific values within the root JSON value by adding additional field and array indices. For example: `{data:root.example_array[0].message}`.

### Scheme Expression Example

You can execute arbitrary Scheme expressions in your template file. Amina will evaluate these expressions and replace the tags with the resulting values. Additionally, Amina defines a function named `get-data <path>` that accepts a JSON path expression in a Scheme string and returns the referenced data. So, for example, the following scheme expression tag is equivalent to our previous JSON path expression tag.

```
{expr:(get-data "root.example_array[0].message")}
```

Of course, you can call all of the functions that Guile defines. For example, Amina will read the message referenced in the previous example, but uppercase it using Schemes' uppercase function.

```
{expr:(string-upcase (get-data "root.example_array[0].message"))}
```

### Each Path Expression Section Example

Often, we want to display some snippet of text for each element of an array. For example, In markdown, we can easily represent tables using text. However, doing so requires us to wrap the values in each row within vertical pipe characters. The following example, shows how we can do this in Amina:

| Name | Message |
| ---- | ------- |
{#each:root.example_array}| {data:local.name} | {data:local.message} |
{/each}

### Each Scheme Expression Section Example

Amina lets you define your own local contexts using Scheme. For example, the following example uses scheme to create a list of values and then inserts them into the nested template.

| ID | Name | Message |
| -- | ---- | ------- |
{#each-expr:
  (list
    (list 1 "first" "this is the first")
    (list 2 "second" "this is another"))
}| {data:local[0]} | {data:local[1]} | {data:local[2]} |
{/each-expr}

You can use this feature to print sorted, filtered, and otherwise transformed lists.

| ID | Name | Income | Notes |
| -- | ---- | ------ | ----- |
{#each-expr:
  (use-modules (ice-9 format))
  (sort
    (list
      (list 1 "first" 234.12 "this is the first")
      (list 2 "second" 1532.34 "this is another"))
    (lambda (x y) (> (list-ref x 2) (list-ref y 2))))
}| {data:local[0]} | {data:local[1]} | {expr:(float-to-string (get-data "local[2]") 2)} | {data:local[3]} |
{/each-expr}

### Integrating with SQLite

Most databases support JSON exports. For example, SQLite can be used to generate JSON strings as follows:

```bash
sqlite3 data.sqlite "SELECT JSON_GROUP_ARRAY (JSON_OBJECT ('name', name_hash, 'age', age)) FROM (SELECT * FROM thd LIMIT 10)" > data.json;

amina --json=data.json template.md
```

You can use this feature to generate reports from data stored in databases using Amina. 

## Conclusion

