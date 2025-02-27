"""

Generates appropriate replacements (masses, BC conditions, and abundances for MESA
inlist files. Outputs lists of replacements that are inputs to make_replacements.py

Args:
    runname: the name of the grid
    startype: the mass range of the models
    afe: the [a/Fe] value of the grid as str
    feh: the [Fe/H] value of the grid as str
    zbase: the Zbase corresponding to [Fe/H] and [a/Fe] as float
    rot: initial v/vcrit 
    net: name of the nuclear network

Returns:
    the list of replacements
    
See Also:
    make_replacements: takes the list of replacements as an input
    
Example:
    >>> replist = make_inlist_inputs(runname, 'VeryLow')
    
Acknowledgment:
    Thanks to Joshua Burkart for providing assistance with and content for earlier versions of this code.
    
"""

import sys
import numpy as np
    
def make_inlist_inputs(runname, startype, feh, afe, zbase, rot, net, gridtype="DEFAULT", customgrid=[]):
    
    #Array of all masses
    massgrid = lambda i,f,step: np.linspace(i,f,round(((f-i)/step))+1.0)


    if gridtype=="DEFAULT":
# MIST2 - low and intermediate
    #bigmassgrid = np.unique(np.hstack((massgrid(0.5,9,0.5), massgrid(100,250,10) )))

# MIST2 - high
#    bigmassgrid = np.unique(np.hstack((massgrid(8,20,2), massgrid(20,60,5))))

# MIST2 - full
        bigmassgrid = np.unique(np.hstack((massgrid(0.1,0.65,0.05),massgrid(0.7,1.2,0.01),massgrid(1.25,2.0,0.05),\
                                           massgrid(2.1,6.0,0.2),massgrid(6.5,9.0,0.5), \
                                           massgrid(9,20,1),massgrid(25,35,5),massgrid(36,60,2), \
                                           massgrid(65,100,5),massgrid(100,300,10))))

        

    elif gridtype=="CUSTOM":
        bigmassgrid = np.array(customgrid)
    else:
        print("gridtype must be either DEFAULT or CUSTOM")
        sys.exit(0)

# MIST1
#    bigmassgrid = np.unique(np.hstack((massgrid(0.1,0.3,0.05),massgrid(0.3,0.4,0.01),massgrid(0.4,2.0,0.05),\
#					massgrid(2.0,4.0,0.1),massgrid(4.0,6.0,0.25),\
#                                        massgrid(6.0,9.0,0.5),massgrid(9,20,1), massgrid(20,40,5),\
#                                        massgrid(40,150,10),massgrid(150, 300, 25))))

    #Choose the correct mass range and boundary conditions                                   
    if (startype == 'VeryLow'):
        massindex = np.where(bigmassgrid <= 0.6)
    elif (startype == 'Intermediate'):
        massindex = np.where((bigmassgrid < 7.0) & (bigmassgrid > 0.499))
    elif (startype == 'VeryHigh'):
        massindex = np.where(bigmassgrid >= 7.0)
    else:
        print('Invalid choice.')
        sys.exit(0)

    #Create mass lists
    mapfunc = lambda var: str(int(var)) if var == int(var) else '{:4.2f}'.format(var)
    masslist = map(mapfunc, bigmassgrid[massindex])
        
    #Create [a/Fe] lists
    afelist = list([afe]*np.size(massindex))

    #create [Fe/H] lists
    fehlist = list([feh]*np.size(massindex))

    #Create Zbase list
    zbaselist = list([zbase]*np.size(massindex))

    #Create rot list
    rotlist = list([rot]*np.size(massindex))

    #Create net list
    netlist = list([net]*np.size(massindex))
        
    #Make list of [replacement string, values]
    replist = [\
            ["<<MASS>>", masslist],\
            ["<<AFE>>", afelist],\
            ["<<FEH>>", fehlist],\
            ["<<ZBASE>>", zbaselist],\
            ["<<ROT>>", rotlist],\
            ["<<NET>>", netlist],\
        ]
    
    return replist
