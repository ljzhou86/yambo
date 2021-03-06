!
!        Copyright (C) 2000-2018 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM CA DS
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
subroutine RT_Observables(en,k,dG_lesser,OBSERVABLES)
 !
 ! This subroutine compute the variation of the energy and its different components,
 ! the number of electrons injected in conduction and holes in valence,
 ! and finally the variation in entropy and the associated temperature
 ! which is compared with the temperature from the fits
 !
 use pars,           ONLY:SP
 use R_lattice,      ONLY:bz_samp
 use electrons,      ONLY:levels
 use real_time,      ONLY:RT_nk,RT_bands
 use RT_control,     ONLY:RT_do_it
 use fields,         ONLY:A_tot
 use timing_m,       ONLY:timing
 !
 implicit none 
 !
 type(levels),  intent(inout) :: en
 type(bz_samp), intent(in)    :: k
 complex(SP),   intent(in)    :: dG_lesser(RT_bands(1):RT_bands(2),RT_bands(1):RT_bands(2),RT_nk)
 real(SP),   intent(inout)    :: OBSERVABLES(23)
 !
 ! Workspace
 !
 real(SP) :: NCarr(3),TFit(2),EfFit(2),Ener(5),Entr(3),TEntr(3),EnEntr(3),BGR(2)
 real(SP) :: E_IP
 !
 call timing('RT observables',OPR='start')
 !
 ! Current, Polarization and Magnetization
 !==========================================
 ! (evaluated also in RT_integrator when an induced field is included)
 call RT_current_AND_polarization(k,en,dG_lesser,A_tot)
 !
 if (.not. RT_do_it('OUT') ) then
   call timing('RT observables',OPR='stop')
   return
 endif
 !
 !
 call timing('RT observables',OPR='stop')
 !
end subroutine RT_Observables
