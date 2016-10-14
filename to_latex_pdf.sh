find Prologue Chapter* -name "*.ipynb" | grep -v "PyMC2" | xargs ipython3 nbconvert --to pdf --template article

# merge all files:
pdfjoin Prologue.pdf Ch*.pdf DontOverfit.pdf MachineLearning.pdf
