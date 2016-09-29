import sys

import numpy as np
from IPython.core.display import Image

import praw


reddit = praw.Reddit("BayesianMethodsForHackers")
subreddit  = reddit.get_subreddit("showerthoughts")

top_submissions = subreddit.get_top(limit=100)

n_sub = int( sys.argv[1] ) if sys.argv[1] else 1

i = 0
while i < n_sub:
    top_submission = next(top_submissions)
    i+=1

top_post = top_submission.title

upvotes = []
downvotes = []
contents = []

for sub in top_submissions:
    try:
        ratio = reddit.get_submission(sub.permalink).upvote_ratio
        ups = int(round((ratio*sub.score)/(2*ratio - 1)) if ratio != 0.5 else round(sub.score/2))
        upvotes.append(ups)
        downvotes.append(ups - sub.score)
        contents.append(sub.title)
    except Exception as e:
        continue
votes = np.array( [ upvotes, downvotes] ).T