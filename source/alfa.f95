program alfa

use mod_readfiles
use mod_routines
use mod_types
use mod_quicksort
use mod_continuum
use mod_fit
use mod_uncertainties

implicit none
integer :: I, spectrumlength, nlines
character (len=512) :: spectrumfile,linelistfile

type(linelist) :: referencelinelist
type(linelist), dimension(:),allocatable :: population
type(spectrum), dimension(:,:), allocatable :: synthspec
type(spectrum), dimension(:), allocatable :: realspec
type(spectrum), dimension(:), allocatable :: continuum
character(len=85), dimension(:), allocatable :: linedata

real, dimension(:), allocatable :: rms
real :: normalisation

CHARACTER*2048, DIMENSION(:), allocatable :: options
CHARACTER*2048 :: commandline
integer :: narg

logical :: normalise

!temp XXXX

open (101,file="intermediate",status="replace")

!set defaults

normalise = .false.

! start

print *,"ALFA, the Automated Line Fitting Algorithm"
print *,"------------------------------------------"

print *
print *,gettime(),": starting code"
print *,gettime(),": command line: ",trim(commandline)

! random seed

call init_random_seed()

! read command line

narg = IARGC() !count input arguments
if (narg .lt. 2) then
  print *,gettime()," : Error : files to analyse not specified"
  stop
endif

call get_command(commandline)
ALLOCATE (options(Narg))
if (narg .gt. 2) then
  do i=1,Narg-2
    call get_command_argument(i,options(i))
    if (options(i) .eq. "-n") then
      normalise = .true.
    endif
  enddo
endif

call get_command_argument(narg-1,spectrumfile)
call get_command_argument(narg,linelistfile)

! read in spectrum to fit and line list

call readfiles(spectrumfile,linelistfile,realspec,referencelinelist,spectrumlength, nlines, linedata)

! then subtract the continuum

print *,gettime()," : fitting continuum"
call fit_continuum(realspec,spectrumlength, continuum)

! now do the fitting

print *,gettime()," : fitting lines"
print *
print *,"Best fitting model parameters:          Resolution      Redshift          RMS"
call fit(realspec, referencelinelist, population, synthspec, rms)

! calculate the uncertainties

print *
print *,gettime()," : estimating uncertainties"
call get_uncertainties(synthspec, realspec, population, rms)

!write out line fluxes of best fitting spectrum

print *,gettime()," : writing output files ",trim(spectrumfile),"_lines.tex and ",trim(spectrumfile),"_fit"

!normalise Hb to 100 if requested

normalisation = 1.D0
if (normalise) then
  do i=1,nlines
    if (population(1)%wavelength(i) .eq. 4861.33) then
      normalisation = 100./gaussianflux(population(minloc(rms,1))%peak(i),(population(minloc(rms,1))%wavelength(i)/population(minloc(rms,1))%resolution))
      exit
    endif
  enddo
endif

open(100,file=trim(spectrumfile)//"_lines.tex")
write(100,*) "Observed wavelength & Rest wavelength & Flux & Uncertainty & Ion & Multiplet & Lower term & Upper term & g_1 & g_2 \\"
do i=1,nlines
  if (population(minloc(rms,1))%uncertainty(i) .gt. 3.0) then
    write (100,"(F7.2,' & ',F7.2,' & ',F12.3,' & ',F12.3,A85)") population(1)%wavelength(i)*population(1)%redshift,population(1)%wavelength(i),normalisation*gaussianflux(population(minloc(rms,1))%peak(i),(population(minloc(rms,1))%wavelength(i)/population(minloc(rms,1))%resolution)), normalisation*gaussianflux(population(minloc(rms,1))%peak(i),(population(minloc(rms,1))%wavelength(i)/population(minloc(rms,1))%resolution))/population(minloc(rms,1))%uncertainty(i), linedata(i)
  end if
end do
close(100)

! write out fit

open(100,file=trim(spectrumfile)//"_fit")

write (100,*) """wavelength""  ""fitted spectrum""  ""cont-subbed orig"" ""continuum""  ""residuals"""
do i=1,spectrumlength
  write(100,*) synthspec(i,minloc(rms,1))%wavelength,synthspec(i,minloc(rms,1))%flux, realspec(i)%flux, continuum(i)%flux, realspec(i)%flux - synthspec(i,minloc(rms,1))%flux
end do

close(100)
close(101) !temp XXXX

print *,gettime()," : all done"

end program alfa 
