      module wang_landau
      use utility_pack
      use wang_landau_module
      use mc_moves
      use ewald_module

      contains
      subroutine wang_landau_sim
     &(idnode,imcon,keyfce,alpha,rcut,delr,drewd,totatm,ntpguest,
     &ntpfram,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,engunit,
     &sumchg,maxmls,surftol,overlap,newld,outdir,levcfg,cfgname,
     &wlprec)
c*****************************************************************************
c     
c     Main routine for computing the weighted histogram of Wang and
c     Landau
c     PB - 21/08/2017
c
c*****************************************************************************
      implicit none
      logical lgchk,loverlap,lnewsurf,lprod
      character*8 outdir
      character*1 cfgname(80)      
      integer idnode,imcon,keyfce,ntpguest,kmax1,kmax2,kmax3
      integer ntpatm,maxvdw,newld,maxmls,totatm,levcfg
      integer natms,iguest,mol,idum,ntpfram,i
      real(8) alpha,rcut,delr,drewd,volm,epsq,dlrpot,engunit
      real(8) sumchg,surftol,overlap,estep,chgtmp
      real(8) engsictmp,delrc,wlprec
      write(nrite, 
     &"(/'Entering main routine for Wang - Landau calculation',/)")
      write(nrite,
     &"('Initial coefficient set to',f9.5,/)")wlprec
      lgchk=.true.
c     Temporary: exit if more than one guest included in the
c     FIELD/CONTROL files. Make clear that this currently works
c     for estimating the partition function for a single guest
c     at a single temperature.
      if(ntpguest.gt.1)call error(idnode,2318)
      iguest=1
      mol=locguest(iguest)
      natms=numatoms(mol)

      do i=1,ntpguest
        ! compute reduced thermal debroglie wavelength for each guest

        if(guest_insert(i).gt.0)call insert_guests
     &(idnode,imcon,totatm,ntpguest,ntpfram,iguest,guest_insert(i),
     &rcut,delr,sumchg,surftol,overlap,keyfce,alpha,drewd,volm,newld,
     &kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,engunit,delrc,
     &maxmls)
      enddo

      do while(lgchk)
c       randomly select guest
c       chose an MC move to perform
        
c       accept/reject based on modified acceptance criteria
        call random_ins(idnode,natms,iguest,rcut,delr)
        estep=0.d0
        call insertion
     & (imcon,iguest,keyfce,alpha,rcut,delr,drewd,totatm,
     & volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     & engunit,delrc,estep,sumchg,chgtmp,engsictmp,maxmls,
     & loverlap,lnewsurf,surftol,overlap,newld)
        call accept_move
     & (iguest,.true.,.false.,.false.,lnewsurf,
     & delrc,totatm,idum,ntpfram,ntpguest,maxmls,sumchg,
     & engsictmp,chgtmp,newld)
        lgchk=.false.
      enddo
      lprod=.true.
      call revive
     &(totatm,levcfg,lprod,ntpguest,maxmls,
     &imcon,cfgname,0.d0,outdir)

      call error(idnode,2316)
      end subroutine wang_landau_sim

      logical function convergence_check()
c**********************************************************************
c
c     check to see if the histogram is converged. 
c     PB - 15/11/2017
c
c**********************************************************************
      implicit none
       
      convergence_check=.false.
      return
      end function convergence_check

      real(8) function adjust_factor(f)
c**********************************************************************
c
c     Function to decrease the density of states scaling factor
c     PB - 15/11/2017
c
c**********************************************************************
      implicit none
      real(8) f
      adjust_factor = sqrt(f)
      return
      end function adjust_factor

      logical function accept_wl_move
     &(idnode, iguest, insert, delete, displace)
c**********************************************************************
c
c     Acceptance criteria for the Wang-Landau algorithm. Right now
c     this is for ajusting the number of molecules as a macrostate
c     variable.
c     PB - 15/11/2017
c
c**********************************************************************
      implicit none
      logical insert, delete, displace
      integer idnode, iguest

      accept_wl_move=.false.
      return
      end function accept_wl_move

      subroutine wl_insert
     &(idnode,imcon,keyfce,iguest,totatm,rcut,delr,ins_count,alpha,
     &drewd,ntpguest,ntpfram,ntpatm,volm,statvolm,kmax1,kmax2,kmax3,
     &epsq,dlrpot,maxvdw,newld,engunit,delrc,sumchg,maxmls,surftol,
     &overlap,accepted,temp,beta,accept_ins)
c*******************************************************************************
c
c     keeps track of all the associated arrays and calls the 'insertion' 
c     subroutine. Acceptance/rejection criteria based on Metropolis
c     importance sampling coupled to a ?? ensemble.
c
c*******************************************************************************
      implicit none
      logical lnewsurf,loverlap,accepted
      integer iguest,idnode,imcon,natms,totatm,mol,nmol
      integer ins_count,keyfce,ntpguest,kmax1,kmax2,kmax3
      integer ntpatm,maxvdw,maxmls,newld,accept_ins
      integer ntpfram,randchoice
      real(8) rcut,delr,estep,alpha,drewd,volm
      real(8) epsq,dlrpot,engunit,delrc,sumchg,chgtmp,engsictmp
      real(8) surftol,overlap,rande,gpress,statvolm,temp,beta
      mol=locguest(iguest)
      nmol=nummols(mol)
      natms=numatoms(mol)

      lnewsurf = .false.
      engsicorig=engsic
      ins(iguest)=1
      ins_count=ins_count+1
      call random_ins(idnode,natms,iguest,rcut,delr)
      estep = 0.d0
      call insertion
     & (imcon,iguest,keyfce,alpha,rcut,delr,drewd,totatm,
     & volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     & engunit,delrc,estep,sumchg,chgtmp,engsictmp,maxmls,
     & loverlap,lnewsurf,surftol,overlap,newld)
      accepted=.false.

      if (.not.loverlap)then
        gpress=gstfuga(iguest)
        rande=duni(idnode)
        call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &.false.,.true.,.false.,.false.,accepted)
      endif
c     DEBUG
c      accepted=.true.
c     END DEBUG
      if(accepted)then
        accept_ins=accept_ins+1
        randchoice=0
        call accept_move
     &(iguest,.true.,.false.,.false.,
     &lnewsurf,delrc,totatm,randchoice,ntpfram,ntpguest,maxmls,
     &sumchg,engsictmp,chgtmp,newld)
      else
        call reject_move
     &(iguest,0,.true.,.false.,.false.,.false.)
      endif
      return
      end subroutine wl_insert
      subroutine wl_delete
     &(idnode,imcon,keyfce,iguest,totatm,rcut,delr,del_count,alpha,
     &drewd,ntpguest,ntpfram,ntpatm,volm,statvolm,kmax1,kmax2,kmax3,
     &epsq,dlrpot,maxvdw,newld,engunit,delrc,sumchg,maxmls,surftol,
     &overlap,accepted,temp,beta,accept_del)
c*******************************************************************************
c
c     keeps track of all the associated arrays and calls the 'deletion' 
c     subroutine. Acceptance/rejection criteria based on Metropolis
c     importance sampling coupled to 
c
c*******************************************************************************
      implicit none
      logical linitsurf,accepted
      integer iguest,idnode,imcon,totatm,mol,nmol
      integer del_count,keyfce,ntpguest,kmax1,kmax2,kmax3
      integer ntpatm,maxvdw,maxmls,newld,accept_del
      integer ntpfram,randchoice
      real(8) rcut,delr,estep,alpha,drewd,volm
      real(8) epsq,dlrpot,engunit,delrc,sumchg,chgtmp,engsictmp
      real(8) surftol,overlap,rande,gpress,statvolm,temp,beta
      mol=locguest(iguest)
      nmol=nummols(mol)

      engsicorig=engsic
      linitsurf = .false.
      del(iguest)=1
      del_count=del_count+1 
      randchoice=floor(duni(idnode)*nmol)+1
      estep = 0.d0
      call deletion 
     &(imcon,keyfce,iguest,randchoice,alpha,rcut,delr,drewd,
     &maxmls,totatm,volm,kmax1,kmax2,kmax3,epsq,dlrpot,
     &ntpatm,maxvdw,engunit,delrc,estep,linitsurf,surftol,sumchg,
     &engsictmp,chgtmp,overlap,newld)

      gpress=gstfuga(iguest)
      accepted=.false.

      rande=duni(idnode)
      call energy_eval
     &(-estep,rande,statvolm,iguest,0,temp,beta,
     &.false.,.false.,.true.,.false.,accepted)
         
c     the following occurs if the move is accepted.
      if(accepted)then
        accept_del=accept_del+1
        call accept_move
     &(iguest,.false.,.true.,.false.,
     &linitsurf,delrc,totatm,randchoice,ntpfram,ntpguest,maxmls,
     &sumchg,engsictmp,chgtmp,newld)
      else
        call reject_move
     &(iguest,0,.false.,.true.,.false.,.false.)
      endif
      return
      end subroutine wl_delete

      subroutine wl_displace
     &(idnode,imcon,keyfce,iguest,totatm,volm,statvolm,tran,
     &tran_count,tran_delr,rota,rota_count,rota_rotangle,disp_count,
     &delrdisp,rotangle,maxmls,kmax1,kmax2,kmax3,newld,alpha,rcut,delr,
     &drewd,epsq,engunit,overlap,surftol,dlrpot,sumchg,accepted,temp,
     &beta,delrc,ntpatm,maxvdw,accept_tran,accept_rota,accept_disp,
     &ntpguest,ntpfram)
c*******************************************************************************
c
c     Keeps track of all the associated arrays and calls the 
c     'wl_displace_guest' subroutine. 
c     The underlying mechanics of this code is a 'deletion/insertion'
c     move, where the molecule is only perturbed as far as delrdisp and
c     rotangle dictates.
c     Acceptance/rejection criteria based on Metropolis
c     importance sampling coupled to 
c
c*******************************************************************************
      implicit none
      logical tran,rota,loverlap,linitsurf,lnewsurf,accepted
      integer iguest,keyfce,imcon,idnode,tran_count,rota_count
      integer disp_count,mol,ik,newld,maxmls,totatm,maxvdw
      integer kmax1,kmax2,kmax3,randchoice,nmol,ntpatm
      integer accept_tran,accept_rota,accept_disp
      integer ntpguest,ntpfram
      real(8) a,b,c,q1,q2,q3,q4,tran_delr,rota_rotangle,epsq
      real(8) delrdisp,rotangle,volm,alpha,rcut,delr,drewd
      real(8) engunit,overlap,surftol,dlrpot,sumchg,estep,rande
      real(8) statvolm,temp,beta,delrc,engsictmp,chgtmp,guest_toten

      mol=locguest(iguest)
      nmol=nummols(mol)

      a=0.d0;b=0.d0;c=0.d0;q1=0.d0;q2=0.d0;q3=0.d0;q4=0.d0
      if(tran)then
        dis(iguest)=2
        tran_count = tran_count + 1
        call random_disp(idnode,tran_delr,a,b,c)
      elseif(rota)then
        dis(iguest)=3
        rota_count = rota_count + 1
c        a=0.5d0
c        b=0.5d0
c        c=0.5d0
        call random_rot(idnode,rota_rotangle,q1,q2,q3,q4)
      else
        dis(iguest)=1
        disp_count=disp_count+1
        call random_disp(idnode,delrdisp,a,b,c)
        call random_rot(idnode,rotangle,q1,q2,q3,q4)
      endif
      do ik=1,newld
        ckcsorig(mol,ik)=ckcsum(mol,ik) 
        ckssorig(mol,ik)=ckssum(mol,ik) 
        ckcsorig(maxmls+1,ik)=ckcsum(maxmls+1,ik) 
        ckssorig(maxmls+1,ik)=ckssum(maxmls+1,ik)
      enddo
c     choose a molecule from the list
      randchoice=floor(duni(idnode)*nmol)+1

      call wl_displace_guest
     &(imcon,alpha,rcut,delr,drewd,totatm,newld,
     &maxmls,volm,kmax1,kmax2,kmax3,
     &epsq,engunit,overlap,surftol,linitsurf,lnewsurf,loverlap,
     &iguest,randchoice,dlrpot,sumchg,a,b,c,q1,q2,q3,q4,estep)
      accepted=.false.
      if (.not.loverlap)then
        if(estep.lt.0.d0)then
          accepted=.true.
        else
          rande=duni(idnode)
          call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &.true.,.false.,.false.,.false.,accepted)
        endif
      endif
c     DEBUG
c      accepted=.true.
c      accepted=.false.
c     END DEBUG
      if(accepted)then
        call accept_move
     &(iguest,.false.,.false.,.true.,
     &lnewsurf,delrc,totatm,randchoice,ntpfram,ntpguest,maxmls,
     &sumchg,engsictmp,chgtmp,newld)
c       check if the energy probability grid is requested,
c       then one has to compute the standalone energy
c       at the new position (requires ewald1 calc)
        if(lprobeng(iguest))then
          call gstlrcorrect(imcon,iguest,keyfce,
     &                        ntpatm,maxvdw,delrc,
     &                        volm,maxmls,.true.) 
          guest_toten=estep-delrc/engunit
        endif            
c       tally surface molecules
        if((linitsurf).and.(.not.lnewsurf))then
          surfacemols(mol) = surfacemols(mol) - 1
          if(surfacemols(mol).lt.0)surfacemols(mol) = 0
        elseif((.not.linitsurf).and.(lnewsurf))then
          surfacemols(mol) = surfacemols(mol) + 1
        endif
        if(tran)then
          accept_tran = accept_tran + 1
        elseif(rota)then
          accept_rota = accept_rota + 1
        else
          accept_disp=accept_disp+1
        endif
      else
        do ik=1,newld
          ckcsum(mol,ik)=ckcsorig(mol,ik) 
          ckssum(mol,ik)=ckssorig(mol,ik) 
          ckcsum(maxmls+1,ik)=ckcsorig(maxmls+1,ik) 
          ckssum(maxmls+1,ik)=ckssorig(maxmls+1,ik)
c          ckcsnew(mol,ik)=0.d0
c          ckssnew(mol,ik)=0.d0
c          ckcsnew(maxmls+1,ik)=0.d0 
c          ckssnew(maxmls+1,ik)=0.d0
        enddo
        call reject_move
     &(iguest,0,.false.,.false.,.true.,.false.)
      endif
      return
      end subroutine wl_displace

      subroutine wl_jump
     &(idnode,imcon,keyfce,iguest,totatm,volm,statvolm,
     &jump_count,jumpangle,maxmls,kmax1,kmax2,kmax3,newld,alpha,
     &rcut,delr,drewd,epsq,engunit,overlap,surftol,dlrpot,sumchg,
     &accepted,temp,beta,delrc,ntpatm,maxvdw,accept_jump,ntpfram,
     &ntpguest)
c*******************************************************************************
c
c     Keeps track of all the associated arrays and calls the 
c     'wl_displace_guest' subroutine. 
c     The underlying mechanics of this code is a 'deletion/insertion'
c     move, where the molecule is randomly perturbed to another point  
c     in the simulation cell.
c     Acceptance/rejection criteria based on Metropolis
c     importance sampling coupled to 
c
c*******************************************************************************
      implicit none
      logical accepted,linitsurf,lnewsurf,loverlap
      integer idnode,imcon,keyfce,iguest,totatm,jump_count,maxmls,kmax1
      integer kmax2,kmax3,newld,ntpatm,maxvdw,accept_jump,randchoice
      integer nmol,natms,mol,ik,ntpfram,ntpguest
      real(8) volm,statvolm,jumpangle,alpha,rcut,delr,drewd,epsq,engunit
      real(8) overlap,surftol,dlrpot,sumchg,temp,beta,delrc
      real(8) a,b,c,q1,q2,q3,q4,estep,gpress,rande,engsictmp,chgtmp

      mol=locguest(iguest)
      nmol=nummols(mol)
      natms=numatoms(mol)

      jmp(iguest)=1
      jump_count=jump_count+1
c     choose a molecule from the list
      randchoice=floor(duni(idnode)*nmol)+1
c     find which index the molecule "randchoice" is
      do ik=1,newld
        ckcsorig(mol,ik)=ckcsum(mol,ik) 
        ckssorig(mol,ik)=ckssum(mol,ik) 
        ckcsorig(maxmls+1,ik)=ckcsum(maxmls+1,ik) 
        ckssorig(maxmls+1,ik)=ckssum(maxmls+1,ik)
      enddo
      call get_guest(iguest,randchoice,mol,natms,nmol)

      call random_jump
     &(idnode,a,b,c,jumpangle)
      call random_rot(idnode,jumpangle,q1,q2,q3,q4)

      call wl_displace_guest
     &(imcon,alpha,rcut,delr,drewd,totatm,newld,maxmls,volm,kmax1,
     &kmax2,kmax3,epsq,engunit,overlap,surftol,linitsurf,lnewsurf,
     &loverlap,iguest,randchoice,dlrpot,sumchg,a,b,c,q1,q2,q3,q4,estep)

      accepted=.false.
      if (.not.loverlap)then
        gpress=gstfuga(iguest)
        if(estep.lt.0.d0)then
          accepted=.true.
        else
          accepted=.false.
          rande=duni(idnode)
          call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &.true.,.false.,.false.,.false.,accepted)
        endif
      endif

      if(accepted)then
        accept_jump=accept_jump+1
        call accept_move
     &(iguest,.false.,.false.,.true.,
     &lnewsurf,delrc,totatm,randchoice,ntpfram,ntpguest,maxmls,
     &sumchg,engsictmp,chgtmp,newld)
c       tally surface molecules
        if((linitsurf).and.(.not.lnewsurf))then
          surfacemols(mol) = surfacemols(mol) - 1
          if (surfacemols(mol).lt.0)surfacemols(mol) = 0
        elseif((.not.linitsurf).and.(lnewsurf))then
          surfacemols(mol) = surfacemols(mol) + 1
        endif
      else
        do ik=1,newld
          ckcsum(mol,ik)=ckcsorig(mol,ik) 
          ckssum(mol,ik)=ckssorig(mol,ik) 
          ckcsum(maxmls+1,ik)=ckcsorig(maxmls+1,ik) 
          ckssum(maxmls+1,ik)=ckssorig(maxmls+1,ik)
        enddo
        call reject_move
     &(iguest,0,.false.,.false.,.true.,.false.)
      endif
      return
      end subroutine wl_jump

      subroutine wl_switch
     &(idnode,imcon,keyfce,iguest,totatm,volm,statvolm,
     &switch_count,maxmls,kmax1,kmax2,kmax3,newld,alpha,
     &rcut,delr,drewd,epsq,engunit,overlap,surftol,dlrpot,sumchg,
     &accepted,temp,beta,delrc,ntpatm,maxvdw,accept_switch,ntpfram,
     &ntpguest)
c*******************************************************************************
c
c     Keeps track of all the associated arrays and calls the 
c     The underlying mechanics of this code is a 
c     'deletion / displacement / insertion'
c     move, where two molecules of different types in the simulation cell 
c     switch locations.
c     Acceptance/rejection criteria based on Metropolis
c     importance sampling coupled to 
c
c     *** Currently only one switch is performed, but one could possibly
c         include multi switches as long as (detailed) balance isn't
c         violated. ***
c*******************************************************************************
      implicit none
      logical accepted,loverlap,loverallap,linitsurf,linitsurfj
      logical lnewsurf,lnewsurfj
      integer switch_count,nswitchgst,ntpguest,i,j,mol,nmols,jguest
      integer ichoice,jchoice,imol,jmol,ik,kk,iatm,idnode,imcon,keyfce
      integer iguest,totatm,maxmls,kmax1,kmax2,kmax3,newld
      integer ntpatm,maxvdw,accept_switch,ntpfram,natms
      real(8) icomx,icomy,icomz,jcomx,jcomy,jcomz,estep
      real(8) estepi,estepj,volm,statvolm,alpha,rcut,delr,drewd,epsq
      real(8) engunit,overlap,surftol,dlrpot,sumchg,temp,beta,delrc
      real(8) engsictmp,chgtmp,rande 
      nswitchgst = 0
      do i=1,ntpguest
        mol=locguest(i)
        nmols=nummols(mol)
c       generate array of molecules to randomly select
        do j=1,nmols
          switch_mols(i,j) = j
        enddo
        switch_mol_count(i) = nmols
        if((nmols.gt.0).and.(i.ne.iguest))then
          nswitchgst=nswitchgst+1
          switch_chosen_guest(nswitchgst)=i
        endif
      enddo
c     return if one can't make a switch move
      if(nswitchgst.lt.2)return
      switch_count=switch_count+1
      engsicorig = engsic
c     loverallap is true if one or both of the guests 
c     overlap with other atoms in their new configurations.
      loverallap=.false.
c     random choice of the second guest to switch
      jguest = floor(duni(idnode)*nswitchgst)+1
      jguest = switch_chosen_guest(jguest)
c     molecule choice to switch on each
      swi(iguest)=swi(iguest)+1
      ichoice=floor(duni(idnode)*switch_mol_count(iguest))+1
      ichoice = switch_mols(iguest,ichoice)
      
      swi(jguest)=swi(jguest)+1
      jchoice=floor(duni(idnode)*switch_mol_count(jguest))+1
      jchoice= switch_mols(jguest,jchoice)
c     store original framework configuration if the move is rejected
      do i=1,maxmls
        origenergy(i) = energy(i)
        origsurfmols(i) = surfacemols(i)
      enddo
      jmol=locguest(jguest)
      imol=locguest(iguest)
c     back up original arrays in case move is rejected
      do kk=1,totatm
        origmolxxx(imol,kk) = molxxx(imol,kk)
        origmolyyy(imol,kk) = molyyy(imol,kk)
        origmolzzz(imol,kk) = molzzz(imol,kk)
        origmolxxx(jmol,kk) = molxxx(jmol,kk)
        origmolyyy(jmol,kk) = molyyy(jmol,kk)
        origmolzzz(jmol,kk) = molzzz(jmol,kk)
      enddo
      do ik=1,newld
        ckcsorig(imol,ik)=ckcsum(imol,ik) 
        ckssorig(imol,ik)=ckssum(imol,ik) 
        ckcsorig(jmol,ik)=ckcsum(jmol,ik) 
        ckssorig(jmol,ik)=ckssum(jmol,ik) 
        ckcsorig(maxmls+1,ik)=ckcsum(maxmls+1,ik) 
        ckssorig(maxmls+1,ik)=ckssum(maxmls+1,ik)
c        ckcsnew(imol,ik)=0.d0
c        ckssnew(imol,ik)=0.d0
c        ckcsnew(jmol,ik)=0.d0
c        ckssnew(jmol,ik)=0.d0
c        ckcsnew(maxmls+1,ik)=0.d0 
c        ckssnew(maxmls+1,ik)=0.d0
      enddo
c     keeping track of the guest orientations by
c     re-populating the 'template' configurations for
c     guestx,guesty,guestz
      call get_guest(jguest,jchoice,jmol,natms,nmols)
      call com(natms,jmol,newx,newy,newz,jcomx,jcomy,jcomz)
      do iatm=1,natms
        guestx(jguest,iatm)=newx(iatm) - jcomx
        guesty(jguest,iatm)=newy(iatm) - jcomy
        guestz(jguest,iatm)=newz(iatm) - jcomz
      enddo
      call get_guest(iguest,ichoice,imol,natms,nmols)
      call com(natms,imol,newx,newy,newz,icomx,icomy,icomz)
      do iatm=1,natms
        guestx(iguest,iatm)=newx(iatm) - icomx
        guesty(iguest,iatm)=newy(iatm) - icomy
        guestz(iguest,iatm)=newz(iatm) - icomz
      enddo
c************************************************************************
c       START SWITCH OF GUESTI AND GUESTJ
c       Delete it, since shifting it to the new position would
c       create infinite energies.
c************************************************************************
      estep = 0.d0
      call deletion 
     &(imcon,keyfce,iguest,ichoice,alpha,rcut,delr,drewd,maxmls,
     &totatm,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estep,linitsurf,surftol,sumchg,engsictmp,chgtmp,
     &overlap,newld)
c     have to default accept move so the energy arrays are updated
c     and ichoice from iguest is actually deleted from the system
c     so that jchoice from jguest can be inserted there.
      call accept_move
     &(iguest,.false.,.true.,.false.,linitsurf,delrc,totatm,ichoice,
     &ntpfram,ntpguest,maxmls,sumchg,engsictmp,chgtmp,newld)
      estepi=-estep
      call get_guest(jguest,jchoice,jmol,natms,nmols)
      estep=0.d0
      call deletion 
     &(imcon,keyfce,jguest,jchoice,alpha,rcut,delr,drewd,maxmls,
     &totatm,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estep,linitsurfj,surftol,sumchg,engsictmp,chgtmp,
     &overlap,newld)
      call accept_move
     &(jguest,.false.,.true.,.false.,linitsurfj,delrc,totatm,jchoice,
     &ntpfram,ntpguest,maxmls,sumchg,engsictmp,chgtmp,newld)
      estepj=-estep

c     now insert the guests in their new positions (jguest in iguests
c     position and vise versa)
      do iatm=1,natms
        newx(iatm) = guestx(jguest,iatm) + icomx
        newy(iatm) = guesty(jguest,iatm) + icomy
        newz(iatm) = guestz(jguest,iatm) + icomz
      enddo
      estep=0.d0
      call insertion
     & (imcon,jguest,keyfce,alpha,rcut,delr,drewd,totatm,
     & volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     & engunit,delrc,estep,sumchg,chgtmp,engsictmp,maxmls,
     & loverlap,lnewsurfj,surftol,overlap,newld)
      if(loverlap)loverallap=.true.
      estepj=estepj+estep
      call accept_move
     &(jguest,.true.,.false.,.false.,lnewsurfj,delrc,totatm,jchoice,
     &ntpfram,ntpguest,maxmls,sumchg,engsictmp,chgtmp,newld)

      call get_guest(iguest,ichoice,imol,natms,nmols)
      do iatm=1,natms
        newx(iatm) = guestx(iguest,iatm) + jcomx
        newy(iatm) = guesty(iguest,iatm) + jcomy
        newz(iatm) = guestz(iguest,iatm) + jcomz
      enddo
      estep=0.d0
      call insertion
     & (imcon,iguest,keyfce,alpha,rcut,delr,drewd,totatm,
     & volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     & engunit,delrc,estep,sumchg,chgtmp,engsictmp,maxmls,
     & loverlap,lnewsurf,surftol,overlap,newld)
      if(loverlap)loverallap=.true.
      estepi=estepi+estep
      call accept_move
     &(iguest,.true.,.false.,.false.,lnewsurf,delrc,totatm,ichoice,
     &ntpfram,ntpguest,maxmls,sumchg,engsictmp,chgtmp,newld)
c************************************************************************
c           END OF SWITCH
c************************************************************************
c     perform energy evaluation
      if((estepi+estepj).lt.0.d0)then
        accepted=.true.
      else
        accepted=.false.
        rande=duni(idnode)
        call energy_eval
     &(estepi+estepj,rande,statvolm,iguest,jguest,temp,beta,
     &.true.,.false.,.false.,.false.,accepted)
      endif
      if(loverallap)accepted=.false.
c     DEBUG
c      accepted=.false.
c     END DEBUG
      if(accepted)then
        accept_switch=accept_switch+1
        call condense(totatm,ntpfram,ntpguest)
      else
        do ik=1,maxmls
          delE(ik)=0.d0
          energy(ik)=origenergy(ik)
          surfacemols(ik)=origsurfmols(ik)
        enddo
c       restore original framework if move is rejected
        do ik=1,totatm 
          molxxx(imol,ik)=origmolxxx(imol,ik)
          molyyy(imol,ik)=origmolyyy(imol,ik)
          molzzz(imol,ik)=origmolzzz(imol,ik)
          molxxx(jmol,ik)=origmolxxx(jmol,ik)
          molyyy(jmol,ik)=origmolyyy(jmol,ik)
          molzzz(jmol,ik)=origmolzzz(jmol,ik)
        enddo
c       restore original ewald1 sums if step is rejected
        do ik=1,newld
          ckcsum(imol,ik)=ckcsorig(imol,ik) 
          ckssum(imol,ik)=ckssorig(imol,ik) 
          ckcsum(jmol,ik)=ckcsorig(jmol,ik) 
          ckssum(jmol,ik)=ckssorig(jmol,ik) 
          ckcsum(maxmls+1,ik)=ckcsorig(maxmls+1,ik) 
          ckssum(maxmls+1,ik)=ckssorig(maxmls+1,ik)
c          ckcsnew(imol,ik)=0.d0
c          ckssnew(imol,ik)=0.d0
c          ckcsnew(jmol,ik)=0.d0
c          ckssnew(jmol,ik)=0.d0
c          ckcsnew(maxmls+1,ik)=0.d0 
c          ckssnew(maxmls+1,ik)=0.d0
        enddo
        elrc=origelrc
        elrc_mol=origelrc_mol
        engsic=engsicorig
c       restore original surfacemols if step is rejected
        call condense(totatm,ntpfram,ntpguest)
      endif
      return
      end subroutine wl_switch

      subroutine wl_swap
     &(idnode,imcon,keyfce,iguest,jguest,totatm,volm,statvolm,
     &swap_count,maxmls,kmax1,kmax2,kmax3,newld,alpha,
     &rcut,delr,drewd,epsq,engunit,overlap,surftol,dlrpot,sumchg,
     &accepted,temp,beta,delrc,ntpatm,maxvdw,accept_swap,ntpfram,
     &ntpguest,rotangle)
c*******************************************************************************
c
c     Keeps track of all the associated arrays and calls the 
c     'deletion' and 'insertion' subroutines. 
c     The underlying mechanics of this code is a 'deletion/insertion'
c     move, where a molecule in the simulation cell is swapped with a
c     molecule with a different identity.
c     Acceptance/rejection criteria based on Metropolis
c     importance sampling coupled 
c
c*******************************************************************************
      implicit none
      logical accepted,linitsurf,lnewsurf,loverlap
      integer idnode,imcon,keyfce,iguest,jguest,totatm,swap_count
      integer maxmls,kmax1,kmax2,kmax3,origtotatm,ik,imol,jmol,iatm
      integer newld,ntpatm,maxvdw,accept_swap,randchoice
      integer nmols,natms,mol,ntpfram,ntpguest,ichoice,jchoice,j
      integer jnatms,jnmols
      real(8) volm,statvolm,alpha,rcut,delr,drewd,epsq,engunit
      real(8) overlap,surftol,dlrpot,sumchg,temp,beta,delrc
      real(8) a,b,c,q1,q2,q3,q4,estepi,estepj,gpress,rande,estep
      real(8) comx,comy,comz,engsictmp,chgtmp,rotangle

      swap_count = swap_count+1
      origtotatm = totatm 

      imol=locguest(iguest)
      natms=numatoms(imol)
      nmols=nummols(imol)
c     store original ewald1 sums in case the move is rejected
      do ik=1,maxmls
        chgsum_molorig(ik)=chgsum_mol(ik)
        origsurfmols(ik)=surfacemols(ik)
        origenergy(ik)=energy(ik)
      enddo
      engsicorig=engsic
      origelrc = elrc
      origelrc_mol=elrc_mol
      do j=1,iguest-1
        switch_chosen_guest(j) = j
      enddo 
      do j=iguest,ntpguest
        switch_chosen_guest(j)=j+1
      enddo
      ichoice=floor(duni(idnode)*nmols)+1
      call get_guest(iguest,ichoice,imol,natms,nmols)
      call com(natms,imol,newx,newy,newz,comx,comy,comz)
c     chose a second guest to swap with
      jguest = floor(duni(idnode) * (ntpguest-1)) + 1
      jguest = switch_chosen_guest(jguest)
      jmol=locguest(jguest)
c     store original framework configuration if the move is rejected
      do ik=1,totatm
        origmolxxx(imol,ik)=molxxx(imol,ik)
        origmolyyy(imol,ik)=molyyy(imol,ik)
        origmolzzz(imol,ik)=molzzz(imol,ik)
        origmolxxx(jmol,ik)=molxxx(jmol,ik)
        origmolyyy(jmol,ik)=molyyy(jmol,ik)
        origmolzzz(jmol,ik)=molzzz(jmol,ik)
      enddo
      do ik=1,newld
        ckcsorig(imol,ik)=ckcsum(imol,ik) 
        ckssorig(imol,ik)=ckssum(imol,ik) 
        ckcsorig(jmol,ik)=ckcsum(jmol,ik) 
        ckssorig(jmol,ik)=ckssum(jmol,ik) 
        ckcsorig(maxmls+1,ik)=ckcsum(maxmls+1,ik) 
        ckssorig(maxmls+1,ik)=ckssum(maxmls+1,ik)
c        ckcsnew(imol,ik)=0.d0
c        ckssnew(imol,ik)=0.d0
c        ckcsnew(jmol,ik)=0.d0
c        ckssnew(jmol,ik)=0.d0
c        ckcsnew(maxmls+1,ik)=0.d0
c        ckssnew(maxmls+1,ik)=0.d0 
      enddo
      swp(iguest) = 1
      swp(jguest) = 1     
c     delete first guest
      estepi=0.d0
      call deletion 
     &(imcon,keyfce,iguest,ichoice,alpha,rcut,delr,drewd,maxmls,
     &totatm,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estepi,linitsurf,surftol,sumchg,engsictmp,chgtmp,
     &overlap,newld)
      call accept_move
     &(iguest,.false.,.true.,.false.,
     &linitsurf,delrc,totatm,ichoice,ntpfram,ntpguest,maxmls,
     &sumchg,engsictmp,chgtmp,newld)
c     insert second guest
      jmol=locguest(jguest)
      jnatms=numatoms(jmol)
      jnmols=nummols(jmol)

      do iatm=1,jnatms
        newx(iatm) = guestx(jguest,iatm) + comx
        newy(iatm) = guesty(jguest,iatm) + comy
        newz(iatm) = guestz(jguest,iatm) + comz
      enddo
      call random_rot(idnode,rotangle,q1,q2,q3,q4)
      call rotation(newx,newy,newz,comx,comy,comz,
     & jnatms,q1,q2,q3,q4)

      estepj=0.d0
      call insertion
     & (imcon,jguest,keyfce,alpha,rcut,delr,drewd,totatm,
     & volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     & engunit,delrc,estepj,sumchg,chgtmp,engsictmp,maxmls,
     & loverlap,lnewsurf,surftol,overlap,newld)
      jchoice=0
      call accept_move
     &(jguest,.true.,.false.,.false.,
     &lnewsurf,delrc,totatm,jchoice,ntpfram,ntpguest,maxmls,
     &sumchg,engsictmp,chgtmp,newld)

c     acceptance criteria
      accepted=.false.
      if(.not.loverlap)then
        rande=duni(idnode)
        estep = estepj - estepi
        call energy_eval
     &(estep,rande,statvolm,iguest,jguest,temp,beta,
     &.false.,.false.,.false.,.true.,accepted)
      endif
c     DEBUG
c      accepted=.false.
c     END DEBUG
      if(accepted)then
        accept_swap=accept_swap+1
        call condense(totatm,ntpfram,ntpguest)
      else
c       restore original framework if move is rejected
        call reject_move
     &(iguest,jguest,.false.,.false.,.false.,.true.)
        do ik=1,totatm
          molxxx(imol,ik)=origmolxxx(imol,ik)
          molyyy(imol,ik)=origmolyyy(imol,ik)
          molzzz(imol,ik)=origmolzzz(imol,ik)
          molxxx(jmol,ik)=origmolxxx(jmol,ik)
          molyyy(jmol,ik)=origmolyyy(jmol,ik)
          molzzz(jmol,ik)=origmolzzz(jmol,ik)
        enddo
c       restore original ewald1 sums if step is rejected
        do ik=1,newld
          ckcsum(imol,ik)=ckcsorig(imol,ik) 
          ckssum(imol,ik)=ckssorig(imol,ik) 
          ckcsum(jmol,ik)=ckcsorig(jmol,ik) 
          ckssum(jmol,ik)=ckssorig(jmol,ik) 
          ckcsum(maxmls+1,ik)=ckcsorig(maxmls+1,ik) 
          ckssum(maxmls+1,ik)=ckssorig(maxmls+1,ik)
c          ckcsnew(imol,ik)=0.d0
c          ckssnew(imol,ik)=0.d0
c          ckcsnew(jmol,ik)=0.d0
c          ckssnew(jmol,ik)=0.d0
c          ckcsnew(maxmls+1,ik)=0.d0
c          ckssnew(maxmls+1,ik)=0.d0 
        enddo
        chgsum_mol(imol)=chgsum_molorig(imol)
        chgsum_mol(jmol)=chgsum_molorig(jmol)
c       restore original surfacemols if step is rejected
        surfacemols(imol)=origsurfmols(imol)
        surfacemols(jmol)=origsurfmols(jmol)
        elrc = origelrc
        totatm = origtotatm
        nummols(locguest(iguest)) = nummols(locguest(iguest)) + 1
        nummols(locguest(jguest)) = nummols(locguest(jguest)) - 1
        call condense(totatm,ntpfram,ntpguest)
        energy = origenergy
      endif
      return
      end subroutine wl_swap

      subroutine wl_displace_guest
     &(imcon,alpha,rcut,delr,drewd,totatm,newld,
     &maxmls,volm,kmax1,kmax2,kmax3,
     &epsq,engunit,overlap,surftol,linitsurf,lnewsurf,loverlap,
     &iguest,imol,dlrpot,sumchg,a,b,c,q1,q2,q3,q4,estep)
c***********************************************************************
c                                                                      *
c     Displace a guest from its initial point to a pre-defined         *
c     coordinate (therefore useable for both random jumps, and         *
c     normal displacements)                                            *
c                                                                      *
c***********************************************************************
      implicit none
      logical loverlap,linitsurf,lnewsurf
      integer imcon,totatm,maxmls
      integer kmax1,kmax2,kmax3,iguest,imol,i,mol,newld
      integer nmols,natms,ik,mxcmls
      real(8) alpha,rcut,delr,drewd,volm,epsq,overlap,surftol
      real(8) dlrpot,sumchg,comx,comy,comz,q1,q2,q3,q4,a,b,c
      real(8) estep,enginit,engunit,ewld3sum,chgtmp,engsictmp
      real(8) ewld1eng,ewld2sum,vdwsum
      call get_guest(iguest,imol,mol,natms,nmols)
c     Calculate the energy for the chosen guest in
c     its orginal place
      mxcmls=maxmls*(maxmls-1)/2 + maxmls
      mol=locguest(iguest) 
      call guest_energy
     &(imcon,iguest,alpha,rcut,delr,drewd,
     &totatm,maxmls,volm,kmax1,kmax2,kmax3,epsq,dlrpot,
     &engunit,vdwsum,ewld2sum,ewld1eng,linitsurf,newld,
     &surftol,sumchg,chgtmp,engsictmp,loverlap,overlap,estep,.true.)
      ewld3sum=ewald3en(mol)
c      print *, "EWALD1:", (-ewld1eng-ewld3sum)/engunit
c      print *, "EWALD2:", ewld2sum/engunit
c      print *, "VDW   :", vdwsum/engunit
c      print *, "DELRC :", delrc/engunit
c      print *, "ESTEP :", estep - delrc/engunit

      enginit=estep
      do ik=1,mxcmls
        ewald1entmp(ik) = ewald1en(ik)
        ewald2entmp(ik) = ewald2en(ik)
        vdwentmp(ik) = vdwen(ik)
      enddo
      do ik=1,newld
        ckcsum(mol,ik)=ckcsum(mol,ik)-ckcsnew(mol,ik)
        ckssum(mol,ik)=ckssum(mol,ik)-ckssnew(mol,ik)
        ckcsum(maxmls+1,ik)=ckcsum(maxmls+1,ik)-ckcsnew(maxmls+1,ik)
        ckssum(maxmls+1,ik)=ckssum(maxmls+1,ik)-ckssnew(maxmls+1,ik)
c        ckcsnew(mol,ik)=0.d0
c        ckssnew(mol,ik)=0.d0
c        ckcsnew(maxmls+1,ik)=0.d0 
c        ckssnew(maxmls+1,ik)=0.d0
      enddo
      call translate
     &(natms,mol,newx,newy,newz,cell,rcell,comx,comy,comz,
     &a,b,c)
      call rotation(newx,newy,newz,comx,comy,comz,natms,q1,q2,q3,q4)
      call guest_energy
     &(imcon,iguest,alpha,rcut,delr,drewd,
     &totatm,maxmls,volm,kmax1,kmax2,kmax3,epsq,dlrpot,
     &engunit,vdwsum,ewld2sum,ewld1eng,lnewsurf,newld,
     &surftol,sumchg,chgtmp,engsictmp,loverlap,overlap,estep,.false.)
c      print *, "EWALD1:", (-ewld1eng-ewld3sum)/engunit
c      print *, "EWALD2:", ewld2sum/engunit
c      print *, "VDW   :", vdwsum/engunit
c      print *, "DELRC :", delrc/engunit
c      print *, "ESTEP :", estep + delrc/engunit 
c     total up the energy contributions.
      estep=estep-enginit
      do i=1, maxmls
        ik=loc2(mol,i)
        if(i.ne.mol)delE(i)=delE(i)+
     &(ewald1en(ik)-ewald1entmp(ik)
     &+ewald2en(ik)-ewald2entmp(ik)
     &+vdwen(ik)-vdwentmp(ik))
     &/engunit
      enddo
      delE(mol)=delE(mol)+
     &  estep

      return
      end subroutine wl_displace_guest
      end module wang_landau
