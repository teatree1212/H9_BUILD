!=====================================================================!
PROGRAM H9_BUILD
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Use this code to build the approaches to be used in HYBRID9.
! First work up the soil hydrology for a single site.
! All quantities are positive upwards where relevant to conform to the
! CLM technical description Olesen et al. (2013) (e.g. Eqn. 7.79).
! O13 refers to Olesen et al. (2013).
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
IMPLICIT NONE
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
INTEGER :: I ! Soil layer index (n).
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Layer index of first unsaturated layer from surface (n).
!---------------------------------------------------------------------!
INTEGER :: iwt
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Integration timestep (s).
!---------------------------------------------------------------------!
!REAL :: dt = 86400.0 / 48.0
REAL :: dt = 86400.0 / 96.0
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Number of ground layers (n).
!---------------------------------------------------------------------!
INTEGER, PARAMETER :: Nlevgrnd = 15
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Number of soil layers (n).
!---------------------------------------------------------------------!
INTEGER, PARAMETER :: Nlevsoi = 10
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Percentage sand, clay (%age).
!---------------------------------------------------------------------!
REAL, PARAMETER :: pc_sand = 33.0
REAL, PARAMETER :: pc_clay = 33.0
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Temporary variables.
!---------------------------------------------------------------------!
REAL :: tempi,temp0,theta_e1,voleq1 ! Equlibrium water profile.
REAL :: s1,s2                       ! Hydraulic conductivity.
REAL :: den,dpsie,num,qin(1:Nlevsoi+1),qout(1:Nlevsoi+1),psi1
!---------------------------------------------------------------------!
! Water head at water table depth (mm).
REAL :: wh_zwt
REAL :: ka,wh,qcharge

!---------------------------------------------------------------------!
! Restriction for min of soil matric potential (mm). Value taken from O13
! Eqn. 7.134.
!---------------------------------------------------------------------!
REAL, PARAMETER :: psi_min = -1.0E08
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Scaling factor for soil layer depths (Eqn. 6.5).
!---------------------------------------------------------------------!
REAL, PARAMETER :: fs = 0.025
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Temporary variables for tridiagonal computations.
!---------------------------------------------------------------------!
REAL :: BET,GAM(Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Soil layer centre heights, positive downwards from surface (mm).
!---------------------------------------------------------------------!
REAL :: z (1:Nlevgrnd)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Soil layer interface depths, positive downwards from surface (mm).
!---------------------------------------------------------------------!
REAL :: zi (0:Nlevgrnd)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Soil layer thickneses (mm).
!---------------------------------------------------------------------!
REAL :: dz (1:Nlevgrnd)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Primary state variable is volumetric soil water content (mm^3 mm^-3).
!---------------------------------------------------------------------!
REAL :: theta (1:Nlevsoi+1)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Equilibrium soil volumetric water content (mm^3 mm^-3).
!---------------------------------------------------------------------!
REAL :: theta_e (1:Nlevsoi+1)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Fraction of water that is frozen in layer (fraction).
!---------------------------------------------------------------------!
REAL :: f_frz (1:Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Matric potentials in soil layers (mm).
!---------------------------------------------------------------------!
REAL :: psi (1:Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Equilibrium matric potentials in soil layers (mm).
!---------------------------------------------------------------------!
REAL :: psi_e (1:Nlevsoi+1)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Hydraulic conductivities at layer interfaces (mm s^-1).
!---------------------------------------------------------------------!
REAL :: k (1:Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Water fluxes at layer interfaces, positive upwards (mm s-1).
! Index refers to bottom of layer.
!---------------------------------------------------------------------!
REAL :: q (Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Time derivatives of thetas (mm^3 mm^-3 s^-1).
!---------------------------------------------------------------------!
REAL :: dtheta (1:Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Soil Matric Potential derivatives. (?Vector of O13 Eqn. 7.121-123 values.
!---------------------------------------------------------------------!
REAL :: dpdth (1:Nlevsoi+1)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Hydraulic conductivity derivatives. (?Vector of O13 Eqn. 7.124 values.
!---------------------------------------------------------------------!
REAL :: dkdth (1:Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Vector of O13 Eqn. 7.118, 7.119, 7.120 values.
!---------------------------------------------------------------------!
REAL :: dqidth0(1:Nlevsoi+1),dqidth1(1:Nlevsoi+1)
REAL :: dqodth1(1:Nlevsoi+1),dqodth2(1:Nlevsoi+1)
REAL :: dpdth1
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Timestep index.
!---------------------------------------------------------------------!
INTEGER :: iTIME
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Water infiltration into surface soil layer (mm s^-1).
!---------------------------------------------------------------------!
REAL :: q_infl
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Water table depth, positive downwards (mm).
!---------------------------------------------------------------------!
REAL :: zwt
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Saturated matric potential (mm).
!---------------------------------------------------------------------!
REAL :: psi_sat (1:Nlevsoi+1)
!---------------------------------------------------------------------!

REAL :: sucsat (1:Nlevsoi)

!---------------------------------------------------------------------!
! Saturated water content (mm).
!---------------------------------------------------------------------!
REAL :: theta_sat (1:Nlevsoi+1)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Saturated hydraulic conductivity (mm s^-1).
!---------------------------------------------------------------------!
REAL :: k_sat (1:Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Clapp and Hornberger (1978) parameter.
!---------------------------------------------------------------------!
REAL :: B (1:Nlevsoi)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Water saturation fraction (fraction).
!---------------------------------------------------------------------!
REAL :: wv
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Tridiagonal coefficients.
!---------------------------------------------------------------------!
REAL :: A_t(1:Nlevsoi+1),B_t(1:Nlevsoi+1),C_t(1:Nlevsoi+1)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Tridiagonal solutions.
!---------------------------------------------------------------------!
REAL :: R(1:Nlevsoi+1)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
WRITE (*,*) 'Starting...'
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! File for diagnostics.
!---------------------------------------------------------------------!
OPEN (10, FILE = 'water.out', STATUS = 'UNKNOWN')
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Write diagnostics file header.
!---------------------------------------------------------------------!
WRITE (10,*) 'I l1 l2 l3 l4 l5 l6 l7 l8'
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Just hack for now. Work up later. Variabled used in O13 Eqn. 7.124.
! Assuming is fraction of water that is frozen in layer.
!---------------------------------------------------------------------!
f_frz (I) = 0.0
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Define soil layer interface depths, positive downwards from surface
! (mm). Also compute layer thicknesses and layer centres (mm).
!---------------------------------------------------------------------!
zi (0) = 0.0
zi (1) = 50.0
dz (1) = zi (1) - zi (0)
z (1)  = zi (0) + dz (1) / 2.0
!---------------------------------------------------------------------!
DO I = 2, Nlevsoi
  zi (I) = zi (I-1) + 100.0
  dz (I) = zi (I) - zi (I-1)
  z (I)  = zi (I-1) + dz (I) / 2.0
END DO
!---------------------------------------------------------------------!
! Soil layer node depths Eqn 6.5 (m).
! Will have to be modified if move to n=15 for heat.
!---------------------------------------------------------------------!
DO I = 1, Nlevgrnd
  z (I) = 1.0E3 * fs * (EXP (0.5 * (I - 0.5)) - 1.0)
  WRITE(*,*) 'z', z (I)
END DO
!---------------------------------------------------------------------!
! Soil layer thicknesses from Eqn. 6.6.
!---------------------------------------------------------------------!
dz (1) = 0.5 * (z (1) + z (2))
DO I = 2, Nlevgrnd-1
  dz (I) = 0.5 * (z (I+1) - z (I-1))
END DO
dz (Nlevgrnd) = z (Nlevgrnd) - z (Nlevgrnd-1)
! Soil layer interface depths (mm).
zi (0) = 0.0
DO I = 1, Nlevgrnd-1
  zi (I) = 0.5 * (z (I) + z (I+1))
END DO
zi (Nlevgrnd) = z (Nlevgrnd) + 0.5 * dz (Nlevgrnd)
!---------------------------------------------------------------------!
write (*,*) 'z', z(1:Nlevgrnd)
write (*,*)
write (*,*) 'dz', dz (1:Nlevgrnd)
write (*,*)
write (*,*) 'zi' ,zi (1:Nlevgrnd)
!---------------------------------------------------------------------!

!---------------------------------------------------------------------!
! Saturated matric potential from Eqn. 7.96 of O13 (mm).
!---------------------------------------------------------------------!
psi_sat (:) = -10.0 * (10.0 ** (1.88 - 0.0131 * pc_sand))
!---------------------------------------------------------------------!
write (*,*) 'psi_sat',psi_sat(:)

!---------------------------------------------------------------------!
! Water content at saturation from Eqn. 7.91 of O13 (mm).
!---------------------------------------------------------------------!
theta_sat (:) = 0.489 - 0.00126 * pc_sand
!---------------------------------------------------------------------!
write (*,*) 'theta_sat',theta_sat(:)

!---------------------------------------------------------------------!
! Saturated hydraulic conductivity from Eqn. 7.99 of O13 (mm s-1).
!---------------------------------------------------------------------!
k_sat (:) = 0.0070556 * 10.0 ** (-0.884 + 0.0153 * pc_sand)
!---------------------------------------------------------------------!
write (*,*) 'k_sat',k_sat(:)

!---------------------------------------------------------------------!
! Clapp and Hornberger parameter from Eqn. 7.93 of O13.
!---------------------------------------------------------------------!
B (:) = 2.91 + 0.159 * pc_clay
!---------------------------------------------------------------------!
write (*,*) 'B',B(:)

!---------------------------------------------------------------------!
! Initialise thetas (mm^3 mm^-3).
!---------------------------------------------------------------------!
theta (:) = theta_sat (:) * 0.1
!---------------------------------------------------------------------!
write (*,*) 'theta'
write (*,*) theta(:)

DO iTIME = 1, 510*3

  write (*,*) iTIME,'************************************'

  !-------------------------------------------------------------------!
  ! Water infiltration into surface soil layer (mm s^-1).
  !-------------------------------------------------------------------!
  q_infl = 5.0 / 86400.0
  !-------------------------------------------------------------------!

  !-------------------------------------------------------------------!
  ! Depth of water table (mm).
  !-------------------------------------------------------------------!
  zwt = 5000.0 !???????
  !-------------------------------------------------------------------!

  !-------------------------------------------------------------------!
  ! The layer index of the first unsaturate layer (i.e. the layer right
  ! above the water table (from CESM).
  !-------------------------------------------------------------------!
  iwt = Nlevsoi
  DO I = 1, Nlevsoi
    IF (zwt <= z (I)) THEN
      iwt = I - 1
      EXIT
    END IF
  END DO
  !-------------------------------------------------------------------!

  !-------------------------------------------------------------------!
  ! Equilibrium water content based on water table depth (from CESM).
  !-------------------------------------------------------------------!
  DO I = 1, Nlevsoi
    IF (zwt <= zi (I-1)) THEN
      !---------------------------------------------------------------!
      ! Full saturated when water table is above the layer's top
      ! (mm^3 mm^-3).
      !---------------------------------------------------------------!
      theta_e (I) = theta_sat (I)
      !---------------------------------------------------------------!
    ELSE IF ((zwt < zi (I)) .AND. (zwt > zi (I-1))) THEN
      !---------------------------------------------------------------!
      ! Water table top is within the layer. Use weighted average of
      ! saturated part (depth > wtd) and the equilibrium solution for
      ! the rest of the layer.
      !---------------------------------------------------------------!
      tempi = 1.0
      temp0 = (((-psi_sat (I) + zwt - zi (I-1)) / (-psi_sat (I)))) &
              ** (1.0 - 1.0 / B (I)) ! Eqn. 7.127
      voleq1 = psi_sat (I) * theta_sat (I) / &
               (1.0 - 1.0 / B (I)) / &
               (zwt - zi (I-1)) * (tempi - temp0)
      theta_e (I) = (voleq1 * (zwt - zi (I-1)) + &
                    theta_sat (I) * (zi (I) - zwt))/ &
                    (zi (I) - zi (I-1)) !Eqn. 7.127
      theta_e (I) = MIN (theta_sat (I), theta_e (I))
      theta_e (I) = MAX (theta_e (I), 0.0)
      !---------------------------------------------------------------!
    ELSE
      !---------------------------------------------------------------!
      ! Water table is below soil column. Taken from CESM code, based
      ! on O13 Eqn. 7.129.
      !---------------------------------------------------------------!
      tempi = (((-psi_sat (I) + zwt - zi (I)) / (-psi_sat (I)))) ** &
              (1.0 - 1.0 / B (I))
      temp0 = (((-psi_sat (I) + zwt - zi (I - 1)) / (-psi_sat (I)))) ** &
              (1.0 - 1.0 / B (I)) ! Eqn. 7.127
      theta_e (I) = psi_sat (I) * theta_sat (I) / (1.0 - 1.0 / B (I)) &
                    / (zi (I) - zi (I-1)) * (tempi - temp0)
      theta_e (I) = MAX (theta_e (I),0.0)
      theta_e (I) = MIN (theta_sat (I), theta_e (I))
      !---------------------------------------------------------------!
    END IF
    !-----------------------------------------------------------------!
    ! Equilibrium matric potential, from CESM, based on
    ! O13 Eqn. 7.134 (mm).
    !-----------------------------------------------------------------!
    psi_e (I) = psi_sat (I) * (MAX (theta_e (I) / theta_sat (I), &
                0.01)) ** (-B (I))
    psi_e (I) = MAX (psi_min, psi_e (I))
    !-----------------------------------------------------------------!
  END DO ! I = 1, Nlevsoi
  !-------------------------------------------------------------------!

  !-------------------------------------------------------------------!
  ! Equlibrium matric potential in aquifer layer.
  ! If water table is below soil column calculate psi_e for the 11th layer
  !-------------------------------------------------------------------!
  I = Nlevsoi
  IF (iwt == Nlevsoi) then
    tempi = 1.0
    temp0 = (((-psi_sat (I) + zwt - &
            zi (I)) / (-psi_sat(I)))) ** (1.0 - 1.0 / B (I))
    theta_e (I+1) = psi_sat (I) * theta_sat (I) / &
                    (1.0 - 1.0 / B (I)) / (zwt - zi (I)) * &
                    (tempi - temp0)
    theta_e (I+1) = MAX (theta_e (I+1), 0.0)
    theta_e (I+1) = MIN (theta_sat (I), theta_e (I+1))
    psi_e (I+1) = psi_sat (I) * (MAX (theta_e (I+1) / &
                  theta_sat (I), 0.01)) ** (-B (I))
    psi_e (I+1) = MAX (psi_min, psi_e (I+1))
  end if
  !-------------------------------------------------------------------!
write (*,*) 'theta_e'
write (*,*) theta_e(:)
write (*,*) 'psi_e'
write (*,*) psi_e(:)

  !-------------------------------------------------------------------!
  DO I = 1, Nlevsoi
    !-----------------------------------------------------------------!
    ! Hydraulic conductivity based on liquid water content only.
    ! From CESM, based on O13 Eqn. 7.89.
    !-----------------------------------------------------------------!
    ! Eqn for s1 is a term which is part of Eqn. 7.125
    s1 = 0.5 * (theta (I)     + theta     (MIN(Nlevsoi,I+1))) / &
        (0.5 * (theta_sat (I) + theta_sat (MIN(Nlevsoi,I+1))))
    s1 = MIN (1.0, s1)
    ! Eqn for s2 is a term which is part of Eqn. 7.125
    s2 = k_sat (I) * s1 ** (2.0 * B (I) + 2.0)
    !-----------------------------------------------------------------!
    ! Hydraulic conductivity (mm s^-1). Need to add ice impedence.
    !-----------------------------------------------------------------!
    k (I) = s1 * s2
    !-----------------------------------------------------------------!
    ! Change in hydraulic conductivity O13 Eqn. 7.125.
    !-----------------------------------------------------------------!
    dkdth (I) = (2.0 * B (I) + 3.0) * s2 * &
                (1.0 / (theta_sat (I) + theta_sat (MIN (Nlevsoi,I+1))))
write (*,*) 'dkdth- change in hydraulic conductivity'
write (*,*)  dkdth (:)
    !-----------------------------------------------------------------!
    ! Matric potentials and dervative.
    !-----------------------------------------------------------------!
    wv = MAX (theta (I) / theta_sat (I), 0.01)
    wv = MIN (1.0, wv)
    psi (I) = psi_sat (I) * wv ** (-B (I))
    psi (I) = MAX (psi_min, psi (I))
write (*,*) 'wv',wv,'theta',theta(I),'psi',psi(I)
    dpdth (I) = -B (I) * psi (I) / (wv * theta_sat (I)) !Eqn. 7.122
  END DO
  !-------------------------------------------------------------------!
write (*,*) 'dpdth- change in soil matric potential'
write (*,*) dpdth(:)

  !-------------------------------------------------------------------!
  ! aquifer (11th) layer
  !-------------------------------------------------------------------!
  z (Nlevsoi+1) = 0.5 * (1.0 * zwt + z (Nlevsoi))
  IF (iwt < Nlevsoi) THEN
    dz (Nlevsoi + 1) = dz (Nlevsoi)
  ELSE
    dz (Nlevsoi + 1) = (1.0 * zwt - z (Nlevsoi))
  END IF
  !-------------------------------------------------------------------!

  !-------------------------------------------------------------------!
  ! Set up R, A_t, B_t, and C_t vectors for tridiagonal solution.
  !-------------------------------------------------------------------!
  I = 1
  qin (I) = q_infl
  den      = (z       (I+1) - z       (I))
  dpsie    = (psi_e (I+1) - psi_e (I))
  num      = (psi (I+1) - psi (I)) - dpsie
  qout (I) = -k (I) * num / den
  dqodth1 (I) = -(-k (I) * dpdth (I)   + num * dkdth (I)) / den
  dqodth2 (I) = -( k (I) * dpdth (I+1) + num * dkdth (I)) / den
  R   (I) =  qin (I) - qout (I)  ! Eqn. 7.139
  A_t (I) =  0.0 !  Eqn 7.136
  B_t (I) =  dz (I) / dt + dqodth1 (I)  ! Eqn 7.137
  C_t (I) =  dqodth2 (I) !  Eqn 7.138
  !-------------------------------------------------------------------!
  DO I = 2, Nlevsoi - 1
    den     = (z (I) - z (I-1))
    dpsie   = (psi_e (I) - psi_e (I-1))
    num     = (psi (I) - psi (I-1)) - dpsie
    qin (I) = -k (I-1) * num / den
    dqidth0 (I) = -(-k (I-1) * dpdth (I-1) + num * dkdth (I - 1)) / den
    dqidth1 (I) = -( k (I-1) * dpdth (I)   + num * dkdth (I - 1)) / den
    den    = (z (I+1) - z (I))
    dpsie  = (psi_e (I+1) - psi_e (I))
    num    = (psi (I + 1) - psi (I)) - dpsie
    qout (I)   = -k (I) * num / den
    dqodth1 (I) = -(-k (I) * dpdth (I)   + num * dkdth (I)) / den
    dqodth2 (I) = -( k (I) * dpdth (I+1) + num * dkdth (I)) / den
    R   (I)    =  qin (I) - qout (I)
    A_t (I)    = -dqidth0 (I)
    B_t (I)    =  dz (I) / dt - dqidth1 (I) + dqodth1 (I)
    C_t (I)    =  dqodth2 (I)
  END DO
  !-------------------------------------------------------------------!
  I = Nlevsoi
  !-------------------------------------------------------------------!
  IF (I > iwt) THEN ! Water table is in soil column (Section 7.4.2.4)
    den    = (z (I) - z (I-1))
    dpsie  = (psi_e (I) - psi_e (I-1))
    num    = (psi (I) - psi (I-1)) - dpsie
    qin (I)   = -k (I-1) * num / den
    dqidth0 (I) = -(-k (I-1) * dpdth(I-1) + num * dkdth (I-1)) / den
    dqidth1 (I) = -( k (I-1) * dpdth(I)   + num * dkdth (I-1)) / den
    qout    (I) =  0.0
    dqodth1 (I) =  0.0
    R (I)   =  qin (I) - qout (I)
    A_t (I) = -dqidth0 (I)
    B_t (I) =  dz (I) / dt - dqidth1 (I) + dqodth1 (I)
    C_t (I) =  0.0
    ! Next set up aquifer layer; hydrologically inactive
    R   (I+1) = 0.0
    A_t (I+1) = 0.0
    B_t (I+1) = dz (I+1) / dt
    C_t (I+1) = 0.0
  ELSE ! water table is below soil column
    ! Compute aquifer soil moisture as average of layer 10 and saturation
    wv = MAX (0.5 * (1.0 + theta (I) / theta_sat (I)), 0.01)
    wv = MIN (1.0, wv)
    ! compute psi for aquifer layer
    psi1 = psi_sat (I) * wv ** (-B (I))
    psi1 = MAX (psi_min, psi1)
    ! compute dpdth for aquifer layer
    dpdth1 = -B (I) * psi1 / (wv * theta_sat (I))
    ! first set up bottom layer of soil column
    den   = (z (I) - z (I-1))
    dpsie = (psi_e (I) - psi_e (I-1))
    num   = (psi (I) - psi (I-1)) - dpsie
    qin (I)    = -k (I-1) * num / den
    dqidth0 (I) = -(-k (I-1) * dpdth (I-1) + num * dkdth (I-1)) / den
    dqidth1 (I) = -( k (I-1) * dpdth (I)   + num * dkdth (I-1)) / den
    den   = (z (I+1) - z (I))
    dpsie = (psi_e (I+1) - psi_e (I))
    num   = (psi1 - psi (I)) - dpsie
    qout (I)   = -k (I)*num/den
    dqodth1 (I) = -(-k (I) * dpdth (I) + num * dkdth (I)) / den
    dqodth2 (I) = -( k (I) * dpdth1    + num * dkdth(I)) / den
    R   (I) =  qin (I) - qout (I)
    A_t (I) = -dqidth0 (I)
    B_t (I) =  dz (I) / dt - dqidth1 (I) + dqodth1 (I)
    C_t (I) =  dqodth2 (I)
    ! next set up aquifer layer; den/num unchanged, qin=qout
    qin (I+1)    = qout (I)
    dqidth0 (I+1) = -(-k (I) * dpdth (I) + num * dkdth (I)) / den
    dqidth1 (I+1) = -( k (I) * dpdth1    + num * dkdth (I)) / den
    qout    (I+1) = 0.0  ! zero-flow bottom boundary condition
    dqodth1 (I+1) = 0.0  ! zero-flow bottom boundary condition
    R   (I+1) =  qin (I+1) - qout (I+1)
    A_t (I+1) = -dqidth0 (I+1)
    B_t (I+1) =  dz (I+1) / dt - dqidth1 (I+1) + dqodth1 (I+1)
    C_t (I+1) =  0.0
  END IF
  !-------------------------------------------------------------------!
!write (*,*) R(:),A_t(:),B_t(:),C_t(:)
  !-------------------------------------------------------------------!
  ! Solve for dwat.
  !-------------------------------------------------------------------!

  ! Solve the tridiagonal system of equations.

  !forward elimination
  ! in the first layer I=1,  A_t = 0, whch is why in layer I=1, BET =B_t(1)
  ! this also leads to the first dtheta being R(1)/ denom

  DO I = 1, Nlevsoi+1
  BET = B_t (I) + A_t (I) * GAM (I-1)
  GAM (I)= - C_t(I) / BET
  dtheta(I)= (R(I) - A_t(I) * dtheta (I-1)) / BET

  !IF (B_t (1) == 0.0) THEN
  !  WRITE(*,*) 'press enter'
  !  READ(*,*)
  !ENDIF
  ! BET = B_t (1)
!  dtheta (1) = R (1) / BET
  !DO I = 2, Nlevsoi+1
  !  GAM (I) = C_t (I-1) / BET
  !  BET = B_t (I) - A_t (I) * GAM (I)
  !  IF (BET == 0.0) THEN
  !     WRITE(*,*) 'press enter'
  !     READ(*,*)
  !  ENDIF
  !  dtheta (I) = (R (I) - A_t (I) * dtheta (I-1)) / BET
  END DO
  !back substitution
  DO I = Nlevsoi, 1, -1
    dtheta (I) =  GAM (I) * dtheta (I+1) + dtheta(I)
  END DO
write (*,*) 'dtheta'
write (*,*) dtheta
  !-------------------------------------------------------------------!

  !-------------------------------------------------------------------!
  ! Update mass of liquid water in each layer. Also compute qcharge,
  ! the flow from the aquifer layer and update in drainage for case
  ! iwt < Nlevsoi.
  !-------------------------------------------------------------------!
  DO I = 1, Nlevsoi
    theta (I) = theta (I) + dtheta (I) * dz (I)
  END DO ! I = 1, Nlevsoi
  !-------------------------------------------------------------------!

  !-------------------------------------------------------------------!
  IF (iwt < Nlevsoi) THEN
    !-----------------------------------------------------------------!
    ! Water head at the water table depth is zero
    ! since wh_zwt = phi_sat - zq_zwt, where zq_zwt = phi_sat (mm).
    !-----------------------------------------------------------------!
    wh_zwt = 0.0
    !-----------------------------------------------------------------!
    ! Recharge rate qcharge to groundwater (positive to aquifer).
    wv = MAX (theta (iwt+1) / theta_sat (iwt+1), 0.01)
    wv = MIN (1.0, wv)
    ka = k_sat (iwt+1) * wv ** (2.0 * B (iwt+1) + 3.0)
    psi1 = MAX (psi_min, psi (MAX (1, iwt)))
    wh = psi1 - psi_e (MAX (1, iwt))
    IF (iwt == 0) THEN
      qcharge = -ka * (wh_zwt - wh) / ((zwt + 1.0) * 1000.0)
    ELSE
      !qcharge(c) = -ka * (wh_zwt-wh)/((zwt(c)-z(c,jwt(c)))*1000._r8)
      !scs: 1/2, assuming flux is at zwt interface, saturation deeper than zwt
      qcharge = -ka * (wh_zwt - wh) / ((zwt - z (iwt)) * 1000.0 * 2.0)
    END IF
    ! To limit qcharge (for the first several timesteps)
    qcharge = MAX (-10.0 / dt, qcharge)
    qcharge = MIN ( 10.0 / dt, qcharge)
  ELSE
    ! if water table is below soil column, compute qcharge from dwat2(11)
    qcharge = dtheta (Nlevsoi+1) * dz (Nlevsoi+1) / dt
  !-------------------------------------------------------------------!
  END IF ! iwt < Nlevsoi
  !-------------------------------------------------------------------!
write (*,*) 'theta'
write (*,*) theta (:)
!stop
  ! Write diagnostics to 'water.out'.
  WRITE (10,'(I5,12F8.3)') iTIME,theta(:)

END DO ! Time loop.

CLOSE (10)

!---------------------------------------------------------------------!
END PROGRAM H9_BUILD
!=====================================================================!
