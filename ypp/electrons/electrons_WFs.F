! 
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
!
! This file is distributed under the terms of the GNU
! General Public License. You can redistribute it and/or
! modify it under the terms of the GNU General Public
! License as published by the Free Software Foundation;
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will
! be useful, but WITHOUT ANY WARRANTY; without even the
! implied warranty of MERCHANTABILITY or FITNESS FOR A
! PARTICULAR PURPOSE.  See the GNU General Public License
! for more details.
!
! You should have received a copy of the GNU General Public
! License along with this program; if not, write to the Free
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston,
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
subroutine electrons_WFs(Xen)
 !
 use pars,           ONLY:SP,lchlen
 Use stderr,         ONLY:intc
 use wave_func,      ONLY:WF,wf_ng
 use FFT_m,          ONLY:fft_size,fft_dim
 use com,            ONLY:error
 use electrons,      ONLY:levels,n_spinor,spin,n_sp_pol
 use QP_m,           ONLY:QP_table,QP_n_states
 use YPP,            ONLY:v2plot,output_fname,plot_dim,use_xcrysden,&
&                         use_gnuplot,use_cube,nr,l_sp_wf,deg_energy,l_norm_to_one,&
&                         plot_title
 use com,            ONLY:msg,of_open_close,warning
 use functions,      ONLY:Fermi_fnc_derivative
 use xc_functionals, ONLY:magn
#if defined _YPP_ELPH
 use YPP_ELPH,       ONLY:elph_residual_treshold
 use pars,           ONLY:cZERO
 use ELPH,           ONLY:elph_Ham_bands
 use com,            ONLY:jobstr,file_exists
 use R_lattice,      ONLY:nkibz
#endif
 !
#include<memory.h>
 !
 type(levels)  ::Xen
 !
 ! Work Space
 !
 integer               :: i_qp,ik,i_sp_pol,ib,ibp,ir,i_wf,nb_to_load(2),nkpt_to_load(2),ik_ref
 character(lchlen)     :: ch_ws(2)
#if defined _YPP_ELPH
 integer               :: iq_s,iq_ibz
 logical               :: l_polaronic_wf
#endif
 !
#if defined _YPP_ELPH
 !
 !Polaronic Wf
 !
 integer, parameter      :: n_max_res=100
 integer                 :: n_top_residuals,top_residual(n_max_res),i_st,H_size,i_c
 character(lchlen)       :: db_name
 integer                 :: ok_ibz,il,ok_s
 real(SP)                :: polaronic_residual(n_max_res),max_residual
 complex(SP)             :: B_n_ok
 complex(SP), allocatable:: v2plot_c(:),wf_rot(:)
 !
 ! ELPH setup
 !============
 l_polaronic_wf=.FALSE.
 db_name=trim(jobstr)//'/TOP_RESIDUAL_b'//trim(intc(QP_table(1,1)))//'_k'//trim(intc(QP_table(1,3)))
 if (file_exists(trim(db_name))) then
  l_polaronic_wf=.TRUE.
   open(unit=100,file=trim(db_name),form='unformatted')
   read(100) elph_Ham_bands
   close(100)
   nb_to_load    =elph_Ham_bands
   nkpt_to_load  =(/1,nkibz/)
 endif
 YAMBO_ALLOC(v2plot_c,(fft_size))
 YAMBO_ALLOC(wf_rot,(fft_size))
#endif
 !
 !
 ! SYMMETRIZED WAVEFUNCTIONS (summed over all symmetries and degenerate states)
 !==============================================================================
 !
 ! GPL_EXCLUDE_END
 !
#if defined _YPP_ELPH
 if (l_polaronic_wf) then
   !
   i_qp=1
   !
   l_norm_to_one=.true.
   !
   do while (i_qp<=QP_n_states) 
     !
     ib    =QP_table(i_qp,1)
     ik    =QP_table(i_qp,3)
     i_sp_pol=spin(QP_table(i_qp,:))
     !
     db_name=trim(jobstr)//'/TOP_RESIDUAL_b'//trim(intc(ib))//'_k'//trim(intc(ik))
     !
     i_qp=i_qp+1
     !
     if (.not.file_exists(trim(db_name))) cycle
     !  
     do i_st=1,2
       n_top_residuals=1
       open(unit=100,file=trim(db_name),form='unformatted')
       do while(.true.)
         read(100,end=2) top_residual(n_top_residuals),polaronic_residual(n_top_residuals)
         if  (polaronic_residual(n_top_residuals)>elph_residual_treshold/100.*max_residual) n_top_residuals=n_top_residuals+1
       enddo
2      n_top_residuals=n_top_residuals-1
       close(100)
       if (i_st==1) max_residual=maxval(polaronic_residual(:n_top_residuals))
     enddo 
     ! 
     call msg('s',':: Found '//trim(intc(n_top_residuals))//' residuals@k'//trim(intc(ik))//&
&                 '_b'//trim(intc(ib))//':', top_residual(:n_top_residuals))
     !
     do i_st=1,n_top_residuals
       !
       if  (polaronic_residual(i_st)<elph_residual_treshold/100.*maxval(polaronic_residual(:n_top_residuals))) cycle
       !
       v2plot_c=cZERO
       !
       db_name=trim(jobstr)//'/EIGENV_I'//trim(intc(top_residual(i_st)))//'_k'//trim(intc(ik))
       open(unit=100,file=trim(db_name),form='unformatted')
       read(100) H_size
       do i_c=1,H_size
         read(100) ibp,ok_ibz,ok_s,il,iq_ibz,iq_s,B_n_ok
         !
         if (il==0) then
           !
           i_wf=WF%index(ib,ik,1)
           !
           forall(ir=1:fft_size) v2plot_c(ir)=v2plot_c(ir)+WF%c(ir,1,i_wf)
           !
         else
           !
           call WF_apply_symm((/ibp,ok_ibz,ok_s,1/),wf_rot)
           !
           forall(ir=1:fft_size) v2plot_c(ir)=v2plot_c(ir)+B_n_ok*wf_rot(ir)
           !
         endif
         !
       enddo
       close(100)
       !
       v2plot  =abs(real(v2plot_c))
       !
       ch_ws(1)='sp_wf_k'//trim(intc(ik))//'_b'//trim(intc(ib))//'_'//trim(intc(plot_dim))//&
&               '_STATE'//trim(intc(top_residual(i_st)))//'_'//trim(intc(plot_dim))
       if (use_xcrysden) output_fname=trim(ch_ws(1))//'d.xsf'
       if (use_gnuplot)  output_fname=trim(ch_ws(1))//'d'
       !
       call of_open_close(trim(output_fname),'ot')
       call msg('o wf',"#")
       !
       call plot_check_and_launch(.false.)
       !
       call of_open_close(trim(output_fname))
       !
     enddo
     !
   enddo
   !
 endif
 !
#endif
 !
 ! GPL_EXCLUDE_END
 !
 ! WAVEFUNCTIONS (and Mean Potential)
 !====================================
 !
 ik_ref=-1
 ch_ws(2)='sp_wf'
 !
 if (l_sp_wf &
#if defined _YPP_ELPH
&    .and..not.l_polaronic_wf &
#endif
&   ) then
   !
   v2plot=0.
   !
   if (l_sp_wf)          call section('*','Single Particle wavefunction Plot')
   !
   !
   i_qp=1
   !
   do while (i_qp<=QP_n_states) 
     !
     ! n   =QP_table(i_qp,1)
     ! k   =QP_table(i_qp,3)
     ! sp  =QP_table(i_qp,4)
     !
     ib    =QP_table(i_qp,1)
     ik    =QP_table(i_qp,3)
     i_sp_pol=spin(QP_table(i_qp,:))
     !
     i_qp=i_qp+1
     !
     !
       i_wf=WF%index(ib,ik,i_sp_pol)
     !
       forall(ir=1:fft_size) v2plot(ir)=real( WF%c(ir,1,i_wf)*conjg( WF%c(ir,1,i_wf) ) )
       if (n_spinor==2) forall(ir=1:fft_size) v2plot(ir)=v2plot(ir) + real( WF%c(ir,2,i_wf)*conjg( WF%c(ir,2,i_wf) ) )
     !
     ibp=ib+1
     if (ib==Xen%nb) ibp=ib
     if (ib/=Xen%nb.and.abs(Xen%E(ib,ik,i_sp_pol)-Xen%E(ibp,ik,i_sp_pol))<deg_energy) then
       cycle
     else
       !
       if (n_sp_pol==2) then
         if (i_sp_pol==1) ch_ws(1)=trim(ch_ws(2))//'_k'//trim(intc(ik))//'_b'//trim(intc(ib))//'_UP_'//trim(intc(plot_dim))
         if (i_sp_pol==2) ch_ws(1)=trim(ch_ws(2))//'_k'//trim(intc(ik))//'_b'//trim(intc(ib))//'_DN_'//trim(intc(plot_dim))
         if (i_sp_pol==1) plot_title='k '//trim(intc(ik))//' b '//trim(intc(ib))//' UP'
         if (i_sp_pol==2) plot_title='k '//trim(intc(ik))//' b '//trim(intc(ib))//' DN'
       else
         ch_ws(1)=trim(ch_ws(2))//'_k'//trim(intc(ik))//'_b'//trim(intc(ib))//'_'//trim(intc(plot_dim)) 
       endif
       !
       if (use_cube) output_fname=trim(ch_ws(1))//'d.cube'
       if (use_xcrysden) output_fname=trim(ch_ws(1))//'d.xsf'
       if (use_gnuplot)  output_fname=trim(ch_ws(1))//'d'
       !
       if (use_cube) then 
         call of_open_close(trim(output_fname),'o')
       else
         call of_open_close(trim(output_fname),'ot')
         call msg('o wf',"#")
       endif
       !
       call plot_check_and_launch(.false.)
       !
       call of_open_close(trim(output_fname))
       !
     endif
     !
   enddo
    !
 endif
 !
#if defined _YPP_ELPH 
 YAMBO_FREE(v2plot_c)
#endif
 !
end subroutine
