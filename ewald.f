      subroutine erfcgen(keyfce,alpha,rcut,drewd)
      use ewald_module
      use utility_pack
      implicit none

      integer i,keyfce
      real(8) drewd,a1,a2,a3,a4,a5,pp,rrr,rrrsq,tt,exp1
      real(8) rcut,alpha 

      data a1,a2,a3/0.254829592d0,-0.284496736d0,1.421413741d0/
      data a4,a5,pp/-1.453152027d0,1.061405429d0,0.3275911d0/
      
c     mxegrd is the maximum number of grid points for potential arrays
c     why the hell do we do this on a grid??

c     look-up tables for real space part of ewald sum
      if(keyfce/2.eq.1.or.keyfce/2.eq.6)then
        drewd=rcut/dble(mxegrd-4)
        do i=1,mxegrd
           rrr=dble(i)*drewd
           rrrsq=rrr*rrr
           tt=1.d0/(1.d0+pp*alpha*rrr)
           exp1=exp(-(alpha*rrr)**2)
           erc(i)=tt*(a1+tt*(a2+tt*(a3+tt*(a4+tt*a5))))
     &       *exp1/rrr
           fer(i)=erc(i)/rrrsq+2.d0*(alpha/sqrpi)*exp1/rrrsq
        enddo
      endif
      return
      end subroutine erfcgen

      subroutine ewald1_guest
     &(imcon,engcpe,natms,iguest,volm,alpha,sumchg,
     &kmax1,kmax2,kmax3,epsq,maxmls,insert,delete,displace,pass)
c********************************************************************
c                Subroutine to determine the                        *
c                reciprocal part of the ewald                       *
c                sum.                                               *
c********************************************************************
      use utility_pack
      use ewald_module
      implicit none
      logical safe,lconsw
      logical insert,delete,displace
      integer idnode,kmax1,kmax2,kmax3,natms,pass
      integer iatm0,iatm1,i,j,limit,l,kkk,nmin
      integer mmin,ll,m,mm,n,nn,k,imcon,iguest,mol
      integer maxmls
      real(8) engcpe,volm,epsq,alpha,sic,sumchg,qfix,chgtmp
      real(8) twopi,rvolm,ralph,det,rcpcut,rcpct2,engsictmp,ssx
      real(8) ssy,ssz,rkx1,rky1,rkz1,cs,tmp,rkx2,rky2,rkz2
      real(8) rkx3,rky3,rkz3,rksq,tchge,tclm,tenc,tslm,tens
      real(8) ckcs,ckss,rrksq,fkk,akk,bkk,akv,chge,prev
      real(8) ckcold,cksold,qfixtmp,ckcpass2,ckspass2,eng1
      real(8) ckcmol2,cksmol2,ckcsmol,ckssmol 
      real(8), dimension(10) :: buffer
      real(8), dimension(9) :: rcell


      data lconsw/.true./
      safe=.true.
      twopi=2.d0*pi

c    initialize the coulombic potential energy

      engcpe=0.d0

c    working parameters
      mol=locguest(iguest)
      rvolm=twopi/volm
      ralph=-0.25d0/alpha**2

c    Note boundary conditions for different types of cells
      if(imcon.eq.4.or.imcon.eq.5.or.imcon.eq.7)then
         rvolm=0.5d0*rvolm
         lconsw=.false.
      endif

      call invert(cell,rcell,det)
      
      call dcell(rcell,buffer)
 
      rcpcut=min(dble(kmax1)*buffer(7),dble(kmax2)*buffer(8),
     & dble(kmax3)*buffer(9))
      rcpcut=rcpcut*1.05d0*twopi
      rcpct2=rcpcut**2 

      chgtmp=0.d0
      engsictmp=0.d0
c     the self interaction correction in real space
      do n=1,natms
        chge=atmchg(mol,n)
        chgtmp=chgtmp+chge
        tchge = chge*chge 
        engsictmp=engsictmp+tchge
        if (insert)then
          qfix_mol(mol)=qfix_mol(mol)+chge
          qfix_mol(maxmls+1)=qfix_mol(maxmls+1)+chge
          engsic(mol)=engsic(mol)+tchge
          engsic(maxmls+1)=engsic(maxmls+1)+tchge
        else if (delete)then
          qfix_mol(mol)=qfix_mol(mol)-chge
          qfix_mol(maxmls+1)=qfix_mol(maxmls+1)-chge
          engsic(mol)=engsic(mol)-tchge
          engsic(maxmls+1)=engsic(maxmls+1)-tchge
        end if
      enddo      
      engsictmp=-r4pie0/epsq*alpha*engsictmp/sqrpi
      
c     calculate and store the exponential factors
     
      i=0
      do k=1,natms
        i=i+1
        elc(i,0)=1.d0
        emc(i,0)=1.d0
        enc(i,0)=1.d0
        els(i,0)=0.d0
        ems(i,0)=0.d0
        ens(i,0)=0.d0
        ssx=rcell(1)*newx(k)+rcell(4)*newy(k)+rcell(7)*newz(k)
        ssy=rcell(2)*newx(k)+rcell(5)*newy(k)+rcell(8)*newz(k)
        ssz=rcell(3)*newx(k)+rcell(6)*newy(k)+rcell(9)*newz(k)
        elc(i,1)=cos(twopi*ssx)
        emc(i,1)=cos(twopi*ssy)
        enc(i,1)=cos(twopi*ssz)
        els(i,1)=sin(twopi*ssx)
        ems(i,1)=sin(twopi*ssy)
        ens(i,1)=sin(twopi*ssz)
      enddo
      limit=i

      do l=2,kmax2
        do i=1,limit
          
           emc(i,l)=emc(i,l-1)*emc(i,1)-ems(i,l-1)*ems(i,1)
           ems(i,l)=ems(i,l-1)*emc(i,1)+emc(i,l-1)*ems(i,1)
        enddo

      enddo

      do l=2,kmax3
       
        do i=1,limit

           enc(i,l)=enc(i,l-1)*enc(i,1)-ens(i,l-1)*ens(i,1)
           ens(i,l)=ens(i,l-1)*enc(i,1)+enc(i,l-1)*ens(i,1)

        enddo

      enddo

c    main loop over k vectors

      kkk=0
      mmin=0
      nmin=1

      do ll=0,kmax1
        l=ll
        tmp=twopi*dble(ll)
        rkx1=tmp*rcell(1)
        rky1=tmp*rcell(4)
        rkz1=tmp*rcell(7)

c    put cos(i,L) terms into cos(i,0) array
 
        if(l.eq.1)then

          do i=1,limit

             elc(i,0)=elc(i,1)
             els(i,0)=els(i,1)

          enddo

        elseif(l.gt.1)then
           do i=1,limit

             cs=elc(i,0)
             elc(i,0)=cs*elc(i,1)-els(i,0)*els(i,1)
             els(i,0)=els(i,0)*elc(i,1)+cs*els(i,1)

           enddo
        endif

        do mm=mmin,kmax2

          m=iabs(mm)
          tmp=twopi*dble(mm)
          rkx2=rkx1+tmp*rcell(2)
          rky2=rky1+tmp*rcell(5)
          rkz2=rkz1+tmp*rcell(8)

          if(mm.ge.0)then
             do i=1,limit

               clm(i)=elc(i,0)*emc(i,m)-els(i,0)*ems(i,m)
               slm(i)=els(i,0)*emc(i,m)+ems(i,m)*elc(i,0)

             enddo
       
          else
             do i=1,limit

               clm(i)=elc(i,0)*emc(i,m)+els(i,0)*ems(i,m)
               slm(i)=els(i,0)*emc(i,m)-ems(i,m)*elc(i,0)

             enddo

          endif
          
          do nn=nmin,kmax3

            n=iabs(nn)

            tmp=twopi*dble(nn)
            rkx3=rkx2+tmp*rcell(3)
            rky3=rky2+tmp*rcell(6)
            rkz3=rkz2+tmp*rcell(9)

c       test magnitude of k vector

            rksq=rkx3*rkx3+rky3*rky3+rkz3*rkz3

            if(rksq.le.rcpct2)then
c       calculate exp(ikr) terms and product with charges
              i=0
              if(nn.ge.0)then
                do k=1,natms
                  i=i+1
                  tchge=atmchg(mol,k)
                  tclm=clm(i)
                  tenc=enc(i,n)
                  tslm=slm(i)
                  tens=ens(i,n)

                  ckc(i)=tchge*(tclm*tenc-tslm*tens)
                  cks(i)=tchge*(tslm*tenc+tclm*tens)
                enddo

              else
                do k=1,natms
                  i=i+1
                  tchge=atmchg(mol,k)
                  tclm=clm(i)
                  tenc=enc(i,n)
                  tslm=slm(i)
                  tens=ens(i,n)

                  ckc(k)=tchge*(tclm*tenc+tslm*tens)
                  cks(k)=tchge*(tslm*tenc-tclm*tens)
                enddo

              endif

c            calculate vector sums

              ckcs=0.d0
              ckss=0.d0

              do i=1,limit
                ckcs=ckcs+ckc(i)
                ckss=ckss+cks(i)
              enddo
              kkk=kkk+1
c             ckcold and cksold are the previous steps' sums
c             these will be manipulated depending on the move.
c             New sums are stored in ckcnew and cksnew in case
c             the move is accepted, then these sums become 
c             ckcsum,and ckssum
              ckcold=ckcsum(maxmls+1,kkk)
              cksold=ckssum(maxmls+1,kkk)
c             insertions will add an additional sum to the existing
c             summation
              if(insert)then
c               update molecule sum, then total sum
                ckcsnew(mol,kkk)=ckcsum(mol,kkk)+ckcs
                ckssnew(mol,kkk)=ckssum(mol,kkk)+ckss
                ckcs=ckcs+ckcold
                ckss=ckss+cksold
                ckcsnew(maxmls+1,kkk)=ckcs
                ckssnew(maxmls+1,kkk)=ckss

c          deletions will subtract the sums of a guest from the
c          existing summation
              elseif(delete)then
c               update molecule sum, then total sum
                ckcsnew(mol,kkk)=ckcsum(mol,kkk)-ckcs
                ckssnew(mol,kkk)=ckssum(mol,kkk)-ckss
                ckcs=ckcold-ckcs
                ckss=cksold-ckss
                ckcsnew(maxmls+1,kkk)=ckcs
                ckssnew(maxmls+1,kkk)=ckss

c          translations will subtract the sums of a guest at it's
c          old position and then add the sums of the new position
              elseif(displace)then
                if(pass.eq.1)then
                  ckcsnew(mol,kkk)=ckcsum(mol,kkk)-ckcs
                  ckssnew(mol,kkk)=ckssum(mol,kkk)-ckss
                  ckcs=ckcold-ckcs
                  ckss=cksold-ckss
                  ckcsnew(maxmls+1,kkk)=ckcs
                  ckssnew(maxmls+1,kkk)=ckss
                elseif(pass.eq.2)then
                  ckcmol2=ckcsnew(mol,kkk)
                  ckcsmol=ckcmol2+ckcs
                  ckcsnew(mol,kkk)=ckcsmol

                  cksmol2=ckssnew(mol,kkk)
                  ckssmol=cksmol2+ckss
                  ckssnew(mol,kkk)=ckssmol
c                  if(abs(ckcsnew(maxmls+1,kkk)).gt.10.d0)then
c                    write(*,*)ckcs,ckcsnew(maxmls+1,kkk)
c                  endif
                  ckcpass2=ckcsnew(maxmls+1,kkk)
                  ckspass2=ckssnew(maxmls+1,kkk)
                  ckcs=ckcpass2+ckcs
                  ckss=ckspass2+ckss
                  ckcsnew(maxmls+1,kkk)=ckcs
                  ckssnew(maxmls+1,kkk)=ckss
                endif
              endif

c             calculation of akk coefficients

              rrksq=1.d0/rksq
              if(lconsw)then
                akk=exp(ralph*rksq)*rrksq
              else
                akk=4.d0*exp(ralph*rksq)*rrksq
              endif

c             accumulate potential energy terms
c             the expression for the energy term has
c             squared values for the above calculated sums
c             the new squared values are subtracted from the
c             old squared values to give the delE for the 
c             reciprocal ewald sums
  
c              if(displace)then
c                if(pass.eq.2)then
c                  engcpe=engcpe+akk*(ckcs*ckcs+ckss*ckss
c     & -ckcold*ckcold-cksold*cksold)
c                endif 
c              else
c              if((displace).and.(pass.eq.1))then
cc              if(insert)then
c                write(*,"(/,a12,a12,a12,a12,/,f12.5,f12.5,f12.5,f12.5
c     &,/)")"ckcsnew","ckssnew","ckcsum","ckssum",
c     &              ckcs,ckss,
c     &              ckcold,cksold
c                write(*,"('ewald1 energy',f12.5,f12.4/)")
c     &              engcpe,akk
c              endif
              engcpe=engcpe+akk*(ckcs*ckcs+ckss*ckss
     & -ckcold*ckcold-cksold*cksold)
c             store sums of all mixtures as well
c              do i=1,maxmls
c                fkk=2.d0*akk
c                if(i.eq.mol)fkk=akk
c                ewald1en(i)=ewald1en(i)+
c     &            fkk*(ckcsnew(i,kkk)*ckcsnew(mol,kkk)+
c     &            ckssnew(i,kkk)*ckssnew(mol,kkk) -
c     &            ckcsum(i,kkk)*ckcsum(mol,kkk) -
c     &            ckssum(i,kkk)*ckssum(mol,kkk))
c                if((i.ne.mol).and.(nummols(i).eq.0))then
c                  write(*,"(/,a12,a12,a12,a12,/,f12.5,f12.5,f12.5,f12.5
c     &,/)")"ckcsnew","ckssnew","ckcsum","ckssum",
c     &              ckcsnew(i,kkk),ckssnew(i,kkk),
c     &              ckcsum(i,kkk),ckssum(i,kkk)
c                  write(*,"('ewald1 energy',f12.5,/)")
c     &              ewald1en(i)
c                endif
c              enddo  

            endif
          
          enddo
          
          nmin=-kmax3
       
        enddo

        mmin=-kmax2
        
      enddo
c     correction for charged systems
      qfix=-(0.5d0*pi*r4pie0/epsq)*(((qfix_mol(maxmls+1)/alpha)**2-
     &     (sumchg/alpha)**2)/volm)
c      write(*,*)qfix
c     add self interaction correction (sic) to the 
c     potential.
c     in most cases lconsw=.true. probably deprecate the
c     lconsw=.false. conditions
      if(lconsw)then
c     the self interaction correction is not needed for
c     translation since it is the same before and after
c     the move 
        if(displace)then 
          if(pass.eq.1)then
            eng1=engcpe
            engcpe=2.d0*rvolm*r4pie0*engcpe/epsq-engsictmp
            ewald1en(maxmls+1)=engcpe
c            do i=1,maxmls
c              if(i.eq.mol)then
c                fkk=0.5d0
c                prev=(qfix_mol(i)+chgtmp)*(qfix_mol(i)+chgtmp)
c                sic=engsictmp
c              else
c                fkk=1.d0
c                prev=(qfix_mol(i)*(qfix_mol(mol)+chgtmp))
c                sic=0.d0
c              endif
c              qfixtmp=-fkk*pi*r4pie0/epsq*
c     &          (qfix_mol(i)*qfix_mol(mol) - prev)/ 
c     &          (alpha*alpha*volm)
c              sic=0.d0
c              qfixtmp=0.d0
c              ewald1en(i) =
c     &2.d0*rvolm*r4pie0*ewald1en(i)/epsq
c     &-sic+qfixtmp
c            enddo
          elseif(pass.eq.2)then
            eng1=engcpe
            engcpe=2.d0*rvolm*r4pie0*engcpe/epsq
            ewald1en(maxmls+1)=engcpe
c            do i=1,maxmls
c              ewald1en(i) =
c     &2.d0*rvolm*r4pie0*ewald1en(i)/epsq
c            enddo
          endif
        elseif(delete)then
          eng1=engcpe
          engcpe=2.d0*rvolm*r4pie0*engcpe/epsq-engsictmp+qfix
          ewald1en(maxmls+1)=engcpe
c          do i=1,maxmls
c            if(i.eq.mol)then
c              fkk=0.5d0
c              prev=(qfix_mol(i)+chgtmp)*(qfix_mol(i)+chgtmp)
c              sic=engsictmp
c            else
c              fkk=1.d0
c              prev=(qfix_mol(i)*(qfix_mol(mol)+chgtmp))
c              sic=0.d0
c            endif
c            qfixtmp=-fkk*pi*r4pie0/epsq*
c     &          (qfix_mol(i)*qfix_mol(mol) - prev)/ 
c     &          (alpha*alpha*volm)
c            qfixtmp=0.d0
c            sic=0.d0
c            ewald1en(i) =
c     &2.d0*rvolm*r4pie0*ewald1en(i)/epsq-sic+qfixtmp
c          enddo
        else
          eng1=engcpe
          engcpe=2.d0*rvolm*r4pie0*engcpe/epsq+engsictmp+qfix
          ewald1en(maxmls+1)=engcpe
c          do i=1,maxmls
c            if(i.eq.mol)then
c              fkk=0.5d0
c              prev=(qfix_mol(i)-chgtmp)*(qfix_mol(i)-chgtmp)
c              sic=engsictmp
c            else
c              fkk=1.d0
c              prev=(qfix_mol(i)*(qfix_mol(mol)-chgtmp))
c              sic=0.d0
c            endif
c            qfixtmp=-fkk*pi*r4pie0/epsq*
c     &          (qfix_mol(i)*qfix_mol(mol) - prev)/ 
c     &          (alpha*alpha*volm)
c            qfixtmp=0.d0
c            sic=0.d0
c            ewald1en(i) =
c     &2.d0*rvolm*r4pie0*ewald1en(i)/epsq+sic+qfixtmp
c          enddo
        endif
      else
        write(*,*)"YOU DONE MESS'D UP!"
      endif

      return
      end subroutine ewald1_guest  

      subroutine ewald1_init
     &(imcon,engcpe,engsicold,mxatm,volm,alpha,sumchg,
     &kmax1,kmax2,kmax3,epsq,newld,maxmls)
c********************************************************************
c                Subroutine to determine the                        *
c                reciprocal part of the ewald                       *
c                sum.                                               *
c********************************************************************
      use utility_pack
      use ewald_module
      implicit none
      logical safe,lconsw
      integer idnode,kmax1,kmax2,kmax3,mxatm,jj
      integer iatm0,iatm1,i,j,limit,l,kkk,nmin,maxmls
      integer mmin,ll,m,mm,n,nn,k,imcon,newld,mol,molidx
      integer mixcount
      real(8) engcpe,volm,epsq,alpha,sumchg,qfix
      real(8) twopi,rvolm,ralph,det,rcpcut,rcpct2,engsicold,ssx
      real(8) sic
      real(8) ssy,ssz,rkx1,rky1,rkz1,cs,tmp,rkx2,rky2,rkz2
      real(8) rkx3,rky3,rkz3,rksq,tchge,tclm,tenc,tslm,tens
      real(8) ckcs,ckss,rrksq,fkk,akk,bkk,akv,eng1
      real(8), dimension(10) :: buffer
      real(8), dimension(9) :: rcell


      data safe/.true./,lconsw/.true./
      twopi=2.d0*pi
c    initialize the coulombic potential energy
      ckcsum=0.d0
      ckssum=0.d0
      engcpe=0.d0
      jj=0
c    working parameters

      rvolm=twopi/volm
      ralph=-0.25d0/alpha**2

c    Note boundary conditions for different types of cells
      if(imcon.eq.4.or.imcon.eq.5.or.imcon.eq.7)then
         rvolm=0.5d0*rvolm
         lconsw=.false.
      endif

      call invert(cell,rcell,det)
      
      call dcell(rcell,buffer)
 
      rcpcut=min(dble(kmax1)*buffer(7),dble(kmax2)*buffer(8),
     & dble(kmax3)*buffer(9))
      rcpcut=rcpcut*1.05d0*twopi
      rcpct2=rcpcut**2 

c     the self interaction correction in real space
c     we can optimize the ewald at each step if we
c     dont re-calculate this each time.  insertions
c     and deletions would cause difficulty..
      engsicold=0.d0
      qfix_mol(:)=0.d0
      engsic(:)=0.d0
      do n=1,mxatm
        mol=moltype(n)
        tchge=atmcharge(n)**2
        engsicold=engsicold+tchge
        engsic(mol)=engsic(mol)+tchge
        engsic(maxmls+1)=engsic(maxmls+1)+tchge
        qfix_mol(mol)=qfix_mol(mol)+atmcharge(n)
        qfix_mol(maxmls+1)=qfix_mol(maxmls+1)+atmcharge(n)
      enddo      
      engsicold=-r4pie0/epsq*alpha*engsicold/sqrpi
c     calculate and store the exponential factors

      i=0
      do k=1,mxatm
          i=i+1
          elc(i,0)=1.d0
          emc(i,0)=1.d0
          enc(i,0)=1.d0
          els(i,0)=0.d0
          ems(i,0)=0.d0
          ens(i,0)=0.d0
          ssx=rcell(1)*xxx(k)+rcell(4)*yyy(k)+rcell(7)*zzz(k)
          ssy=rcell(2)*xxx(k)+rcell(5)*yyy(k)+rcell(8)*zzz(k)
          ssz=rcell(3)*xxx(k)+rcell(6)*yyy(k)+rcell(9)*zzz(k)
          elc(i,1)=cos(twopi*ssx)
          emc(i,1)=cos(twopi*ssy)
          enc(i,1)=cos(twopi*ssz)
          els(i,1)=sin(twopi*ssx)
          ems(i,1)=sin(twopi*ssy)
          ens(i,1)=sin(twopi*ssz)
      enddo
      limit=i

      do l=2,kmax2
        
        do i=1,limit
          
           emc(i,l)=emc(i,l-1)*emc(i,1)-ems(i,l-1)*ems(i,1)
           ems(i,l)=ems(i,l-1)*emc(i,1)+emc(i,l-1)*ems(i,1)

        enddo

      enddo

      do l=2,kmax3
       
        do i=1,limit

           enc(i,l)=enc(i,l-1)*enc(i,1)-ens(i,l-1)*ens(i,1)
           ens(i,l)=ens(i,l-1)*enc(i,1)+enc(i,l-1)*ens(i,1)

        enddo

      enddo

c    main loop over k vectors

      kkk=0
      mmin=0
      nmin=1

      do ll=0,kmax1

        l=ll
        tmp=twopi*dble(ll)
        rkx1=tmp*rcell(1)
        rky1=tmp*rcell(4)
        rkz1=tmp*rcell(7)

c    put cos(i,L) terms into cos(i,0) array
 
        if(l.eq.1)then

          do i=1,limit

             elc(i,0)=elc(i,1)
             els(i,0)=els(i,1)

          enddo

        elseif(l.gt.1)then
           do i=1,limit

             cs=elc(i,0)
             elc(i,0)=cs*elc(i,1)-els(i,0)*els(i,1)
             els(i,0)=els(i,0)*elc(i,1)+cs*els(i,1)

           enddo
        endif

        do mm=mmin,kmax2

          m=iabs(mm)
          tmp=twopi*dble(mm)
          rkx2=rkx1+tmp*rcell(2)
          rky2=rky1+tmp*rcell(5)
          rkz2=rkz1+tmp*rcell(8)

          if(mm.ge.0)then
             do i=1,limit

               clm(i)=elc(i,0)*emc(i,m)-els(i,0)*ems(i,m)
               slm(i)=els(i,0)*emc(i,m)+ems(i,m)*elc(i,0)

             enddo
       
          else
             do i=1,limit

               clm(i)=elc(i,0)*emc(i,m)+els(i,0)*ems(i,m)
               slm(i)=els(i,0)*emc(i,m)-ems(i,m)*elc(i,0)

             enddo

          endif
          
          do nn=nmin,kmax3

            n=iabs(nn)

            tmp=twopi*dble(nn)
            rkx3=rkx2+tmp*rcell(3)
            rky3=rky2+tmp*rcell(6)
            rkz3=rkz2+tmp*rcell(9)

c       test magnitude of k vector

            rksq=rkx3*rkx3+rky3*rky3+rkz3*rkz3

            if(rksq.le.rcpct2)then
c       calculate exp(ikr) terms and product with charges
              i=0
              if(nn.ge.0)then
                do k=1,mxatm
                  i=i+1
                  tchge=atmcharge(i)
                  tclm=clm(i)
                  tenc=enc(i,n)
                  tslm=slm(i)
                  tens=ens(i,n)

                  ckc(i)=tchge*(tclm*tenc-tslm*tens)
                  cks(i)=tchge*(tslm*tenc+tclm*tens)
                enddo

              else
                do k=1,mxatm
                  i=i+1
                  tchge=atmcharge(i)
                  tclm=clm(i)
                  tenc=enc(i,n)
                  tslm=slm(i)
                  tens=ens(i,n)

                  ckc(i)=tchge*(tclm*tenc+tslm*tens)
                  cks(i)=tchge*(tslm*tenc-tclm*tens)

                enddo

              endif

c            calculate vector sums

              ckcs=0.d0
              ckss=0.d0

              kkk=kkk+1
              do i=1,limit
                ckcs=ckcs+ckc(i)
                ckss=ckss+cks(i)
                mol=moltype(i)
c               store individual molecule sums
                ckcsum(mol,kkk) = ckcsum(mol,kkk) + ckc(i)
                ckssum(mol,kkk) = ckssum(mol,kkk) + cks(i)
              enddo
c             store total energy sums in the last index
              ckcsum(maxmls+1,kkk)=ckcs
              ckssum(maxmls+1,kkk)=ckss

c             calculation of akk coefficients

              rrksq=1.d0/rksq
              if(lconsw)then
                akk=exp(ralph*rksq)*rrksq
              else
                akk=4.d0*exp(ralph*rksq)*rrksq
              endif

c             accumulate potential energy terms
              engcpe=engcpe+akk*(ckcs*ckcs+ckss*ckss)
              ewald1en(maxmls+1)=engcpe

c             store sums of all mixtures as well
              do i=1,maxmls
                fkk=2.d0*akk
                do j=i,maxmls
                  if(i.eq.j)fkk=akk
                  ewald1en(i)=ewald1en(i) +
     &              fkk*(ckcsum(i,kkk)*ckcsum(j,kkk) 
     &              + ckssum(i,kkk)*ckssum(j,kkk))
                  ewald1en(j)=ewald1en(j) +
     &              fkk*(ckcsum(i,kkk)*ckcsum(j,kkk) 
     &              + ckssum(i,kkk)*ckssum(i,kkk))
                  
                enddo
              enddo  

            endif
          
          enddo
          
          nmin=-kmax3
       
        enddo

        mmin=-kmax2
        
      enddo
      newld=jj

      qfix=-(0.5d0*pi*r4pie0/epsq)*((sumchg/alpha)**2/volm)
c     add self interaction correction (sic) to the 
c     potential.
      if(lconsw)then 
        eng1=engcpe
        engcpe=2.d0*rvolm*r4pie0*engcpe/epsq+engsicold+qfix
        ewald1en(maxmls+1)=engcpe
        do i=1,maxmls
          fkk=1.d0
          sic=-r4pie0/epsq*alpha*engsic(i)/sqrpi
          do j=i,maxmls
            if(i.eq.j)fkk=0.5d0
c            sic=sic- 
c     &        ((fkk*pi*r4pie0/epsq)*qfix_mol(i)*qfix_mol(j)/
c     &        (alpha*alpha*volm))
          enddo
          ewald1en(i)=2.d0*rvolm*r4pie0*ewald1en(i)/epsq+sic
        enddo
      else
        eng1=engcpe
        engcpe=rvolm*r4pie0*engcpe/epsq+engsicold+qfix
        ewald1en(maxmls+1)=engcpe
        do i=1,maxmls
          fkk=1.d0
          sic=-r4pie0/epsq*alpha*engsic(i)/sqrpi
          do j=i,maxmls
            if(i.eq.j)fkk=0.5d0
c            sic=sic-
c     &        ((fkk*pi*r4pie0/epsq)*qfix_mol(i)*qfix_mol(j)/
c     &        (alpha*alpha*volm))
          enddo
          ewald1en(i) =rvolm*r4pie0*ewald1en(i)/epsq+sic
        enddo
      endif
      return
      end subroutine ewald1_init

      subroutine ewald2(chg,natm,engcpe,mol,maxmls,
     &drewd,rcut,epsq)
c********************************************************************
c                Subroutine to determine the                        *
c                real part of the ewald                             *
c                sum.                                               *
c********************************************************************
      use ewald_module
      use utility_pack

      implicit none
      integer m,n,i,ik,jatm,natm,ll,l1,l2,mol,idxij
      integer jmol,maxmls
      real(8) engcpe,drewd,epsq,rcut
      real(8) rcsq,rdrewd,chgea,chg
      real(8) chgprd,rsq,rrr,ppp,vk0,vk1,vk2,t1,t2,erfcr
c     cutoff condition for pair forces
      rcsq=rcut**2 
c     reciprocal of interpolation interval
      rdrewd=1.d0/drewd
      engcpe=0.d0
c     altered this from atmcharge(iatm) to just chg for the 
c     gcmc sim.  
      chgea=chg/epsq*r4pie0
      ik=0

      do i=1,natm
c     atomic index and charge product.

        jatm=ilist(i)
c     ilist is a list of neighbour atoms from a neighbour list
        jmol=moldf(i)
         
        ik=ik+1
        chgprd=chgea*atmcharge(jatm) 
c     if chgprd is zero, ignore
        if(abs(chgprd).gt.1.d-10)then
           rsq=rsqdf(i)
           if(rcsq.gt.rsq)then
             rrr=sqrt(rsq)

             ll=int(rrr*rdrewd)
             l1=ll+1
             l2=ll+2
             ppp=rrr*rdrewd-dble(ll)
c     calculate interaction energy using 3-point interpolation
              
             vk0=erc(ll)
             vk1=erc(l1)
             vk2=erc(l2)

             t1=vk0+(vk1-vk0)*ppp
             t2=vk1+(vk2-vk1)*(ppp-1.0d0)
             erfcr=(t1+(t2-t1)*ppp*0.5d0)*chgprd
c     separate guest-framwork interactions for Hconst.
             engcpe=engcpe+erfcr
c             write(*,*)engcpe
             ewald2en(mol)=ewald2en(mol)+erfcr
             if(jmol.ne.mol)ewald2en(jmol)=ewald2en(jmol)+erfcr

            endif

         endif
  
      enddo
      ewald2en(maxmls+1)=ewald2en(maxmls+1)+engcpe
      return

      end subroutine ewald2


      subroutine ewald3(chg,mol,natms,alpha,engcpe,epsq)
c********************************************************************
c                Subroutine to calculate the                        *
c                correction terms for excluded                      *
c                atoms                                              *
c********************************************************************
      use ewald_module
      use utility_pack
      implicit none

      integer jatm,natms,m,mol,imol

      real(8) engcpe,epsq,a1,a2,a3,alpha,chg
      real(8) a4,a5,pp,rr3,r10,r42,r216,chgea,chgprd,rrr,rsq,alpr
      real(8) alpr2,erfr,egamma,tt,exp1


      data a1,a2,a3/0.254829592d0,-0.284496736d0,1.421413741d0/
      data a4,a5,pp/-1.453152027d0,1.061405429d0,0.3275911d0/
      data rr3/0.333333333333d0/,r10/0.1d0/,r42/0.02380952381d0/
      data r216/4.62962962963d-3/

      engcpe=0.d0

      chgea=chg/epsq*r4pie0

c     this is a list of all atoms in other lists which we do not
c     want to calculate the electrostatic interaction with
      do m=1,natms

        jatm=jlist(m)
        imol=moldf(m)
        chgprd=chgea*atmchg(mol,jatm)
c       calculate interatomic distance

        rsq=xdf(m)**2+ydf(m)**2+zdf(m)**2

        rrr=sqrt(rsq)
        alpr=rrr*alpha
        alpr2=alpr*alpr
        
        if(alpr.lt.1.d-2)then

          erfr=2.d0*chgprd*(alpha/sqrpi)*
     &         (1.d0+alpr2*(-rr3+alpr2*(r10+alpr2*(-r42+alpr2*r216))))

        else
          tt=1.d0/(1.d0+pp*alpha*rrr)
          exp1=exp(-(alpha*rrr)**2)
          erfr=(1.d0-tt*(a1+tt*(a2+tt*(a3+tt*(a4+tt*a5))))*exp1)*
     &          chgprd/rrr
        endif
        engcpe=engcpe-erfr
        ewald3spe(imol)=ewald3spe(imol)-erfr
        if(imol.ne.mol)ewald3spe(mol)=ewald3spe(mol)-erfr
      
      enddo

      return
      end subroutine ewald3
