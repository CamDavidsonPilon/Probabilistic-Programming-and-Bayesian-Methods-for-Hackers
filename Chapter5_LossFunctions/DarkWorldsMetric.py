""" DarkWorldsMetricMountianOsteric.py
Custom evaluation metric for the 'Observing Dark Worlds' competition.

[Description of metric, or reference to documentation.]

Update: Made for the training set only so users can check there results from the training c

@Author: David Harvey
Created: 22 August 2012
"""

import numpy as np
import math as mt
import itertools as it
import csv as c
import getopt as gt
import sys as sys
import argparse as ap
import string as st
import random as rd

def calc_delta_r(x_predicted,y_predicted,x_true,y_true): 
    """ Compute the scalar distance between predicted halo centers
    and the true halo centers. Predictions are matched to the closest
    halo center.
    Notes: It takes in the predicted and true positions, and then loops over each possible configuration and finds the most optimal one.
    Arguments:
        x_predicted, y_predicted: vector for predicted x- and y-positions (1 to 3 elements)
        x_true, y_true: vector for known x- and y-positions (1 to 3 elements)
    Returns:
        radial_distance: vector containing the scalar distances between the predicted halo centres and the true halo centres (1 to 3 elements)
        true_halo_indexes: vector containing indexes of the input true halos which matches the predicted halo indexes (1 to 3 elements)
        measured_halo_indexes: vector containing indexes of the predicted halo position with the  reference to the true halo position.
       e.g if true_halo_indexes=[0,1] and measured_halo_indexes=[1,0] then the first x,y coordinates of the true halo position matches the second input of the predicted x,y coordinates.
    """
    
    num_halos=len(x_true) #Only works for number of halos > 1
    num_configurations=mt.factorial(num_halos) #The number of possible different comb
    configurations=np.zeros([num_halos,num_configurations],int) #The array of combinations
                                                                #I will pass back
    distances = np.zeros([num_configurations],float) #The array of the distances
                                                     #for all possible combinations
    
    radial_distance=[]  #The vector of distances
                        #I will pass back
    
    #Pick a combination of true and predicted 
    a=['01','012'] #Input for the permutations, 01 number halos or 012
    count=0 #For the index of the distances array
    true_halo_indexes=[] #The tuples which will show the order of halos picked
    predicted_halo_indexes=[]
    distances_perm=np.zeros([num_configurations,num_halos],float) #The distance between each
                                                                  #true and predicted
                                                                  #halo for every comb
    true_halo_indexes_perm=[] #log of all the permutations of true halos used
    predicted_halo_indexes_perm=[] #log of all the predicted permutations
    
    for  perm in it.permutations(a[num_halos-2],num_halos):
        which_true_halos=[]
        which_predicted_halos=[]
        for j in range(num_halos): #loop through all the true halos with the

            distances_perm[count,j]=np.sqrt((x_true[j]-x_predicted[int(perm[j])])**2\
                                      +(y_true[j]-y_predicted[int(perm[j])])**2)
                                      #This array logs the distance between true and
                                      #predicted halo for ALL configurations
                                      
            which_true_halos.append(j) #log the order in which I try each true halo
            which_predicted_halos.append(int(perm[j])) #log the order in which I true
                                                       #each predicted halo
        true_halo_indexes_perm.append(which_true_halos) #this is a tuple of tuples of
                                                        #all of thifferent config
                                                        #true halo indexes
        predicted_halo_indexes_perm.append(which_predicted_halos)
        
        distances[count]=sum(distances_perm[count,0::]) #Find what the total distances
                                                        #are for each configuration
        count=count+1

    config = np.where(distances == min(distances))[0][0] #The configuration used is the one
                                                         #which has the smallest distance
    radial_distance.append(distances_perm[config,0::]) #Find the tuple of distances that
                                                       #correspond to this smallest distance
    true_halo_indexes=true_halo_indexes_perm[config] #Find the tuple of the index which refers
                                                     #to the smallest distance
    predicted_halo_indexes=predicted_halo_indexes_perm[config]
            
    return radial_distance,true_halo_indexes,predicted_halo_indexes


def calc_theta(x_predicted, y_predicted, x_true, y_true, x_ref, y_ref):
    """ Calculate the angle the predicted position and the true position, where the zero degree corresponds to the line joing the true halo position and the reference point given.
    Arguments:
        x_predicted, y_predicted: vector for predicted x- and y-positions (1 to 3 elements)
        x_true, y_true: vector for known x- and y-positions (1 to 3 elements)
        Note that the input of these are matched up so that the first elements of each
        vector are associated with one another
        x_ref, y_ref: scalars of the x,y coordinate of reference point
    Returns:
        Theta: A vector containing the angles of the predicted halo w.r.t the true halo
        with the vector joining the reference point and the halo as the zero line. 
    """

    num_halos=len(x_predicted)
    theta=np.zeros([num_halos+1],float) #Set up the array which will pass back the values
    phi = np.zeros([num_halos],float)
    
    psi = np.arctan( (y_true-y_ref)/(x_true-x_ref) )

    
                     # Angle at which the halo is at
                                                     #with respect to the reference point
    phi[x_true != x_ref] = np.arctan((y_predicted[x_true != x_predicted]-\
                                      y_true[x_true != x_predicted])\
                    /(x_predicted[x_true != x_predicted]-\
                      x_true[x_true != x_predicted])) # Angle of the estimate
                                                               #wrt true halo centre

    #Before finding the angle with the zero line as the line joining the halo and the reference
    #point I need to convert the angle produced by Python to an angle between 0 and 2pi
    phi =convert_to_360(phi, x_predicted-x_true,\
         y_predicted-y_true)
    psi = convert_to_360(psi, x_true-x_ref,\
                             y_true-y_ref)
    theta = phi-psi #The angle with the baseline as the line joing the ref and the halo

    
    theta[theta< 0.0]=theta[theta< 0.0]+2.0*mt.pi #If the angle of the true pos wrt the ref is
                                                  #greater than the angle of predicted pos
                                                  #and the true pos then add 2pi
    return theta


def convert_to_360(angle, x_in, y_in):
    """ Convert the given angle to the true angle in the range 0:2pi 
    Arguments:
        angle:
        x_in, y_in: the x and y coordinates used to determine the quartile
        the coordinate lies in so to add of pi or 2pi
    Returns:
        theta: the angle in the range 0:2pi
    """
    n = len(x_in)
    for i in range(n):
        if x_in[i] < 0 and y_in[i] > 0:
            angle[i] = angle[i]+mt.pi
        elif x_in[i] < 0 and y_in[i] < 0:
            angle[i] = angle[i]+mt.pi
        elif x_in[i] > 0 and y_in[i] < 0:
            angle[i] = angle[i]+2.0*mt.pi
        elif x_in[i] == 0 and y_in[i] == 0:
            angle[i] = 0
        elif x_in[i] == 0 and y_in[i] > 0:
            angle[i] = mt.pi/2.
        elif x_in[i] < 0 and y_in[i] == 0:
            angle[i] = mt.pi
        elif x_in[i] == 0 and y_in[i] < 0:
            angle[i] = 3.*mt.pi/2.



    return angle

def get_ref(x_halo,y_halo,weight):
    """ Gets the reference point of the system of halos by weighted averaging the x and y
    coordinates.
    Arguments:
         x_halo, y_halo: Vector num_halos referring to the coordinates of the halos
         weight: the weight which will be assigned to the position of the halo
         num_halos: number of halos in the system
    Returns:
         x_ref, y_ref: The coordinates of the reference point for the metric
    """
 

        #Find the weighted average of the x and y coordinates
    x_ref = np.sum([x_halo*weight])/np.sum([weight])
    y_ref = np.sum([y_halo*weight])/np.sum([weight])


    return x_ref,y_ref

    
def main_score( nhalo_all, x_true_all, y_true_all, x_ref_all, y_ref_all, sky_prediction):
    """abstracts the score from the old command-line interface. 
       sky_prediction is a dx2 array of predicted x,y positions
    
    -camdp"""
    
    r=np.array([],dtype=float) # The array which I will log all the calculated radial distances
    angle=np.array([],dtype=float) #The array which I will log all the calculated angles
    #Load in the sky_ids from the true
    num_halos_total=0 #Keep track of how many halos are input into the metric

        

    for selectskyinsolutions, sky in enumerate(sky_prediction): #Loop through each line in result.csv and analyse each one


        nhalo=int(nhalo_all[selectskyinsolutions])#How many halos in the
                                                       #selected sky?
        x_true=x_true_all[selectskyinsolutions][0:nhalo]
        y_true=y_true_all[selectskyinsolutions][0:nhalo]
                    
        x_predicted=np.array([],dtype=float)
        y_predicted=np.array([],dtype=float)
        for i in range(nhalo):
            x_predicted=np.append(x_predicted,float(sky[0])) #get the predicted values
            y_predicted=np.append(y_predicted,float(sky[1]))
            #The solution file for the test data provides masses 
            #to calculate the centre of mass where as the Training_halo.csv
            #direct provides x_ref y_ref. So in the case of test data
            #we need to calculate the ref point from the masses using
            #Get_ref()
  
        x_ref=x_ref_all[selectskyinsolutions]
        y_ref=y_ref_all[selectskyinsolutions]

        num_halos_total=num_halos_total+nhalo


        #Single halo case, this needs to be separately calculated since
        #x_ref = x_true
        if nhalo == 1:
            #What is the radial distance between the true and predicted position
            r=np.append(r,np.sqrt( (x_predicted-x_true)**2 \
                                          + (y_predicted-y_true)**2)) 
            #What is the angle between the predicted position and true halo position
            if (x_predicted-x_true) != 0:
                psi = np.arctan((y_predicted-y_true)/(x_predicted-x_true))
            else: psi=0.
            theta = convert_to_360([psi], [x_predicted-x_true], [y_predicted-y_true])
            angle=np.append(angle,theta)

        
        else:        
            #r_index_index, contains the radial distances of the predicted to
            #true positions. These are found by matching up the true halos to
            #the predicted halos such that the average of all the radial distances
            #is optimal. it also contains indexes of the halos used which are used to
            #show which halo has been matched to which.
            
            r_index_index = calc_delta_r(x_predicted, y_predicted, x_true, \
                                         y_true)
  
            r=np.append(r,r_index_index[0][0])
            halo_index= r_index_index[1] #The true halos indexes matched with the 
            predicted_index=r_index_index[2] #predicted halo index

            angle=np.append(angle,calc_theta\
                                  (x_predicted[predicted_index],\
                                   y_predicted[predicted_index],\
                                   x_true[halo_index],\
                                   y_true[halo_index],x_ref,\
                                   y_ref)) # Find the angles of the predicted
                                               #position wrt to the halo and
                                               # add to the vector angle

    
    # Find what the average distance the estimate is from the halo position
    av_r=sum(r)/len(r)
    
    #In order to quantify the orientation invariance we will express each angle 
    # as a vector and find the average vector
    #R_bar^2=(1/N Sum^Ncos(theta))^2+(1/N Sum^Nsin(theta))**2
    
    N = float(num_halos_total)
    angle_vec = np.sqrt(( 1.0/N * sum(np.cos(angle)) )**2 + \
        ( 1.0/N * sum(np.sin(angle)) )**2)
    
    W1=1./1000. #Weight the av_r such that < 1 is a good score > 1 is not so good.
    W2=1.
    metric = W1*av_r + W2*angle_vec #Weighted metric, weights TBD
    print('Your average distance in pixels you are away from the true halo is', av_r)
    print('Your average angular vector is', angle_vec)
    print('Your score for the training data is', metric)
    return metric
    
    
def main(user_fname, fname):
    """ Script to compute the evaluation metric for the Observing Dark Worlds competition. You can run it on your training data to understand how well you have done with the training data.
    """

    r=np.array([],dtype=float) # The array which I will log all the calculated radial distances
    angle=np.array([],dtype=float) #The array which I will log all the calculated angles
    #Load in the sky_ids from the true
    
    true_sky_id=[]
    sky_loader = c.reader(open(fname, 'rb')) #Load in the sky_ids from the solution file
    for row in sky_loader:
        true_sky_id.append(row[0])

    #Load in the true values from the solution file

    nhalo_all=np.loadtxt(fname,usecols=(1,),delimiter=',',skiprows=1)
    x_true_all=np.loadtxt(fname,usecols=(4,6,8),delimiter=',',skiprows=1)
    y_true_all=np.loadtxt(fname,usecols=(5,7,9),delimiter=',',skiprows=1)
    x_ref_all=np.loadtxt(fname,usecols=(2,),delimiter=',',skiprows=1)
    y_ref_all=np.loadtxt(fname,usecols=(3,),delimiter=',',skiprows=1)

    
    for row in sky_loader:
        true_sky_id.append(row[1])
        

    
    num_halos_total=0 #Keep track of how many halos are input into the metric


    sky_prediction = c.reader(open(user_fname, 'rb')) #Open the result.csv   
   
    try: #See if the input file from user has a header on it
         #with open('JoyceTest/trivialUnitTest_Pred.txt', 'r') as f:
        with open(user_fname, 'r') as f:   
            header = float((f.readline()).split(',')[1]) #try and make where the
                                                         #first input would be
                                                         #a float, if succeed it
                                                         #is not a header
        print('THE INPUT FILE DOES NOT APPEAR TO HAVE A HEADER')
    except :
        print('THE INPUT FILE APPEARS TO HAVE A HEADER, SKIPPING THE FIRST LINE')
        skip_header = sky_prediction.next()
        

    for sky in sky_prediction: #Loop through each line in result.csv and analyse each one
        sky_id = str(sky[0]) #Get the sky_id of the input
        does_it_exist=true_sky_id.count(sky_id) #Is the input sky_id
                                                #from user a real one?
        
        if does_it_exist > 0: #If it does then find the matching solutions to the sky_id
                            selectskyinsolutions=true_sky_id.index(sky_id)-1
        else: #Otherwise exit
            print('Sky_id does not exist, formatting problem: ',sky_id)
            sys.exit(2)


        nhalo=int(nhalo_all[selectskyinsolutions])#How many halos in the
                                                       #selected sky?
        x_true=x_true_all[selectskyinsolutions][0:nhalo]
        y_true=y_true_all[selectskyinsolutions][0:nhalo]
                    
        x_predicted=np.array([],dtype=float)
        y_predicted=np.array([],dtype=float)
        for i in range(nhalo):
            x_predicted=np.append(x_predicted,float(sky[2*i+1])) #get the predicted values
            y_predicted=np.append(y_predicted,float(sky[2*i+2]))
            #The solution file for the test data provides masses 
            #to calculate the centre of mass where as the Training_halo.csv
            #direct provides x_ref y_ref. So in the case of test data
            #we need to calculae the ref point from the masses using
            #Get_ref()
  
        x_ref=x_ref_all[selectskyinsolutions]
        y_ref=y_ref_all[selectskyinsolutions]

        num_halos_total=num_halos_total+nhalo


        #Single halo case, this needs to be separately calculated since
        #x_ref = x_true
        if nhalo == 1:
            #What is the radial distance between the true and predicted position
            r=np.append(r,np.sqrt( (x_predicted-x_true)**2 \
                                          + (y_predicted-y_true)**2)) 
            #What is the angle between the predicted position and true halo position
            if (x_predicted-x_true) != 0:
                psi = np.arctan((y_predicted-y_true)/(x_predicted-x_true))
            else: psi=0.
            theta = convert_to_360([psi], [x_predicted-x_true], [y_predicted-y_true])
            angle=np.append(angle,theta)

        
        else:        
            #r_index_index, contains the radial distances of the predicted to
            #true positions. These are found by matching up the true halos to
            #the predicted halos such that the average of all the radial distances
            #is optimal. it also contains indexes of the halos used which are used to
            #show which halo has been matched to which.
            
            r_index_index = calc_delta_r(x_predicted, y_predicted, x_true, \
                                         y_true)
  
            r=np.append(r,r_index_index[0][0])
            halo_index= r_index_index[1] #The true halos indexes matched with the 
            predicted_index=r_index_index[2] #predicted halo index

            angle=np.append(angle,calc_theta\
                                  (x_predicted[predicted_index],\
                                   y_predicted[predicted_index],\
                                   x_true[halo_index],\
                                   y_true[halo_index],x_ref,\
                                   y_ref)) # Find the angles of the predicted
                                               #position wrt to the halo and
                                               # add to the vector angle

    
    # Find what the average distance the estimate is from the halo position
    av_r=sum(r)/len(r)
    
    #In order to quantify the orientation invariance we will express each angle 
    # as a vector and find the average vector
    #R_bar^2=(1/N Sum^Ncos(theta))^2+(1/N Sum^Nsin(theta))**2
    
    N = float(num_halos_total)
    angle_vec = np.sqrt(( 1.0/N * sum(np.cos(angle)) )**2 + \
        ( 1.0/N * sum(np.sin(angle)) )**2)
    
    W1=1./1000. #Weight the av_r such that < 1 is a good score > 1 is not so good.
    W2=1.
    metric = W1*av_r + W2*angle_vec #Weighted metric, weights TBD
    print('Your average distance in pixels you are away from the true halo is', av_r)
    print('Your average angular vector is', angle_vec)
    print('Your score for the training data is', metric)


if __name__ == "__main__":
    #For help just typed 'python DarkWorldsMetric.py -h'

    parser = ap.ArgumentParser(description='Work out the Metric for your input file')
    parser.add_argument('inputfile',type=str,nargs=1,help='Input file of halo positions. Needs to be in the format SkyId,halo_x1,haloy1,halox_2,halo_y2,halox3,halo_y3 ')
    parser.add_argument('reffile',type=str,nargs=1,help='This should point to Training_halos.csv')
    args = parser.parse_args()

    user_fname=args.inputfile[0]
    filename = (args.reffile[0]).count('Training_halos.csv')
    if filename == 0:
        fname=args.reffile[0]+str('Training_halos.csv')
    else:
        fname=args.reffile[0]

    main(user_fname, fname)
    
