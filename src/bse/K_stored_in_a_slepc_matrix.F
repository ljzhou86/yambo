!
!        Copyright (C) 2000-2018 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): HM
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
subroutine K_stored_in_a_slepc_matrix(iq,slepc_mat)
 !
 ! Here I fill the kernel (coupling not yet included) in a slepc matrix to be
 ! used for diagonalization and/or invertion
 !
 !      | (K_r)     (cI*K_c)    |  
 !  K = |                       |
 !      | (-cI*K_c^*)  (-K_r^*) |
 !
 use pars,           ONLY:SP,DP,cI,cONE
 use electrons,      ONLY:n_sp_pol
 use BS,             ONLY:BS_K_dim,BS_H_dim,BS_blk,n_BS_blks,BS_T_grp,BS_K_coupling
 use BS_solvers,     ONLY:BSS_eh_E,BSS_eh_W,&
&                         BSS_perturbative_width,BSS_alloc
 use com,            ONLY:error,msg
 !
 implicit none
 !
#include <petsc/finclude/petscsys.h>
#include <petsc/finclude/petscvec.h>
#include <petsc/finclude/petscmat.h>
#include <petsc/finclude/petscvec.h90>
#include <slepc/finclude/slepcsys.h>
#include <slepc/finclude/slepceps.h>
 !
 complex(SP) :: E_plus_W
 integer     :: iq,i_c,i_r,i_Tk,i_Tp,i_B
 Mat   :: slepc_mat
 PetscFortranComplex :: val
 PetscFortranInt     :: H_pos(2),SL_K_dim,SL_H_dim
 PetscErrorCode      :: ierr
 !
 SL_K_dim=BS_K_dim
 SL_H_dim=BS_H_dim
 !
 ! Allocate the slepc Matrix
 !
 call MatCreate(PETSC_COMM_WORLD,slepc_mat,ierr)
 call MatSetSizes(slepc_mat,PETSC_DECIDE,PETSC_DECIDE,SL_H_dim,SL_H_dim,ierr)
 call MatSetType(slepc_mat, MATMPIDENSE,ierr)
 call MatSetUp(slepc_mat,ierr)
 ! 
 ! filling of the slepc_mat
 !
 do i_B=1,n_BS_blks
   !
   i_Tk  =BS_blk(i_B)%iT_k
   i_Tp  =BS_blk(i_B)%iT_p
   !
   do i_r=1,BS_blk(i_B)%size(1)
     !
     H_pos(1)=sum(BS_T_grp(:I_Tk-1)%size)+i_r-1
     !
     ! First the diagonal
     !
     if (i_Tk==i_Tp) then
       if (BS_blk(i_B)%mode=="R") then
         E_plus_W=BSS_eh_E(H_pos(1)+1)*cONE
         if (allocated(BSS_eh_W).and..not.BSS_perturbative_width) then
            E_plus_W=E_plus_W-cI*BSS_eh_W(H_pos(1)+1)
         endif
         val = E_plus_W+real(BS_blk(i_B)%mat(i_r,i_r),SP)
         call MatSetValue( slepc_mat, H_pos(1),          H_pos(1), val, INSERT_VALUES, ierr )
       else
         val = BS_blk(i_B)%mat(i_r,i_r)
         call MatSetValue( slepc_mat, H_pos(1)+SL_K_dim, H_pos(1), val, INSERT_VALUES, ierr )
       endif
       !
     endif
     !
     ! Then the upper triangle of each block
     !
     do i_c=1,BS_blk(i_B)%size(2)
       !
       H_pos(2)=sum(BS_T_grp(:I_Tp-1)%size)+i_c-1
       !
       if (H_pos(1)>=H_pos(2)) cycle
       !
       val = BS_blk(i_B)%mat(i_r,i_c)
       if (BS_blk(i_B)%mode=="R") then
         call MatSetValue( slepc_mat, H_pos(1), H_pos(2),       val , INSERT_VALUES, ierr )
         call MatSetValue( slepc_mat, H_pos(2), H_pos(1), conjg(val), INSERT_VALUES, ierr )
       endif
       !
       if (BS_blk(i_B)%mode=="A") then
         call MatSetValue( slepc_mat, H_pos(1), H_pos(2)+SL_K_dim,       val , INSERT_VALUES, ierr )
         call MatSetValue( slepc_mat, H_pos(2)+SL_K_dim, H_pos(1), conjg(val), INSERT_VALUES, ierr )
       endif
       !
     enddo
     !
   enddo
   !
 enddo
 !
 if (BS_K_coupling) call error('BSE coupling with slepc not implemented')
 !
 call MatAssemblyBegin(slepc_mat,MAT_FINAL_ASSEMBLY,ierr)
 call MatAssemblyEnd(slepc_mat,MAT_FINAL_ASSEMBLY,ierr)
 !
end subroutine K_stored_in_a_slepc_matrix

