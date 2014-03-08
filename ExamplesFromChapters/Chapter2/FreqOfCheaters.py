import pymc as pm

p = pm.Uniform("freq_cheating", 0, 1)


@pm.deterministic
def p_skewed(p=p):
    return 0.5 * p + 0.25

yes_responses = pm.Binomial(
    "number_cheaters", 100, p_skewed, value=35, observed=True)

model = pm.Model([yes_responses, p_skewed, p])

# To Be Explained in Chapter 3!
mcmc = pm.MCMC(model)
mcmc.sample(50000, 25000)
