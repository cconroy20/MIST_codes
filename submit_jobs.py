#!/usr/bin/env python 

"""

Calls all of the necessary routines to submit a grid of specified name and metallicity.

Args:
    runname: the name of the grid
    FeH: metallicity
    aFe: alpha-enhancement
    rotation
    net_name

Keywords:
    vvcrit: rotation
    
Example:
    To run a [Fe/H] = 0, [a/Fe] = 0 grid called MIST_v0.1 with v/vcrit=0.4 and using basic.net
    >>> ./submit_jobs MIST_v0.1 0.0 0.0 0.4 basic.net

"""

import os
import sys
import shutil

from scripts import make_slurm_sh
from scripts import make_inlist_inputs
from scripts import make_replacements

def name(feh,afe):
    def m_or_p(x):
        if x >= 0:
            return 'p'
        else:
            return 'm'
    ifeh=int(round(1000*feh)/10)
    iafe=int(round(1000*afe)/100)
    return 'feh_'+m_or_p(ifeh)+str(abs(ifeh)).zfill(3)+'_afe_'+m_or_p(iafe)+str(abs(iafe))


from numpy import float

if __name__ == "__main__":

    #net_name='mesa_49.net'
    #net_name = 'basic_plus_fe56_ni58.net'
    #net_name = 'pp_cno_extras_o18_ne22.net'
    #net_name = 'MIST2_36.net'
    net_name = 'MIST2_49.net'
    vvcrit = 0.4

    #Digest the inputs
    if len(sys.argv) < 3:
        print "Usage: ./submit_jobs name_of_grid FeH aFe vvcrit* net_name*"
        print "* vvcrit and net_name are optional. They default to 0.4 and mesa_49.net."
        sys.exit(0)
    elif len(sys.argv) == 3:
        #runname = sys.argv[1]
        FeH = float(sys.argv[1])
        aFe = float(sys.argv[2])
    elif len(sys.argv) == 4:
        #runname = sys.argv[1]
        FeH = float(sys.argv[1])
        aFe = float(sys.argv[2])
        vvcrit = float(sys.argv[3])
    elif len(sys.argv) > 4:
        #runname = sys.argv[1]
        FeH = float(sys.argv[1])
        aFe = float(sys.argv[2])
        vvcrit = float(sys.argv[3])
        net_name = "'" + sys.argv[4] + "'"
        if len(sys.argv)==6:
            suffix = "_" + sys.argv[5]
        else:
            suffix = ""

    runname = name(FeH,aFe) + suffix

    print('grid name is: {0}'.format(runname))
    print('[Fe/H] = {0}'.format(FeH))
    print('[a/Fe] = {0}'.format(aFe))
    print('v/vcrit = {0}'.format(vvcrit))
    print('network = {0}'.format(net_name))
    #sys.exit(0)

    dirname = os.path.join(os.environ['MIST_GRID_DIR'], runname)    
   
    print dirname
 
    #Create a working directory
    try:
        os.mkdir(dirname)
    except OSError:
        print "The directory already exists."
        sys.exit(0)
    
    #Generate inlists using template inlist files
    tempstor_inlist_dir = os.path.join(os.environ['MESAWORK_DIR'], 'inlists/inlists_'+'_'.join(runname.split('/')))
#    new_inlist_name = '<<MASS>>M.inlist'
    path_to_inlist_lowinter = os.path.join(os.environ['MIST_CODE_DIR'],'mesafiles/inlist_lowinter')
    path_to_inlist_VLM = os.path.join(os.environ['MIST_CODE_DIR'],'mesafiles/inlist_VLM')
    path_to_inlist_high = os.path.join(os.environ['MIST_CODE_DIR'],'mesafiles/inlist_high')
    
    
    #aFe value must be between -0.2 and 0.6 in steps of 0.2 (for opacity table reasons)
    okay_Fe = [-0.2, 0.0, 0.2, 0.4, 0.6]
    if aFe not in okay_Fe:
        print "[a/Fe] must be one of the following: "+(" ").join([str(x) for x in okay_Fe])
        sys.exit(0)
    if aFe < 0:
        afe_fmt = 'afe'+str(aFe)
    else:
        afe_fmt = 'afe+'+str(aFe)
 
    if FeH < 0:
        feh_fmt = "feh{0:5.2f}".format(FeH)
    else:
        feh_fmt = "feh+{0:4.2f}".format(FeH)

    new_inlist_name = '<<MASS>>M_'+feh_fmt+'_'+afe_fmt+'.inlist'
   
    new_name = os.path.join(os.environ['MESA_DIR'], 'data/atm_data/') + 'table10_summary.txt'
    #old_name = os.path.join(os.environ['MESA_DIR'], 'data/atm_data/') +'table10_summary_'+afe_fmt+'_mdwarf.txt'
    old_name = os.path.join(os.environ['MESA_DIR'], 'data/atm_data/') +'table10_summary_'+afe_fmt+'.txt'

    print('cp ' + old_name + ' ' + new_name)
    os.system('cp ' + old_name + ' ' + new_name)
        
    #Run Aaron's code to get the abundances
    shutil.copy(os.path.join(os.environ["XA_CALC_DIR"],"initial_xa_calculator"),os.environ['MIST_CODE_DIR'])
    os.system(os.path.join(os.environ['MIST_CODE_DIR'],"initial_xa_calculator") +\
        " " +  net_name + " " + str(FeH) + " " +str(aFe) + " 1.3245")
        
    #Zbase needs to be set in MESA for Type II opacity tables. Get this from a file produced by Aaron's code
    with open('input_XYZ') as f:
        Xval = float(f.readline().replace('D','E'))
        Yval = float(f.readline().replace('D','E'))
        zbase = float(f.readline().replace('D','E'))

    #Make the substitutions in the template inlists
    make_replacements.make_replacements(make_inlist_inputs.make_inlist_inputs(runname, 'VeryLow', FeH, afe_fmt, zbase, vvcrit, net_name),\
        new_inlist_name, direc=tempstor_inlist_dir, file_base=path_to_inlist_VLM)
    make_replacements.make_replacements(make_inlist_inputs.make_inlist_inputs(runname, 'Intermediate', FeH, afe_fmt, zbase, vvcrit, net_name),\
        new_inlist_name, direc=tempstor_inlist_dir, file_base=path_to_inlist_lowinter)
    make_replacements.make_replacements(make_inlist_inputs.make_inlist_inputs(runname, 'VeryHigh', FeH, afe_fmt, zbase, vvcrit, net_name),\
        new_inlist_name, direc=tempstor_inlist_dir, file_base=path_to_inlist_high)
        
    inlist_list = os.listdir(tempstor_inlist_dir)
    inlist_list.sort()

    for inlistname in inlist_list:
        #Make individual directories for each mass
        onemassdir = inlistname.replace('.inlist', '_dir')

        #Define an absolute path to this directory.
        path_to_onemassdir = os.path.join(dirname, onemassdir)

        #Copy over the contents of the template directory
        shutil.copytree(os.path.join(os.environ['MESAWORK_DIR'], "cleanworkdir"), path_to_onemassdir)

        #Populate each directory with appropriate inlists and rename as inlist_project
        shutil.copy(os.path.join(tempstor_inlist_dir,inlistname), os.path.join(path_to_onemassdir, 'inlist_project'))
        
        #Populate each directory with the most recent my_history columns and profile columns
        shutil.copy(os.path.join(os.environ['MIST_CODE_DIR'], 'mesafiles/my_history_columns.list'),\
                os.path.join(path_to_onemassdir, 'my_history_columns.list'))
        #shutil.copy(os.path.join(os.environ['MIST_CODE_DIR'], 'mesafiles/my_profile_columns.list'),\
        #        os.path.join(path_to_onemassdir, 'my_profile_columns.list'))
        shutil.copy(os.path.join(os.environ['MIST_CODE_DIR'], 'mesafiles/run_star_extras.f90'),\
                os.path.join(path_to_onemassdir, 'src/run_star_extras.f90'))
	#shutil.copy(os.path.join(os.environ['MESA_DIR'], 'star/work/star'),\
	#	os.path.join(path_to_onemassdir, 'star'))        

        #Populate each directory with the input abundance file named input_initial_xa.data and input_XYZ
        shutil.copy(os.path.join(os.environ['MIST_CODE_DIR'], 'input_initial_xa.data'), path_to_onemassdir)
        shutil.copy(os.path.join(os.environ['MIST_CODE_DIR'], 'input_XYZ'), path_to_onemassdir)

        #Populate each directory with the opacity configuration file
        #shutil.copy(os.path.join(os.environ['MIST_CODE_DIR'], 'mesafiles/kap_config_file.txt'), path_to_onemassdir)

        #Create and move the SLURM file to the correct directory
        runbasefile = os.path.join(os.environ['MIST_CODE_DIR'], 'mesafiles/SLURM_MISTgrid.sh')
        slurmfile = make_slurm_sh.make_slurm_sh(inlistname, path_to_onemassdir, runbasefile)
        shutil.move(slurmfile, path_to_onemassdir)
        
        #cd into the individual directory and submit the job
        os.chdir(path_to_onemassdir)
        print "sbatch " + slurmfile
        os.system("sbatch "+slurmfile)
        os.chdir(os.environ['MIST_CODE_DIR'])
    
    #Clean up
    os.remove(os.path.join(os.environ['MIST_CODE_DIR'], 'input_initial_xa.data'))
    os.remove(os.path.join(os.environ['MIST_CODE_DIR'], 'input_XYZ'))
    os.remove(os.path.join(os.environ['MIST_CODE_DIR'], 'initial_xa_calculator'))
