#!/bin/bash

cat <<EOS
[po_directory] po
[options] \\
  --master-charset UTF-8 \\
  --localized-charset UTF-8 \\
  --addendum-charset UTF-8 \\
  --master-language en \\
  --package-name github.com/Marwes/combine/wiki
EOS

for f in original/*.md
do
  cat <<EOS
[type:text] \\
  $f ja:translation/${f#original/} \\
  opt:"--option markdown --keep 0"
EOS
done
