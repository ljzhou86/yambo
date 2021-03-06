!
!        Copyright (C) 2000-2018 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM DS
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
subroutine K_inversion_Lo(iq,W,E,k,Lo_dim,Lo_n_loop,Lo) 
 !
 use pars,           ONLY:SP,cZERO,cI,pi,rZERO,schlen
 use stderr,         ONLY:intc
 use R_lattice,      ONLY:bz_samp,q_norm
 use X_m,            ONLY:Epsilon_ii,X_drude_term,global_gauge,l_drude,X_DbGd_nkpt_at_q,X_DbGd_nkpt_at_q_table,skip_cond_sum_rule
 use electrons,      ONLY:levels,BZ_DbGd_tot_nk_levels,spin
 use frequency,      ONLY:w_samp,W_reset,W_duplicate
 use BS_solvers,     ONLY:Co_factor,diam_term_exact,BSS_dipoles,&
&                         BSS_eh_table,BSS_eh_E,BSS_eh_f,&
&                         BSS_n_descs,BSS_description,BSS_eh_W,&
&                         BSS_add_antiresonant,K_diago_in_BS_mat,BS_diagonal,BSS_uses_DbGd
 use BS,             ONLY:BS_H_dim,BS_K_dim,BS_K_coupling,BSE_mode
 use parallel_m,     ONLY:PP_redux_wait,PAR_IND_Xk_ibz_ID,PAR_COM_Xk_ibz_INDEX,PAR_IND_Xk_ibz
 use LIVE_t,         ONLY:live_timing
 !
#if defined _ELPH
 use BS_solvers,     ONLY:BSS_uses_GreenF
 use BS,             ONLY:BS_bands
#endif
 !
#include<memory.h>
 !
 type(w_samp),  intent(in)  :: W
 type(levels),  intent(in)  :: E
 type(bz_samp), intent(in)  :: k
 integer,       intent(in)  :: iq,Lo_dim,Lo_n_loop
 complex(SP),   intent(out) :: Lo(BS_H_dim,W%n_freqs,Lo_dim)
 !
 ! Work Space
 !
 type(w_samp)     :: W_mins,W_plus
 integer          :: iw_ref,i_res,i_cpl,i_Lo_trans,ik_bz,iv,ic,iw,i_sp,ik_ibz,i_loop,n_loop,i_eps,i_Lo,transition(4)
 complex(SP)      :: E_plus_W,residual,diam_term_used,para_term_w0
 character(schlen):: LT_title
 !
 !
 Epsilon_ii(:,3:4) = cZERO
 !
 ! DbGd setup
 !
 call X_Double_Grid_setup(1,k)  
 !
 ! Look for the W(iw_ref) closest 0
 !==================================
 call FREQUENCIES_set_reference_point(W%p,W%n_freqs,iw_ref)
 !
 !
 if (     K_diago_in_BS_mat) n_loop=1
 if (.not.K_diago_in_BS_mat) n_loop=2
 !
 do i_loop=1,n_loop
   !
   i_eps=2+i_loop
   !
   if(n_loop==2) then
     if(i_loop==1) LT_title='IP Absorption'
     if(i_loop==2) LT_title='Shifted GF and Absorption'
   else
     LT_title='IP GF and Absorption'
   endif
   call live_timing(trim(LT_title),PAR_IND_Xk_ibz%n_of_elements(PAR_IND_Xk_ibz_ID+1))
   !
   Lo=cZERO
   !
   call W_reset(W_mins)
   call W_reset(W_plus)
   call W_duplicate(W,W_mins)
   call W_duplicate(W,W_plus)
   !
   do i_res=1,BS_K_dim
     !
     i_cpl=i_res+BS_K_dim
     !
     ik_bz =BSS_eh_table(i_res,1)
     iv    =BSS_eh_table(i_res,2)
     ic    =BSS_eh_table(i_res,3)
     i_sp  =spin(BSS_eh_table(i_res,:))
     !
     ik_ibz=k%sstar(ik_bz,1)   
     !
     if (.not.PAR_IND_Xk_ibz%element_1D(ik_ibz)) cycle
     !
     transition=(/ik_bz,iv,ic,i_sp/)
     !
     i_Lo_trans=i_res
     i_Lo      =1
     !
     if ( trim(BSE_mode)=='retarded') then
       i_Lo_trans=i_res
       i_Lo      =2
     else if( trim(BSE_mode)=="coupling") then
       i_Lo_trans=i_cpl
       i_Lo      =1
     endif
     !
     if (.not.allocated(BSS_eh_W)) E_plus_W=BSS_eh_E(i_res)
     if (     allocated(BSS_eh_W)) E_plus_W=BSS_eh_E(i_res)-cI*BSS_eh_W(i_res)
     !
     if(i_loop==2) then
       forall(iw=1:W%n_freqs) W_mins%p(iw)=W%p(iw)-BS_diagonal(i_res)*BSS_eh_f(i_res)
       forall(iw=1:W%n_freqs) W_plus%p(iw)=W%p(iw)+BS_diagonal(i_res)*BSS_eh_f(i_res)
     endif
     !
     if ( .not.allocated(E%GreenF) ) then
       !
       ! Analytical GFs
       !================
       call X_GreenF_analytical(1,transition,W_mins,E,k,Lo(i_res,:,1),"r","eh",.FALSE.)
       !
       if (BSS_add_antiresonant.or.BS_K_coupling) then
         !
         call X_GreenF_analytical(1,transition,W_plus,E,k,Lo(i_Lo_trans,:,i_Lo),"Ra","eh",.FALSE.)
         !
       endif
       !
     else 
       !
       !
     endif
     !
     residual=BSS_dipoles(i_res)*conjg(BSS_dipoles(i_res))
     if (allocated(BSS_eh_W) .and. trim(global_gauge)=="velocity") residual=residual*E_plus_W/conjg(E_plus_W)
     if (trim(global_gauge)=='velocity') para_term_w0=para_term_w0+Lo(i_res,iw_ref,1)
     Epsilon_ii(:,i_eps)=Epsilon_ii(:,i_eps)-residual*Lo(i_res,:,1)
     !
     if (BSS_add_antiresonant.or.BS_K_coupling) then
       residual=conjg(BSS_dipoles(i_Lo_trans))*BSS_dipoles(i_Lo_trans)
       if (trim(global_gauge)=='velocity') para_term_w0=para_term_w0+Lo(i_Lo_trans,iw_ref,i_Lo)
       Epsilon_ii(:,i_eps)=Epsilon_ii(:,i_eps)-conjg(residual)*Lo(i_Lo_trans,:,i_Lo)
     endif
     !
     !
     if (k%sstar(ik_bz,2)==1) call live_timing(steps=1)
     !
   enddo
   !
   call live_timing( )
   !
   if(i_loop==n_loop) call PP_redux_wait(Lo,COMM=PAR_COM_Xk_ibz_INDEX%COMM)
   !
   call PP_redux_wait(Epsilon_ii(:,i_eps),COMM=PAR_COM_Xk_ibz_INDEX%COMM)
   call PP_redux_wait(para_term_w0,       COMM=PAR_COM_Xk_ibz_INDEX%COMM)
   !
   if (.not.skip_cond_sum_rule) diam_term_used=para_term_w0
   if (     skip_cond_sum_rule) diam_term_used=diam_term_exact
   !
   if(trim(global_gauge)=="length")   Epsilon_ii(:,i_eps)=(1._SP+ Epsilon_ii(:,i_eps)                *Co_factor/q_norm(1)**2)
   if(trim(global_gauge)=="velocity") Epsilon_ii(:,i_eps)=(1._SP+(Epsilon_ii(:,i_eps)-diam_term_used)*Co_factor/  W%p(:) **2)
   !
   if (l_drude) Epsilon_ii(:,i_eps)=Epsilon_ii(:,i_eps)+X_drude_term(:)*Co_factor/q_norm(1)**2
   if (skip_cond_sum_rule) Epsilon_ii(:,i_eps)=Epsilon_ii(:,i_eps)+(para_term_w0-diam_term_exact)*Co_factor/ W%p(:)**2
   !
 enddo
 !
 if(.not.K_diago_in_BS_mat) then
   YAMBO_FREE(BS_diagonal)
 endif
 if (BSS_uses_DbGd) then
   YAMBO_FREE(X_DbGd_nkpt_at_q)
   YAMBO_FREE(X_DbGd_nkpt_at_q_table)
 endif  
 !
 BSS_n_descs=BSS_n_descs+2
 BSS_description(BSS_n_descs-1)=' '
 BSS_description(BSS_n_descs)=' BSS|BZ Double Grid points      :'//intc(BZ_DbGd_tot_nk_levels)
 !
end subroutine K_inversion_Lo
