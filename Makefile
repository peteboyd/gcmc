# fast gcmc make file


# Any optimisation flags?
OPTIM=
#OPTIM=

# ifort debugging
#DEBUG = -g -traceback -debug extended
# gfortran debugging
DEBUG = -g
# no debugging
#DEBUG=

SERIAL=ser
PARALLEL=par
.SUFFIXES: .f .o

OBJPAR = parse_module.o basic_comms.o utility_pack.o error.o \
		 vdw_module.o vdw_terms.o nlist_builders.o \
		 ewald_module.o ewald.o flex_module.o readinputs.o gcmc.o

OBJSER = parse_module.o setup_module.o serial.o utility_pack.o \
		 error.o vdw_module.o vdw_terms.o nlist_builders.o \
		 ewald_module.o ewald.o flex_module.o readinputs.o gcmc.o

# must choose a version to compile
all:
	@echo "[1m>> Please specify the target:[0m"
	@echo
	@echo "[1;32m * [0mserial"
	@echo "[1;32m * [0mgfortran"
	@echo "[1;32m * [0mparallel"
	@echo

# parameters for different versions
gfortran:
	${MAKE} FC="gfortran" \
	FFLAGS="${OPTIM}" EXE="gcmc_gfort.x" ${SERIAL}

serial:
	${MAKE} FC="ifort" \
	FFLAGS="${OPTIM}" EXE="gcmc.x" ${SERIAL}

parallel:
	${MAKE} FC="mpifort" \
	FFLAGS="${OPTIM}" EXE="gcmc-par.x" ${PARALLEL}
debug:
	${MAKE} FC="gfortran" \
	FFLAGS="${OPTIM}" EXE="gcmc_gfort.x" ${SERIAL}

# stuff that does the compilations
ser: ${OBJSER}
	${FC} ${FFLAGS} ${DEBUG} -o ${EXE} ${OBJSER}

par: ${OBJPAR}
	${FC} ${FFLAGS} ${DEBUG} -o ${EXE} ${OBJPAR}

clean:
	rm -f *.o *.mod

.f.o:
	${FC} ${FFLAGS} ${DEBUG} -c $*.f