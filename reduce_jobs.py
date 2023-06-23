#!/usr/bin/env python

"""

Takes MESA grids to create isochrones and organizes all the output files
into a nice directory structure.

The directory structure is as follows:
    top level directory --> MIST_vXX/FIDUCIAL/feh_pX.X_afe_pX.X/
    five subdirectories --> tracks/    eeps/    inlists/    isochrones/    plots/

Args:
    runname: the name of the grid

Keywords:
    doplot: if True, generates plots of EEPs and isochrones

"""

import os
import sys
import subprocess
import glob
from shutil import copytree

#from scripts import mesa_plot_grid
from scripts import make_eeps_isos
from scripts import mesa_hist_trim
from scripts import reduce_jobs_utils
    
if __name__ == "__main__":
    
    #Digest the inputs
    if len(sys.argv) == 2:
        runname = sys.argv[1]
        doplot = False
        dobotheeps = False
    elif ((len(sys.argv) < 2) or (len(sys.argv) == 3)):
        print "Usage: ./reduce_jobs name_of_grid doplot* dobotheeps*"
        print "* doplot and dobotheeps are optional, but both must be set at the same time. They both default to False."
        sys.exit(0)
    else:
        runname = sys.argv[1]
        doplot = sys.argv[2]
        dobotheeps = sys.argv[3]
                    
    #Rename the run directory XXX as XXX_raw
    rawdirname = runname+"_raw"
    os.system("mv " + os.path.join(os.environ['MIST_GRID_DIR'],runname) + " " + os.path.join(os.environ['MIST_GRID_DIR'],rawdirname))
    
    #The XXX directory will contain the organized, reduced information
    newdirname = os.path.join(os.environ['MIST_GRID_DIR'],runname)
    os.mkdir(newdirname)
    
    #Make the eeps directory that will be filled in later
    os.mkdir(os.path.join(newdirname, "eeps"))
    
    #Make the isochrones directory that will be filled in later
    os.mkdir(os.path.join(newdirname, "isochrones"))

    print "************************************************************"
    print "****************SORTING THE HISTORY FILES*******************"
    print "************************************************************"
    reduce_jobs_utils.sort_histfiles(rawdirname)
    
    print "************************************************************"
    print "****************SAVING THE ABUNDANCES FILE******************"
    print "************************************************************"
    abunfile = glob.glob(os.path.join(os.path.join(os.environ['MIST_GRID_DIR'],rawdirname),'*dir/input_initial_xa.data'))[0]
    xyzfile = glob.glob(os.path.join(os.path.join(os.environ['MIST_GRID_DIR'],rawdirname),'*dir/input_XYZ'))[0]
    os.system("cp " + abunfile + " " + newdirname)
    os.system("cp " + xyzfile + " " + newdirname) 
    
    print "************************************************************"
    print "****************SORTING THE INLIST FILES********************"
    print "************************************************************"
    reduce_jobs_utils.save_inlists(rawdirname)
    
 #   print "************************************************************"
 #   print "***************SORTING THE PHOTOS AND MODELS****************"
 #   print "************************************************************"
 #   reduce_jobs_utils.save_lowM_photo_model(rawdirname)
   
    print "************************************************************"
    print "************************** BLEND ***************************"
    print "************************************************************"



    print "************************************************************"
    print "**********************MAKE ISOCHRONES***********************"
    print "************************************************************"
    make_eeps_isos.make_eeps_isos(runname, basic=False, fsps=True)
    
    print "************************************************************"
    print "****************GENERATING A SUMMARY FILE*******************"
    print "************************************************************"
    reduce_jobs_utils.gen_summary(rawdirname)
    os.system("mv tracks_summary_"+rawdirname.split("_raw")[0]+".txt " + newdirname)

    print "************************************************************"
    print "****************MOVING TO LONG-TERM STORAGE*****************"
    print "************************************************************"
    old_dir = os.path.join(os.environ['MIST_GRID_DIR'],runname) 
    new_dir = os.path.join(os.environ['STORE_DIR'],runname)
    if os.path.isdir(new_dir):
        print 'deleting old version of reduced directory'
        os.system("rm -rf "+new_dir)
    os.system("mv "+old_dir+" "+new_dir)

    dir1 = os.path.join(os.environ['MIST_GRID_DIR'],runname)
    dir2 = os.path.join(os.environ['MIST_GRID_DIR'],runname+"_raw")
    os.system("mv "+dir2+" "+dir1)
