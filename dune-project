(lang dune 2.7)
(name amina)
(license GPL-3.0)
(authors "Larry D. Lee Jr. <llee454@gmail.com>")
(source (uri https://github.com/llee454/amina))
(version 0.5.0)
(package
 (name amina)
 (synopsis "Amina is a modern template program")
 (description "
  Amina is a modern templating language. It takes a text file, called a \"template\"
  file, that contains \"tags\" and reads a JSON value from STDIN. The tags within
  the template file contain JSON path expressions and Scheme expressions. Amina
  evaluates these expressions and replaces the tags with values taken from the
  JSON stream. You can use Amina to generate text files that report data taken
  from a JSON stream.
  ")
 )