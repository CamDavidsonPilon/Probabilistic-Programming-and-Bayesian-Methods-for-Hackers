import numpy as np
import pymc as pm


data = np.loadtxt("../../Chapter3_MCMC/data/mixture_data.csv",  delimiter=",")


p = pm.Uniform("p", 0, 1)

assignment = pm.Categorical("assignment", [p, 1 - p], size=data.shape[0])

taus = 1.0 / pm.Uniform("stds", 0, 100, size=2) ** 2  # notice the size!
centers = pm.Normal("centers", [150, 150], [0.001, 0.001], size=2)

"""
The below deterministic functions map a assingment, in this case 0 or 1,
to a set of parameters, located in the (1,2) arrays `taus` and `centers.`
"""


@pm.deterministic
def center_i(assignment=assignment, centers=centers):
        return centers[assignment]


@pm.deterministic
def tau_i(assignment=assignment, taus=taus):
        return taus[assignment]

# and to combine it with the observations:
observations = pm.Normal("obs", center_i, tau_i,
                         value=data, observed=True)

# below we create a model class
model = pm.Model([p, assignment, taus, centers])


map_ = pm.MAP(model)
map_.fit()
mcmc = pm.MCMC(model)
mcmc.sample(100000, 50000)
