import pymc as mc

p = mc.Uniform( "freq_cheating", 0, 1) 

@mc.deterministic
def p_skewed( p =  p ):
    return 0.5*p + 0.25
    
yes_responses = mc.Binomial( "number_cheaters", 100, p_skewed, value = 35, observed = True )
                                
model = mc.Model( [yes_responses, p_skewed, p ] )

### To Be Explained in Chapter 3!
mcmc = mc.MCMC(model)
mcmc.sample( 50000, 25000 )
