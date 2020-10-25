import sys

import numpy as np
from IPython.core.display import Image

import praw

# don't forget to replace values of client_id, etc 
reddit = praw.Reddit(client_id='YOUR_CLIENT_ID',
                     client_secret='YOUR_CLIENT_SECRET',
                     password='YOUR_PASSWORD',
                     user_agent='SOME_USER_AGENT',
                     username='YOUR_USERNAME')

subreddit = reddit.subreddit("showerthoughts")
top_submissions = subreddit.hot(limit=100)

n_sub = int( sys.argv[1] ) if sys.argv[1] else 1

i = 0 
while i < n_sub:
    top_submission = next(top_submissions)
    i+=1

top_post = top_submission.title


upvotes = []
downvotes = []
contents = []

for submission in top_submissions:
    try:
        ratio = submission.upvote_ratio
        ups = int(round((ratio*submission.score)/(2*ratio - 1)) if ratio != 0.5 else round(submission.score/2))
        upvotes.append(ups)
        downvotes.append(ups - submission.score)
        contents.append(submission.title)
    except Exception as e:
        continue
    
votes = np.array([upvotes, downvotes]).T   
