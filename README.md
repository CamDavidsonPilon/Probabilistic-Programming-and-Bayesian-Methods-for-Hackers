Bayesian Methods for Hackers
---------

Bayesian method is the natural approach to inference, yet it is hidden from readers behind chapters of slow, mathematical, analysis. The 
typical text on Bayesian inference involves two to three chapters on probabity theory, then enters what Bayesian inference is. Unfortunately, 
due to mathematical intractibility of most Bayesian models, the reader is only shown simple, artificial examples. This can leave the user with a
"so-what" feeling about Bayesian inference. In fact, this was the author's own prior opinion. 

After some recent success of Bayesian methods in machine-learning competitions, I decided to investigate the subject again. Even with my mathematical 
background, it took me three straight-days of reading examples and trying to put the pieces together to understand how the method works so well. That
being said, I suffered then so the reader would not have to now. The problem with my misunderstanding was the disconnect between Bayesian mathematics and 
probablistic programming. This book attempts to bridge the gap.  


If Bayesian inference is the destination, then mathematical analysis is a path to it. On the other hand, computing power is cheap enough
that we can afford to take an alternate route via probablistic programming. The path is much more useful, as it denies the necessity of 
mathematical interventation at each step, that is, we remove often-intracible mathematical analysis as a 
prequsite to Bayesian inference. Simpley put, this path proceeds via small intermediate *jumps* from beginning to end, where as 
the first path proceeds by enourmous leaps, often landing far away from our target. Furthermore, with a tuned-mathematical background, 
the analysis required by the first path cannot even take place.


*Bayesian Methods for Hackers* is designed as a introduction to Bayesian methods and inference from an understand-first, computational-second, and 
mathematical-third, point of view. Of course as an introductory book without the mathematical rigour, we can only leave it at that: an introductory book.
For the mathematical inclined, they may supplement this text with other texts designed with mathematics in mind. For the programmer with less 
mathematical-background, or one who is not interested in the mathematics but simpely the practice of Bayesian methods, this text should be sufficient. 


The choice of [PyMC](http://pymc-devs.github.com/pymc/) as the probabilistic programming language is two-fold. As of this writing, there is currently
no central resource for examples and explaination in the PyMC universe. The official documentation assumes prior knowledge of Bayesian inference
and probabilistic programming. We hope this book encourages users at every level to look at PyMC. Secondly, with recent core developments and popularity of the scientific stack in Python, PyMC is likely to become a core
component of the stack.

PyMC does have some dependencies to run, namely NumPy and SciPy. To not limit the user, the examples in this book will
rely only on PyMC, NumPy and SciPy. 