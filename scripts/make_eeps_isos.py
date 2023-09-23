"""

A wrapper for Aaron Dotter's fortran routines (https://github.com/dotbot2000/iso) to generate eeps and isochrones
from MESA history files and write MIST and FSPS isochrones.

Args:
    runname: the name of the grid
    
Returns:
    None
    
"""

import glob
import os
import shutil
import subprocess

import mist2fsps
import make_blend_input_file
import make_iso_input_file

def make_eeps_isos(runname, basic=False, fsps=False):

    print runname
    exit
    
    runname_format = runname.split('/')[-1]
    inputfile = "input."+runname_format
    
    #if basic = True, then only print out a very basic set of columns
    #if basic != True, then print out all of the columns except for things like num_retries, etc.

    #Copy the most recent copy of my_history_columns.list file to the iso directory
    if basic == True:
        shutil.copy(os.path.join(os.environ['MIST_CODE_DIR'], 'mesafiles/my_history_columns_basic.list'), os.path.join(os.environ['ISO_DIR'], 'my_history_columns_basic.list'))
    else:
        shutil.copy(os.path.join(os.environ['MIST_CODE_DIR'], 'mesafiles/my_history_columns_full.list'), os.path.join(os.environ['ISO_DIR'], 'my_history_columns_full.list'))

    #Make the input file for the isochrones code to make eeps
    make_iso_input_file.make_iso_input_file(runname, "eeps", basic)

    #cd into the isochrone directory and run the codes
    os.chdir(os.environ['ISO_DIR'])
    os.system("./make_eep " + inputfile)

    #blend the tracks (0.50, 0.55, 0.60) if they exist

    eeps_dir = os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], runname), "eeps")

    if os.path.isfile(eeps_dir+'/00050M_VLM.track.eep'):
        #Write out the contents of the file
        content = ["#data directory\n", eeps_dir+"\n", "#number of tracks to blend\n", "2\n", \
                   "#names of those tracks; if .eep doesn't exist, then will create them\n", "00050M.track\n", \
                   "00050M_VLM.track\n", "#blend fractions, must sum to 1.0\n", "0.25\n", \
                   "0.75\n", "#name of blended track\n", "00050M.track.eep"]

        with open("input.blend1", "w") as newinputfile:
            for contentline in content:
                newinputfile.write(contentline)

        result = os.system("./blend_eeps input.blend1")
        if result==0: os.remove(eeps_dir+'/00050M_VLM.track.eep')

    if os.path.isfile(eeps_dir+'/00055M_VLM.track.eep'):
        #Write out the contents of the file
        content = ["#data directory\n", eeps_dir+"\n", "#number of tracks to blend\n", "2\n", \
                   "#names of those tracks; if .eep doesn't exist, then will create them\n", "00055M.track\n", \
                   "00055M_VLM.track\n", "#blend fractions, must sum to 1.0\n", "0.50\n", \
                   "0.50\n", "#name of blended track\n", "00055M.track.eep"]

        os.chdir(os.environ['ISO_DIR'])

        with open("input.blend1", "w") as newinputfile:
            for contentline in content:
                newinputfile.write(contentline)

        result = os.system("./blend_eeps input.blend1")
        if result==0: os.remove(eeps_dir+'/00055M_VLM.track.eep')

    if os.path.isfile(eeps_dir+'/00060M_VLM.track.eep'):
        #Write out the contents of the file
        content = ["#data directory\n", eeps_dir+"\n", "#number of tracks to blend\n", "2\n", \
                   "#names of those tracks; if .eep doesn't exist, then will create them\n", "00060M.track\n", \
                   "00060M_VLM.track\n", "#blend fractions, must sum to 1.0\n", "0.75\n", \
                   "0.25\n", "#name of blended track\n", "00060M.track.eep"]

        os.chdir(os.environ['ISO_DIR'])

        with open("input.blend1", "w") as newinputfile:
            for contentline in content:
                newinputfile.write(contentline)

        result = os.system("./blend_eeps input.blend1")
        if result==0: os.remove(eeps_dir+'/00060M_VLM.track.eep')


    #and rename the other VLM files for isochrone processing
    os.chdir(eeps_dir)
    files=['00010M_VLM.track.eep', '00015M_VLM.track.eep', '00020M_VLM.track.eep', '00025M_VLM.track.eep', '00030M_VLM.track.eep', 
           '00035M_VLM.track.eep', '00040M_VLM.track.eep', '00045M_VLM.track.eep']
    for f in files:
        if os.path.isfile(f):
            g=f.replace('_VLM','')
            print(f+' -> '+g)
            os.rename(f,g)

            
    #Make the input file for the isochrones code to make isochrones
    os.chdir(os.environ['MIST_CODE_DIR'])
    make_iso_input_file.make_iso_input_file(runname, "iso", basic)
    
    #Run the isochrone code
    os.chdir(os.environ['ISO_DIR'])
    os.system("./make_iso " + inputfile)


    #Run "Charlie's Angel":
    eep_file=os.path.join(os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], runname), "eeps"), "00010M.track")
    iso_dir=os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], runname), "isochrones")
    if basic:
        iso_root=runname_format+"_basic.iso"
    else:
        iso_root=runname_format+"_full.iso"

    iso_file = os.path.join(iso_dir, iso_root)
    
    os.system("./charlies_angel "+eep_file+" "+iso_file+" "+iso_file)

    
    #Get the path to the home directory for the run (runname)
    with open(inputfile) as f:
        lines=f.readlines()
        tracks_directory = lines[5].replace("\n", "")
        home_run_directory = tracks_directory.split("/tracks")[0]

    #Get the total number of EEPs from input.eep
    #12 lines of header
    with open(os.path.join(os.environ['ISO_DIR'], "input.eep"), "r") as inputf:
        inputeep_data = inputf.readlines()
        #Add 1 to account for the first primary EEP
        lowmass_num_lines = 12 + 1
        intmass_num_lines = 12 + 1
        highmass_num_lines = 12 + 1
        for i_l, line in enumerate(inputeep_data[2:8]):
            #Get the secondary EEP number
            numseceep = int(line.strip('\n').split(' ')[-1])
            #Add one for each primary EEP
            if i_l < 3:
                lowmass_num_lines += numseceep+1
                if i_l < 7:
                    highmass_num_lines += numseceep+1 
                    intmass_num_lines += numseceep+1

    #Generate a list of incomplete EEPs
    eeps_directory = os.path.join(home_run_directory, "eeps")
    incomplete_eeps_arr = []

    #Make the input.track file 
    os.chdir(os.environ['ISO_DIR'])    
    header = ["#input file containing list of EEPs\n", inputfile+"\n", "#number of new tracks to interpolate\n", str(len(incomplete_eeps_arr))+"\n", "#masses and output filenames\n"]
    with open("input.tracks_"+runname_format, "w") as trackinputfile:
        for headerline in header:
            trackinputfile.write(headerline)
            for incomplete_eeps in incomplete_eeps_arr:
                mass_val = float(incomplete_eeps.split('M.track')[0].split('/')[-1])/100.0
                eepline = str(mass_val) + ' ' + incomplete_eeps.split('/')[-1] + "_INTERP\n"
                trackinputfile.write(eepline)

    #Make the FSPS isochrones
    if fsps==True:
        isoch_directory = os.path.join(home_run_directory, "isochrones")
        isoch_output = glob.glob(isoch_directory + "/*.iso")
        fsps_iso_filename = mist2fsps.write_fsps_iso(isoch_output[0],logage=True)
        shutil.move(os.path.join(os.environ['ISO_DIR'], fsps_iso_filename), isoch_directory)
        
    
    
    
