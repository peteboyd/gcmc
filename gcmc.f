c*************************************************************
c      main gcmc program                                     *
c*************************************************************
c      personal reference                                    *
c      imcon                                                 *
c      0  -  no periodic boundaries                          *
c      1  -  cubic boundary conditions  (b.c.)               *
c      2  -  orthorhombic b.c.                               *
c      3  -  parallelpiped b.c.                              *
c      4  -  truncated octahedral b.c.                       *
c      5  -  rhombic dodecahedral b.c                        *
c      6  -  x-y parallelogram b.c. no periodicity in z      *
c      7  -  hexagonal prism b.c.                            *
c                                                            *
c                                                            *
c                                                            *
c                                                            *
c     avgwindow will reset to 0's once the average has been  *
c     carried over to varwindow.                             *
c     Varwindow will be a rolling variance calculation of    *
c     the windowed averages.                                 * 
c     currently the order is:                                *
c     chainstats(1) = production gcmc step count             *
c     chainstats(2) = rolling average number of guests <N>   *
c     chainstats(3) = rolling average energy <E>             *
c     chainstats(4) = rolling average for energy*guests <EN> *
c     chainstats(5) = rolling average for N^2 <N2>           *
c     chainstats(6) = rolling average for (energy)^2 <E2>    *
c     chainstats(7) = rolling average for <N surface>        *
c     chainstats(8) = rolling average for <exp(-E/kb/T)>     *
c     chainstats(9) = rolling stdev value for <N>            *
c     chainstats(10) = rolling stdev value for <E>           *
c     chainstats(11) = rolling stdev value for <EN>          *
c     chainstats(12) = rolling stdev value for <N2>          *
c     chainstats(13) = rolling stdev value for <E2>          *
c     chainstats(14) = rolling stdev value for <N surface>   *
c     chainstats(15) = rolling stdev value for <Q_st>        *
c     chainstats(16) = rolling stdev value for <C_v>         *
c     chainstats(17) = rolling stdev value for <exp(-E/kb/T)>*
c*************************************************************


      use utility_pack
      use readinputs
      use vdw_module
      use flex_module
      use ewald_module

      implicit none

      character*1 cfgname(80)      
      character*8 outdir,localdir
      character*2 mnth
      character*7 debug
      character(8):: date
      character(10) :: time
      character(5) :: zone
      character*25 outfile
      character*80 command
      character*25 outfile2
      character*21 outfile3
      character*18 outfile4
      character*70 string
      logical lgchk,lspe,ljob,lprob,widchk
      logical lfuga, loverlap, lwidom, lwanglandau
      logical insert,delete,displace,lrestart,laccsample
      logical jump, flex, swap, switch
      logical tran, rota
      logical accepted,production,jobsafe,lnumg
      logical tick_tock_cycles(5)
      logical lnewsurf, linitsurf, lnewsurfj,linitsurfj
      integer, dimension(1) :: myseed
      integer nfo(8)
      integer accept_ins,accept_del,accept_disp,totaccept,nnumg,nhis
      integer accept_jump, accept_flex, accept_swap, scell_factor
      integer accept_switch,minchk
      integer accept_tran, accept_rota, aa, ab, ivdw
      integer ins_count,del_count,disp_count,buffer,idum,levcfg,nstat
      integer jump_count, flex_count, swap_count, np, widcount
      integer tran_count, rota_count, ichain, inodes, switch_count
      integer totatm,jatm,isite,imol,at,atmadd,iatm,ntprob,ntpsite
      integer itatm,newld,gcmccount,prodcount,globalprod,ii
      integer ibuff,iprob,cprob,totfram,prevnodes,nwind,rollstat,c
      integer n,k,p,i,j,ik,ka,jj,kk,l,mm,ierr,ksite,ntpatm,nang,gridsize
      integer kmax1,kmax2,kmax3,ntpvdw,maxvdw,mxcmls,maxmls,mxnode
      integer ntpfram,randchoice,nmols,ngsts,molecules,totsteps
      integer ichoice,jchoice,iswap,origtotatm
      integer mxatm,imcon,keyfce,mxatyp,sittyp,mcsteps,eqsteps,vstat
      integer iguest,ntpguest,ntpmls,natms,mol,maxanglegrid,rollcount
      integer jguest,jmol,jnatms,jnmols,ifram,nframmol
      integer ins_rollcount, nswapguest, num_swaps, swap_max
      integer swap_guest_max,idnode
      integer ngrida,ngridb,ngridc,nguests,mxewld,istat,avcount
      integer totalguests,globalnguests,globalsteps
      integer, allocatable :: fwksumbuff(:)
      real(8), allocatable :: gridbuff(:)
      real(8), dimension(10) :: celprp
      real(8), dimension(10) :: ucelprp
      real(8), dimension(9) :: rcell
      real(8), dimension(9) :: rucell
      real(8) vdweng,sumchg
      real(8) ewld1test,ewld1,engsicold,ang,hyp,norm,oldeng,ewld1old
      real(8) det,engcpe,engacc,engac1,drewd,epsq,statvolm,volm
      real(8) engsrp,rand,randmov,chg,rande,delta,req,sig
      real(8) stdQst,stdCv,rotangle,delrc,junk,stdevcv,stdevq
      real(8) tzero,timelp,engunit,rvdw,press,temp,beta
      real(8) dlrpot,rcut,eps,alpha,delr,delrdisp,init,gpress
      real(8) ewld1eng,ewld2eng
      real(8) alen,blen,clen,ecoul,evdw
      real(8) ecoulg,evdwg,engcomm,dummy,overlap,surfmol
      real(8) ewld2sum,vdwsum,ewld3sum,comx,comy,comz,ewaldaverage
      real(8) comshiftx, comshifty, comshiftz 
      real(8) dmolecules,molecules2,energy2,Q_st,eng,C_v,cv_old
      real(8) weight,tw,spenergy,dlpeng,estep,thrd,twothrd
      real(8) estepi,estepj
      real(8) E,aN,EN,E2,N2,H_const,avgH,stdH,ak
      real(8) avgN,stdN,avgE,stdE,avgEN,stdEN,avgN2,stdN2,avgE2,stdE2
      real(8) avgNF,NF,stdNF,surftol,surftolsq,guest_toten
      real(8) newewld2sum,newvdwsum
      real(8) griddim,grvol,randa,randb,randc,rand1,rand2,rand3,rand4
      real(8), dimension(9) :: iabc
      real(8) delE_fwk, eng_before, eng_after
      integer m, indatm, indfwk, gstidx
      logical isguest
c Cumulative move probabilities, remeber to zero and include in normalising
      real(8) mcinsf, mcdelf, mcdisf, mcswpf, mcflxf, mcjmpf, mcmvnorm
      real(8) mctraf, mcrotf, mcswif,mcmvsum
      real(8) disp_ratio, tran_ratio, rota_ratio, tran_delr
      real(8) rota_rotangle, dis_delr, dis_rotangle
      integer, dimension(3) :: gridfactor
      integer fwk_step_magnitude

      data lgchk/.true./,insert/.false./,delete/.false./,
     &lwidom/.false./,lwanglandau/.false./,
     &displace/.false./,accepted/.false./,production/.false./
      data jump/.false./,flex/.false./,swap/.false./,switch/.false./
      data tran/.false./,rota/.false./,laccsample/.false./
      data lspe/.false./,ljob/.false./,jobsafe/.true./,lrestart/.false./
     &,lnumg/.false./
      data lfuga/.false./,loverlap/.false./ ! change to false
      data linitsurf/.false./,lnewsurf/.false./
      data linitsurfj/.false./,lnewsurfj/.false./
      data accept_ins,accept_del,accept_disp,totaccept/0,0,0,0/
      data accept_jump, accept_flex, accept_swap, accept_switch/0,0,0,0/
      data ins_count,del_count,disp_count,gcmccount,prevnodes/0,0,0,0,0/
      data jump_count, flex_count, swap_count, switch_count/0,0,0,0/
      data tran_count, rota_count, accept_tran, accept_rota/0,0,0,0/
c     Default these to grand canonical.. can turn 'off' in CONTROL file
      data mcinsf/0.3333333/
      data mcdelf/0.3333333/
      data mcdisf/0.3333333/
      data mcjmpf, mcflxf, mcswpf, mctraf, mcrotf, mcswif/0,0,0,0,0,0/

      integer, parameter, dimension(3) :: revision = (/1, 3, 5 /)
c     TODO(pboyd): include error checking for the number of guests
c     coinciding between the CONTROL file and the FIELD file.
      tw=0.d0
      ewaldaverage=0.d0
      ewld1old=0.d0
      guest_toten=0.d0
      ecoul=0.d0
      evdw=0.d0
      overlap=0.d0
c     surface tolerance default set to -1 angstroms (off)
      surftol=-1.d0
      ntpatm=0
      mxatm=0
      mxegrd=0
      gridsize=0
      ibuff=0
      nnumg=1
      rollcount=0
      ins_rollcount=0
      avcount = 0
c     averaging window to calculate errors
      nwind=100000

c scoping issues
      delrc = 0

c Default target acceptance ratios of 0.5      
      disp_ratio = 0.5d0
      tran_ratio = 0.5d0
      rota_ratio = 0.5d0

      thrd=1.d0/3.d0
      twothrd=2.d0/3.d0

c default length of a side of a grid box in angstroms (in CONTROL)
      griddim=0.1d0
c default supecell folding for grid points (in CONTROL)
      gridfactor = (/ 1, 1, 1 /)
      
c     global number of production steps over all nodes
      globalprod=0
c     local production steps (after equilibrium)
      prodcount=0
c     local insertion steps (after equilibrium) - to keep track 
c     newld is the number of ewald points in reciprocal space
      newld=0
c     mcsteps = number of production steps, energies and molecules
c counted towards final averages
      mcsteps=1
c     eqsteps = number of equilibrium steps, energies and molecules
c ignored
      eqsteps=0
c when running mc cycles keep track of if history to help averaging
      tick_tock_cycles = .false.
      
c     initialize communications
      call initcomms()
      call gsync()
      call timchk(0,tzero)

c     determine processor identities
      call machine(idnode,mxnode)

c     open main output file.
      if(idnode.eq.0)then

        open(nrite,file='OUTPUT')
        write(nrite,
     &"(/,20x,'FastMC version ',i1,'.',i1,'.',i1,/,/)")revision
        call date_and_time(date,time,zone,nfo)
        mnth=date(5:6)
        
        write(nrite,
     &"('Started : ',9x,a2,3x,a9,1x,a4,3x,a2,':',a2,a6,' GMT',/)")
     &date(7:8),month(mnth),date(1:4),time(1:2),time(3:4),zone
        write(nrite,"('Running on ',i4,' nodes',/,/)")mxnode
      endif
      call initscan
     &(idnode,imcon,volm,keyfce,rcut,eps,alpha,kmax1,kmax2,kmax3,lprob,
     & delr,rvdw,ntpguest,ntprob,ntpsite,ntpvdw,maxmls,mxatm,mxatyp,
     & griddim, gridfactor)

      maxvdw=max(ntpvdw,(mxatyp*(mxatyp+1))/2)
c      write(*,"('maxmls:',i6,' mxatm: ',i6,' mxatyp: ',i6,' volm: ',
c     & f9.3,' kmax2: ', i6, ' kmax3: ',i6,' mxebuf: ',i6,' mxewld: ',
c     & i6,' ntpguest: ',i6,' rcut: ',f6.3,' rvdw: ',f6.3,' delr: ',
c     & f6.3)")maxmls,mxatm,mxatyp,volm,kmax2,kmax3,mxebuf,mxewld,
c     & ntpguest,rcut,rvdw,delr
      call alloc_config_arrays
     & (idnode,mxnode,maxmls,mxatm,mxatyp,volm,ntpguest,rcut,rvdw,delr)

      call alloc_vdw_arrays(idnode,maxvdw,maxmls,mxatyp)
      call readfield
     &(idnode,ntpvdw,maxvdw,ntpatm,ntpmls,ntpguest,
     &ntpfram,totatm,rvdw,dlrpot,engunit,sumchg)
     
      call readconfig(idnode,mxnode,imcon,cfgname,levcfg,
     &ntpmls,maxmls,totatm,volm,rcut,celprp)

      call alloc_ewald_arrays
     &(idnode,maxmls,kmax1,kmax2,kmax3,rvdw,totatm,maxguest)
c     volume reported in m^3 for statistical calculations
      statvolm=volm*1d-30
      call invert(cell,rcell,det)

      if(lprob)then
c      calculate number of grid points in a,b,and c directions
c      calculate the volume of a grid point (differs from griddim^3)
c NB these are allocated before assigning to guests in readconfig
c        ngrida=gridfactor(1)*ceiling(celprp(1)/(griddim*gridfactor(1)))
c        ngridb=gridfactor(2)*ceiling(celprp(2)/(griddim*gridfactor(2)))
c        ngridc=gridfactor(3)*ceiling(celprp(3)/(griddim*gridfactor(3)))
        ngrida=ceiling(celprp(1)/(griddim*gridfactor(1)))
        ngridb=ceiling(celprp(2)/(griddim*gridfactor(2)))
        ngridc=ceiling(celprp(3)/(griddim*gridfactor(3)))
        gridsize=ngrida*ngridb*ngridc
        if(idnode.eq.0)
     &write(nrite,"(/,' Probability grid size:',
     &i8,i8,i8)")ngrida,ngridb,ngridc
        allocate(gridbuff(gridsize))
        call alloc_prob_arrays(idnode,ntpguest,ntpsite,ntprob,gridsize)
        grvol=celprp(1)/dble(ngrida)*celprp(2)/dble(ngridb)*
     &  celprp(3)/dble(ngridc)
      else
c       this is in case we run into allocation problems later on

        ntprob=0
        gridsize=1
        call alloc_prob_arrays(idnode,ntpguest,ntpsite,ntprob,gridsize)
      endif

c     produce unit cell for folding purposes
      do i=1, 9
        c = ceiling(dble(i)/3.d0)
        ucell(i)=cell(i)/dble(gridfactor(c))
      enddo
      call invert(ucell,rucell,det)
      call dcell(ucell,ucelprp)
      scell_factor = gridfactor(1)*gridfactor(2)*gridfactor(3)
      do i=1,ntpfram
        ifram=locfram(i)
        nframmol=nummols(ifram)
        if (scell_factor.gt.nframmol)then
          write(nrite,"(/a9,a44,/,a50,/,a45,/)")
     &      "WARNING: ","The grid factor setting in the CONTROL file ",
     &      "is larger than the number of framework molecules. ",
     &      "This may result in useless probability plots."
        endif
      enddo
      call readcontrol(idnode,lspe,temp,ljob,mcsteps,eqsteps,
     &celprp,ntpguest,lrestart,laccsample,lnumg,nnumg,nhis,nwind,
     &mcinsf, mcdelf, mcdisf, mcjmpf, mcflxf, mcswpf,
     &swap_max, mcswif,mctraf, mcrotf,
     &disp_ratio, tran_ratio, rota_ratio, lfuga, overlap,
     &surftol, n_fwk, l_fwk_seq, fwk_step_max, fwk_initial, lwidom,
     &lwanglandau)
c     square the overlap so that it can be compared to the rsqdf array
      overlap = overlap**2
c     square the surface tolerance so that it can be compared to the
c     rsqdf array
      call fugacity(idnode,lfuga,temp,ntpguest)

c     FLEX
      if(n_fwk.gt.0)then
          allocate(fwksumbuff(n_fwk))
          call flex_init(idnode, mxatm, imcon, ntpmls, maxmls,
     &totatm, rcut, celprp, ntpguest, volm)
      endif
c Normalise the move frequencies
      mcmvnorm = mcinsf+mcdelf+mcdisf+mcjmpf+mcflxf+mcswpf+mctraf+mcrotf
     &+mcswif
      if(mcmvnorm.eq.0)then
        if(idnode.eq.0)
     &write(nrite,"(/,'No move frequencies specified, defaulting to 
     &Grand Canonical')")
        mcmvnorm = 1
        mcinsf = 1.d0/3.d0
        mcdelf = 1.d0/3.d0
        mcdisf = 1.d0/3.d0
        mcjmpf = 0.d0
        mcflxf = 0.d0
        mcswpf = 0.d0
        mctraf = 0.d0
        mcrotf = 0.d0
        mcswif = 0.d0
      endif
      if(idnode.eq.0)
     &write(nrite,"(/,'Normalised move frequencies:',/,
     &a18,f7.3,a18,f7.3,a18,f7.3,/,a18,f7.3,a18,f7.3,a18,f7.3,/,
     &a18,f7.3,a18,f7.3,a18,f7.3/)")
     &'insertion:',mcinsf/mcmvnorm, 'deletion:',mcdelf/mcmvnorm,
     &'displacement:',mcdisf/mcmvnorm,'jumping:',mcjmpf/mcmvnorm,
     &'flexing:',mcflxf/mcmvnorm,'swapping:',mcswpf/mcmvnorm,
     &'translation:',mctraf/mcmvnorm,'rotation:',mcrotf/mcmvnorm,
     &'switching:',mcswif/mcmvnorm
c Now we normalise
      mcmvsum=0.d0
      mcmvsum=mcmvsum+mcinsf
      if(mcinsf.gt.0.d0)mcinsf=mcmvsum/mcmvnorm
      mcmvsum=mcmvsum+mcdelf
      if(mcdelf.gt.0.d0)mcdelf=mcmvsum/mcmvnorm
      mcmvsum=mcmvsum+mcdisf
      if(mcdisf.gt.0.d0)mcdisf=mcmvsum/mcmvnorm
      mcmvsum=mcmvsum+mcjmpf
      if(mcjmpf.gt.0.d0)mcjmpf=mcmvsum/mcmvnorm
      mcmvsum=mcmvsum+mcflxf
      if(mcflxf.gt.0.d0)mcflxf=mcmvsum/mcmvnorm
      mcmvsum=mcmvsum+mcswpf
      if(mcswpf.gt.0.d0)mcswpf=mcmvsum/mcmvnorm
      mcmvsum=mcmvsum+mctraf
      if(mctraf.gt.0.d0)mctraf=mcmvsum/mcmvnorm
      mcmvsum=mcmvsum+mcrotf
      if(mcrotf.gt.0.d0)mcrotf=mcmvsum/mcmvnorm
      mcmvsum=mcmvsum+mcswif
      if(mcswif.gt.0.d0)mcswif=mcmvsum/mcmvnorm

      if(idnode.eq.0)
     &write(nrite,"(/,'Target acceptance ratios:',/,
     &a18,f7.3,a18,f7.3,a18,f7.3,/)")
     &'displacement:',disp_ratio,'translation:',tran_ratio,
     &'rotation:',rota_ratio

      if(.not.lspe)then
        call sleep(idnode+1)
        init=duni(idnode)

c     initialize jobcontrol file
        if(idnode.eq.0)then
          open(205,file='jobcontrol.in')
          close(205)
        endif
      

c       initialize rotangle 
        rotangle=pi/3.d0
   
c==========================================================================        
c       if restart requested then descend into the branch
c       and read the REVIVE and REVCON for the appropriate
c       arrays
c==========================================================================

        if(lrestart)then
c         do a check to see if the number of branch directories
c         matches the number of nodes.  adjust accordingly depending
c         on the situation.  
c         This is a rather shitty way of scanning branch directories
c         if other files are called "branch" in the working directory
c         problems happen.

          call revscan(idnode,prevnodes)
          if(prevnodes.eq.0)then
            if(idnode.eq.0)write(nrite,"(/,a85,/)")
     &"No branches found in the working directory, starting from
     &the CONFIG file provided"
            write(outdir,"('branch',i2.2)")idnode+1
            write(command,"('mkdir 'a8)")outdir
            call system(command)
c         if the restart calculation has more nodes than the previous
c         calculation
          elseif(idnode+1.gt.prevnodes)then
c           create the new directory
            write(outdir,"('branch',i2.2)")idnode+1
            write(command,"('mkdir 'a8)")outdir
            call system(command)

c           apply the values from other branches to the new node.
            write(localdir,"('branch',i2.2)")(mod(idnode+1,prevnodes)+1)
            
            call revread(localdir,production,ntpmls,totatm,ntpguest)

          elseif(idnode+1.le.prevnodes)then 
c         read the values from the first mxnodes
            write(localdir,"('branch',i2.2)")idnode+1
            outdir=localdir
            call revread(localdir,production,ntpmls,totatm,ntpguest)
          endif
c     write warning if the number of nodes does not correspond with the 
c     previous calculation
          if(idnode.eq.0.and.prevnodes.ne.mxnode)then
           write(nrite,"(/,3x,a35,i2,a36,i2,/)")"WARNING - previous 
     &calculation had",prevnodes," branches while the current job has ",
     &mxnode
           if(mxnode.lt.prevnodes)write(nrite,"(3x,a9,i2,a4,i2,a17,/)")
     &"Branches ",mxnode+1,"  - ", prevnodes,"  will be ignored"
           if(mxnode.gt.prevnodes)
     & write(nrite,"(3x,a9,i2,a4,i2,a30,i2,a3,i2,/)")
     &"Branches ", prevnodes+1,"  - ", mxnode,"  will take data from
     & branches ",1," - ",prevnodes
          endif
          if(production)then
            if(eqsteps.gt.0)then
              production=.false.
              if(idnode.eq.0)write(nrite,"(3x,a41,i7,a6,/)")
     &"Production averaging will continue after ",eqsteps," steps"
            else
              if(idnode.eq.0)write(nrite,"(3x,a59,/)")
     &"Production averaging will start at the beginning of the run"
            endif
          endif

c     local output for each node
c     This may only work on system specific machines
        else 
          write(outdir,"('branch',i2.2)")idnode+1
          write(command,"('mkdir ',a8)")outdir
          call system(command)
        endif
c=========================================================================
c      open necessary archiving files
c=========================================================================

        if(ntpguest.gt.1)then
          do i=1,ntpguest
            if(lnumg)then
              write(outfile,"(a8,'/numguests',i2.2,'.out')")outdir,i
              open(400+i,file=outfile)
            endif
            if(abs(nhis).gt.0)then
              write(outfile4,"(a8,'/his',i2.2,'.xyz')")outdir,i
              open(500+i,file=outfile4)
            endif
          enddo
        else
          if(lnumg)then
            outfile=outdir // '/numguests.out'
            open(401,file=outfile)
          endif
          if(abs(nhis).gt.0)then
            outfile4=outdir // '/his.xyz'
            open(501,file=outfile4)
          endif
        endif
        outfile2=outdir // '/runningstats.out'
        open(202,file=outfile2)
c        outfile3=outdir // '/energies.out'
c        open(203,file=outfile3)
      endif

c     ins,del,dis store the last move made for each guest type
 
c     debugging.. need to see if all information gets to each
c     node
c      write(debug,"('debug',i2.2)")idnode
c      open(999,file=debug)
c      write(999,'(a20,i2,/)')'data for node ',idnode
c      write(999,'(a20,/,3f16.5,/,3f16.5,/,3f16.5)')'cell vectors',
c     & (cell(i),i=1,3),(cell(j),j=4,6),(cell(k),k=7,9)
      call guest_exclude(ntpmls,ntpguest)
      call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)

c      write(999,"('atomic information',/)")
c      do i=1,totatm
c        write(999,'(3x,a4,3f16.6)')atomname(i),xxx(i),yyy(i),zzz(i)
c      enddo

c      write(999,"('some other info ',/)")
c      write(999,"('production?',3x,l)")production
c      write(999,"('number of guests',3x,i3)")ntpguest
c      write(999,"('number of equilibrium steps',3x,i9)")eqsteps
c      write(999,"('number of production steps ',3x,i9)")mcsteps
c      write(999,"('number of probability plots',3x,i9)")ntprob
c      close(999)
      engsrp=0.d0
      engcpe=0.d0
      engacc=0.d0
      engac1=0.d0

c     beta is a constant used in the acceptance criteria for the gcmc
c     moves
      beta=1.d0/(kboltz*temp)
c     this is the relative dielectric constant. default is 1
c     we don't need this....

      epsq=1.d0

c     create ewald interpolation arrays 
      call erfcgen(keyfce,alpha,rcut,drewd)
c     populate ewald3 arrays
      call single_point
     &(imcon,idnode,keyfce,alpha,drewd,rcut,delr,totatm,totfram,ntpfram,
     &ntpguest,ntpmls,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,spenergy,vdwsum,ecoul,dlpeng,maxmls,surftol)
      if(idnode.eq.0)then
c        write(nrite,'(/,/,a35,f22.6)')'Configurational energy:
c     & ',spenergy
c        write(nrite,'(/,a35,f22.6)')'Initial framework energy :',
c     &(evdw+ecoul)/engunit
        do iguest=1,ntpguest
          mol=locguest(iguest)
          nmols=nummols(mol)
          spenergy=0.d0
          do jmol=1,ntpmls
            ik=loc2(mol,jmol)
c            THIS EWALD1 AND 3 CALCULATION SHOULD BE THE SAME,
c            BUT THEY'RE CURRENTLY NOT!
c            print*, jmol,ewald1en(10)/engunit,ewald3en(jmol)/engunit
            spenergy=spenergy+(
     &ewald1en(ik) +
     &ewald2en(ik) +
     &vdwen(ik)+
     &elrc_mol(ik))/engunit
          enddo 
          if(nmols.gt.0)spenergy=spenergy-nmols*ewald3en(mol)/engunit
          write(nrite,'(a23,i3,a9,f22.6)')'Initial guest ',
     &iguest,' energy :',spenergy
        enddo
        write(nrite,'(a35,f22.6)')'van der Waals energy :',
     &vdwsum/engunit
        write(nrite,'(a35,f22.6)')'Electrostatic energy :',
     &ecoul/engunit
        write(nrite,'(a35,f22.6)')'Energy reported by DL_POLY :',
     &dlpeng

      endif
      call error(idnode,0)


      nguests=0
      do i=1,ntpguest
c       this is incorrect because spenergy includes energies
c       calculated from all guests in the framework at the begining
c       where energy separates these values
        mol=locguest(i)
        nmols=nummols(mol)
        energy(mol)=spenergy
        nguests=nguests+nmols
      enddo
     
      if(lspe)then
        if(lspe)lgchk=.false.
        call error(idnode,0)
        
      endif

   
      call timchk(1,tzero)
      if((eqsteps.eq.0).and.(.not.ljob))production=.true.

c******************************************************************
c
c       Widom insertion method begins
c
c******************************************************************
      if(lwidom)then
        lgchk=.false.
        gcmccount=0 
        do iguest=1,ntpguest
          mol=locguest(i) 
          istat=1+16*(iguest-1)
          widchk=.true.
          widcount=0
          do while(widchk)
            ins(iguest)=1
            ins_count=ins_count+1
            delE=0.d0
            call random_ins(idnode,imcon,natms,totatm,iguest,rcut,delr)
            estep = 0.d0
            call insertion
     &  (imcon,idnode,iguest,keyfce,alpha,rcut,delr,drewd,totatm,
     &  ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &  engunit,delrc,estep,loverlap,lnewsurf,surftol)
            gcmccount = gcmccount + 1
            call reject_move
     &  (idnode,iguest,0,.true.,.false.,.false.,.false.)
            if(.not.loverlap)then
              if(lprobeng(iguest))then
                call storeenprob(iguest,0,rucell,ngrida,
     &            ngridb,ngridc,estep)
              endif
              H_const=dexp(-1.d0*estep/kboltz/temp)
c             no rolling average here, just div by widcount at the end
              chainstats(istat+7) = chainstats(istat+7)+H_const
              widcount = widcount + 1
            endif
            if(widcount.ge.mcsteps)widchk=.false.
          enddo
          chainstats(istat+7) = chainstats(istat+7)/dble(widcount)
        enddo
        prodcount=widcount
        chainstats(1) = dble(widcount)
      endif
      if (lwanglandau)then
        lgchk=.false.
        call error(idnode,2316)
        
      endif
c******************************************************************
c
c       gcmc begins
c
c******************************************************************

c     start delrdisp as delr (read from the CONTROL file)
      minchk=min(400,nnumg)
      delrdisp=delr
      tran_delr = delr
      rota_rotangle = rotangle
      call timchk(0,timelp)
c     DEBUG
      call test
     &(imcon,idnode,keyfce,alpha,rcut,delr,drewd,totatm,
     &ntpguest,volm,kmax1,kmax2,kmax3,epsq,ntpatm,maxvdw,
     &engunit,ntpfram,ntpmls,maxmls,outdir,cfgname,levcfg)
      call error(idnode,0)
c     END DEBUG
      do while(lgchk)
        gcmccount=gcmccount+1
c     every so often, update the total number of prodcounts
c     across all nodes
        if(mod(gcmccount,minchk).eq.0)then

c         check jobcontrol
          call jobcheck(idnode,jobsafe,ljob,production)

          if(.not.jobsafe)then
            call gstate(jobsafe)
            lgchk=.false. 
            call error(idnode,-2312)
          endif
          if (production)then
            call gisum2(prodcount,1,globalprod)
            if(mcsteps.lt.0)then
c             Check for cycles here
              tick_tock_cycles = cshift(tick_tock_cycles, -1)
              tick_tock_cycles(1) = .true.
c             sum up for all guests
              totalguests = 0
              do i=1,ntpguest
                mol=locguest(i)
                totalguests = totalguests + nummols(mol)
              enddo
              call gisum2(totalguests,1,globalnguests)
c             If the total number of production steps over all nodes
c             is less than the total number of guests (plus one)
c             multiplied by desired cycles flag this check as not done
              if((globalprod).lt.(-mcsteps*(globalnguests+1)))then
                tick_tock_cycles(1) = .false.
              endif
c             safe to end if every check passes
              if(all(tick_tock_cycles))then
                if(idnode.eq.0)write(nrite, "('Completed at least ',
     &i10,' production cycles for each guest')")
     &-mcsteps
                lgchk=.false.
              endif
            else
              if(globalprod.ge.mcsteps)lgchk=.false.
            endif
          elseif(.not.ljob)then
c           not production yet; test if we are equilibratied
            if(eqsteps.gt.0)then
              if(gcmccount.ge.eqsteps)then
                if(idnode.eq.0)write(nrite, "('Completed at least ',
     &i10,' equlibration steps',/,'Starting production at ',i10)")
     &eqsteps, gcmccount
                production=.true.
              endif
            elseif(eqsteps.lt.0)then
              call gisum2(gcmccount,1,globalsteps)
c             Check for cycles here
              tick_tock_cycles = cshift(tick_tock_cycles, -1)
              tick_tock_cycles(1) = .true.
c             sum up for all guests
              totalguests = 0
              do i=1,ntpguest
                mol=locguest(i)
                totalguests = totalguests + nummols(mol)
              enddo
              call gisum2(totalguests,1,globalnguests)
c             If the total number of production steps over all nodes
c             is less than the total number of guests (plus one)
c             multiplied by desired cycles flag this check as not done
              if((globalsteps).lt.(-eqsteps*(globalnguests+1)))then
                tick_tock_cycles(1) = .false.
              endif
c             safe to end if every check passes
              if(all(tick_tock_cycles))then
                if(idnode.eq.0)write(nrite, "('Completed at least ',
     &i10,' equilibration cycles for each guest',/,
     &'Starting production at',i10,' over all nodes')")
     &-eqsteps, globalsteps
                production=.true.
c               reset the cycles for production
                tick_tock_cycles=.false.
              endif
            endif
          endif
        endif

c       randomly choose a guest type to move 
        if(ntpguest.gt.1)then
          iguest=floor(duni(idnode)*ntpguest)+1
        elseif(ntpguest.eq.1)then
          iguest=1
        endif
        mol=locguest(iguest)
        natms=numatoms(mol)
        nmols=nummols(mol)

        if(mod(gcmccount,1000).eq.0)then
          call revive
     &(idnode,totatm,0,production,ntpguest,ntpmls,imcon,cfgname,
     &   delE(mol),outdir)
        endif

c Randomly decide which MC move to do
        randmov=duni(idnode)

        if(randmov.lt.mcinsf)then
          insert = .true.
        elseif(randmov.lt.mcdelf)then
          delete = .true.
        elseif(randmov.lt.mcdisf)then
          displace = .true.
        elseif(randmov.lt.mcjmpf)then
          jump = .true.
        elseif(randmov.lt.mcflxf)then
          flex = .true.
        elseif(randmov.lt.mcswpf)then
          swap = .true.
        elseif(randmov.lt.mctraf)then
          displace = .true.
          tran = .true.
        elseif(randmov.lt.mcrotf)then
          displace = .true.
          rota = .true.
        elseif(randmov.lt.mcswif)then
          switch = .true.
        else
c Failover displace -- shouldn't reach here
          displace=.true.
        endif
        if((nhis.ne.0).and.(mod(gcmccount,abs(nhis)).eq.0))then
          write(202,'(a35,f20.15,a15,f15.10,a15,f15.10)')
     &'displacement acceptance ratio: ',
     &(dble(accept_disp)/dble(disp_count)),
     &'delr: ',delrdisp,'angle: ',rotangle
          if(nhis.lt.0)call hisarchive(ntpguest,gcmccount)
          if((nhis.gt.0).and.(prodcount.gt.0))call hisarchive
     &      (ntpguest,gcmccount) 
        endif
        if(nmols.ge.1.and.disp_count.ge.1)then
          if(mod(disp_count,100).eq.0)then
c update distance part of displacement on n00s
            if((accept_disp/dble(disp_count)).gt.disp_ratio)then 
              delrdisp=delrdisp*1.05d0
            else
              if(delrdisp.gt.delrmin)delrdisp=delrdisp*0.95d0
            endif
          elseif(mod(disp_count,50).eq.0)then
c update rotation part of displacement on n50s
            if((accept_disp/dble(disp_count)).gt.disp_ratio)then
              rotangle=rotangle*1.05d0
            else
              if(rotangle.gt.minangle)rotangle=rotangle*0.95d0
            endif
          endif
        endif
        if((nmols.ge.1).and.(tran_count.ge.1).and.
     &mod(tran_count,100).eq.0)then
c update distance moves on n00s
          if((accept_tran/dble(tran_count)).gt.tran_ratio)then 
            tran_delr=tran_delr*1.05d0
          else
            if(tran_delr.gt.delrmin)tran_delr=tran_delr*0.95d0
          endif
        endif
        if((nmols.ge.1).and.(rota_count.ge.1).and.
     &mod(rota_count,100).eq.0)then
c update rotation moves on n00s
          if((accept_rota/dble(rota_count)).gt.rota_ratio)then
            rota_rotangle=rota_rotangle*1.05d0
          else
            if(rota_rotangle.gt.minangle)
     &rota_rotangle=rota_rotangle*0.95d0
          endif
        endif

c       the following is added in case of initial conditions
        if (nmols.eq.0)then
          insert=.true.
          delete=.false.
          displace=.false.
          jump = .false.
          flex = .false.
          swap = .false.
          tran = .false.
          rota = .false.
          switch = .false.
        endif
c        if (nmols.eq.1)then
c          insert=.false.
c          delete=.false.
c          displace=.true.
c          jump = .false.
c          flex = .false.
c          swap = .false.
c          tran = .false.
c          rota = .false.
c          switch = .false.
c        endif
c       DEBUG
c        if(gcmccount.eq.1)then
c          insert=.true.
c          iguest=1
c        else if (gcmccount.eq.2)then
c          insert=.true.
c          iguest=2
c        else if (gcmccount.eq.3)then
c          insert=.true.
c          iguest=3
c        else if (gcmccount.eq.4)then
c          displace=.true.
c          iguest=2
c        else if (gcmccount.eq.5)then
c          delete=.true.
c          iguest=3
c        endif
c       END DEBUG 
        oldeng = 0.d0
        ewald1en=0.d0
        ewald2en=0.d0
        vdwen=0.d0
        qfix_molorig=qfix_mol
        ckcsnew=0.d0
        ckssnew=0.d0
        delE=0.d0
c***********************************************************************
c    
c       Insertion
c
c***********************************************************************
        if(insert)then
c         calculate the ewald sums ewald1 and ewald2(only for new mol)
c         store ewald1 and 2 separately for the next step.
c         calculate vdw interaction (only for new mol)

          lnewsurf = .false.
          engsicprev=engsic
          ins(iguest)=1
          ins_count=ins_count+1
          call random_ins(idnode,imcon,natms,totatm,iguest,rcut,delr)
          estep = 0.d0
          call insertion
     &(imcon,idnode,iguest,keyfce,alpha,rcut,delr,drewd,totatm,
     &ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estep,loverlap,lnewsurf,surftol)
          accepted=.false.

          if (.not.loverlap)then
            gpress=gstfuga(iguest)
            ngsts=nummols(mol)
            rande=duni(idnode)
            call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &displace,insert,delete,swap,accepted)
          endif
c         DEBUG
c          accepted=.true.
c         END DEBUG
          if(accepted)then
            accept_ins=accept_ins+1
            call accept_move
     &(imcon,idnode,iguest,insert,delete,displace,estep,guest_toten,
     &lnewsurf,delrc,totatm,randchoice,ntpfram,ntpmls,ntpguest,
     &maxmls,sumchg)
          else
            call reject_move
     &(idnode,iguest,0,insert,delete,displace,swap)
          endif
          insert=.false.
          

c***********************************************************************
c    
c             Deletion 
c
c***********************************************************************
        elseif(delete)then
          engsicprev=engsic
          mol=locguest(iguest)
          natms=numatoms(mol)
          nmols=nummols(mol)
          linitsurf = .false.
         
c       calculate the ewald sum of the mol you wish to delete
c       ewald1,ewald2,vdw of the mol you wish to delete
          del(iguest)=1
          del_count=del_count+1 
          randchoice=floor(duni(idnode)*nmols)+1
          estep = 0.d0
          call deletion 
     &(imcon,idnode,keyfce,iguest,randchoice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estep,linitsurf,surftol)

          gpress=gstfuga(iguest)
          ngsts=nummols(mol)

          accepted=.false.

          rande=duni(idnode)
          call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &displace,insert,delete,swap,accepted)
         
c         the following occurs if the move is accepted.
c         DEBUG
c          accepted=.true.
c         END DEBUG

          if(accepted)then
            accept_del=accept_del+1
c            if(nummols(mol).eq.1)then
c              write(*,*)"1. ",energy(3),delE(3)
c            endif
            call accept_move
     &(imcon,idnode,iguest,insert,delete,displace,estep,guest_toten,
     &linitsurf,delrc,totatm,randchoice,ntpfram,ntpmls,ntpguest,
     &maxmls,sumchg)
c            if (nummols(mol).eq.0)then
c              write(*,*)"2. ",energy(3)
c            endif
          else
            call reject_move
     &(idnode,iguest,0,insert,delete,displace,swap)
          endif

          delete=.false.
          
            
c***********************************************************************
c    
c           Displacement 
c
c***********************************************************************

        elseif(displace)then
          if(tran)then
            dis(iguest)=2
            tran_count = tran_count + 1
            randa=duni(idnode)
            randb=duni(idnode)
            randc=duni(idnode)
            rand1=0.d0
            rand2=0.d0
            rand3=0.d0
            rand4=0.d0
            dis_delr = tran_delr
            dis_rotangle = 0.d0
          elseif(rota)then
            dis(iguest)=3
            rota_count = rota_count + 1
            randa=0.5d0
            randb=0.5d0
            randc=0.5d0
            rand1=duni(idnode)
            rand2=duni(idnode)
            rand3=duni(idnode)
            rand4=duni(idnode)
            dis_delr = 0.d0
            dis_rotangle = rota_rotangle
          else
            dis(iguest)=1
            disp_count=disp_count+1
            randa=duni(idnode)
            randb=duni(idnode)
            randc=duni(idnode)
            rand1=duni(idnode)
            rand2=duni(idnode)
            rand3=duni(idnode)
            rand4=duni(idnode)
            dis_delr = delrdisp
            dis_rotangle = rotangle
          endif
c         choose a molecule from the list
          randchoice=floor(duni(idnode)*nmols)+1

          call get_guest(iguest,randchoice,mol,natms,nmols)
c         LOOP 1 - calculate the energy for the chosen guest in
c         its orginal place
          linitsurf=.false.
          call guest_energy
     &(imcon,idnode,keyfce,iguest,randchoice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,vdwsum,ewld2sum,ewld1eng,linitsurf,surftol,
     &loverlap,1)
          ewld2sum=-ewld2sum
          vdwsum=-vdwsum 
          ewld1old=(-ewld1eng+ewald3en(mol))

c          write(*,*)"Ewald1 Energy Before: ",ewld1eng/engunit
c         LOOP 2 - shift the newx,newy,newz coordinates and re-calculate
c         the new energy and subtract from the above energy.
c         dis_delr and dis_rotangle depend on the type of move!
          call random_disp
     &(imcon,natms,mol,newx,newy,newz,dis_delr,cell,rcell,dis_rotangle,
     &randa,randb,randc,rand1,rand2,rand3,rand4)
          lnewsurf=.false.
          ewald1en(:)=0.d0
          ewald2en(:)=0.d0
          vdwen(:)=0.d0
          call guest_energy
     &(imcon,idnode,keyfce,iguest,randchoice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,newvdwsum,newewld2sum,ewld1eng,lnewsurf,
     &surftol,loverlap,2)
c         total up the energy contributions. The Ewald1 sum is dealt
c         with internally
c          write(*,*)"Ewald1 Energy After:  ",ewld1eng/engunit
          ewld2sum = ewld2sum + newewld2sum
          vdwsum = vdwsum + newvdwsum
          accepted=.false.
          if (.not.loverlap)then
            gpress=gstfuga(iguest)
            ngsts=nummols(mol)
            ewld3sum=ewald3en(mol)
            estep=(ewld1eng+ewld2sum+vdwsum)/engunit
c            write(*,*)"Final Ewald1+3 :",(ewld1eng-ewld3sum)/engunit
c            write(*,*)"Final Ewald1   :",(ewld1eng)/engunit
c            write(*,*)"Estep          :",estep
c            write(*,*)ewld2sum/engunit
c            write(*,*)vdwsum/engunit
            if(estep.lt.0.d0)then
              accepted=.true.
            else
              rande=duni(idnode)
              call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &displace,insert,delete,swap,accepted)
            endif
          endif
c         DEBUG
c          accepted=.true.
c         END DEBUG
          if(accepted)then
            call accept_move
     &(imcon,idnode,iguest,insert,delete,displace,estep,guest_toten,
     &lnewsurf,delrc,totatm,randchoice,ntpfram,ntpmls,ntpguest,
     &maxmls,sumchg)
c           check if the energy probability grid is requested,
c           then one has to compute the standalone energy
c           at the new position (requires ewald1 calc)
            if(lprobeng(iguest))then
c             the ewald1sum should be the energy of inserting a guest
c             in the new spot? shouldn't the elimination of the guest
c             in the old spot be accounted for in the energy?
              call gstlrcorrect(idnode,imcon,mol,keyfce,natms,
     &                            ntpatm,maxvdw,engunit,delrc,
     &                            rcut,volm,maxmls) 
              guest_toten=
     &             (ewld1old+ewld1eng+newewld2sum+
     &              newvdwsum+delrc)/engunit
            endif            
c           tally surface molecules
            if((linitsurf).and.(.not.lnewsurf))then
              surfacemols(iguest) = surfacemols(iguest) - 1
              if (surfacemols(iguest).lt.0)then
                surfacemols(iguest) = 0
              endif
            elseif((.not.linitsurf).and.(lnewsurf))then
                surfacemols(iguest) = surfacemols(iguest) + 1
            endif
            if(tran)then
              accept_tran = accept_tran + 1
            elseif(rota)then
              accept_rota = accept_rota + 1
            else
              accept_disp=accept_disp+1
            endif
          else
            call reject_move
     &(idnode,iguest,0,insert,delete,displace,swap)
          endif
          displace=.false.
          tran = .false.
          rota = .false.


c***********************************************************************
c    
c          Long jumps (eg insertion+deletion)
c
c***********************************************************************

        elseif(jump)then
          jmp(iguest)=1
          jump_count=jump_count+1
          delE=0.d0
c         choose a molecule from the list
          randchoice=floor(duni(idnode)*nmols)+1
c         find which index the molecule "randchoice" is
          call get_guest(iguest,randchoice,mol,natms,nmols)
          linitsurf=.false.
          call guest_energy
     &(imcon,idnode,keyfce,iguest,randchoice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,vdwsum,ewld2sum,ewld1eng,linitsurf,surftol,
     &loverlap,1)
          ewld2sum=-ewld2sum
          vdwsum=-vdwsum
          ewld1old=(-ewld1eng+ewald3en(mol))
          ewald1en(:)=0.d0
          ewald2en(:)=0.d0
          vdwen(:)=0.d0

          call random_jump
     &(idnode,natms,mol,newx,newy,newz)
          lnewsurf=.false.
          call guest_energy
     &(imcon,idnode,keyfce,iguest,randchoice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,newvdwsum,newewld2sum,ewld1eng,lnewsurf,
     &surftol,loverlap,2)
          
          ewld2sum = ewld2sum + newewld2sum
          vdwsum = vdwsum + newvdwsum
          accepted=.false.
          if (.not.loverlap)then
            gpress=gstfuga(iguest)
            ngsts=nummols(mol)

            estep=(ewld1eng+ewld2sum+vdwsum)/engunit

            if(estep.lt.0.d0)then
              accepted=.true.
            else
              accepted=.false.
              rande=duni(idnode)
              call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &jump,insert,delete,swap,accepted)
            endif
          endif

          if(accepted)then
            accept_jump=accept_jump+1
            call accept_move
     &(imcon,idnode,iguest,insert,delete,jump,estep,guest_toten,
     &lnewsurf,delrc,totatm,randchoice,ntpfram,ntpmls,ntpguest,
     &maxmls,sumchg)
            if(lprobeng(iguest))then
              call gstlrcorrect(idnode,imcon,mol,keyfce,natms,
     &                          ntpatm,maxvdw,engunit,delrc,
     &                          rcut,volm,maxmls) 
              guest_toten=
     &           (ewld1old+ewld1eng+newewld2sum+
     &            newvdwsum+delrc)/engunit

            endif            
c           tally surface molecules
            if((linitsurf).and.(.not.lnewsurf))then
              surfacemols(iguest) = surfacemols(iguest) - 1
              if (surfacemols(iguest).lt.0)then
                surfacemols(iguest) = 0
              endif
            elseif((.not.linitsurf).and.(lnewsurf))then
              surfacemols(iguest) = surfacemols(iguest) + 1
            endif
          else
            call reject_move
     &(idnode,iguest,0,insert,delete,jump,swap)
          endif
          jump=.false.


c***********************************************************************
c    
c         Framework flex  
c
c***********************************************************************

        elseif(flex)then

          flex_count = flex_count + 1
          accepted = .false.
          delE_fwk = 0
          evdwg = 0
          ecoulg = 0

c FIXME(td): only works for a single guest
c Assume that energy of single guest is correct
          delE_fwk = energy(mol)+fwk_ener(curr_fwk)

c Select a new framework
c if sequential is requested move up to the maximum jump in a random
c direction
          new_fwk = curr_fwk
          if (l_fwk_seq)then
            do while ((new_fwk.eq.curr_fwk).or.(new_fwk.gt.n_fwk).or.
     &(new_fwk.lt.1))
              fwk_step_magnitude = 1+floor(duni(idnode)*
     &dble(fwk_step_max))
              if (duni(idnode).lt.0.5)then
                new_fwk = curr_fwk + fwk_step_magnitude
              else
                new_fwk = curr_fwk - fwk_step_magnitude
              endif
            enddo
c otherwise just pick any framework randomly
          else
            do while (new_fwk.eq.curr_fwk)
              new_fwk = 1+floor(duni(idnode)*dble(n_fwk))
            enddo
          endif
c store the state of the system
          state_cell = cell
          state_x = molxxx
          state_y = molyyy
          state_z = molzzz
          state_chg = atmchg
          state_vol = volm

c now start to switch out new configuration
          cell = fwk_cell(new_fwk,:)
c put in new positions for framework only
          do k = 1,maxmls
            isguest = .false.
            do gstidx=1, ntpguest
              if (k.eq.locguest(gstidx)) isguest=.true.
            enddo
            indatm = 0
            indfwk = 0
            do l = 1, nummols(k)
              do m = 1, numatoms(k)
                indatm=indatm+1
                if(.not.isguest) then
                  indfwk = indfwk+1
                  molxxx(k,indatm) = fwk_posx(new_fwk,indfwk)
                  molyyy(k,indatm) = fwk_posy(new_fwk,indfwk)
                  molzzz(k,indatm) = fwk_posz(new_fwk,indfwk)
                endif
              enddo
            enddo
          enddo
c switch charges for framework only
          do l = 1,ntpmls
            isguest = .false.
            do gstidx=1, ntpguest
              if (l.eq.locguest(gstidx)) isguest=.true.
            enddo
            if(.not.isguest) then
              do m = 1,numatoms(l) 
                atmchg(l,m) = fwk_chg(new_fwk, m)
              enddo
            endif
          enddo
c new volume
          volm = fwk_vol(new_fwk)
c calculate interations with new configuration
c without the condensing the energy breaks when wrapping on boundary
conditions
          ckcsnew = ckcsum
          ckssnew = ckssum

          call guest_exclude(ntpmls,ntpguest)
          call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
          call lrcorrect(idnode,imcon,keyfce,totatm,ntpatm,maxvdw,
     &engunit,rcut,volm,maxmls)
c Assume the single_point calculates the correct spenergy (evdwg+ecoulg)
          call single_point
     &(imcon,idnode,keyfce,alpha,drewd,rcut,delr,totatm,totfram,ntpfram,
     &ntpguest,ntpmls,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,spenergy,vdwsum,ecoul,dlpeng,maxmls,surftol)

          delE_fwk = spenergy+fwk_ener(new_fwk)-delE_fwk

c energy acceptance criterion same as a displacement

          if(delE_fwk.lt.0.d0)then
            accepted=.true.
          else
            accepted=.false.
            rande=duni(idnode)
            call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &.true.,.false.,.false.,.false.,accepted)
          endif

          if(accepted)then
c accept! Frameworks are fine as they are
            accept_flex = accept_flex + 1
            flx(iguest) = new_fwk
            energy(mol) = spenergy
            delE(mol) = delE_fwk
            cfgname(:) = fwk_name(new_fwk,:)
            curr_fwk = new_fwk
          else
c have to put everything back as it was
            flx(iguest) = -curr_fwk
            delE = 0.d0
            cell = state_cell
            molxxx = state_x
            molyyy = state_y
            molzzz = state_z
            atmchg = state_chg
            volm = state_vol
            ckcsum = ckcsnew
            ckssum = ckssnew
c rebuild all the atom lists
c            call guest_exclude(ntpmls,ntpguest)
            call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
c            call erfcgen(keyfce,alpha,rcut,drewd)
            call parlst(imcon,totatm,rcut,delr)
            call lrcorrect(idnode,imcon,keyfce,totatm,ntpatm,maxvdw,
     &engunit,rcut,volm,maxmls)
c             call single_point
c     &(imcon,idnode,keyfce,alpha,drewd,rcut,delr,totatm,totfram,ntpfram,
c     &ntpguest,ntpmls,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
c     &engunit,spenergy,vdwsum,ecoul,dlpeng,maxmls,surftol)
          endif
          flex = .false.

        elseif(switch)then
c***********************************************************************
c    
c         Switch - only if multiple guests in sim
c
c***********************************************************************
c         first generate a maximum limit on the number of swaps
c         by determining the quantities of the different guest types
c         in the framework
          switch = .false.
          delE=0.d0
          nswapguest = swap_max
          do i=1,ntpguest
c           store original energies
            mol=locguest(i)
            nmols=nummols(mol)
c           generate array of molecules to randomly select
            do j=1,nmols
              swap_mols(i,j) = j
            enddo
            swap_mol_count(i) = nmols
            nswapguest = min(nswapguest, nmols)
          enddo
          nswapguest = min(swap_max, nswapguest)
          if(nswapguest.le.0)then
            cycle
          endif 
          switch_count=switch_count+1
          num_swaps = floor(duni(idnode)*nswapguest) + 1 
          num_swaps = 1
c         store original framework configuration if the move is rejected
          origenergy = energy
          origmolxxx = molxxx
          origmolyyy = molyyy
          origmolzzz = molzzz

          origelrc = elrc
          origelrc_mol=elrc_mol
c         store original ewald1 sums in case the move is rejected
          ckcsorig = ckcsum
          ckssorig = ckssum
c         store original surface molecule counts in case the move 
c         is rejected
          origsurfmols = surfacemols
          loverlap=.false.
          estep=0.d0
          do iswap=1,num_swaps
c           random choice of two different guests to swap
            swap_guest_max = ntpguest
            do j=1,ntpguest
              swap_chosen_guest(j) = j
            enddo 
            iguest = floor(duni(idnode) * swap_guest_max) + 1

c           determine the second guest by shifting the array
c           and randomly selecting from the reduced array
            do j=iguest,ntpguest
              swap_chosen_guest(j)=j+1
            enddo
            swap_guest_max = swap_guest_max - 1
            jguest = floor(duni(idnode) * swap_guest_max) + 1
            jguest = swap_chosen_guest(jguest)
c           break here if one of the molecules has no more 
c           molecules to swap, but still count this as one of 
c           the swap attempts.
            if((swap_mol_count(iguest) <= 0)
     &.or.(swap_mol_count(jguest)<=0))cycle
c           molecule choice to swap on each
            swi(iguest)=swi(iguest) + 1
            ichoice=floor(duni(idnode)*swap_mol_count(iguest))+1
            ichoice = swap_mols(iguest, ichoice)
            
            swi(jguest)=swi(jguest)+1
            jchoice=floor(duni(idnode)*swap_mol_count(jguest))+1
            jchoice= swap_mols(jguest, jchoice)
            call get_guest(jguest, jchoice, jmol, natms, nmols)
            call com(natms,jmol,newx,newy,newz,comx,comy,comz)
            do iatm=1,natms
              guestx(jguest,iatm)=newx(iatm) - comx
              guesty(jguest,iatm)=newy(iatm) - comy
              guestz(jguest,iatm)=newz(iatm) - comz
            enddo
            linitsurfj = .false.
            call get_guest(iguest, ichoice, imol, natms, nmols)
            call com(natms,imol,newx,newy,newz,comshiftx,
     &comshifty,comshiftz)
            do iatm=1,natms
              guestx(iguest,iatm)=newx(iatm) - comshiftx
              guesty(iguest,iatm)=newy(iatm) - comshifty
              guestz(iguest,iatm)=newz(iatm) - comshiftz
            enddo
c************************************************************************
c           START SWITCH OF GUESTI AND GUESTJ
c           Delete it, since shifting it to the new position would
c           create infinite energies.
c************************************************************************
            linitsurf=.false.
            estepi = 0.d0
            call deletion 
     &(imcon,idnode,keyfce,iguest,ichoice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estepi,linitsurf,surftol)
c           update ewald arrays as if the deletion was accepted
            estep=estep+estepi
            call accept_move
     &(imcon,idnode,iguest,.false.,.true.,.false.,estepi,guest_toten,
     &.false.,delrc,totatm,ichoice,ntpfram,ntpmls,ntpguest,maxmls,
     &sumchg)
            ewald1en=0.d0
            ewald2en=0.d0
            vdwen=0.d0
            ckcsnew=0.d0
            ckssnew=0.d0
            estepj=0.d0
            call get_guest(jguest,jchoice,jmol,natms,nmols)
            call deletion 
     &(imcon,idnode,keyfce,jguest,jchoice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estepj,linitsurfj,surftol)
            estep=estep+estepj
c           update ewald arrays as if the deletion was accepted
            call accept_move
     &(imcon,idnode,jguest,.false.,.true.,.false.,estepj,guest_toten,
     &.false.,delrc,totatm,jchoice,ntpfram,ntpmls,ntpguest,maxmls,
     &sumchg)
            ewald1en=0.d0
            ewald2en=0.d0
            vdwen=0.d0
            ckcsnew=0.d0
            ckssnew=0.d0

            lnewsurfj=.false.
            do iatm=1,natms
              newx(iatm) = guestx(jguest,iatm) + comshiftx
              newy(iatm) = guesty(jguest,iatm) + comshifty
              newz(iatm) = guestz(jguest,iatm) + comshiftz
            enddo
            estepj=0.d0
            call insertion
     &(imcon,idnode,jguest,keyfce,alpha,rcut,delr,drewd,totatm,
     &ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estepj,loverlap,lnewsurfj,surftol)
            estep=estep+estepj
            call accept_move
     &(imcon,idnode,jguest,.true.,.false.,.false.,estepj,guest_toten,
     &.false.,delrc,totatm,jchoice,ntpfram,ntpmls,ntpguest,maxmls,
     &sumchg)
            ewald1en=0.d0
            ewald2en=0.d0
            vdwen=0.d0
            ckcsnew=0.d0
            ckssnew=0.d0

            if((linitsurfj).and.(.not.lnewsurfj))then
              surfacemols(jguest) = surfacemols(jguest) - 1
              if (surfacemols(jguest).lt.0)then
                surfacemols(jguest) = 0
              endif
            elseif((.not.linitsurfj).and.(lnewsurfj))then
              surfacemols(jguest) = surfacemols(jguest) + 1
            endif
            call get_guest(iguest,ichoice,imol,natms,nmols)
            lnewsurf=.false.
            do iatm=1,natms
              newx(iatm) = guestx(iguest,iatm) + comx
              newy(iatm) = guesty(iguest,iatm) + comy
              newz(iatm) = guestz(iguest,iatm) + comz
            enddo
            estepi=0.d0
            call insertion
     &(imcon,idnode,iguest,keyfce,alpha,rcut,delr,drewd,totatm,
     &ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estepi,loverlap,lnewsurf,surftol)
            estep=estep+estepi
            energy=origenergy
            call accept_move
     &(imcon,idnode,iguest,.true.,.false.,.false.,estepi,guest_toten,
     &.false.,delrc,totatm,ichoice,ntpfram,ntpmls,ntpguest,maxmls,
     &sumchg)
            ewald1en=0.d0
            ewald2en=0.d0
            vdwen=0.d0
            ckcsnew=0.d0
            ckssnew=0.d0
            
c           have to recompute the guest energy for guestj
c           since before this point, guesti had not been inserted
c           in it's position yet.
c            call get_guest(jguest,jchoice,jmol,natms,nmols)
c            call guest_energy
c     &(imcon,idnode,keyfce,jguest,jchoice,alpha,rcut,delr,drewd,
c     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
c     &engunit,delrc,vdwsum,ewld2sum,ewld1eng,linitsurfj,surftol,
c     &loverlap,1)
c            estepj = estepj + (vdwsum + ewld2sum + ewld1eng) / engunit
c            estepj=estepj+delE(jmol)
            if((linitsurf).and.(.not.lnewsurf))then
                surfacemols(iguest) = surfacemols(iguest) - 1
                if (surfacemols(iguest).lt.0)then
                    surfacemols(iguest) = 0
                endif
            elseif((.not.linitsurf).and.(lnewsurf))then
                surfacemols(iguest) = surfacemols(iguest) + 1
            endif
c************************************************************************
c           END OF SWITCH
c************************************************************************
c           update swap arrays for iguest
            do k=1,nummols(locguest(iguest))
              if (swap_mols(iguest,k) >= ichoice) then
                swap_mols(iguest, k) = swap_mols(iguest,k+1)
              end if
            enddo
            swap_mol_count(iguest) = swap_mol_count(iguest) - 1
c           same for jguest
            do k=1,nummols(locguest(jguest))
              if (swap_mols(jguest,k) >= jchoice) then
                swap_mols(jguest, k) = swap_mols(jguest,k+1)
              end if
            enddo
            swap_mol_count(jguest) = swap_mol_count(jguest) - 1
c            energy(imol)=energy(imol)+estepi
c            delE(imol)=delE(imol)+estepi
c            energy(jmol)=energy(jmol)+estepj
c            delE(jmol)=delE(jmol)+estepj
          enddo

c         perform energy evaluation
          if(estep.lt.0.d0)then
            accepted=.true.
          else
            accepted=.false.
            rande=duni(idnode)
            call energy_eval
     &(estep,rande,statvolm,iguest,0,temp,beta,
     &displace,insert,delete,swap,accepted)
            if(loverlap)then
              accepted=.false.
            endif
          endif
          if(accepted)then
            accept_switch=accept_switch+1
c            energy=origenergy
c            energy(imol)=energy(imol)+estepi
c            energy(jmol)=energy(jmol)+estepj
c            do i=1,maxmls
c              if((i.ne.imol).and.(i.ne.jmol))then
c                energy(i)=energy(i)+delE(i)
c              endif
c            enddo
            call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)

          else
c           restore original framework if move is rejected
            molxxx=origmolxxx
            molyyy=origmolyyy
            molzzz=origmolzzz
c           restore original ewald1 sums if step is rejected
            ckcsum=ckcsorig
            ckssum=ckssorig
            elrc=origelrc
            elrc_mol=origelrc_mol
c           restore original surfacemols if step is rejected
            surfacemols=origsurfmols
            call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
            energy=origenergy
            delE=0.d0
          endif
        elseif(swap)then
c***********************************************************************
c    
c         Swap - replace one guest in the simulation with another
c                of a different type
c
c***********************************************************************
          swap_count = swap_count+1
          delE=0.d0
c         store original framework configuration if the move is rejected
          origmolxxx = molxxx
          origmolyyy = molyyy
          origmolzzz = molzzz

c         store original ewald1 sums in case the move is rejected
          engsicprev=engsic
          ckcsorig = ckcsum
          ckssorig = ckssum
          ckcsnew=0.d0
          ckssnew=0.d0
          
          origtotatm = totatm 
          origsurfmols = surfacemols
          origelrc = elrc
          origelrc_mol=elrc_mol
          origenergy = energy 
          do j=1,iguest-1
            swap_chosen_guest(j) = j
          enddo 
          do j=iguest,ntpguest
            swap_chosen_guest(j)=j+1
          enddo
          ichoice=floor(duni(idnode)*nmols)+1
          call get_guest(iguest,ichoice,imol,natms,nmols)
          call com(natms,imol,newx,newy,newz,comx,comy,comz)
c         chose a second guest to swap with
          jguest = floor(duni(idnode) * (ntpguest-1)) + 1
          jguest = swap_chosen_guest(jguest)
          swp(iguest) = 1
          swp(jguest) = 1     
c         delete first guest
          linitsurf = .false.
          estepi = 0.d0
          call deletion 
     &(imcon,idnode,keyfce,iguest,ichoice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estepi,linitsurf,surftol)
          call accept_move
     &(imcon,idnode,iguest,.false.,.true.,.false.,estepi,guest_toten,
     &linitsurf,delrc,totatm,ichoice,ntpfram,ntpmls,ntpguest,
     &maxmls,sumchg)
          energy=origenergy
          ckcsnew=0.d0
          ckssnew=0.d0
c         reset energy arrays for next move.
          ewald1en=0.d0
          ewald2en=0.d0
          vdwen=0.d0
c         insert second guest
          jmol=locguest(jguest)
          jnatms=numatoms(jmol)
          jnmols=nummols(jmol)
          do iatm=1,jnatms
            newx(iatm) = guestx(jguest,iatm) + comx
            newy(iatm) = guesty(jguest,iatm) + comy
            newz(iatm) = guestz(jguest,iatm) + comz
          enddo
          loverlap=.false.
          lnewsurf=.false.
          estepj = 0.d0
          call insertion
     &(imcon,idnode,jguest,keyfce,alpha,rcut,delr,drewd,totatm,
     &ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estepj,loverlap,lnewsurf,surftol)
c          write(*,*)delE(imol)-estepi,delE(jmol)-estepj
          call accept_move
     &(imcon,idnode,jguest,.true.,.false.,.false.,estepj,guest_toten,
     &lnewsurf,delrc,totatm,jchoice,ntpfram,ntpmls,ntpguest,
     &maxmls,sumchg)

c         acceptance criteria
          accepted=.false.
          if(.not.loverlap)then
            rande=duni(idnode)
            estep = estepi+estepj 
            call energy_eval
     &(estep,rande,statvolm,iguest,jguest,temp,beta,
     &displace,insert,delete,swap,accepted)
          endif
          if(accepted)then
c            delE(imol) = estepi
c            delE(jmol) = estepj
c           reset the energy arrays, as they are 
c           updated in the subroutine accept_move
c            energy=origenergy+delE
c            energy=origenergy
c            energy(imol)=energy(imol)+delE(imol)
c            energy(jmol)=energy(jmol)+delE(jmol)
c            do i=1,maxmls
cc              energy(i)=energy(i)+delE(i)
c              if((i.ne.imol).and.(i.ne.jmol))then
c                  energy(i)=origenergy(i)
cc                if(nummols(i).eq.0)then
cc                  write(*,*)energy(i)+delE(i)
cc                endif
c                energy(i)=energy(i)+delE(i)
c              endif
c            enddo
            accept_swap=accept_swap+1
            call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
          else
c           restore original framework if move is rejected
            call reject_move
     &(idnode,iguest,jguest,insert,delete,jump,swap)
            molxxx=origmolxxx
            molyyy=origmolyyy
            molzzz=origmolzzz
c           restore original ewald1 sums if step is rejected
            ckcsum=ckcsorig
            ckssum=ckssorig
c           restore original surfacemols if step is rejected
            surfacemols=origsurfmols
            elrc = origelrc
            totatm = origtotatm
            nummols(locguest(iguest)) = nummols(locguest(iguest)) + 1
            nummols(locguest(jguest)) = nummols(locguest(jguest)) - 1
            call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
            energy = origenergy
            delE=0.d0
          endif
          swap = .false.
        endif
c=========================================================================
c       once GCMC move is done, check if production is requested
c       if so, store averages, probability plots etc..
c=========================================================================
        if(production)then 
          if((laccsample).and.(accepted).or.(.not.laccsample))then
            if(n_fwk.gt.0)fwk_counts(curr_fwk)=fwk_counts(curr_fwk)+1
            prodcount=prodcount+1
            rollcount=rollcount+1
            chainstats(1) = dble(prodcount)
c           for the guest which was just perturbed and if the
c           move was accepted, update the list of framework 
c           adsorbed molecules and add to the average.
c           otherwise re-sum the old list.
            
            do i=1,ntpguest
              mol=locguest(i) 
              dmolecules=real(nummols(mol))
              molecules2=dmolecules*dmolecules
              energy2=energy(mol)*energy(mol)
              surfmol=real(surfacemols(i))

              istat=1+16*(i-1)
c           Rolling <N>
              delta = dmolecules - chainstats(istat+1)
              aN = chainstats(istat+1) + delta/prodcount
              chainstats(istat+1) = aN 
c           Rolling <E>
              delta = energy(mol) - chainstats(istat+2)
              E = chainstats(istat+2) + delta/prodcount
              chainstats(istat+2) = E 
c           Rolling <EN>
              delta = energy(mol)*dmolecules - chainstats(istat+3)
              EN = chainstats(istat+3) + delta/prodcount
              chainstats(istat+3) = EN 
c           Rolling <N^2>
              delta = molecules2 - chainstats(istat+4)
              N2 = chainstats(istat+4) + delta/prodcount
              chainstats(istat+4) = N2 
c           Rolling <E^2>
              delta = energy2 - chainstats(istat+5)
              E2 = chainstats(istat+5) + delta/prodcount
              chainstats(istat+5) = E2
c           Rolling <NF>
              delta = surfmol - chainstats(istat+6)
              NF = chainstats(istat+6) + delta/prodcount
              chainstats(istat+6) = NF
c           Sampling the Henry's coefficient (This requires an
c              energy calculation between the guest and framework
c              only. This can be done, but will require a major
c              overhaul of the energy calculations at each step
c              namely, will need to split the energy between
c              framework - guest and guest - guest.
c              tricky with the ewald sums.
              rollstat=9*(i-1)
c              if((ins(i).eq.1).and.(accepted))then
cc             Rolling <exp(-E/kT)>
c                H_const=dexp(-1.d0*delE(mol)/kboltz/temp)
c                ins_rollcount = ins_rollcount + 1
c                delta = H_const - chainstats(istat+7)
c                H_const = chainstats(istat+7) + delta/accept_ins
c                chainstats(istat+7) = H_const
cc             Rolling <exp(E/k/T)> for window
c                avgwindow(rollstat+9)=
c     &((ins_rollcount-1)*avgwindow(rollstat+9)+H_const)/
c     &dble(ins_rollcount)
c              endif
c           Rolling <N> for window
              avgwindow(rollstat+1)=
     &((rollcount-1)*avgwindow(rollstat+1)+dmolecules)/dble(rollcount)
c           Rolling <E> for window
              avgwindow(rollstat+2)=
     &((rollcount-1)*avgwindow(rollstat+2)+energy(mol))/dble(rollcount)
c           Rolling <EN> for window
              avgwindow(rollstat+3)=
     &((rollcount-1)*avgwindow(rollstat+3)+
     &energy(mol)*dmolecules)/dble(rollcount)
c           Rolling <N^2> for window
              avgwindow(rollstat+4)=
     &((rollcount-1)*avgwindow(rollstat+4)+molecules2)/dble(rollcount)
c           Rolling <E^2> for window
              avgwindow(rollstat+5)=
     &((rollcount-1)*avgwindow(rollstat+5)+energy2)/dble(rollcount)
c           Rolling <NF> for window
              avgwindow(rollstat+6)=
     &((rollcount-1)*avgwindow(rollstat+6)+NF)/dble(rollcount)
            enddo
          endif
          if((mod(prodcount,nwind).eq.0).or.(.not.lgchk))then
c         store averages for standard deviations
c         reset windows to zero
            avcount = avcount + 1 
            weight = dble(rollcount) / dble(nwind)
            do i=1,ntpguest
              istat = 1+(i-1)*16
              rollstat = (i-1)*9
c           get the rolled averages for all the variables
              aN = chainstats(istat+1) 
              E = chainstats(istat+2)
              EN = chainstats(istat+3)
              N2 = chainstats(istat+4)
              E2 = chainstats(istat+5)
c           compute C_v and Q_st for the windowed averages
              avgwindow(rollstat+7) = calc_Qst(E2, E, aN, N2, EN, temp)
              avgwindow(rollstat+8) = calc_Cv(E2, E, aN, N2, EN, temp)
            enddo 
            do i=1,ntpguest*9
              delta = weight * (avgwindow(i) - sumwindowav(i))
              sumwindowav(i) = sumwindowav(i) + delta/avcount
              varwindow(i) = varwindow(i) + 
     &delta*weight*(avgwindow(i) - sumwindowav(i))
              avgwindow(i)=0.d0
            enddo
            
            rollcount = 0
          endif
          if((lprob).and.(.not.lwidom))then
            call storeprob(ntpguest,rucell,ngrida,ngridb,ngridc)
            if((lprobeng(iguest)).and.(accepted))then
                call storeenprob(iguest,randchoice,rucell,ngrida,
     &ngridb,ngridc,guest_toten)
            endif
          endif
        endif

c       increment the numguests.out storage buffer

c        ibuff=ibuff+1
        if(lnumg.and.(mod(gcmccount,nnumg).eq.0))then
c          write(*,'(4e18.5)')ewld1eng/engunit,ewld2sum/engunit,
c     &ewld3sum/engunit,vdwsum/engunit
c          do i=1,natms
c            write(*,'(a3,3f15.5)')atmname(mol,i),newx(i),newy(i),newz(i)

c          enddo
          do i=1,ntpguest
            mol=locguest(i)
            write(400+i,"(i9,i7,2f20.6,7i4)")
     &        gcmccount,nummols(mol),energy(mol),
     &        delE(mol),ins(i),del(i),dis(i),jmp(i),flx(i),swp(i),swi(i)

          enddo
        endif
        do i=1,ntpguest 
          ins(i)=0
          del(i)=0
          dis(i)=0
          jmp(i)=0
          flx(i)=0
          swp(i)=0
          swi(i)=0
        enddo
      enddo
c*************************************************************************
c     END OF GCMC RUN
c*************************************************************************
      call timchk(0,timelp)

c     run statistics on uptake, energies locally
c     then add the sums globally for a global weighted
c     average
c      print *, "Ewald1 average", ewaldaverage/accept_ins
      if(prodcount.gt.0)then
        weight = chainstats(1)
        do i=1,ntpguest
          istat = 1+(i-1)*16
          vstat = (i-1)*9

          avgN = chainstats(istat+1)
          avgE = chainstats(istat+2)
          avgEN = chainstats(istat+3)
          avgN2 = chainstats(istat+4)
          avgE2 = chainstats(istat+5)
          avgNF = chainstats(istat+6)
          avgH = chainstats(istat+7)
          stdN = sqrt(varwindow(vstat+1)/avcount)
          stdE = sqrt(varwindow(vstat+2)/avcount)
          stdEN = sqrt(varwindow(vstat+3)/avcount)
          stdN2 = sqrt(varwindow(vstat+4)/avcount)
          stdE2 = sqrt(varwindow(vstat+5)/avcount)
          stdNF = sqrt(varwindow(vstat+6)/avcount)
          stdQst = sqrt(varwindow(vstat+7)/avcount)
          stdCv = sqrt(varwindow(vstat+8)/avcount)
          stdH = sqrt(varwindow(vstat+9)/avcount)
          chainstats(istat+8) = stdN
          chainstats(istat+9) = stdE
          chainstats(istat+10) = stdEN
          chainstats(istat+11) = stdN2
          chainstats(istat+12) = stdE2
          chainstats(istat+13) = stdNF
          chainstats(istat+14) = stdQst
          chainstats(istat+15) = stdCv
          chainstats(istat+16) = stdH
        enddo
      endif

c     sum all variables for final presentation

c     first send all local statistics to the master node.
c     via csend([messagetag],[variable to send],[length],[destination],
c     [dummy var])
c     message tag for chainstats is even
      if(idnode.gt.0)then
        call csend(idnode*2+1,chainstats,1+ntpguest*16,0,1)
      endif


c     this is final file writing stuff.. probably should put this in a 
c     subroutine so it looks less messy in the main program. 
      if(idnode.eq.0)then

         nodeweight(1)=weight
         write(nrite,"(/,a100,/,3x,'Data reported from node ',
     &i3,/,a100,/)")repeat('*',100),0,repeat('*',100)
         do i=1,ntpguest
           istat=1+(i-1)*16
           mol=locguest(i)
           avgN = chainstats(istat+1)
           avgE = chainstats(istat+2)
           avgEN = chainstats(istat+3)
           avgN2 = chainstats(istat+4)
           avgE2 = chainstats(istat+5)
           avgNF = chainstats(istat+6)
           avgH = chainstats(istat+7)
           stdN = chainstats(istat+8) 
           stdE = chainstats(istat+9) 
           stdEN = chainstats(istat+10) 
           stdN2 = chainstats(istat+11) 
           stdE2 = chainstats(istat+12) 
           stdNF = chainstats(istat+13)
           stdQst = chainstats(istat+14)
           stdCv = chainstats(istat+15)
           stdH = chainstats(istat+16)
c     isosteric heat calculation 
           Q_st = calc_Qst(avgE2, avgE, avgN, avgN2, avgEN, temp)
c     constant volume heat capacity
           C_v = calc_Cv(avgE2, avgE, avgN, avgN2, avgEN, temp)

           write(nrite,"(5x,'guest ',i2,': ',40a,/)")i,
     &       (molnam(p,mol),p=1,40)
           if(.not.lwidom)then
             write(nrite,"(5x,a60,f20.9,/,5x,a60,f20.9,/,
     &         5x,a60,f20.9,/,5x,a60,f20.9,/,5x,a60,f20.9,/,
     &         5x,a60,i20,/,5x,a60,f20.9,/,5x,a60,f20.9,/,
     &         5x,a60,f20.9,/,5x,a60,f20.9,/,5x,a60,f20.9,/)")
     &         '<N>: ', avgN, 
     &         '<E>: ', avgE,
     &         '<E*N>: ', avgEN, 
     &         '<N*N>: ', avgN2,
     &         '<E*E>: ', avgE2,
     &         'Multiplier: ',prodcount,
     &         'Isosteric heat of adsorption (kcal/mol): ',Q_st,
     &         'Isosteric heat error: ', stdQst,
     &         'Heat capacity, Cv (kcal/mol/K): ', C_v,
     &         'Heat capacity error: ', stdCv,
     &         '<surface adsorbed N>:', avgNF
           elseif(lwidom)then
             write(nrite,"(5x,a60,E20.9,/)")
     &         "Henry's Constant (mol /kg /bar): ",
     &         avgH/avo/boltz/temp*1.d5
           endif
           nstat = (i-1)*9
           node_avg(1,(nstat+1):(nstat+6)) =
     &                    chainstats((istat+1):(istat+6))
           node_avg(1, nstat+7) = Q_st
           node_avg(1, nstat+8) = C_v
           node_avg(1, nstat+9) = chainstats(istat+7)
           node_std(1,nstat+1:nstat+9) =
     &                   chainstats(istat+8:istat+16)
         enddo
         tw=tw+weight
         do i=1,mxnode-1
c        recieve all data from other nodes (via crecv)
c        prodcount used for weighting the mean and stdev
           statbuff(1:1+ntpguest*16) = 0.d0
           call crecv(i*2+1,statbuff,1+ntpguest*16,1)
           weight=statbuff(1)
           nodeweight(i+1)=weight
           tw=tw+weight
           prodcount=prodcount+int(weight)
           write(nrite,"(/,a100,/,3x,'Data reported from node ',i3,
     &/,a100,/)")repeat('*',100),i,repeat('*',100)
           do j=1,ntpguest
             mol=locguest(j)
             write(nrite,"(5x,'guest ',i2,': ',40a,/)")j,
     &       (molnam(p,mol),p=1,40)
             istat=1+(j-1)*16

             avgN = statbuff(istat+1)
             avgE = statbuff(istat+2)
             avgEN = statbuff(istat+3)
             avgN2 = statbuff(istat+4)
             avgE2 = statbuff(istat+5)
             avgNF = statbuff(istat+6)
             avgH = statbuff(istat+7)
             stdN = statbuff(istat+8)
             stdE = statbuff(istat+9)
             stdEN = statbuff(istat+10)
             stdN2 = statbuff(istat+11)
             stdE2 = statbuff(istat+12)
             stdNF = statbuff(istat+13)
             stdQst = statbuff(istat+14)
             stdCv = statbuff(istat+15)
             stdH = statbuff(istat+16)

             Q_st = calc_Qst(avgE2, avgE, avgN, avgN2, avgEN, temp)
             C_v = calc_cv(avgE2, avgE, avgN, avgN2, avgEN, temp)
             if(.not.lwidom)then
               write(nrite,"(5x,a60,f20.9,/,5x,a60,f20.9,/,
     &           5x,a60,f20.9,/,5x,a60,f20.9,/,5x,a60,f20.9,/,
     &           5x,a60,i20,/,5x,a60,f20.9,/,5x,a60,f20.9,/,
     &           5x,a60,f20.9,/,5x,a60,f20.9,/,5x,a60,f20.9,/)")
     &           '<N>: ', avgN, 
     &           '<E>: ', avgE,
     &           '<E*N>: ', avgEN, 
     &           '<N*N>: ', avgN2,
     &           '<E*E>: ', avgE2,
     &           'Multiplier: ',prodcount,
     &           'Isosteric heat of adsorption (kcal/mol): ',Q_st,
     &           'Isosteric heat error: ', stdQst,
     &           'Heat capacity, Cv (kcal/mol/K): ', C_v,
     &           'Heat capacity error: ', stdCv,
     &           '<surface adsorbed N>:', avgNF
             elseif(lwidom)then
                write(nrite,"(5x,a60,E20.9,/)")
     &            "Henry's Constant (mol /kg /bar): ", 
     &            avgH/avo/boltz/temp*1.d5
             endif
             nstat = (j-1)*9
             node_avg(i+1,nstat+1:nstat+6) = statbuff(istat+1:istat+6)
             node_avg(i+1,nstat+7) = Q_st
             node_avg(i+1,nstat+8) = C_v
             node_avg(i+1,nstat+9) = statbuff(istat+7)
             node_std(i+1,nstat+1:nstat+9) = statbuff(istat+8:istat+16)
          enddo
        enddo
      endif

      call gisum(accept_ins,1,buffer)
      call gisum(ins_count,1,buffer)

      call gisum(accept_del,1,buffer)
      call gisum(del_count,1,buffer)

      call gisum(accept_disp,1,buffer)
      call gisum(disp_count,1,buffer)

      call gisum(accept_jump,1,buffer)
      call gisum(jump_count,1,buffer)

      call gisum(accept_flex,1,buffer)
      call gisum(flex_count,1,buffer)

      call gisum(accept_swap,1,buffer)
      call gisum(swap_count,1,buffer)

      call gisum(accept_tran,1,buffer)
      call gisum(tran_count,1,buffer)

      call gisum(accept_rota,1,buffer)
      call gisum(rota_count,1,buffer)
      
      call gisum(accept_switch,1,buffer)
      call gisum(switch_count,1,buffer)

      call gisum(gcmccount,1,buffer)

      if(n_fwk.gt.0)then 
        call gisum(fwk_counts,n_fwk,fwksumbuff)
      endif
c     write final probability cube files
      
      cprob=0
      cell=cell*angs2bohr
      ucell=ucell*angs2bohr
      if(lprob.and.prodcount.gt.0)then
        do i=1,ntpguest
          iprob=0
          if(lprobeng(i))then
              np=nprob(i)-2
          else
              np=nprob(i)
          endif
          do j=1,np
            cprob=cprob+1
            iprob=iprob+1
            if (.not.lwidom)then
              call gdsum3(grid,cprob,ntprob,gridsize,gridbuff)
              if(idnode.eq.0)call writeprob
     &  (i,cprob,iprob,ucell,ntpguest,ntpfram,gridsize,
     &  ngrida,ngridb,ngridc,prodcount,scell_factor)
            endif
          enddo
          if(lprobeng(i))then
              iprob=iprob+1
              cprob=cprob+1
              call gdsum3(grid,cprob,ntprob,gridsize,gridbuff)
c             add counters again for the tally grid.
              iprob=iprob+1
              cprob=cprob+1
              call gdsum3(grid,cprob,ntprob,gridsize,gridbuff)
              if(idnode.eq.0)call writeenprob
     &(i,cprob-1,ucell,ntpfram,gridsize,
     &ngrida,ngridb,ngridc,scell_factor)
          endif
        enddo
      endif
      
      if(idnode.eq.0)then
        write(nrite,"(/,a17,i9,a15,f13.3,a8)")
     &'time elapsed for ',gcmccount,' gcmc steps : ',timelp,' seconds'
        write(nrite,"(/,a30,i9)")
     &'total accepted steps : ',accept_ins+accept_del+accept_disp+
     &accept_jump+accept_flex+accept_swap+accept_tran+accept_rota
        if(ins_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'insertion ratio: ',dble(accept_ins)/dble(ins_count)
        if(del_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'deletion ratio: ',dble(accept_del)/dble(del_count)
        if(disp_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'displacement ratio: ',dble(accept_disp)/dble(disp_count)
        if(jump_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'jump ratio: ',dble(accept_jump)/dble(jump_count)
        if(flex_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'flex ratio: ',dble(accept_flex)/dble(flex_count)
        do jj=1,n_fwk
          write(nrite,"(/,6x,a26,i6,60a1,e13.6)")
     &'Framework population for: ',jj,(fwk_name(jj, kk),kk=1,60),
     & dble(fwk_counts(jj))/dble(prodcount)
        enddo
        if(swap_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'swap ratio: ',dble(accept_swap)/dble(swap_count)
        if(switch_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'switch ratio: ',dble(accept_switch)/dble(switch_count)
        if(tran_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'translation ratio: ',dble(accept_tran)/dble(tran_count)
        if(rota_count.gt.0)
     &write(nrite,"(/,3x,a21,f15.9)")
     &'rotation ratio: ',dble(accept_rota)/dble(rota_count)
        do i=1,ntpguest
          mol=locguest(i)

          avgN = 0.d0
          avgE = 0.d0
          avgEN = 0.d0
          avgN2 = 0.d0
          avgE2 = 0.d0
          avgNF = 0.d0
          avgH = 0.d0
          stdN = 0.d0
          stdE = 0.d0
          stdEN = 0.d0
          stdN2 = 0.d0
          stdE2 = 0.d0
          stdNF = 0.d0
          stdQst = 0.d0
          stdCv = 0.d0
          stdH = 0.d0
c         compute unions of averages and standard deviations
          call avunion(i,mxnode,avgN,avgE,avgEN,avgN2,avgE2,avgNF,avgH)
c       isosteric heat of adsorption 
          Q_st = calc_Qst(avgE2, avgE, avgN, avgN2, avgEN,temp)
c       heat capacity
          C_v = calc_Cv(avgE2, avgE, avgN, avgN2, avgEN,temp)
          call stdunion
     &(i,mxnode,stdN,stdE,stdEN,stdN2,stdE2, stdNF,stdQst,stdCv,stdH,
     &avgN,avgE,avgEN,avgN2,avgE2,avgNF,Q_st,C_v,avgH)

          write(nrite,"(/,a100,/,'final stats for guest ',
     &          i2,3x,40a,/,a100,/)")
     &       repeat('=',100),
     &       i,(molnam(p,mol),p=1,40),
     &       repeat('=',100)

          if(.not.lwidom)then
            write(nrite,"(/,a36,f15.6,a5,f12.3,/,
     &        a36,f15.6,a5,f12.3,/,a36,f15.6,a5,f12.3,/,
     &        a36,f15.6,a5,f12.3,/,a36,f15.6,a5,f12.3,/)")
     &        '<N>: ',avgN, ' +/- ', stdN,
     &        '<E>: ',avgE, ' +/- ', stdE,
     &        '<E*N>: ',avgEN, ' +/- ', stdEN,
     &        '<N*N>: ',avgN2, ' +/- ', stdN2,
     &        '<E*E>: ',avgE2, ' +/- ', stdE2
            write(nrite,"(/,a60,f15.6,/,a60,f15.6)")
     &        'average number of guests: ',avgN,
     &        'standard error: ',stdN
            write(nrite,"(a60,f15.6,/,a60,f15.6)")
     &        'Isosteric heat of adsorption (kcal/mol): ',Q_st,
     &        'Isosteric heat error: ', stdQst
c           I added surface data here so that faps would read it in
c           as the [useless IMO] heat capacity of the guest. This
c           is a hack to force faps to report surface adsorbed data
c           in the C_v column of the faps results .csv file
            if(surftol.ge.0.d0)write(nrite,"(a60,f15.6,/,a60,f15.6)")
     &        'average surface adsorption: ',avgNF,
     &        'standard error: ',stdNF
            write(nrite,"(a60,f15.6,/,a60,f15.6,/,a60,i15,/)")
     &        'Heat capacity, Cv (kcal/mol/K): ', C_v,
     &        'Heat capacity error: ', stdCv,
     &        'Total steps counted: ',int(tw)
          elseif(lwidom)then
            write(nrite,"(/a60,E15.6,/,a60,i15,/)")
     &        "Henry's Constant (mol /kg /bar): ", 
     &         avgH/avo/boltz/temp*1.d5,
     &        "Total steps counted: ",int(tw)
          endif
        enddo
      endif
      close(202)
      close(ncontrol)
      close(nconfig)
      close(nfield)
      do i=1,ntpguest
        if(lnumg)close(400+i)
        if(abs(nhis).gt.0)close(500+i)
      enddo
      if(idnode.eq.0)then
       close(nrite)
c       close(nang)
      endif
      call exitcomms()
      contains
      character*9 function month(date)
      implicit none
      character*2 date

      if(date.eq.'01')month='January'
      if(date.eq.'02')month='February'
      if(date.eq.'03')month='March'   
      if(date.eq.'04')month='April'   
      if(date.eq.'05')month='May'     
      if(date.eq.'06')month='June'
      if(date.eq.'07')month='July'
      if(date.eq.'08')month='August'
      if(date.eq.'09')month='September'
      if(date.eq.'10')month='October'
      if(date.eq.'11')month='November'
      if(date.eq.'12')month='December'

      return
      end function month
      subroutine avunion(iguest,mxnode,avgN,avgE,avgEN,avgN2,avgE2,
     &avgNF,avgH)

      implicit none
      real(8) avgE,avgN,avgEN,avgN2,avgE2,avgH,sumweight,weight
      real(8) avgNF
      integer iguest,i,node,mxnode,istat
      istat=(iguest-1)*9
      sumweight=0.d0
      do node=1,mxnode
        weight = nodeweight(node)
        sumweight = weight + sumweight
        avgN = avgN + weight*node_avg(node,istat+1)
        avgE = avgE + weight*node_avg(node,istat+2)
        avgEN = avgEN + weight*node_avg(node,istat+3)
        avgN2 = avgN2 + weight*node_avg(node,istat+4)
        avgE2 = avgE2 + weight*node_avg(node,istat+5)
        avgNF = avgNF + weight*node_avg(node,istat+6)
        avgH = avgH + weight*node_avg(node,istat+9)
      enddo

      avgE = avgE/sumweight
      avgN = avgN/sumweight
      avgEN = avgEN/sumweight
      avgN2 = avgN2/sumweight
      avgE2 = avgE2/sumweight
      avgNF = avgNF/sumweight
      avgH = avgH/sumweight
      end subroutine avunion
       
      subroutine stdunion(iguest,mxnode,stdN,stdE,stdEN,stdN2,stdE2,
     &stdNF,stdQst,stdCv,stdH,avgN,avgE,avgEN,avgN2,avgE2,avgNF,
     &Q_st,C_v,avgH)

      implicit none
      real(8) stdN,stdE,stdEN,stdN2,stdE2,stdQst,stdCv,stdH
      real(8) weight,sumweight, stdNF
      real(8) avgN,avgE,avgEN,avgN2,avgE2,Q_st,C_v,avgH, avgNF
      integer mxnode,iguest,istat,node
      
      istat = (iguest-1)*9
      sumweight=0.d0
      do node = 1,mxnode 
        weight = nodeweight(node)
        sumweight = nodeweight(node)+sumweight

        stdN = stdN + weight*
     &(node_std(node,istat+1)**2+node_avg(node,istat+1)**2)
        stdE = stdE + weight*
     &(node_std(node,istat+2)**2+node_avg(node,istat+2)**2)
        stdEN = stdEN + weight*
     &(node_std(node,istat+3)**2+node_avg(node,istat+3)**2)
        stdN2 = stdN2 + weight*
     &(node_std(node,istat+4)**2+node_avg(node,istat+4)**2)
        stdE2 = stdE2 + weight*
     &(node_std(node,istat+5)**2+node_avg(node,istat+5)**2)
        stdNF = stdNF + weight*
     &(node_std(node,istat+6)**2+node_avg(node,istat+6)**2)
        stdQst = stdQst + weight*
     &(node_std(node,istat+7)**2+node_avg(node,istat+7)**2)
        stdCv = stdCv + weight*
     &(node_std(node,istat+8)**2+node_avg(node,istat+8)**2)
        stdH = stdH + weight*
     &(node_std(node,istat+9)**2+node_avg(node,istat+9)**2)
      enddo
      stdN = sqrt((stdN/sumweight) - avgN**2)
      stdE = sqrt((stdE/sumweight) - avgE**2)
      stdEN = sqrt((stdEN/sumweight) - avgEN**2)
      stdN2 = sqrt((stdN2/sumweight) - avgN2**2)
      stdE2 = sqrt((stdE2/sumweight) - avgE2**2)
      stdNF = sqrt((stdNF/sumweight) - avgNF**2)
      stdQst = sqrt((stdQst/sumweight) - Q_st**2)
      stdCv = sqrt((stdCv/sumweight) - C_v**2)
c      stdH = sqrt((stdH/sumweight) - avgH**2)
      end subroutine stdunion
      subroutine timchk(ktim,time)

c***********************************************************************
c     
c     timing routine for time elapsed in seconds
c     
c***********************************************************************
      implicit none

      logical init
      character*12 dat,tim,zon
      integer idnode,mynode,ktim,day
      real(8) time,told,tsum,tnow
      integer info(8)

      save init,idnode,told,tsum,day

      data init/.true./

   10 format(/,'time elapsed since job start = ',f15.3,' seconds',/)

      call date_and_time(dat,tim,zon,info)
      
      if(init)then

         tsum=0.d0
         time=0.d0
         day=info(3)
         idnode=mynode()
         told=3600.d0*dble(info(5))+60.d0*dble(info(6))+
     x         dble(info(7))+0.001d0*dble(info(8))
         init=.false.

      else 

         tnow=3600.d0*dble(info(5))+60.d0*dble(info(6))+
     x         dble(info(7))+0.001d0*dble(info(8))
         if(day.ne.info(3))then
           told=told-86400.d0
           day=info(3)
         endif
         tsum=tsum+tnow-told
         told=tnow
         time=tsum

      endif

      if(ktim.gt.0.and.idnode.eq.0) write(nrite,10)time

      return
      end subroutine timchk
      subroutine hisarchive(ntpguest,gcmccount)
c*****************************************************************************
c
c     writes an xyz file of the current geometries of the guest
c
c*****************************************************************************
      implicit none

      integer i,imol,nmols,natms,gcmccount,iatm,ntpguest

      do k=1,ntpguest
        imol=locguest(k)
        nmols=nummols(imol)
        natms=numatoms(imol)
        write(500+k,"(i6,/,'step ',i7)")nmols*natms,gcmccount

        iatm=0
        do i=1,nmols
           do j=1,natms
            iatm=iatm+1
            write(500+k,'(2x,a1,3f16.6)')atmname(imol,j),
     &  molxxx(imol,iatm),molyyy(imol,iatm),molzzz(imol,iatm)
          enddo
        enddo
      enddo

      end subroutine hisarchive
      subroutine single_point
     &(imcon,idnode,keyfce,alpha,drewd,rcut,delr,totatm,totfram,ntpfram,
     &ntpguest,ntpmls,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,spenergy,vdwsum,ecoul,dlpeng,maxmls,surftol)
c*****************************************************************************
c
c     does a single point energy calculation over all atoms in the
c      system
c
c*****************************************************************************
      implicit none
      logical latmsurf,lmolsurf
      integer i,ii,ik,j,jj,p,kmax1,kmax2,kmax3,imcon,keyfce
      integer totatm,newld,sittyp,idnode,ntpatm,maxvdw,totfram
      integer k,mol,ntpguest,natms,nmols,ntpfram,maxmls
      integer aa,ab,jatm,ivdw,iatm,ntpmls
      real(8) drewd,dlrpot,volm,epsq,alpha,rcut,delr,ecoul,evdw
      real(8) engsic,chg,engsrp,engunit,ecoulg,evdwg
      real(8) ewald1sum,ewald2sum,ewald3sum,vdwsum
      real(8) ewald1eng,ewald2eng,ewald3eng,vdweng
      real(8) spenergy,delrc,dlpeng,surftol,surftolsq
      real(8) req,sig,ak
      ewald2sum = 0.d0
      ewald3eng = 0.d0
      vdwsum = 0.d0
      ewald1eng = 0.d0
      ewald2eng = 0.d0
      vdweng = 0.d0 

      spenergy=0.d0
c     long range correction to short range forces.
c     this initializes arrays, a different subroutine
c     is called during the gcmc simulation
c     "gstlrcorrect"

      call lrcorrect(idnode,imcon,keyfce,totatm,ntpatm,maxvdw,
     &engunit,rcut,volm,maxmls)

c     generate neighbour list
      call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
c
      call parlst(imcon,totatm,rcut,delr)
c     reciprocal space ewald calculation
      call ewald1(imcon,ewald1sum,engsic,totatm,volm,alpha,sumchg,
     &kmax1,kmax2,kmax3,epsq,newld,maxmls)
c     compute for all molecules, the excluding contributions
c     to the reciprocal space sum.
      call excluding_ewald_charges
     &(imcon,idnode,ntpmls,ntpguest,totatm,ewald3eng,alpha,epsq)

c     compute short range interactions, molecule-by-molecule
c     integer 'i' counts from the atom beginning to the end.
      i=0

      do mol=1,ntpmls
        if(nummols(mol).gt.0)then
          do imol=1,nummols(mol)
            lmolsurf=.false.
            do iatm=1,numatoms(mol)
c             increment counter over all atoms
              i=i+1
c              aa = ltpsit(mol,i)
              ik=0
              if(lentry(i).gt.0)then
                do j=1,lentry(i)
                  ik=ik+1

                  jatm=list(i,j)
                  ilist(j)=jatm
                  moldf(j)=moltype(jatm)
                  xdf(ik)=xxx(i)-xxx(jatm)
                  ydf(ik)=yyy(i)-yyy(jatm)
                  zdf(ik)=zzz(i)-zzz(jatm)
                enddo
                call images(imcon,ik,cell,xdf,ydf,zdf)
                do j=1,lentry(i)
                  rsqdf(j)=xdf(j)**2+ydf(j)**2+zdf(j)**2
c                 check if a surface atom
                  if(surftol.ge.0.d0)then
                    jatm = ilist(j)
                    call surface_check(i,jatm,surftol,latmsurf)
                    if(latmsurf)lmolsurf=.true.
                  endif
                enddo
                chg=atmcharge(i)
                sittyp=ltype(i)
                
                call ewald2
     &          (chg,lentry(i),ewald2eng,mol,maxmls,
     &          drewd,rcut,epsq)
                ewald2sum=ewald2sum+ewald2eng
c               calc vdw interactions
                call srfrce
     &          (sittyp,lentry(i),mol,maxmls,vdweng,rcut,dlrpot)
                vdwsum=vdwsum+vdweng
              endif
            enddo
          enddo
          if(lmolsurf)surfacemols(mol)=surfacemols(mol)+1
        endif
c       increment surface count
      enddo
c      write(*,'(f25.10)') ewald1eng+ewald1sum,ewald2eng,ewald3eng,vdweng
c     &, elrc/engunit
c      do i=1,maxmls
cc       really don't know how to mix the elrc and ewald3eng properly
c        energy(i)=(ewald1en(i)+ewald2en(i)+vdwen(i)+elrc+ewald3eng)
c     &/engunit 
c      enddo
      vdwsum = vdwsum + elrc
      dlpeng=(ewald1sum+ewald2eng+vdwsum-ewald3eng)
     & /engunit
      ecoul = ewald2sum + ewald1sum - ewald3eng
      return
      end subroutine single_point
      subroutine excluding_ewald_charges
     &(imcon,idnode,ntpmls,ntpguest,totatm,ewald3sum,alpha,epsq)
c***********************************************************************
c                                                                      * 
c     Compute for each molecule type specified in the FIELD file       *
c     the intramolecular charge interactions that will be cancelled    *
c     from the long range ewald contribution.                          *
c     This includes 'frozen' atoms that will not interact with each    *
c     other in a framework, as well as rigid guest molecules which     *
c     move, but do not interact with each other.                       *
c                                                                      *
c***********************************************************************
      implicit none
      logical lguest,lfrzi,lfrzj
      integer nmols,mol,ntpmls,imol,iatm,itgst,gstmol
      integer ntpguest,totatm,imcon,idnode,katm
      real(8) ewald3mol,ewald3sum,engcpe,alpha,epsq
      real(8) chg
      ewald3sum=0.d0
      ewald3en(:)=0.d0
c     count total number of atoms
      do mol=1,ntpmls
        lguest=.false.
        ewald3mol=0.d0
        nmols=nummols(mol)
        natms=numatoms(mol)
c       check if a guest molecule, here we assume that
c       non-bonded interactions between atoms in a guest are 
c       excluded
        do itgst=1,ntpguest
          gstmol=locguest(itgst)
          if (gstmol.eq.mol)then
c           add the total number of atoms in the molecule
c           to the atom count. This is in case there are
c           guests already in the framework at the beginning
c           of the run.
            lguest=.true.
            do iatm=1,natms-1
              ik=0
              do jatm=iatm+1,natms
                ik=ik+1
                jlist(ik)=jatm
                xdf(ik)=guestx(itgst,iatm)-guestx(itgst,jatm)
                ydf(ik)=guesty(itgst,iatm)-guesty(itgst,jatm)
                zdf(ik)=guestz(itgst,iatm)-guestz(itgst,jatm)
              enddo
              call images(imcon,ik,cell,xdf,ydf,zdf)
              chg=atmchg(mol,iatm)
              call ewald3(chg,mol,ik,alpha,engcpe,epsq)
              ewald3mol=ewald3mol+engcpe
              ewald3en(mol)=ewald3en(mol)+engcpe
            enddo
            ewald3sum=ewald3sum+nmols*ewald3mol
          endif
        enddo
c       after this it will be framework atoms populating
c       the list.
c       NB This part doesn't work currently. It doesn't matter
c       since the framework atoms are fixed and the ewald1 energy
c       will not change. the SIC for this is constant. But this 
c       is driving me NUTS.
        if(.not.lguest)then
          do imol=1,nmols
            do iatm=1,natms
              ik=0
              lfrzi=(lfzsite(mol,iatm).ne.0)
              do jmol=imol,nmols
c               do not count the last interaction 
c               it is iatm=jatm=natms
c                if((jmol.eq.imol).and.(iatm.eq.natms))cycle
                if(jmol.eq.imol)then
                  katm=iatm+1
                else
                  katm=1
                endif
                do jatm=katm,natms
                  lfrzj=(lfzsite(mol,jatm).ne.0)
c                 this is the same atom in the same image
                  if((iatm.eq.jatm).and.(imol.eq.jmol))cycle
                  if((lfrzi).and.(lfrzj))then
                    ik=ik+1
                    jlist(ik)=jatm
                    xdf(ik)=molxxx(imol,iatm)-molxxx(jmol,jatm)
                    ydf(ik)=molyyy(imol,iatm)-molyyy(jmol,jatm)
                    zdf(ik)=molzzz(imol,iatm)-molzzz(jmol,jatm)
                  endif
                enddo
              enddo
              call images(imcon,ik,cell,xdf,ydf,zdf)
              chg=atmchg(mol,iatm)
              call ewald3(chg,mol,ik,alpha,engcpe,epsq)
              ewald3en(mol)=ewald3en(mol)+engcpe
c             don't add this contribution to the total.
c             It is a constant factor and will be cancelled
c             out when computing most interactions.
            enddo
          enddo
        endif
      enddo 
      return
      end subroutine excluding_ewald_charges
      subroutine insertion
     &(imcon,idnode,iguest,keyfce,alpha,rcut,delr,drewd,totatm,
     &ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estep,loverlap,lnewsurf,surftol)
c***********************************************************************
c
c     inserts a particle in the framework and computes the 
c     energy of an additional particle.
c
c***********************************************************************
      implicit none
      logical loverlap,lnewsurf,latmsurf
      integer i,ik,j,kmax1,kmax2,kmax3,imcon,keyfce
      integer totatm,sittyp,idnode,ntpatm,maxvdw
      integer k,mol,ntpguest,natms,nmols,iguest,ivdw
      integer jatm,ka,aa,ak,ab,l
      real(8) drewd,dlrpot,volm,epsq,alpha,rcut,delr
      real(8) chg,engsrp,engunit
      real(8) ewld2sum,ewld3sum,vdwsum
      real(8) ewld1eng,ewld2eng,vdweng,delrc_tmp
      real(8) delrc,estep,sig,surftol,req,surftolsq

c c   calculate the ewald sums ewald1 and ewald2(only for new mol)
c c   store ewald1 and 2 separately for the next step.
c c   calculate vdw interaction (only for new mol)
      mol=locguest(iguest)
       
      latmsurf=.false.
      natms=numatoms(mol)
      nmols=nummols(mol)
      ewld2sum=0.d0
      vdwsum=0.d0
      loverlap = .false.
c      
      do i=1,natms
        ind(i)=0
      enddo
      call guestlistgen
     &(imcon,iguest,totatm,rcut,delr,
     &natms,newx,newy,newz)

 
c     calculate long range correction to vdw for the insertion
c     of an additional guest
      do i=1,natms
        ka=ltpsit(mol,i)
        numtyp(ka)=numtyp(ka)+1
        numtyp_mol(mol,ka)=numtyp_mol(mol,ka)+1
        if(lfzsite(mol,i).ne.0)then
          numfrz(ka)=numfrz(ka)+1
          numfrz_mol(mol,ka)=numfrz_mol(mol,ka)+1
        endif
      enddo
      call gstlrcorrect(idnode,imcon,mol,keyfce,natms,ntpatm,maxvdw,
     &engunit,delrc,rcut,volm,maxmls)

      delrc=delrc-elrc
c     do vdw and ewald2 energy calculations for the new atoms

      do i=1,natms
        ik=0
        aa = ltpsit(mol,i)
        do j=1,gstlentry(i)
          ik=ik+1
          jatm=gstlist(i,j)
          ilist(j)=jatm
          moldf(j)=moltype(jatm)
          xdf(ik)=newx(i)-xxx(jatm)
          ydf(ik)=newy(i)-yyy(jatm)
          zdf(ik)=newz(i)-zzz(jatm)
        enddo
        call images(imcon,ik,cell,xdf,ydf,zdf)
        do l=1,gstlentry(i)
          rsqdf(l)=xdf(l)**2+ydf(l)**2+zdf(l)**2
c         check if a surface atom
          if(surftol.ge.0.d0)then
            jatm = ilist(l)
            call surface_check(i,jatm,surftol,latmsurf)
          endif
          if(latmsurf)lnewsurf=.true.
        enddo
c       figure out which index contains charges and ltype arrays
c       that match the guest...
        call overlap_check(loverlap,natms,overlap)
        if (loverlap)then
          exit
        else
          chg=atmchg(mol,i)
          sittyp=ltpsit(mol,i)

c         calc ewald2 interactions
          call ewald2
     & (chg,gstlentry(i),ewld2eng,mol,maxmls,drewd,rcut,epsq)
          ewld2sum=ewld2sum+ewld2eng
c         calc vdw interactions 

          call srfrce
     & (sittyp,gstlentry(i),mol,maxmls,vdweng,rcut,dlrpot)
          vdwsum=vdwsum+vdweng 
        endif
      enddo
c     the pairwise intramolecular coulombic correction
c     calculated for the guest at the begining of the 
c     program run.  Assumes constant bond distances.
      call ewald1_guest
     &(imcon,ewld1eng,natms,iguest,volm,alpha,sumchg,
     &kmax1,kmax2,kmax3,epsq,maxmls,.true.,.false.,.false.,1)
      ewld3sum=ewald3en(mol)
c      write(*,*)"STEP ENERGY"
c      write(*,*)mol,ewld1eng/engunit,ewld2sum/engunit,ewld3sum/engunit,
c     &vdwsum/engunit,delrc/engunit 
c      write(*,*)"DONE"
      estep= estep+ 
     &       (ewld1eng+ewld2sum-ewld3sum+vdwsum+delrc)/engunit

c      write(*,*)ewld1eng/engunit,
c     & ewld2sum/engunit,
c     & ewld3sum/engunit,
c     & vdwsum/engunit,
c     & delrc/engunit
      do i=1, maxmls
        ewld3sum=0.d0
        ik=loc2(mol,i)
        delrc_tmp=delrc_mol(ik)/engunit
        if(i.ne.mol)then
          delE(i)=delE(i)+
     &(ewald1en(i)+ewald2en(i)-ewld3sum+vdwen(i)+delrc_tmp)
     &/engunit
c          write(*,*)nummols(i),
c     &ewald1en(i)/engunit,
c     &ewald2en(i)/engunit,
c     &vdwen(i)/engunit,
c     &delrc_tmp
        endif
      enddo
      delE(mol)=delE(mol)+
     &  estep
c     &  (ewld1eng+ewld2sum+ewld3sum+vdwsum+delrc)/engunit
      end subroutine insertion
      
      subroutine deletion 
     &(imcon,idnode,keyfce,iguest,choice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,estep,linitsurf,surftol)
c***********************************************************************
c
c     deletes a particle from the framework 
c
c***********************************************************************
      implicit none
      logical linitsurf,latmsurf
      integer i,ik,j,kmax1,kmax2,kmax3,imcon,keyfce
      integer totatm,sittyp,idnode,ntpatm,maxvdw
      integer k,mol,ntpguest,natms,nmols,iguest,ivdw
      integer jatm,ka,aa,ak,ab,l,itatm,choice,atmadd
      integer iatm,at,imol
      real(8) drewd,dlrpot,volm,epsq,alpha,rcut,delr
      real(8) chg,engsrp,engunit
      real(8) ewld2sum,ewld3sum,vdwsum
      real(8) ewld1eng,ewld2eng,vdweng,delrc_tmp
      real(8) delrc,estep,sig,surftol,req,surftolsq
      
      latmsurf=.false.
      ewld2sum=0.d0
      vdwsum=0.d0
c     find which index the molecule "choice" is
      call get_guest(iguest,choice,mol,natms,nmols)

      call guestlistgen
     &(imcon,iguest,totatm,rcut,delr,
     &natms,newx,newy,newz)

c     calculate long range correction of the system less one
c     molecule of the guest.  the delta value will be calculated
c     by subtracting this value by the current energy (elrc)

      do i=1,natms
        ka=ltpsit(mol,i)
        numtyp(ka)=numtyp(ka)-1
        numtyp_mol(mol,ka)=numtyp_mol(mol,ka)-1
        if(lfzsite(mol,i).ne.0)then
          numfrz(ka)=numfrz(ka)-1
          numfrz_mol(mol,ka)=numfrz_mol(mol,ka)-1
        endif
      enddo

      call gstlrcorrect(idnode,imcon,mol,keyfce,natms,ntpatm,maxvdw,
     &engunit,delrc,rcut,volm,maxmls) 

      delrc=delrc-elrc
      
      call ewald1_guest
     &(imcon,ewld1eng,natms,iguest,volm,alpha,sumchg,
     &kmax1,kmax2,kmax3,epsq,maxmls,.false.,.true.,.false.,1)
c     do vdw and ewald2 energy calculations for the new atoms
          
      do i=1,natms
        aa = ltpsit(mol,i)
        itatm=ind(i)
        ik=0 
        do j=1,gstlentry(i)
          ik=ik+1
          jatm=gstlist(i,j)
          ilist(j)=jatm
          moldf(j)=moltype(jatm)
          xdf(ik)=newx(i)-xxx(jatm)
          ydf(ik)=newy(i)-yyy(jatm)
          zdf(ik)=newz(i)-zzz(jatm)
        enddo
        
        call images(imcon,ik,cell,xdf,ydf,zdf)
        do l=1,gstlentry(i)
          rsqdf(l)=xdf(l)**2+ydf(l)**2+zdf(l)**2
c         check if a surface atom
          if(surftol.ge.0.d0)then
            jatm = ilist(l)
            call surface_check(i,jatm,surftol,latmsurf)
          endif
          if(latmsurf)linitsurf=.true.
        enddo
        chg=atmcharge(itatm)
        sittyp=ltype(itatm)
        
        call ewald2
     & (chg,gstlentry(i),ewld2eng,mol,maxmls,
     &  drewd,rcut,epsq)
        ewld2sum=ewld2sum+ewld2eng
c       calc vdw interactions
        call srfrce
     & (sittyp,gstlentry(i),mol,maxmls,vdweng,rcut,dlrpot)
        vdwsum=vdwsum+vdweng
      enddo
c     calculate the pairwise intramolecular coulombic correction
c     (calculated at the begining - assumes constant bond distance)
      ewld3sum=ewald3en(mol)
      estep= estep+ 
     &     (ewld1eng-ewld2sum+ewld3sum-vdwsum+delrc)/engunit
      do i=1, maxmls
        ewld3sum=0.d0
        ik=loc2(mol,i)
        delrc_tmp=delrc_mol(ik)/engunit
        if(i.ne.mol)then
          delE(i)=delE(i)+
     &(ewald1en(i)-ewald2en(i)+ewld3sum-vdwen(i)+delrc_tmp)
     &/engunit
        endif
      enddo
      delE(mol)=delE(mol)+
     &  estep
c     &     (ewld1eng-ewld2sum-ewld3sum-vdwsum+delrc)/engunit
      end subroutine deletion
      subroutine guest_energy
     &(imcon,idnode,keyfce,iguest,choice,alpha,rcut,delr,drewd,
     &totatm,ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &engunit,delrc,vdwsum,ewld2sum,ewld1eng,lsurf,surftol,
     &loverlap,pass)
c***********************************************************************
c
c     compute the energy of a guest in it's current position
c
c***********************************************************************
      implicit none
      logical lsurf,loverlap,latmsurf
      integer i,ik,j,kmax1,kmax2,kmax3,imcon,keyfce
      integer totatm,sittyp,idnode,ntpatm,maxvdw
      integer k,mol,ntpguest,natms,nmols,iguest,ivdw
      integer jatm,ka,aa,ak,ab,l,itatm,choice
      integer pass
      real(8) drewd,dlrpot,volm,epsq,alpha,rcut,delr
      real(8) chg,engsrp,engunit
      real(8) ewld2sum,ewld3sum,vdwsum
      real(8) ewld1eng,ewld2eng,vdweng
      real(8) delrc,estep,sig,surftol,req,surftolsq
      
      mol=locguest(iguest)
      natms=numatoms(mol)
      nmols=nummols(mol)
      ewld2sum=0.d0
      vdwsum=0.d0
      latmsurf=.false.
      call guestlistgen
     &(imcon,iguest,totatm,rcut,delr,
     &natms,newx,newy,newz)

      call ewald1_guest
     &(imcon,ewld1eng,natms,iguest,volm,alpha,sumchg,
     &kmax1,kmax2,kmax3,epsq,maxmls,.false.,.false.,.true.,pass)
c     do vdw and ewald2 energy calculations for the new atoms
          
      do i=1,natms
        aa = ltpsit(mol,i)
        itatm=ind(i)
        ik=0 
        do j=1,gstlentry(i)
          ik=ik+1
          jatm=gstlist(i,j)
          ilist(j)=jatm
          moldf(j)=moltype(jatm)
          xdf(ik)=newx(i)-xxx(jatm)
          ydf(ik)=newy(i)-yyy(jatm)
          zdf(ik)=newz(i)-zzz(jatm)
        enddo
        
        call images(imcon,ik,cell,xdf,ydf,zdf)
        do l=1,gstlentry(i)
          rsqdf(l)=xdf(l)**2+ydf(l)**2+zdf(l)**2
c         check if a surface atom
          if(surftol.ge.0.d0)then
            jatm = ilist(l)
            call surface_check(i,jatm,surftol,latmsurf)
          endif
          if(latmsurf)lsurf=.true.
        enddo
c       only do an overlap check if the pass is not 1
c       This assumes that the particle has moved to a
c       new position, so that an overlap check is relevant
        if (pass .gt. 1)then
          call overlap_check(loverlap,natms,overlap)
          if (loverlap)exit
        endif
        chg=atmcharge(itatm)
        sittyp=ltype(itatm)
        
        call ewald2
     & (chg,gstlentry(i),ewld2eng,mol,maxmls,
     &  drewd,rcut,epsq)
        ewld2sum=ewld2sum+ewld2eng
c       calc vdw interactions
        call srfrce
     & (sittyp,gstlentry(i),mol,maxmls,vdweng,rcut,dlrpot)
        vdwsum=vdwsum+vdweng
      enddo
      ewld3sum=ewald3en(mol)
      if(pass.eq.1)delE(mol)=delE(mol)-(ewld2sum+vdwsum)/engunit
      if(pass.eq.2)delE(mol)=delE(mol)+
     &  (ewld1eng+ewld2sum+vdwsum)/engunit

c     for some reason, updating the other molecule energies is
c     inappropriate and causes energy drift.
      do i=1, maxmls
        if(pass.eq.1)then
          if(i.ne.mol)delE(i)=delE(i)+
     &(-ewald2en(i)-vdwen(i))
     &/engunit
        else if (pass.eq.2)then
          if(i.ne.mol)delE(i)=delE(i)+
     &(ewald1en(i)+ewald2en(i)+vdwen(i))
     &/engunit
        end if
      enddo
      end subroutine guest_energy
      subroutine reject_move
     &(idnode,iguest,jguest,insert,delete,displace,swap)
c***********************************************************************
c
c     updates arrays for the rejection according to the type
c     of move.
c
c***********************************************************************
      implicit none
      integer idnode, iguest, natms, mol, i, ka
      integer jguest,jnatms,jmol
      logical insert,delete,displace,swap

      mol = locguest(iguest)
      natms = numatoms(mol)
      delE=0.d0
      qfix_mol=qfix_molorig
      if (insert) then
c       reset engsic
        engsic = engsicprev
c       if not accepted, must return numtyp to original value,
c       this is to calculate the long range correction to the vdw
c       sum
        do i=1,natms
          ka=ltpsit(mol,i)
          numtyp(ka)=numtyp(ka)-1
          numtyp_mol(mol,ka)=numtyp_mol(mol,ka)-1
          if(lfzsite(mol,i).ne.0)then
            numfrz(ka)=numfrz(ka)-1
            numfrz_mol(mol,ka)=numfrz_mol(mol,ka)-1
          endif
        enddo

      else if (delete)then 
c       reset engsic
        engsic = engsicprev
        do i=1,natms
          ka=ltpsit(mol,i)
          numtyp(ka)=numtyp(ka)+1
          numtyp_mol(mol,ka)=numtyp_mol(mol,ka)+1
          if(lfzsite(mol,i).ne.0)then
            numfrz(ka)=numfrz(ka)+1
            numfrz_mol(mol,ka)=numfrz_mol(mol,ka)+1
          endif
        enddo
      elseif(swap)then
        jmol=locguest(jguest)
        jnatms = numatoms(jmol)
        engsic=engsicprev
        elrc_mol=origelrc_mol
        do i=1,natms
          ka=ltpsit(mol,i)
          numtyp(ka)=numtyp(ka)+1
          numtyp_mol(mol,ka)=numtyp_mol(mol,ka)+1
          if(lfzsite(mol,i).ne.0)then
            numfrz(ka)=numfrz(ka)+1
            numfrz_mol(mol,ka)=numfrz_mol(mol,ka)+1
          endif
        enddo
        do i=1,jnatms
          ka=ltpsit(jmol,i)
          numtyp(ka)=numtyp(ka)-1
          numtyp_mol(jmol,ka)=numtyp_mol(jmol,ka)-1
          if(lfzsite(jmol,i).ne.0)then
            numfrz(ka)=numfrz(ka)-1
            numfrz_mol(jmol,ka)=numfrz_mol(jmol,ka)-1
          endif
        enddo

      endif 

      end subroutine reject_move
      subroutine accept_move
     &(imcon,idnode,iguest,insert,delete,displace,estep,guest_toten,
     &lsurf,delrc,totatm,choice,ntpfram,ntpmls,ntpguest,maxmls,
     &sumchg)
c***********************************************************************
c
c     updates arrays for the rejection according to the type
c     of move.
c
c***********************************************************************
      implicit none
      integer idnode,iguest,natms,mol,i,mm,totatm,choice,at
      integer ntpfram,imcon,ntpmls,ntpguest,maxmls
      logical insert,delete,displace,lsurf
      real(8) estep,guest_toten,delrc,sumchg
c      ewaldaverage = ewaldaverage + abs(ewld1eng+ewld3sum)/engunit
      mol = locguest(iguest)
      natms = numatoms(mol)
      at=(choice-1)*natms+1
      guest_toten=estep
c     update energy arrays
      sumchg=qfix_mol(maxmls+1)
c      energy(mol)=energy(mol)+estep
      do i=1,maxmls
c        if(i.ne.mol)energy(i)=energy(i)+delE(i)
         energy(i)=energy(i)+delE(i)
      enddo
      if(insert)then
        mm=natms*nummols(mol)
c       tally surface molecules
        if(lsurf)then
          surfacemols(iguest) = surfacemols(iguest) + 1
        endif
c       update atomic coordinates
        do i=1,natms
          molxxx(mol,mm+i)=newx(i)
          molyyy(mol,mm+i)=newy(i)
          molzzz(mol,mm+i)=newz(i)
        enddo
c       update ewald1 sums
        ckcsum = ckcsnew
        ckssum = ckssnew
c       update long range correction
        elrc=elrc+delrc
        elrc_mol(:)=elrc_mol(:)+delrc_mol(:)
c       update nummols,totatm, then condense everything to 1d arrays
        nummols(mol)=nummols(mol)+1
c       update the choice variable in case the user does something
c       with this after
        totatm=totatm+natms
        call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
        choice = nummols(mol)
      elseif(delete)then
        guest_toten= -estep
c        write(*,*)"Deletion Total guest energy:",guest_toten
        mm=natms*nummols(mol)
c       update surface molecules
        if(lsurf)then
          surfacemols(iguest) = surfacemols(iguest) - 1
        endif
c       update atomic coordinates
        do i=at+natms,mm
          molxxx(mol,i-natms)=molxxx(mol,i)
          molyyy(mol,i-natms)=molyyy(mol,i)
          molzzz(mol,i-natms)=molzzz(mol,i)
        enddo
c       update ewald1 sums
        ckcsum = ckcsnew
        ckssum = ckssnew

c       update nummols,totatm, then condense everything to 1d arrays
        elrc=elrc+delrc
        elrc_mol(:)=elrc_mol(:)+delrc_mol(:)
        nummols(mol)=nummols(mol)-1
        totatm=totatm-natms
        call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
c        call images(imcon,totatm,cell,xxx,yyy,zzz)
      elseif(displace)then
        mm=0
        do i=at,at-1+natms
          mm=mm+1
          molxxx(mol,i)=newx(mm)
          molyyy(mol,i)=newy(mm)
          molzzz(mol,i)=newz(mm)
        enddo
        ckcsum = ckcsnew
        ckssum = ckssnew
        call condense(imcon,totatm,ntpmls,ntpfram,ntpguest)
      endif

      end subroutine accept_move
      subroutine get_guest(iguest, choice, mol, natms, nmols)
c***********************************************************************
c
c     Grabs a guest from a specified index and populates the 
c     newx newy and newz arrays.
c
c***********************************************************************
      implicit none
      integer atmadd,iatm,iguest,choice,at,natms,nmols
      integer mol,imol,i

      mol=locguest(iguest)
      natms=numatoms(mol)
      nmols=nummols(mol)
      atmadd=0
      if(iguest.gt.1)then
        do i=1,iguest-1
          imol=locguest(i)
          atmadd=atmadd+numatoms(imol)*nummols(imol)
        enddo
      endif
      at=(choice-1)*natms+1
      iatm=0
      do i=at,at-1+natms
        iatm=iatm+1 
        ind(iatm)=atmadd+i
        newx(iatm)=molxxx(mol,i)
        newy(iatm)=molyyy(mol,i)
        newz(iatm)=molzzz(mol,i)
      enddo

      end subroutine get_guest
      subroutine surface_check(iatm,jatm,surftol,latmsurf)
c***********************************************************************
c
c     Checks if the given atom 'iatm' is near a surface atom 'jatm'.
c     This assumes that a 'surface' atom is frozen, and that
c     the array populated with the squared distance between neighbour
c     atoms is populated correctly for 'jatm'.
c
c***********************************************************************
      implicit none
      logical latmsurf
      integer aa,ab,ivdw,iatm,jatm
      real(8) ak,sig,req,surftol
      latmsurf=.false.

      if(lfreezesite(jatm).eq.0)return

      aa = ltype(iatm) 
      ab = ltype(jatm)
      if(aa.gt.ab)then
        ak=(aa*(aa-1.d0)*0.5d0+ab+0.5d0)
      else
        ak=(ab*(ab-1.d0)*0.5d0+aa+0.5d0)
      endif
      ivdw=lstvdw(int(ak))
      sig = prmvdw(ivdw,2)
      req = sig
c      req = sig*(2.d0**(1.d0/6.d0))
      surftolsq = (surftol+req)**2
      if (rsqdf(j).lt.surftolsq)latmsurf=.true.
      end subroutine surface_check
      subroutine test
     &(imcon,idnode,keyfce,alpha,rcut,delr,drewd,totatm,
     &ntpguest,volm,kmax1,kmax2,kmax3,epsq,ntpatm,maxvdw,
     &engunit,ntpfram,ntpmls,maxmls,outdir,cfgname,levcfg)
c***********************************************************************
c
c     testing for various bugs etc in fastmc. 
c
c***********************************************************************
      implicit none
      logical loverlap,lnewsurf
      integer imcon,idnode,iguest,keyfce,totatm,ntpguest
      integer kmax1,kmax2,kmax3,ntpatm,maxvdw
      real(8) alpha,rcut,delr,drewd,volm,epsq,engunit
      integer i,ntpfram,randchoice,maxmls,ntpmls
      integer imol,natms,levcfg
      real(8) apos,bpos,cpos,xc,yc,zc
      real(8) comx,comy,comz
      real(8) angx,angy,angz
      real(8) delrc,estep,surftol
      real(8) guest_toten,sumchg,eng
      character*8 outdir,localdir
      character*1 cfgname(80)      

      randchoice=0
      guest_toten=0.d0
      sumchg=0.d0
      write(*,*)"TESTING"

      delrc=0.d0
      estep=0.d0
      surftol=0.d0

      apos=5.d-1
      bpos=5.d-1
      cpos=5.d-1
c     NB for CO2 angx will not rotate anything due to symmetry
c     and it's starting configuration along the x-axis
      angx=0.d0
      angy=90.d0
      angz=0.d0

c     INSERT in a specific position
c     convert rand fractions to cartesian coordinates in the cell 
      call cartesian(apos,bpos,cpos,xc,yc,zc)
c     xc,yc,zc are the coordinates of the com guestx,guesty,guestz 
c     are the positions of atom i relative to the com
      iguest=1
      imol=locguest(iguest)
      natms=numatoms(imol)

      do i=1, natms
        newx(i)=guestx(iguest,i)
        newy(i)=guesty(iguest,i)
        newz(i)=guestz(iguest,i)
      enddo
c     rotate
      call rotationeuler(newx,newy,newz,natms,angx,angy,angz) 
c     add the com to each atom in the guest
c
      do i=1, natms
        newx(i)=newx(i)+xc
        newy(i)=newy(i)+yc
        newz(i)=newz(i)+zc
c        write(*,*)newx(i),newy(i),newz(i)
      enddo
c
      call insertion
     &  (imcon,idnode,iguest,keyfce,alpha,rcut,delr,drewd,totatm,
     &  ntpguest,volm,kmax1,kmax2,kmax3,epsq,dlrpot,ntpatm,maxvdw,
     &  engunit,delrc,estep,loverlap,lnewsurf,surftol)
      write(*,*)estep

      call accept_move
     &(imcon,idnode,iguest,.true.,.false.,.false.,estep,guest_toten,
     &lnewsurf,delrc,totatm,randchoice,ntpfram,ntpmls,ntpguest,
     &maxmls,sumchg)
      eng = 0.d0 
      call revive
     &(idnode,totatm,levcfg,production,ntpguest,ntpmls,
     &imcon,cfgname,eng,outdir)

c      write(*,*)estep
      end subroutine test
      end