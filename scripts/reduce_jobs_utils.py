import glob
import os
import csv
import subprocess
from shutil import copyfile, move
from datetime import datetime

from scripts import mesa_hist_trim
from scripts import reformat_massname

def gen_summary(rawdirname):
    
    """

    Retrieves various information about the MESA run and writes to a summary file

    Args:
        rawdirname: the name of the grid with the suffix '_raw'
    
    Returns:
        None

    """
    
    #Outputs from the cluster
    listerrfiles = glob.glob(os.path.join(os.environ['MIST_GRID_DIR'], rawdirname) + '/*/*.e')
    listoutfiles = glob.glob(os.path.join(os.environ['MIST_GRID_DIR'], rawdirname) + '/*/*.o')
    
    #Dictionary to store the information about the MESA run
    stat_summary = {}

    #Loop over each model
    for index, file in enumerate(listerrfiles):

        #Declare status and also initialize each iteration
        status = ''

        #Extract the mass of the model
        if 'M_VLM_dir' in file:
            mass = file.split("/")[-2].rstrip('M_VLM_dir/')
        elif 'M_dir' in file:
            mass = file.split("/")[-2].rstrip('M_dir/')
 #       else:
 #           mass = file.split("/")[-2].split('M_')[0] + '_' + file.split("/")[-2].split('M_')[1].rstrip('_dir')

        with open(file, 'r') as errfile:
            errcontent = errfile.readlines()
        with open(listoutfiles[index], 'r') as outfile:
            outcontent = outfile.readlines()

        keep_going = True
        ff = os.path.join(os.environ['MIST_GRID_DIR'],rawdirname.split("_raw")[0]) + '/eeps/'+mass+'M.track.eep'
        try:
            fp = open(ff, "r")
        except IOError:
            ff = os.path.join(os.environ['MIST_GRID_DIR'],rawdirname.split("_raw")[0]) + '/eeps/'+mass+'M_VLM.track.eep'
            try:
                fp = open(ff, "r")
            except IOError:
                keep_going = False
                status = "FAILED"
                termination_reason = " "
                reason = "not found"

        if keep_going:
            eep_len = len(fp.readlines())

            status = 'FAILED'
            termination_reason = ''
            reason = '-- unknown --'

            #Retrieve the stopping reasons
            for line in outcontent[-500:]:
                if 'termination code' in line:
                    termination_reason = line.split('termination code: ')[1].split('\n')[0]
                    reason = termination_reason.replace(' ', '_')
                    if reason == 'min_timestep_limit':
                        status = 'FAILED'
                    else:
                        status = 'OK'
                if 'failed in do_relax_num_steps' in line:
                    termination_reason = 'failed_during_preMS'
                    reason = termination_reason.replace(' ', '_')
                    status = 'FAILED'

            if reason == 'central_C12_mass_fraction_below_1e-2':
                reason = 'stopping_at_cenC12_limit'

            if reason == 'central_H1_mass_fraction_below_0.01':
                reason = 'stopping_at_cenH1_limit'

            if reason == 'logQ_min_limit':
                status = 'FAILED'

            if status != 'OK':
                if (len(errcontent) > 0):
                    for line in errcontent:
                        if 'DUE TO TIME LIMIT' in line:
                            reason = 'hit time limit'
                for line in outcontent:
                    if 'now at TP-AGB phase' in line:
                        reason = '@ TP-AGB phase'
                    if 'now at late AGB phase' in line:
                        reason = '@ late-AGB phase'
                    if 'now at post AGB phase' in line:
                        #reason = '@ post-AGB phase'
                        reason = 'stopping_at_post_AGB'
                        status = 'OK'
                    if 'now at WD phase' in line:
                        #reason = '@ WD phase'
                        reason = 'stopping_at_post_AGB'
                        status = 'OK'
                  #  for line in errcontent:
                  #      if 'DUE TO TIME LIMIT' in line:
                  #          reason = 'need_more_time'
                  #          break
                  #      elif 'exceeded memory limit' in line:
                  #          reason = 'memory_exceeded'
                  #          break
                  #      elif 'Socket timed out on send/recv operation' in line:
                  #          reason = 'socket_timed_out'

            if (float(mass)/100. < 7.0 and eep_len >= 1421):
                status = 'OK'
                reason = 'stopping_at_post_AGB'

            if (float(mass)/100. >= 7.0 and eep_len >= 820):
                status = 'OK'
                reason = 'stopping_at_cenC12_limit'

            # +DATE: %Y-%m-%d%nTIME: %H:%M:%S
            #Retrieve the run time information
            dates = subprocess.Popen('grep [0-9][0-9]:[0-9][0-9]:[0-9][0-9] ' + listoutfiles[index], shell=True, stdout=subprocess.PIPE)
            try:
                startdate, enddate = dates.stdout
                startdate_fmt = datetime.strptime(startdate.decode('ascii').rstrip('\n').strip('START: '), '%Y-%m-%d %H:%M:%S')
                enddate_fmt = datetime.strptime(enddate.decode('ascii').rstrip('\n').strip('END: '), '%Y-%m-%d %H:%M:%S')

                delta_time = (enddate_fmt - startdate_fmt)
                #Total run time in decimal hours
                runtime = delta_time.total_seconds()/(3600.0)

            #If there is no end date
            except ValueError:
                runtime = -1.

            #Populate the stat_summary dictionary
            stat_summary[mass] = "{:10}".format(status) + "{:28}".format(reason) + "{:4.1f}".format(runtime) + "{:12d}".format(eep_len)

    keys = stat_summary.keys()
    #Sort by mass in ascending order
    keys.sort()
    
    #Write to a file
    summary_filename = "tracks_summary_"+rawdirname.split("_raw")[0]+".txt"
    f = csv.writer(open(summary_filename, 'w'), delimiter='\t')
    f.writerow(["{:6}".format('# Mass'), "{:10}".format('Status') + "{:25}".format('Reason') + "{:13}".format('Runtime (hr)') + "{:5}".format('EEP len')])
    f.writerow(['','','',''])
    
    for key in keys:
        f.writerow([" "+"{:.2f}".format(float(key)/100.), stat_summary[key]])
        
def sort_histfiles(rawdirname,merge_TPAGB=False):
    
    """

    Organizes the history files and creates a separate directory.
    Option added to merge an existing track with a TP-AGB restart.

    Args:
        rawdirname: the name of the grid with the suffix '_raw'
        merge_TPAGB: logical (default True)
    
    Returns:
        None

    """

    blend_VLM = True

    #Get the list of history files (tracks)
    listofhist = glob.glob(os.path.join(os.environ['MIST_GRID_DIR'], os.path.join(rawdirname+'/*/LOGS/*.data')))

    #Make the track directory in the new reduced MESA run directory
    new_parentdirname = rawdirname.split("_raw")[0]
    histfiles_dirname = os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], new_parentdirname + "/tracks"))
    os.mkdir(histfiles_dirname)

    #if blend_VLM

    #Merge TP-AGB rerun if it exists
    if merge_TPAGB:
        for histfile in listofhist:
            L1=False
            L2=False
            date_check=False

            if 'M.data' in histfile:
                file1=histfile
                f1=open(file1,'r')
                f1_data=f1.readlines()
                f1.close()
                L1=True
                date1=datetime.strptime(f1_data[2].split()[4].strip('"'),'%Y%m%d')

                file2=file1.strip('M.data')+'M_TPAGB.data'
                if os.path.isfile(file2):
                    f2=open(file2,'r')
                    f2_data=f2.readlines()
                    f2.close()
                    L2=True
                    date2=datetime.strptime(f2_data[2].split()[4].strip('"'),'%Y%m%d')

                    date_check = date2 > date1

            if L1 and L2 and date_check:
                q=file1.index('.data')
                file3=file1[0:q]+'_orig.data'
                copyfile(file1,file3)

                info = f2_data[6].split()
                split=int(info[0].strip())

                for k in range(6,len(f1_data)):
                    i=f1_data[k].split()
                    s=int(i[0].strip())
                    if s > split-1:
                        before=k
                        break

                tmpfile='tmp.data'
                f3=open(tmpfile,'w')

                for i in range(before):
                    f3.write(f1_data[i])

                for i in range(6,len(f2_data)):
                    f3.write(f2_data[i])

                f3.close()
                move(tmpfile,file1)


    #Trim repeated model numbers, then rename & copy the history files over
    for histfile in listofhist:
        print 'processing', histfile
        if 'M_VLM.data' in histfile:
            unformat_mass_string = histfile.split('LOGS/')[1].split('M_VLM.data')[0]
            newhistfilename = histfile.split('LOGS')[0]+'LOGS/'+reformat_massname.reformat_massname(unformat_mass_string)+'M_VLM.track'
            os.system("cp " + histfile + " " + newhistfilename)
            mesa_hist_trim.trim_file(newhistfilename)
            os.system("mv " + newhistfilename + " " + histfiles_dirname)

        elif 'M.data' in histfile:
            unformat_mass_string = histfile.split('LOGS/')[1].split('M.data')[0]
            newhistfilename = histfile.split('LOGS')[0]+'LOGS/'+reformat_massname.reformat_massname(unformat_mass_string)+'M.track'
            os.system("cp " + histfile + " " + newhistfilename)
            mesa_hist_trim.trim_file(newhistfilename)
            os.system("mv " + newhistfilename + " " + histfiles_dirname)
        
def save_inlists(rawdirname):

    """

    Organizes the inlist files.

    Args:
        rawdirname: the name of the grid with the suffix '_raw'
    
    Returns:
        None

    """
    
    #Get the list of inlist files
    listofinlist = glob.glob(os.path.join(os.environ['MIST_GRID_DIR'], os.path.join(rawdirname+'/*/inlist_project')))

    #Nake the inlist directory in the new reduced MESA run directory
    new_parentdirname = rawdirname.split("_raw")[0]
    inlistfiles_dirname = os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], new_parentdirname), "inlists")
    os.mkdir(inlistfiles_dirname)
    
    #Copy the inlist files from the general inlist directory in MESAWORK_DIR to the newly created inlist directory
    for inlistfile in listofinlist:
        format_mass_string = inlistfile.split('/')[-2].split('M_')[0]
        if 'M_dir' in inlistfile:
            newinlistfilename = os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], new_parentdirname),'inlists/'+format_mass_string+'M.inlist')
        else:
            bc_name = inlistfile.split('raw/')[1].split('M_')[1].split('_')[0]
            newinlistfilename = os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], new_parentdirname),'inlists/'+format_mass_string+'M_'+bc_name+'.inlist')
        os.system("cp " + inlistfile + " " + newinlistfilename)

def save_lowM_photo_model(rawdirname):
    
    """

    Saves the .mod and photo saved at postAGB for the low mass stars.

    Args:
        rawdirname: the name of the grid with the suffix '_raw'
    
    Returns:
        None

    """
    
    #Get the list of photos and models
    listofphoto = glob.glob(os.path.join(os.environ['MIST_GRID_DIR'], os.path.join(rawdirname+'/*/photos/pAGB_photo')))
    listofmod = glob.glob(os.path.join(os.environ['MIST_GRID_DIR'], os.path.join(rawdirname+'/*/*pAGB.mod')))

    #Nake the inlist directory in the new reduced MESA run directory
    new_parentdirname = rawdirname.split("_raw")[0]
    models_photos_files_dirname = os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], new_parentdirname), "models_photos")
    os.mkdir(models_photos_files_dirname)
    
    #check first if these files exist in case the grid consists only of high mass stars.
    if len(listofphoto) < 1:
        print "THERE ARE NO PHOTOS OR MODELS SAVED AT THE POST-AGB PHASE."
    else:
        for i in range(len(listofphoto)):
            format_mass_string = listofphoto[i].split('/')[-3].split('M_')[0]
            newphotofilename = os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], new_parentdirname),'models_photos/'+format_mass_string+'M_pAGB.photo')
            newmodfilename = os.path.join(os.path.join(os.environ['MIST_GRID_DIR'], new_parentdirname),'models_photos/'+format_mass_string+'M_pAGB.mod')
            os.system("cp " + listofphoto[i] + " " + newphotofilename)
            os.system("cp " + listofmod[i] + " " + newmodfilename)

