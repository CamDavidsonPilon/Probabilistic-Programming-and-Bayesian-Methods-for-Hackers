
import pymc as mc


data = np.loadtxt( "../../Chapter3_MCMC/data/mixture_data.csv",  delimiter="," )


p = mc.Uniform( "p", 0, 1)

assignment = mc.Categorical("assignment", [p, 1-p], size = data.shape[0] ) 

taus = 1.0/mc.Uniform( "stds", 0, 100, size= 2)**2 #notice the size!
centers = mc.Normal( "centers", [150, 150], [0.001, 0.001], size =2 )

"""
The below determinsitic functions map a assingment, in this case 0 or 1,
to a set of parameters, located in the (1,2) arrays `taus` and `centers.`
"""

@mc.deterministic 
def center_i( assignment = assignment, centers = centers ):
        return centers[ assignment] 

@mc.deterministic
def tau_i( assignment = assignment, taus = taus ):
        return taus[ assignment] 

#and to combine it with the observations:
observations = mc.Normal( "obs", center_i, tau_i, value = data, observed = True )

#below we create a model class
model = mc.Model( [p, assignment, taus, centers ] )


map_ = mc.MAP( model )
map_.fit()
mcmc = mc.MCMC( model )
mcmc.sample( 100000, 50000 )