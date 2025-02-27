!     ***********************************************************************
!
!     Copyright (C) 2010  Bill Paxton
!
!     this file is part of mesa.
!
!     mesa is free software; you can redistribute it and/or modify
!     it under the terms of the gnu general library public license as published
!     by the free software foundation; either version 2 of the license, or
!     (at your option) any later version.
!
!     mesa is distributed in the hope that it will be useful,
!     but without any warranty; without even the implied warranty of
!     merchantability or fitness for a particular purpose.  see the
!     gnu library general public license for more details.
!
!     you should have received a copy of the gnu library general public license
!     along with this software; if not, write to the free software
!     foundation, inc., 59 temple place, suite 330, boston, ma 02111-1307 usa
!
!     ***********************************************************************
module run_star_extras

  use star_lib
  use star_def
  use const_def
  use crlibm_lib
  use atm_lib
  use atm_def

  implicit none

  real(dp) :: original_diffusion_dt_limit
  logical :: rot_set_check = .false.
  logical :: TP_AGB_check = .false.
  logical :: late_AGB_check = .false.
  logical :: post_AGB_check = .false.
  logical :: pre_WD_check = .false.

  
contains

  subroutine extras_controls(id, ierr)
    integer, intent(in) :: id
    integer, intent(out) :: ierr
    type (star_info), pointer :: s
    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return

    s% other_am_mixing => TSF

    s% extras_startup => extras_startup
    s% extras_check_model => extras_check_model
    s% extras_finish_step => extras_finish_step
    s% extras_after_evolve => extras_after_evolve
    s% how_many_extra_history_columns => how_many_extra_history_columns
    s% data_for_extra_history_columns => data_for_extra_history_columns
    s% how_many_extra_profile_columns => how_many_extra_profile_columns
    s% data_for_extra_profile_columns => data_for_extra_profile_columns

    s% job% warn_run_star_extras =.false.

    original_diffusion_dt_limit = s% diffusion_dt_limit

  end subroutine extras_controls


  integer function extras_startup(id, restart, ierr)
    integer, intent(in) :: id
    logical, intent(in) :: restart
    integer, intent(out) :: ierr
    type (star_info), pointer :: s
    integer :: j, cid
    real(dp) :: frac, vct30, vct100
    character(len=256) :: summary
    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return
    extras_startup = 0
    if (.not. restart) then
       call alloc_extra_info(s)
    else
       call unpack_extra_info(s)
    end if

    if (.not. s% job% extras_lpar(1)) rot_set_check = .true.

    if(s% initial_mass < 10.0d0 .and. s% initial_mass >= 0.6d0)then
       TP_AGB_check=.true.
    endif

    if(s% initial_mass <= 4.0d0) then 
    !FULLER et al. TAYLER-SPRUIT
       s% am_nu_ST_factor = 0.0d0
       s% use_other_am_mixing = .true.
       s% am_time_average = .true.
       s% premix_omega = .true.
       s% recalc_mixing_info_each_substep = .true.
       s% am_nu_factor = 1.0d0
       s% am_nu_non_rotation_factor = 1.0d0
       s% am_nu_visc_factor = 0.333d0
       s% angsml = 0.0d0
    !FULLER et al. TAYLER-SPRUIT
    endif

    !increase overshoot from 4 Msun up to the Brott et al. value at 8 Msun
    !s% overshoot_f_above_burn_h_core   = f_ov_fcn_of_mass(s% initial_mass)
    s% overshoot_f_above_burn_h_core   = 0.016_dp
    s% overshoot_f0_above_burn_h_core  = 8.0d-3

    !now set f_ov_below_nonburn from [Fe/H] at extras_cpar(4)
    s% overshoot_f_below_nonburn_shell = f_ov_below_nonburn(s% job% extras_rpar(4), s% initial_mass)
    s% overshoot_f0_below_nonburn_shell = 0.5d0 * s% overshoot_f_below_nonburn_shell

    !set the correct summary file for the BC tables depending on [a/Fe]        
    if(trim(s% which_atm_option)=='tau_10_tables')then
      summary = 'table10_summary_' // trim(s% job% extras_cpar(1)) // '.txt'
      call table_atm_init(summary, ierr)
    elseif(trim(s% which_atm_option)=='tau_100_tables')then
      summary = 'table100_summary_' // trim(s% job% extras_cpar(1)) // '.txt'
      call table_atm_init(summary,ierr)
    endif
  end function extras_startup


  function f_ov_below_nonburn(feh,minit) result(f_ov)
    real(dp), intent(in) :: feh, minit
    real(dp) :: f_ov
    real(dp), parameter :: max_f = 8.0d-2
    real(dp), parameter :: min_f = 1.0d-2
    if (minit < 2.0_dp) then
      f_ov = 0.016_dp - 0.027_dp*feh
      f_ov = min(max(f_ov, min_f),max_f)
    else
      f_ov = 0.016_dp
    endif
  end function f_ov_below_nonburn


  function f_ov_fcn_of_mass(m) result(f_ov)
    real(dp), intent(in) :: m
    real(dp) :: f_ov, frac
    real(dp), parameter :: f1 = 0.016_dp, f2 = 0.0415_dp
    if(m < 4.0d0) then
       frac = 0.0d0
    elseif(m > 8.0d0) then
       frac = 1.0d0
    else
       frac = 0.5_dp * (1.0_dp - cos( pi * 0.25_dp*(m - 4._dp) ))
    endif
    f_ov = f1 + (f2-f1)*frac
  end function f_ov_fcn_of_mass

  integer function extras_check_model(id, id_extra)
    integer, intent(in) :: id, id_extra
    integer :: ierr
    type (star_info), pointer :: s
    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return
    extras_check_model = keep_going

    !if(s% model_number > 100 .and. s% initial_mass < 5._dp ) s% use_other_surface_pt = .true.
    
  end function extras_check_model

  integer function how_many_extra_history_columns(id, id_extra)
    integer, intent(in) :: id, id_extra
    integer :: ierr
    type (star_info), pointer :: s
    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return
    how_many_extra_history_columns = 9
  end function how_many_extra_history_columns

  subroutine data_for_extra_history_columns(id, id_extra, n, names, vals, ierr)
    integer, intent(in) :: id, id_extra, n
    character (len=maxlen_history_column_name) :: names(n)
    real(dp) :: vals(n)
    integer, intent(out) :: ierr
    type (star_info), pointer :: s
    real(dp) :: ocz_top_radius, ocz_bot_radius, &
         ocz_top_mass, ocz_bot_mass, mixing_length_at_bcz, &
         dr, ocz_turnover_time_g, ocz_turnover_time_l_b, ocz_turnover_time_l_t, &
         env_binding_E, total_env_binding_E, MoI
    integer :: i, k, n_conv_bdy, nz, k_ocz_bot, k_ocz_top

    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return

    ! output info about the CONV. ENV.: the CZ location, turnover time
    nz = s% nz
    n_conv_bdy = s% num_conv_boundaries
    i = s% n_conv_regions
    k_ocz_bot = 0
    k_ocz_top = 0
    ocz_turnover_time_g = 0
    ocz_turnover_time_l_b = 0
    ocz_turnover_time_l_t = 0
    ocz_top_mass = 0.0
    ocz_bot_mass = 0.0
    ocz_top_radius = 0.0
    ocz_bot_radius = 0.0

    !check the outermost convection zone
    !if dM_convenv/M < 1d-8, there's no conv env.
    if (s% n_conv_regions > 0) then
       if ((s% cz_top_mass(i)/s% mstar > 0.99d0) .and. &
            ((s% cz_top_mass(i)-s% cz_bot_mass(i))/s% mstar > 1d-11)) then

          ocz_bot_mass = s% cz_bot_mass(i)
          ocz_top_mass = s% cz_top_mass(i)
          !get top radius information
          !start from k=2 (second most outer zone) in order to access k-1
          do k=2,nz
             if (s% m(k) < ocz_top_mass) then
                ocz_top_radius = s% r(k-1)
                k_ocz_top = k-1
                exit
             end if
          end do
          !get top radius information
          do k=2,nz
             if (s% m(k) < ocz_bot_mass) then
                ocz_bot_radius = s% r(k-1)
                k_ocz_bot = k-1
                exit
             end if
          end do

          !if the star is fully convective, then the bottom boundary is the center
          if ((k_ocz_bot == 0) .and. (k_ocz_top > 0)) then
             k_ocz_bot = nz
          end if

          !compute the "global" turnover time
          do k=k_ocz_top,k_ocz_bot
             if (k==1) cycle
             dr = s%r(k-1)-s%r(k)
             ocz_turnover_time_g = ocz_turnover_time_g + (dr/s%conv_vel(k))
          end do

          !compute the "local" turnover time half of a scale height above the BCZ
          mixing_length_at_bcz = s% mlt_mixing_length(k_ocz_bot)
          do k=k_ocz_top,k_ocz_bot
             if (s% r(k) < (s% r(k_ocz_bot)+0.5d0*(mixing_length_at_bcz))) then
                ocz_turnover_time_l_b = mixing_length_at_bcz/s% conv_vel(k)
                exit
             end if
          end do

          !compute the "local" turnover time one scale height above the BCZ
          do k=k_ocz_top,k_ocz_bot
             if (s% r(k) < (s% r(k_ocz_bot)+1.0d0*(mixing_length_at_bcz))) then
                ocz_turnover_time_l_t = mixing_length_at_bcz/s% conv_vel(k)
                exit
             end if
          end do
       end if
    endif

    names(1) = 'conv_env_top_mass'
    vals(1) = ocz_top_mass/msun
    names(2) = 'conv_env_bot_mass'
    vals(2) = ocz_bot_mass/msun
    names(3) = 'conv_env_top_radius'
    vals(3) = ocz_top_radius/rsun
    names(4) = 'conv_env_bot_radius'
    vals(4) = ocz_bot_radius/rsun
    names(5) = 'conv_env_turnover_time_g'
    vals(5) = ocz_turnover_time_g
    names(6) = 'conv_env_turnover_time_l_b'
    vals(6) = ocz_turnover_time_l_b
    names(7) = 'conv_env_turnover_time_l_t'
    vals(7) = ocz_turnover_time_l_t

    ! output info about the ENV.: binding energy

    total_env_binding_E = 0.0d0
    do k=1,s% nz
       if (s% m(k) > (s% he_core_mass * Msun)) then !envelope is defined to be H-rich
          env_binding_E = s% dm(k) * (s% energy(k) - (s% cgrav(1) * s% m(k))/s% r(k))
          total_env_binding_E = total_env_binding_E + env_binding_E
       end if
    end do

    names(8) = 'envelope_binding_energy'
    vals(8) = total_env_binding_E

    names(9) = 'total_moment_of_inertia'
    MoI = 0.0d0
    if(.not.s% rotation_flag)then
       do i=s% nz, 2, -1
          MoI = MoI + 0.4d0*s% dm_bar(i)*(pow5(s% r(i)) - pow5(s% r(i-1)))/(pow3(s% r(i)) - pow3(s% r(i-1)))
       enddo
    else
       MoI = dot_product(s% dm_bar(1:s% nz), s% i_rot(1:s% nz))
    endif

    vals(9) = MoI

  end subroutine data_for_extra_history_columns

  integer function how_many_extra_profile_columns(id, id_extra)
    use star_def, only: star_info
    integer, intent(in) :: id, id_extra
    integer :: ierr
    type (star_info), pointer :: s

    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return
    how_many_extra_profile_columns = 0

  end function how_many_extra_profile_columns


  subroutine data_for_extra_profile_columns(id, id_extra, n, nz, names, vals, ierr)
    use star_def, only: star_info, maxlen_profile_column_name
    integer, intent(in) :: id, id_extra, n, nz
    character (len=maxlen_profile_column_name) :: names(n)
    real(dp) :: vals(nz,n)
    integer, intent(out) :: ierr
    type (star_info), pointer :: s
    integer :: k
    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return
  end subroutine data_for_extra_profile_columns


  integer function extras_finish_step(id, id_extra)
    integer, intent(in) :: id, id_extra
    integer :: ierr
    real(dp) :: envelope_mass_fraction, L_He, L_tot, min_center_h1_for_diff, &
         critmass, feh, rot_full_off, rot_full_on, frac2
    real(dp), parameter :: huge_dt_limit = 3.15d16 ! ~1 Gyr
    real(dp), parameter :: new_varcontrol_target = 1d-3
    real(dp), parameter :: Zsol = 0.0142
    type (star_info), pointer :: s
    logical :: diff_test1, diff_test2, diff_test3
    character (len=strlen) :: photoname, stuff

    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return
    extras_finish_step = keep_going
    call store_extra_info(s)

    ! set ROTATION: extra param are set in inlist: star_job
    rot_full_off = s% job% extras_rpar(1) !1.2
    rot_full_on = s% job% extras_rpar(2) !1.8

    !IF (s% star_age > 1.d7) THEN 
    !   s% log_L_upper_limit = 2.8
    !ENDIF

    if (rot_set_check) then
       if ((s% job% extras_rpar(3) > 0.0d0) .and. (s% initial_mass > rot_full_off)) then
          !check if ZAMS is achieved, then set rotation
          if ((abs(log10_cr(s% power_h_burn * Lsun / s% L(1))) < 1.0d-2) .and. (s% star_age > 1.0d2)) then
             if (s% initial_mass <= rot_full_on) then
                frac2 = (s% initial_mass - rot_full_off) / (rot_full_on - rot_full_off)
                frac2 = 0.5d0*(1.0d0 - cos(pi*frac2))
             else
                frac2 = 1.0d0
             end if
             write(*,*) '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
             write(*,*) 'new omega_div_omega_crit, fraction', s% job% extras_rpar(3) * frac2, frac2
             write(*,*) '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
             s% job% new_omega_div_omega_crit = s% job% extras_rpar(3) * frac2
             s% job% set_near_zams_omega_div_omega_crit_steps = 10
             rot_set_check = .false.
          end if
       else
          write(*,*) '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
          write(*,*) 'no rotation'
          write(*,*) '+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++'
          rot_set_check = .false.
       end if
    end if

    ! TP-AGB
    if(TP_AGB_check .and. s% have_done_TP)then
       TP_AGB_check = .false.
       late_AGB_check = .true.
       !s% which_atm_option = 'simple_photosphere'
       write(*,*) '++++++++++++++++++++++++++++++++++++++++++'
       write(*,*) 'now at TP-AGB phase, model number ', s% model_number
       !save a model and photo
       call star_write_model(id, 'TPAGB.mod', ierr)
       photoname = 'photos/TPAGB_photo'
       call star_save_for_restart(id, photoname, ierr)
       s% delta_lgTeff_limit = -1
       s% delta_lgTeff_hard_limit = -1
       s% delta_lgL_limit = -1
       s% delta_lgL_hard_limit = -1
       !s% Blocker_scaling_factor = 2.0d0
       s% varcontrol_target = 2.0d0*s% varcontrol_target
       write(*,*) ' varcontrol_target = ', s% varcontrol_target
       !write(*,*) ' switch to simple_photosphere             '
       write(*,*) '++++++++++++++++++++++++++++++++++++++++++'
    endif

    ! late AGB
    if(late_AGB_check)then
       if (s% initial_mass < 10.0d0 .and. s% he_core_mass/s% star_mass > 0.95d0) then
          write(*,*) '++++++++++++++++++++++++++++++++++++++++++'
          write(*,*) 'now at late AGB phase, model number ', s% model_number
          write(*,*) '++++++++++++++++++++++++++++++++++++++++++'
          photoname = 'photos/late_AGB_photo'
          call star_save_for_restart(id, photoname, ierr)
          !s% Blocker_scaling_factor = 2.0d0
          late_AGB_check=.false.
          post_AGB_check=.true.
       endif
    endif

    if(post_AGB_check)then
       if(s% Teff > 1.0d4)then
          write(*,*) '++++++++++++++++++++++++++++++++++++++++++'
          write(*,*) 'now at post AGB phase, model number ', s% model_number
          !save a model and photo
          call star_write_model(id, 'postAGB.mod', ierr)
          photoname = 'photos/pAGB_photo'
          call star_save_for_restart(id, photoname, ierr)
          if(s% job% extras_lpar(2))then
             s% max_abar_for_burning = -1
             write(*,*) 'turn off burning for post-AGB'
          endif
          post_AGB_check = .false.
          pre_WD_check = .true.

          termination_code_str(t_xtra2) = 'stopping at post AGB'
          s% termination_code = t_xtra2
          extras_finish_step = terminate

          write(*,*) '++++++++++++++++++++++++++++++++++++++++++'
       endif
    endif

    ! pre-WD
    if(pre_WD_check)then
       if(s% Teff < 3.0d4 .and. s% L_surf < 1.0d0)then
          pre_WD_check = .false.
          !turn burning back on for WD phase
          !if(s% max_abar_for_burning < 0) s% max_abar_for_burning = 200
          write(*,*) '++++++++++++++++++++++++++++++++++++++++++++++'
          write(*,*) 'now at WD phase, model number ', s% model_number
          write(*,*) '++++++++++++++++++++++++++++++++++++++++++++++'
       endif
    endif

    ! define STOPPING CRITERION: stopping criterion for C burning, massive stars.
    if ((s% center_h1 < 1d-4) .and. (s% center_he4 < 5.0d-2) .and. (s% center_c12 < 5.0d-2)) then
       termination_code_str(t_xtra2) = 'central C12 mass fraction below 5e-2'
       s% termination_code = t_xtra2
       extras_finish_step = terminate
    endif

    ! define STOPPING CRITERION: stopping criterion for TAMS, low mass stars.
    if ((s% center_h1 < 1d-2) .and. (s% initial_mass <= 0.6d0) .and. (s% star_age > 5.0d10) )then
       termination_code_str(t_xtra2) = 'central H1 mass fraction below 0.01'
       s% termination_code = t_xtra2
       extras_finish_step = terminate
    endif

    ! check DIFFUSION: to determine whether or not diffusion should happen
    ! no diffusion for fully convective, post-MS, and mega-old models
    ! do diffusion during the WD phase
    min_center_h1_for_diff = 1d-10
    diff_test1 = abs(s% mass_conv_core - s% star_mass) < 1d-2 !fully convective
    diff_test2 = s% star_age > 1.0d11 !really old
    !diff_test3 = .false. !s% center_h1 < min_center_h1_for_diff !past the main sequence
    diff_test3 = s% center_h1 < min_center_h1_for_diff !past the main sequence
    if( diff_test1 .or. diff_test2 .or. diff_test3 )then
       s% diffusion_dt_limit = huge_dt_limit
    else
       s% diffusion_dt_limit = original_diffusion_dt_limit
    end if

  end function extras_finish_step


  ! borrowed directly from atm/private/table_atm.f90;
  ! modified to deallocate allocated arrays before allocating them again with new dimensions
  subroutine table_atm_init(tau10_summary, ierr)
    implicit none
    character(len=256) :: tau10_summary
    integer, intent(out) :: ierr
    type(Atm_info), pointer :: ai
    integer :: nZ, ng, nT, i, j, iounit
    integer, pointer :: ibound(:,:), tmp_version(:)
    character(len=256) :: filename

    ierr = 0
    if (ierr /= 0) return

    ai => ai_10

    call load_table_summary(atm_tau_10_tables, tau10_summary, ai, ierr)
    if (ierr /= 0) return

    print *, 'loaded ', trim(tau10_summary)

    table_atm_is_initialized = .true.

  contains

    subroutine load_table_summary(which_atm_option, fname, ai, ierr)
      use const_def, only: mesa_data_dir
      use crlibm_lib, only: str_to_vector
      integer, intent(in) :: which_atm_option
      character(len=*), intent(in) :: fname
      type (Atm_Info), pointer :: ai
      integer, intent(out) :: ierr

      integer :: nvec
      character (len=500) :: buf
      real(dp), target :: vec_ary(20)
      real(dp), pointer :: vec(:)

      vec => vec_ary

      filename = trim(mesa_data_dir)//'/atm_data/' // trim(fname)

      write(*,*) trim(filename)

      open(iounit,file=trim(filename),action='read',status='old',iostat=ierr)
      if (ierr/= 0) then
         write(*,*) 'table_atm_init: missing atm data'
         write(*,*) trim(filename)
         write(*,*)
         write(*,*)
         write(*,*)
         write(*,*)
         write(*,*)
         write(*,*) 'FATAL ERROR: missing or bad atm data.'
         call mesa_error(__FILE__,__LINE__)
      endif

      !read first line and (nZ, nT, ng)
      read(iounit,*)            !first line is text, skip it
      read(iounit,*) nZ, nT, ng

      ai% nZ = nZ
      ai% nT = nT
      ai% ng = ng
      ai% which_atm_option = which_atm_option

      deallocate(ai% Teff_array, ai% logg_array, ai% Teff_bound, ai% logZ, ai% alphaFe, &
           ai% Pgas_interp1, ai% T_interp1, ai% have_atm_table, ai% atm_mix, ai% table_atm_files)

      allocate( &
           ai% Teff_array(nT), ai% logg_array(ng), ai% Teff_bound(ng), &
           ai% logZ(nZ), ai% alphaFe(nZ), &
           ai% Pgas_interp1(4*ng*nT*nZ), ai% T_interp1(4*ng*nT*nZ), &
           ai% have_atm_table(nZ), ai% atm_mix(nZ), ai% table_atm_files(nZ))

      ai% Pgas_interp(1:4,1:ng,1:nT,1:nZ) => ai% Pgas_interp1(1:4*ng*nT*nZ)
      ai% T_interp(1:4,1:ng,1:nT,1:nZ) => ai% T_interp1(1:4*ng*nT*nZ)

      allocate(ibound(ng,nZ), tmp_version(nZ))

      ai% have_atm_table(:) = .false.

      !read filenames and headers
      read(iounit,*)            !text
      do i=1,nZ
         read(iounit,'(a)') ai% table_atm_files(i)
         read(iounit,'(14x,i4)') tmp_version(i)
         read(iounit,1) ai% logZ(i), ai% alphaFe(i), ai% atm_mix(i), ibound(1:ng,i)
         ibound(1:ng,i) = ibound(1,i)
      enddo

      !read Teff_array
      read(iounit,*)            !text
      read(iounit,2) ai% Teff_array(:)

      !do i = 1,ai% nT
      !   ai% Teff_array(i) = log_cr(ai% Teff_array(i))
      !enddo

      !read logg_array
      read(iounit,*)            !text
      read(iounit,3) ai% logg_array(:)

      close(iounit)

1     format(13x,f5.2,8x,f4.1,1x,a8,1x,15x,99i4)
2     format(13f7.0)
3     format(13f7.2)

      !determine table boundaries
      do i=1,ng           ! -- for each logg, smallest Teff at which Pgas->0
         ai% Teff_bound(i) = ai% Teff_array(ibound(i,1))
         do j=2,nZ
            ai% Teff_bound(i) = min( ai% Teff_bound(i) , ai% Teff_array(ibound(i,j)) )
         enddo
      enddo

      deallocate(ibound, tmp_version)

    end subroutine load_table_summary

  end subroutine table_atm_init



  subroutine extras_after_evolve(id, id_extra, ierr)
    integer, intent(in) :: id, id_extra
    integer, intent(out) :: ierr
    type (star_info), pointer :: s
    ierr = 0
    call star_ptr(id, s, ierr)
    if (ierr /= 0) return
  end subroutine extras_after_evolve


  subroutine alloc_extra_info(s)
    integer, parameter :: extra_info_alloc = 1
    type (star_info), pointer :: s
    call move_extra_info(s,extra_info_alloc)
  end subroutine alloc_extra_info


  subroutine unpack_extra_info(s)
    integer, parameter :: extra_info_get = 2
    type (star_info), pointer :: s
    call move_extra_info(s,extra_info_get)
  end subroutine unpack_extra_info


  subroutine store_extra_info(s)
    integer, parameter :: extra_info_put = 3
    type (star_info), pointer :: s
    call move_extra_info(s,extra_info_put)
  end subroutine store_extra_info


  subroutine move_extra_info(s,op)
    integer, parameter :: extra_info_alloc = 1
    integer, parameter :: extra_info_get = 2
    integer, parameter :: extra_info_put = 3
    type (star_info), pointer :: s
    integer, intent(in) :: op

    integer :: i, j, num_ints, num_dbls, ierr

    i = 0
    num_ints = i

    i = 0
    num_dbls = i

    if (op /= extra_info_alloc) return
    if (num_ints == 0 .and. num_dbls == 0) return

    ierr = 0
    call star_alloc_extras(s% id, num_ints, num_dbls, ierr)
    if (ierr /= 0) then
       write(*,*) 'failed in star_alloc_extras'
       write(*,*) 'alloc_extras num_ints', num_ints
       write(*,*) 'alloc_extras num_dbls', num_dbls
       stop 1
    end if

  contains

    subroutine move_dbl(dbl)
      real(dp) :: dbl
      i = i+1
      select case (op)
      case (extra_info_get)
         dbl = s% extra_work(i)
      case (extra_info_put)
         s% extra_work(i) = dbl
      end select
    end subroutine move_dbl

    subroutine move_int(int)
      integer :: int
      i = i+1
      select case (op)
      case (extra_info_get)
         int = s% extra_iwork(i)
      case (extra_info_put)
         s% extra_iwork(i) = int
      end select
    end subroutine move_int

    subroutine move_flg(flg)
      logical :: flg
      i = i+1
      select case (op)
      case (extra_info_get)
         flg = (s% extra_iwork(i) /= 0)
      case (extra_info_put)
         if (flg) then
            s% extra_iwork(i) = 1
         else
            s% extra_iwork(i) = 0
         end if
      end select
    end subroutine move_flg

  end subroutine move_extra_info


  subroutine TSF(id, ierr)

    integer, intent(in) :: id
    integer, intent(out) :: ierr
    type (star_info), pointer :: s
    integer :: k,j,op_err,nsmooth,nsmootham
    real(dp) :: alpha,shearsmooth,nu_tsf,nu_tsf_t,omegac,omegag,omegaa,&
    omegat,difft,diffm,brunts,bruntsn2,logamnuomega,alphaq

    call star_ptr(id,s,ierr)
    if (ierr /= 0) return

    alpha=1d0
    nsmooth=5
    nsmootham=nsmooth-3
    shearsmooth=1d-30
    op_err = 0

    !Calculate shear at each zone, then calculate TSF torque
    do k=nsmooth+1,s% nz-(nsmooth+1)

        nu_tsf=1d-30
        nu_tsf_t=1d-30
        !Calculate smoothed shear, q= dlnOmega/dlnr
        shearsmooth = s% omega_shear(k)/(2d0*nsmooth+1d0)
        do j=1,nsmooth
            shearsmooth = shearsmooth + (1d0/(2d0*nsmooth+1d0))*( s% omega_shear(k-j) + s% omega_shear(k+j) )
        end do

        diffm =  diffmag(s% rho(k),s% T(k),s% abar(k),s% zbar(k),op_err) !Magnetic diffusivity
        difft = 16d0*5.67d-5*pow3(s% T(k))/(3d0*s% opacity(k)*pow2(s% rho(k))*s% Cv(k)) !Thermal diffusivity
        omegaa = s% omega(k)*pow_cr(shearsmooth*s% omega(k)/sqrt_cr(abs(s% brunt_N2(k))),1d0/3d0) !Alfven frequency at saturation, assuming adiabatic instability
        omegat = difft*pow2(sqrt_cr(abs(s% brunt_N2(k)))/(omegaa*s% r(k))) !Thermal damping rate assuming adiabatic instability
        brunts = sqrt_cr(abs( s% brunt_N2_composition_term(k)&
                +(s% brunt_N2(k)-s% brunt_N2_composition_term(k))/(1d0 + omegat/omegaa) )) !Suppress thermal part of brunt
        bruntsn2 = sqrt_cr(abs( s% brunt_N2_composition_term(k)+&
            (s% brunt_N2(k)-s% brunt_N2_composition_term(k))*min(1d0,diffm/difft) )) !Effective brunt for isothermal instability
        brunts = max(brunts,bruntsn2) !Choose max between suppressed brunt and isothermal brunt
        brunts = max(s% omega(k),brunts) !Don't let Brunt be smaller than omega
        omegaa = s% omega(k)*pow_cr(abs(shearsmooth*s% omega(k)/brunts),1d0/3d0) !Recalculate omegaa

        ! Calculate nu_TSF
        if (s% brunt_N2(k) > 0d0) then
            if (pow2(brunts) > 2d0*pow2(shearsmooth)*pow2(s% omega(k))) then
                omegac = 1d0*s% omega(k)*sqrt_cr(brunts/s% omega(k))*pow_cr(diffm/(pow2(s% r(k))*s% omega(k)),0.25d0)  !Critical field strength
                nu_tsf = 5d-1+5d-1*tanh(5d0*log(alpha*omegaa/omegac)) !Suppress AM transport if omega_a<omega_c
                nu_tsf = nu_tsf*pow3(alpha)*s% omega(k)*pow2(s% r(k))*pow2(s% omega(k)/brunts) !nu_omega for revised Tayler instability
            end if
            ! Add TSF enabled by thermal diffusion
            if (pow2(brunts) < 2d0*pow2(shearsmooth)*pow2(s% omega(k))) then
                nu_tsf_t = alpha*abs(shearsmooth)*s% omega(k)*pow2(s% r(k))
            end if
            s% am_nu_omega(k) = s% am_nu_omega(k) + max(nu_tsf,nu_tsf_t) + 1d-1
        end if

     end do


      !Values near inner boundary
      do k=s% nz-nsmooth,s% nz
        nu_tsf=1d-30
        nu_tsf_t=1d-30
        shearsmooth = shearsmooth

        diffm =  diffmag(s% rho(k),s% T(k),s% abar(k),s% zbar(k),op_err) !Magnetic diffusivity
        difft = 16d0*5.67d-5*pow3(s% T(k))/(3d0*s% opacity(k)*pow2(s% rho(k))*s% Cv(k)) !Thermal diffusivity
        omegaa = s% omega(k)*pow_cr(shearsmooth*s% omega(k)/sqrt_cr(abs(s% brunt_N2(k))),1d0/3d0) !Alfven frequency at saturation, assuming adiabatic instability
        omegat = difft*pow2(sqrt_cr(abs(s% brunt_N2(k)))/(s% omega(k)*s% r(k))) !Thermal damping rate assuming adiabatic instability
        brunts = sqrt_cr(abs( s% brunt_N2_composition_term(k)&
            +(s% brunt_N2(k)-s% brunt_N2_composition_term(k))/(1d0 + omegat/omegaa) )) !Suppress thermal part of brunt
        bruntsn2 = sqrt_cr(abs( s% brunt_N2_composition_term(k)+&
            (s% brunt_N2(k)-s% brunt_N2_composition_term(k))*min(1d0,diffm/difft) )) !Effective brunt for isothermal instability
        brunts = max(brunts,bruntsn2) !Choose max between suppressed brunt and isothermal brunt
        brunts = max(s% omega(k),brunts) !Don't let Brunt be smaller than omega
        omegaa = s% omega(k)*pow_cr(abs(shearsmooth*s% omega(k)/brunts),1d0/3d0) !Recalculate omegaa

        ! Calculate nu_TSF
        if (s% brunt_N2(k) > 0d0) then
            if (pow2(brunts) > 2d0*pow2(shearsmooth)*pow2(s% omega(k))) then
                omegac = 1d0*s% omega(k)*sqrt_cr(brunts/s% omega(k))*pow_cr(diffm/(pow2(s% r(k))*s% omega(k)),0.25d0)  !Critical field strength
                nu_tsf = 5d-1+5d-1*tanh(5d0*log(alpha*omegaa/omegac)) !Suppress AM transport if omega_a<omega_c
                nu_tsf = nu_tsf*pow3(alpha)*s% omega(k)*pow2(s% r(k))*pow2(s% omega(k)/brunts) !nu_omega for revised Tayler instability
            end if
            ! Add TSF enabled by thermal diffusion
            if (pow2(brunts) < 2d0*pow2(shearsmooth)*pow2(s% omega(k))) then
                nu_tsf_t = alpha*abs(shearsmooth)*s% omega(k)*pow2(s% r(k))
            end if
            s% am_nu_omega(k) = s% am_nu_omega(k) + max(nu_tsf,nu_tsf_t) + 1d-1
        end if
      end do

  !Values near outer boundary
  do k=nsmooth,1
    nu_tsf=1d-30
    nu_tsf_t=1d-30
    shearsmooth = shearsmooth

    diffm =  diffmag(s% rho(k),s% T(k),s% abar(k),s% zbar(k),op_err) !Magnetic diffusivity
    difft = 16d0*5.67d-5*pow3(s% T(k))/(3d0*s% opacity(k)*pow2(s% rho(k))*s% Cv(k)) !Thermal diffusivity
    omegaa = s% omega(k)*pow_cr(shearsmooth*s% omega(k)/sqrt_cr(abs(s% brunt_N2(k))),1d0/3d0) !Alfven frequency at saturation, assuming adiabatic instability
    omegat = difft*pow2(sqrt_cr(abs(s% brunt_N2(k)))/(s% omega(k)*s% r(k))) !Thermal damping rate assuming adiabatic instability
    brunts = sqrt_cr(abs( s% brunt_N2_composition_term(k)&
        +(s% brunt_N2(k)-s% brunt_N2_composition_term(k))/(1d0 + omegat/omegaa) )) !Suppress thermal part of brunt
    bruntsn2 = sqrt_cr(abs( s% brunt_N2_composition_term(k)+&
        (s% brunt_N2(k)-s% brunt_N2_composition_term(k))*min(1d0,diffm/difft) )) !Effective brunt for isothermal instability
    brunts = max(brunts,bruntsn2) !Choose max between suppressed brunt and isothermal brunt
    brunts = max(s% omega(k),brunts) !Don't let Brunt be smaller than omega
    omegaa = s% omega(k)*pow_cr(abs(shearsmooth*s% omega(k)/brunts),1d0/3d0) !Recalculate omegaa

    ! Calculate nu_TSF
    if (s% brunt_N2(k) > 0d0) then
        if (pow2(brunts) > 2d0*pow2(shearsmooth)*pow2(s% omega(k))) then
            omegac = 1d0*s% omega(k)*sqrt_cr(brunts/s% omega(k))*pow_cr(diffm/(pow2(s% r(k))*s% omega(k)),0.25d0)  !Critical field strength
            nu_tsf = 5d-1+5d-1*tanh(5d0*log(alpha*omegaa/omegac)) !Suppress AM transport if omega_a<omega_c
            nu_tsf = nu_tsf*pow3(alpha)*s% omega(k)*pow2(s% r(k))*pow2(s% omega(k)/brunts) !nu_omega for revised Tayler instability
        end if
        ! Add TSF enabled by thermal diffusion
        if (pow2(brunts) < 2d0*pow2(shearsmooth)*pow2(s% omega(k))) then
            nu_tsf_t = alpha*abs(shearsmooth)*s% omega(k)*pow2(s% r(k))
        end if
        s% am_nu_omega(k) = s% am_nu_omega(k) + max(nu_tsf,nu_tsf_t) + 1d-1
    end if
  end do

  !Smooth nu_omega
  logamnuomega=-3d1
  do k=nsmootham+1,s% nz-(nsmootham+1)
    !Don't smooth convective diffusivity into non-convective zones
    if (s% mixing_type(k)==1) then
        s% am_nu_omega(k) = s% am_nu_omega(k)
    !Smooth zones if not including a convective zone
    else
        logamnuomega = log10_cr(s% am_nu_omega(k))/(2d0*nsmootham+1d0)
    end if
    do j=1,nsmootham
        !Don't smooth convective diffusivity into non-convective zones
        if (s% mixing_type(k-j)<3.5d0) then
            logamnuomega = log10_cr(s% am_nu_omega(k))
        !Smooth zones if not including a convective zone
        else
            logamnuomega = logamnuomega + (1d0/(2d0*nsmootham+1d0))*log10_cr(s% am_nu_omega(k-j))
        end if
    end do
    do j=1,nsmootham
        !Don't smooth convective diffusivity into non-convective zones
        if (s% mixing_type(k+j)<3.5d0) then
            logamnuomega = logamnuomega
        !Smooth zones if not including a convective zone
        else
            logamnuomega = logamnuomega + (1d0/(2d0*nsmootham+1d0))*log10_cr(s% am_nu_omega(k+j))
        end if
    end do
    s% am_nu_omega(k) = exp10_cr(logamnuomega)
  end do

  !Values near inner boundary
  do k=s% nz-nsmootham,s% nz
        s% am_nu_omega(k) = s% am_nu_omega(k-1)
  end do

  !Values near outer boundary
  do k=nsmootham,1
        s% am_nu_omega(k) = s% am_nu_omega(k-1)
  end do

  end subroutine TSF

  real(dp) function diffmag(rho,T,abar,zbar,ierr)

     ! Written by S.-C. Yoon, Oct. 10, 2003
     ! Electrical conductivity according to Spitzer 1962
     ! See also Wendell et al. 1987, ApJ 313:284
     real(dp), intent(in) :: rho, T, abar, zbar
     integer, intent(out) :: ierr
     real(dp) :: xmagfmu, xmagft, xmagfdif, xmagfnu, &
        xkap, xgamma, xlg, xsig1, xsig2, xsig3, xxx, ffff, xsig, &
        xeta

    if (ierr /= 0) return

    xgamma = 0.2275d0*zbar*zbar*pow_cr(rho*1d-6/abar,1d0/3d0)*1d8/T
    xlg = log10_cr(xgamma)
    if (xlg < -1.5d0) then
        xsig1 = sige1(zbar,T,xgamma)
        xsig = xsig1
    else if (xlg >= -1.5d0 .and. xlg <= 0d0) then
        xxx = (xlg + 0.75d0)*4d0/3d0
        ffff = 0.25d0*(2d0-3d0*xxx + xxx*xxx*xxx)
        xsig1 = sige1(zbar,T,xgamma)

        xsig2 = sige2(T,rho,zbar,ierr)
        if (ierr /= 0) return

        xsig = (1d0-ffff)*xsig2 + ffff*xsig1
    else if (xlg > 0d0 .and. xlg < 0.5d0) then
        xsig2 = sige2(T,rho,zbar,ierr)
        if (ierr /= 0) return

        xsig = xsig2
    else if (xlg >= 0.5d0 .and. xlg < 1d0) then
        xxx = (xlg-0.75d0)*4d0
        ffff = 0.25d0*(2d0-3d0*xxx + xxx*xxx*xxx)
        xsig2 = sige2(T,rho,zbar,ierr)
        if (ierr /= 0) return

        xsig3 = sige3(zbar,T,xgamma)
        xsig = (1d0-ffff)*xsig3 + ffff*xsig2
    else
        xsig3 = sige3(zbar,T,xgamma)
        xsig = xsig3
    endif

    diffmag = 7.1520663d19/xsig ! magnetic diffusivity

  end function diffmag


  ! Helper functions

  real(dp) function sqrt_cr(x)
    real(dp), intent(in) :: x

    sqrt_cr = pow_cr(x, 0.5d0)
  end function sqrt_cr

  real(dp) function sige1(z,t,xgamma)
     ! Written by S.-C. Yoon, Oct. 10, 2003
     ! Electrical conductivity according to Spitzer 1962
     ! See also Wendell et al. 1987, ApJ 313:284
     real(dp), intent(in) :: z, t, xgamma
     real(dp) :: etan, xlambda,f
     if (t >= 4.2d5) then
        f = sqrt_cr(4.2d5/t)
     else
        f = 1d0
     end if
     xlambda = sqrt_cr(3d0*z*z*z)*pow_cr(xgamma,-1.5d0)*f + 1d0
     etan = 3d11*z*log_cr(xlambda)*pow_cr(t,-1.5d0)             ! magnetic diffusivity
     etan = etan/(1d0-1.20487d0*exp_cr(-1.0576d0*pow_cr(z,0.347044d0))) ! correction: gammae
     sige1 = clight*clight/(4d0*pi*etan)                    ! sigma = c^2/(4pi*eta)
  end function sige1


  real(dp) function sige2(T,rho,zbar,ierr)
     ! writen by S.-C. YOON Oct. 10, 2003
     ! electrical conductivity using conductive opacity
     ! see Wendell et al. 1987 ApJ 313:284
     use kap_lib, only: kap_get_elect_cond_opacity
     real(dp), intent(in) :: t,rho,zbar
     integer, intent(out) :: ierr
     real(dp) :: kap, dlnkap_dlnRho, dlnkap_dlnT
     call kap_get_elect_cond_opacity( &
        zbar, log10_cr(rho), log10_cr(T),  &
        kap, dlnkap_dlnRho, dlnkap_dlnT, ierr)
     sige2 = 1.11d9*T*T/(rho*kap)
  end function sige2

  real(dp) function sige3(z,t,xgamma)
     ! writen by S.-C. YOON Oct. 10, 2003
     ! electrical conductivity in degenerate matter,
     ! according to Nandkumar & Pethick (1984)
     real(dp), intent(in) :: z, t, xgamma
     real(dp) :: rme, rm23, ctmp, xi
     rme = 8.5646d-23*t*t*t*xgamma*xgamma*xgamma/powi_cr(z,5)  ! rme = rho6/mue
     rm23 = pow_cr(rme,2d0/3d0)
     ctmp = 1d0 + 1.018d0*rm23
     xi= sqrt_cr(3.14159d0/3d0)*log_cr(z)/3d0 + 2d0*log_cr(1.32d0+2.33d0/sqrt_cr(xgamma))/3d0-0.484d0*rm23/ctmp
     sige3 = 8.630d21*rme/(z*ctmp*xi)
  end function sige3


end module run_star_extras
