#!/bin/bash
# builds a pdf version of the book, requires a latex distribution and pdf toolkit

# get an ordered array of dirs ("prologue can be added in before the chapters once it's possible to build it")
dirs="$(ls -d Chapter*)"
dirs=(${dirs//\\n/})

# get an array of notebook files based on the ordered dirs array
notes=()
for i in "${dirs[@]}"
    do notes=("${notes[@]}" $(find "$i" -regex '.*\.ipynb'))
done

# build the notebook files
for i in "${notes[@]}"
    do ipython nbconvert $i --to pdf
done

# make a list of the pdfs
pdfs=()
for i in ${notes[@]}
    do pdfs=( ${pdfs[@]} $(echo "$i" | sed 's/.*\///; s/ipynb/pdf/') )
done

# concatenate everything into a single pdf
pdftk ${pdfs[@]} cat output book.pdf

# remove intermediates
rm -f ${pdfs[@]}
