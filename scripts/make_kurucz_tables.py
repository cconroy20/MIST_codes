from pylab import *
from scipy.interpolate import interp1d
from matplotlib.colors import Normalize
import matplotlib.cm as cm
from scipy.optimize import curve_fit

norm=Normalize(vmin=-4, vmax=0.5)

f23=2.0/3.0
TAU0=100.0
LOGTAU=log10(TAU0)

TEFF=array([2000.,2500.,2800.,3000.,3200.,3500.,3750.,4000.,4250.,4500.,4750.,5000.,5250.,5500.,5750.,
  6000.,6250.,6500.,6750.,7000.,7250.,7500.,7750.,8000.,8250.,8500.,8750.,9000.,9250.,9500.,9750.,
 10000.,10250.,10500.,10750.,11000.,11250.,11500.,11750.,12000.,12250.,12500.,12750.,13000.,14000.,
 15000.,16000.,17000.,18000.,19000.,20000.,21000.,22000.,23000.,24000.,25000.,26000.,27000.,28000.,
 29000.,30000.,31000.,32000.,33000.,34000.,35000.,36000.,37000.,38000.,39000.,40000.,41000.,42000.,
 43000.,44000.,45000.,46000.,47000.,48000.,49000.,50000.])
LOGG=array([-1. , -0.5,  0. ,  0.5,  1. ,  1.5,  2. ,  2.5,  3. ,  3.5,  4.,  4.5,  5. ,  5.5,  6. ])
NT=len(TEFF)
NG=len(LOGG)

def T_VAL(tau,Teff):
    T4=0.75*pow(Teff,4)*(tau+1.017-0.3*exp(-2.54*tau)-0.291*exp(-30*tau))
    return pow(T4,0.25)

def T_Edd(tau,Teff):
    T4=0.75*pow(Teff,4)*(tau+f23)
    return pow(T4,0.25)

class atm(object):
    def __init__(self,filename):
        self.filename=filename
        self.color=None
        self.data=genfromtxt(self.filename,skip_header=45,skip_footer=2)
        self.Teff, self.logg = self.Teff_logg_from_filename()
        self.logtau=linspace(-6.875,3.0,80)
        self.T_tau=self.T_tau_func()
        self.P_tau=self.P_tau_func()
        #check if radiative or convective;
        #   radiative => T(tau=1000) > 5*Teff
        #   convective => T(tau=1000) < 2*Teff
        if self.T_tau(self.logtau[-1]) > 3.0 * self.Teff:
            self.radiative=1
        else:
            self.radiative=0

    def Teff_logg_from_filename(self):
        #strip leading directories
        x=self.filename.split('/')[-1]
        i=x.index('_t')
        Teff=float(x[i+2:i+7])
        j0=x.index('g')+1
        j1=x.index('.atm')
        logg=float(x[j0:j1])
        return Teff, logg

    def T_tau_func(self):
        x=self.logtau
        y=self.data[:,1] ## T'
        return interp1d(x=x,y=y,kind='cubic')

    def P_tau_func(self):
        x=self.logtau
        y=self.data[:,2] #P
        return interp1d(x=x,y=y,kind='cubic')

    def table(self,logtau):
        #return '{0:12.4f} {1:12.4f} {2:12.4e} {3:12.4e}'.format(self.Teff, self.logg, asscalar(self.T_tau(logtau)), asscalar(self.P_tau(logtau)))
        return '{0:12.4f} {1:12.4f} {2:12.4e} {3:12.4e}'.format(self.Teff, self.logg, self.T_tau(logtau).item(), self.P_tau(logtau).item())


def do_one_table(filename,feh,afe,write_tmp_file=False):
    x=genfromtxt(filename)
    Psurf=-ones((NT,NG))
    Tsurf=-ones((NT,NG))

    for line in x:
        Teff=line[0]
        logg=line[1]
        Ts=line[2]
        Ps=line[3]

        for iT in range(NT):
            for iG in range(NG):
                if TEFF[iT]==Teff and LOGG[iG]==logg:
                    Psurf[iT,iG]=Ps
                    Tsurf[iT,iG]=Ts

    if write_tmp_file:
        newfile=filename+'.tmp'
        print(' writing {0}'.format(newfile))
        with open(newfile,'w') as f:
            for iT in range(NT):
                new_data=concatenate((array([TEFF[iT]]),Psurf[iT,:]))
                line=''.join('{:>15.7e}'.format(q) for q in new_data)
                f.write(line+'\n')
            f.write('#\n')
            for iT in range(NT):
                new_data=concatenate((array([TEFF[iT]]),Tsurf[iT,:]))
                line=''.join('{:>15.7e}'.format(q) for q in new_data)
                f.write(line+'\n')

    #1st pass: fits in y vs. logg
    for iT in range(NT):
        select=squeeze(where(Psurf[iT,:]>0))
        if select.size > 1:
            x=LOGG[select]
            y=log10(Psurf[iT,select])
            f=interp1d(x,y,kind='linear',fill_value='extrapolate')
            Psurf[iT,:] = pow(10,f(LOGG))
            y=log10(Tsurf[iT,select])
            f=interp1d(x,y,kind='linear',fill_value='extrapolate')
            Tsurf[iT,:] = pow(10,f(LOGG))

    #2nd pass: fits in y vs. logT
    for iG in range(NG):
        select=squeeze(where(Psurf[:,iG]>0))
        if select.size > 1:
            x=log10(TEFF[select])
            y=log10(Psurf[select,iG])
            g=interp1d(x,y,kind='linear',fill_value='extrapolate')
            Psurf[:,iG] = pow(10,g(log10(TEFF)))
            y=log10(Tsurf[select,iG])
            g=interp1d(x,y,kind='linear',fill_value='extrapolate')
            Tsurf[:,iG] = pow(10,g(log10(TEFF)))

    #apply T_Edd upper limit for hot stars
    for iT in range(NT):
        Teff=TEFF[iT]
        if Teff > 5000.:
            Tmax=T_Edd(TAU0,Teff)
            for iG in range(NG):
                Tsurf[iT,iG]=min(Tsurf[iT,iG],Tmax)

    newfile=filename+'.tbl'
    print(' writing {0}'.format(newfile))
    with open(newfile,'w') as f:
        f.write('#Table Version   5\n')
        f.write('#[Z/Z_SOLAR]='+feh+' [A/Fe]='+afe+' AG09     | VALID RANGE:   81  81  81  81  81  81  81  81  81  81  81  81  81  81  81  \n')
        f.write('#Teff(K)| Pgas@  log g =-1.00   log g =-0.50   log g = 0.00   log g = 0.50   log g = 1.00   log g = 1.50   log g = 2.00   log g = 2.50   log g = 3.00   log g = 3.50   log g = 4.00   log g = 4.50   log g = 5.00   log g = 5.50   log g = 6.00 \n')
        for iT in range(NT):
            new_data=concatenate((array([TEFF[iT]]),Psurf[iT,:]))
            line=''.join('{:>15.7e}'.format(q) for q in new_data)
            f.write(line+'\n')
        f.write('#Teff(K)|    T@  log g =-1.00   log g =-0.50   log g = 0.00   log g = 0.50   log g = 1.00   log g = 1.50   log g = 2.00   log g = 2.50   log g = 3.00   log g = 3.50   log g = 4.00   log g = 4.50   log g = 5.00   log g = 5.50   log g = 6.00 \n')
        for iT in range(NT):
            new_data=concatenate((array([TEFF[iT]]),Tsurf[iT,:]))
            line=''.join('{:>15.7e}'.format(q) for q in new_data)
            f.write(line+'\n')

    return True




if __name__ == '__main__':
    from os import listdir
    #TESTING
    #fehlist=['+0.00']
    afelist=['+0.0']
    #PRODUCTION
    fehlist=['-1.00','-0.75','-0.50','-0.25','+0.00','+0.25','+0.50']
    #fehlist=['-4.00','-3.50','-3.00','-2.75','-2.50','-2.25','-2.00','-1.75','-1.50','-1.25','-1.00','-0.75','-0.50','-0.25','+0.00','+0.25','+0.50','+0.75']
    #afelist=['-0.2','+0.0','+0.2','+0.4','+0.6']


    close('all')

    log_tau_array=linspace(-3,2,1000)
    tau_array = pow(10,log_tau_array)

    def check(Teff, logg):
        logg_0 = 0.0015*Teff - 8.5
        return logg > logg_0 
    

    a=[]
    
    for i in range(0,len(fehlist),1):
        feh=fehlist[i]
     
        print(feh)
   
        for afe in afelist:
           # m_h = m_div_h(float(feh), float(afe))
            
            dir='c3k_v2.1/at12_feh'+feh+'_afe'+afe+'/atm/'
            out='feh'+feh+'_afe'+afe+'.atm'
            print(dir+' -> '+out)
            
            try:
                y=listdir(dir)
                go_on=True
            except:
                print("dir does not exist")
                go_on=False
            if go_on:
                y.sort()
                with open(out,'w') as f:
                    for x in y:
                        z=atm(dir+x)
                        f.write(z.table(LOGTAU)+'\n')
                do_one_table(out,feh,afe)
