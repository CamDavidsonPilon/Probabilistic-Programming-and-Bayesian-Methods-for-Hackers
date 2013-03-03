
try:
    import numpy as np
    from requests import get
    from bs4 import BeautifulSoup




    stars_to_explore = ( 2**np.arange( -1, 16 ) ).astype("int")
    forks_to_explore = ( 2**np.arange( -1, 16 ) ).astype("int")
    repo_with_stars = np.ones_like( stars_to_explore )
    repo_with_forks = np.ones_like( forks_to_explore )

    URL = "https://github.com/search"
    print "Scrapping data from Github. Sorry Github..."
    print "The data is contained in variables `foo_to_explore` and `repo_with_foo`"
    print
    print "stars first..."
    payload = {"q":""}
    for i, _star in enumerate(stars_to_explore):
        payload["q"] = "stars:>=%d"%_star
        r = get( URL, params = payload )
        soup = BeautifulSoup( r.text )
        try:
            h3 = soup.find( class_="sort-bar").find( "h3" ).text #hopefully the github search results page plays nicely.
            value = int( h3.split(" ")[2].replace(",", "" ) )
        except AttributeError as e:
            #there might be less than 10 repos, so I'll count the number of display results
            value  = len( soup.findAll(class_= "mega-icon-public-repo" ) )
        
        repo_with_stars[i] = value
        print "number of repos with greater than or equal to %d stars: %d"%(_star, value )
    
    #repo_with_stars = repo_with_stars.astype("float")/repo_with_stars[0]


    print 
    print "forks second..."
    payload = {"q":""}
    for i, _fork in enumerate(stars_to_explore):
        payload["q"] = "forks:>=%d"%_fork
        r = get( URL, params = payload )
        soup = BeautifulSoup( r.text )
        try:
            h3 = soup.find( class_="sort-bar").find( "h3" ).text #hopefully the github search results page plays nicely.
            value = int( h3.split(" ")[2].replace(",", "" ) )
        except AttributeError as e:
            #there might be less than 10 repos, so I'll count the number of display results
            value  = len( soup.findAll(class_= "mega-icon-public-repo" ) )
        
        repo_with_forks[i] = value
        print "number of repos with greater than or equal to %d forks: %d"%(_fork, value )
    
    #repo_with_forks = repo_with_forks.astype("float")/repo_with_forks[0]
    
    np.savetxt( "data/gh_forks.csv", np.concatenate( [forks_to_explore, repo_with_forks], axis=1) )
    np.savetxt( "data/gh_stars.csv", np.concatenate( [stars_to_explore, repo_with_stars], axis=1) )

except ImportError as e:
    print e
    print "requests / BeautifulSoup not found. Using data pulled on Feburary 11, 2013"
    _data = np.genfromtxt( "data/gh_forks.csv", delimiter = "," ) #cehck this.
    forks_to_explore = _data[:,0]
    repo_with_forks  = _data[:,1]    
    
    _data = np.genfromtxt( "data/gh_stars.csv", delimiter = "," ) #cehck this.
    stars_to_explore = _data[:,0]
    repo_with_stars  = _data[:,1]
    
    
    