import sys

import numpy as np
from IPython.core.display import Image

import praw


reddit = praw.Reddit("BayesianMethodsForHackers")
subreddit  = reddit.get_subreddit( "crazyideas" )

top_submissions = subreddit.get_top(limit=100)

n_sub = int( sys.argv[1] ) if sys.argv[1] else 1

i = 0
while i < n_sub:
    top_submission = next(top_submissions)
    #while "i.imgur.com" not in top_submission.url:
    #    #make sure it is linking to an image, not a webpage.
    #    top_submission = next(top_submissions)
    i+=1

#print("Post contents: \n", top_submission.title)
top_post = top_submission.title
#top_submission.replace_more_comments(limit=5, threshold=0)
#print(top_post_url)

upvotes = []
downvotes = []
contents = []
"""_all_comments = top_submission.comments
all_comments=[]
for comment in _all_comments:
            try:
                #ups = int(round((ratio*comment.score)/(2*ratio - 1)) if ratio != 0.5 else round(comment.score/2))
                #upvotes.append(ups)
                #downvotes.append(ups - comment.score)
                scores.append( comment.score )
                contents.append( comment.body )
            except Exception as e:
                continue
"""
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