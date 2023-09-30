This is a test expression {expr: (* 3 7)}.
Here's a data reference {data:root.example_array[1]}.
Here's a section:
{#each:root.example_array}
  Name: {data:local.name}
  Message: {data:local.message}
{/each}
It works! See?"
Note that currently whitespaces are not allowed. And, if you get an out of input error its probably because you opened a section tag without closing it.