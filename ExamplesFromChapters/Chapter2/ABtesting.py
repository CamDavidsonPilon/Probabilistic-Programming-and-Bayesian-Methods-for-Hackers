"""
This is an example of using Bayesian A/B testing

"""

import pymc as mc

#these two quantities are unknown to us.
true_p_A = 0.05 
true_p_B = 0.04

#notice the unequal sample sizes -- no problem in Bayesian analysis.
N_A = 1500
N_B = 1000 

#generate data
observations_A = mc.rbernoulli( true_p_A, N_A )
observations_B = mc.rbernoulli( true_p_B, N_B )



#set up the pymc model. Again assume Uniform priors for p_A and p_B

p_A = mc.Uniform("p_A", 0, 1)
p_B = mc.Uniform("p_B", 0, 1)


#define the deterministic delta function. This is our unknown of interest.

@mc.deterministic
def delta( p_A = p_A, p_B = p_B ):
    return p_A - p_B


#set of observations, in this case we have two observation datasets. 
obs_A = mc.Bernoulli( "obs_A", p_A, value = observations_A, observed = True )
obs_B = mc.Bernoulli( "obs_B", p_B, value = observations_B, observed = True )

#to be explained in chapter 3. 
mcmc = mc.MCMC( [p_A, p_B, delta, obs_A, obs_B] )
mcmc.sample( 20000, 1000)