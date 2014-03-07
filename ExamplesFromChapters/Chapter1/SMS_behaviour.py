import pymc as pm
import numpy as np

count_data = np.loadtxt("../../Chapter1_Introduction/data/txtdata.csv")
n_count_data = len(count_data)

alpha = 1.0 / count_data.mean()  # recall count_data is
                                 # the variable that holds our txt counts

lambda_1 = pm.Exponential("lambda_1",  alpha)
lambda_2 = pm.Exponential("lambda_2", alpha)

tau = pm.DiscreteUniform("tau", lower=0, upper=n_count_data)


@pm.deterministic
def lambda_(tau=tau, lambda_1=lambda_1, lambda_2=lambda_2):
    out = np.zeros(n_count_data)
    out[:tau] = lambda_1  # lambda before tau is lambda1
    out[tau:] = lambda_2  # lambda after tau is lambda2
    return out

observation = pm.Poisson("obs", lambda_, value=count_data, observed=True)
model = pm.Model([observation, lambda_1, lambda_2, tau])


mcmc = pm.MCMC(model)
mcmc.sample(100000, 50000, 1)
