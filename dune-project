(lang dune 2.9)
(name amina)
(license GPL-3.0)
(authors "Larry D. Lee Jr. <llee454@gmail.com>")
(maintainers "Larry D. Lee Jr. <llee454@gmail.com>")
(source (github llee454/amina))
(version 2.1.0)
(use_standard_c_and_cxx_flags true)
(generate_opam_files)
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
 (depends
  ocaml-lsp-server
  ocamlformat
  ppx_jane
  ppx_blob
  core
  lwt
  lwt_ppx
  yojson
  ppx_deriving_yojson
  getopt
  angstrom
  conf-guile
 )
)