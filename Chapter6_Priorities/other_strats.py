#other strats.
# TODO: UBC strat, epsilon-greedy

import scipy.stats as stats
import numpy as np
from pymc import rbeta

rand = np.random.rand
beta = stats.beta


class GeneralBanditStrat( object ):	

    """
    Implements a online, learning strategy to solve
    the Multi-Armed Bandit problem.
    
    parameters:
        bandits: a Bandit class with .pull method
		choice_function: accepts a self argument (which gives access to all the variables), and 
						returns and int between 0 and n-1
    methods:
        sample_bandits(n): sample and train on n pulls.

    attributes:
        N: the cumulative number of samples
        choices: the historical choices as a (N,) array
        bb_score: the historical score as a (N,) array

    """
    
    def __init__(self, bandits, choice_function):
        
        self.bandits = bandits
        n_bandits = len( self.bandits )
        self.wins = np.zeros( n_bandits )
        self.trials = np.zeros(n_bandits )
        self.N = 0
        self.choices = []
        self.score = []
        self.choice_function = choice_function

    def sample_bandits( self, n=1 ):
        
        score = np.zeros( n )
        choices = np.zeros( n )
        
        for k in range(n):
            #sample from the bandits's priors, and select the largest sample
            choice = self.choice_function(self)
            
            #sample the chosen bandit
            result = self.bandits.pull( choice )
            
            #update priors and score
            self.wins[ choice ] += result
            self.trials[ choice ] += 1
            score[ k ] = result 
            self.N += 1
            choices[ k ] = choice
            
        self.score = np.r_[ self.score, score ]
        self.choices = np.r_[ self.choices, choices ]
        return 
        
	
def bayesian_bandit_choice(self):
	return np.argmax( rbeta( 1 + self.wins, 1 + self.trials - self.wins) )
    
def max_mean( self ):
    """pick the bandit with the current best observed proportion of winning """
    return np.argmax( self.wins / ( self.trials +1 ) )

def lower_credible_choice( self ):
    """pick the bandit with the best LOWER BOUND. See chapter 5"""
    def lb(a,b):
        return a/(a+b) - 1.65*np.sqrt( (a*b)/( (a+b)**2*(a+b+1) ) )
    a = self.wins + 1
    b = self.trials - self.wins + 1
    return np.argmax( lb(a,b) )
    
def upper_credible_choice( self ):
    """pick the bandit with the best LOWER BOUND. See chapter 5"""
    def lb(a,b):
        return a/(a+b) + 1.65*np.sqrt( (a*b)/( (a+b)**2*(a+b+1) ) )
    a = self.wins + 1
    b = self.trials - self.wins + 1
    return np.argmax( lb(a,b) )
    
def random_choice( self):
    return np.random.randint( 0, len( self.wins ) )
    
    
def ucb_bayes( self ):
	C = 0
	n = 10000
	alpha =1 - 1./( (self.N+1) )
	return np.argmax( beta.ppf( alpha,
							   1 + self.wins, 
							   1 + self.trials - self.wins ) )
							   
	
	
	
class Bandits(object):
    """
    This class represents N bandits machines.

    parameters:
        p_array: a (n,) Numpy array of probabilities >0, <1.

    methods:
        pull( i ): return the results, 0 or 1, of pulling 
                   the ith bandit.
    """
    def __init__(self, p_array):
        self.p = p_array
        self.optimal = np.argmax(p_array)
        
    def pull( self, i ):
        #i is which arm to pull
        return rand() < self.p[i]
    
    def __len__(self):
        return len(self.p)
