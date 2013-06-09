#!/usr/bin/env python

def counts(data,bin_size=30):
    "Yields the counts of photons for a particular bin size"
    from math import floor
    import numpy as np
    counts = []
    bin_end = floor(data[0]) + bin_size
    count = 0
    for d in data:
        if d < bin_end: count += 1
        else :
            counts.append([bin_end,count])
            count = 0
            bin_end += bin_size
    return np.array(counts)
    


if __name__ == "__main__":
    import numpy as np
    import sys
    from pprint import pprint

    # Get the photon times from stdin
    photon_times = np.array([ float(l.strip().split(' ')[1])
                              for l in sys.stdin.readlines()
                              if l.strip().split(' ')[1] ])

    # Write to first command line argument
    dest = sys.argv[1]
    np.savez(dest, photon_counts=counts(photon_times))
