SHELL = /bin/sh

.SUFFIXES:
.SUFFIXES: .c .o .cu .cu.o .omp.o

CUDA_PATH = /usr/local/cuda
SDK_PATH = /usr/local/cuda/samples/common/inc/

# Compilers
#CC    = gcc-4.8
CC = gcc
NCC = cc
NCC_BIN = /usr/bin
NVCC = $(CUDA_PATH)/bin/nvcc
LINK   = $(CC) -fPIC
NLINK = $(NCC) -Wl,--no-undefined -fPIC -Xlinker -rpath $(CUDA_PATH)/lib64

# Directories
ODIR = ./obj
SDIR = ./src

#turn on line and spilling info
ifndef CUDA_PROFILER
  CUDA_PROFILER = 0
endif
ifeq ("$(CUDA_PROFILER)", "4")
  L = 4
endif
#FLAGS, L=0 for testing, L=4 for optimization
ifndef L
  L = 4
endif
#FLAGS, USE_LAPACK, 4 for use MKL in CVODEs, 2 for use the system libraries, 0 for use the serial CVodes version 
ifndef USE_LAPACK
  USE_LAPACK = 4
endif

# Paths
INCLUDES    = -I. -I/usr/local/include/

_DEPS = header.h
DEPS = $(patsubst %,$(SDIR)/%,$(_DEPS))

_OBJ = main.o phiA.o cf.o exp4.o complexInverse.o \
       dydt.o fd_jacob.o chem_utils.o mass_mole.o rxn_rates.o spec_rates.o \
       rxn_rates_pres_mod.o mechanism.o
OBJ = $(patsubst %,$(ODIR)/%,$(_OBJ))

_OBJ_GPU = main.cu.o phiA.cu.o cf.o exp4.cu.o complexInverse.cu.o \
           dydt.cu.o fd_jacob.cu.o chem_utils.cu.o mass_mole.o rxn_rates.cu.o \
					 spec_rates.cu.o rxn_rates_pres_mod.cu.o mechanism.o
OBJ_GPU = $(patsubst %,$(ODIR)/%,$(_OBJ_GPU))

_OBJ_CVODES = main_cvodes.o dydt.o chem_utils.o mass_mole.o rxn_rates.o spec_rates.o \
              rxn_rates_pres_mod.o dydt_cvodes.o mechanism.o
OBJ_CVODES = $(patsubst %,$(ODIR)/%,$(_OBJ_CVODES))

_OBJ_KRYLOV = main_krylov.o phiAHessenberg.o cf.o krylov.o complexInverse.o \
       dydt.o fd_jacob.o chem_utils.o mass_mole.o rxn_rates.o spec_rates.o \
       rxn_rates_pres_mod.o mechanism.o sparse_multiplier.o
OBJ_KRYLOV = $(patsubst %,$(ODIR)/%,$(_OBJ_KRYLOV))

_OBJ_RB43 = main_rb43.o phiAHessenberg.o cf.o exprb43.o complexInverse.o \
       dydt.o fd_jacob.o chem_utils.o mass_mole.o rxn_rates.o spec_rates.o \
       rxn_rates_pres_mod.o mechanism.o sparse_multiplier.o inverse.o
OBJ_RB43 = $(patsubst %,$(ODIR)/%,$(_OBJ_RB43))

_OBJ_RB43_GPU = main_rb43.cu.o phiAHessenberg.cu.o linear-algebra.o cf.o exprb43.cu.o complexInverse.cu.o \
       dydt.cu.o fd_jacob.cu.o chem_utils.cu.o mass_mole.o rxn_rates.cu.o spec_rates.cu.o \
       rxn_rates_pres_mod.cu.o mechanism.o sparse_multiplier.cu.o
OBJ_RB43_GPU = $(patsubst %,$(ODIR)/%,$(_OBJ_RB43_GPU))

_OBJ_KRYLOV_GPU = main_krylov.cu.o phiAHessenberg.cu.o cf.o krylov.cu.o complexInverse.cu.o \
       dydt.cu.o fd_jacob.cu.o chem_utils.cu.o mass_mole.o rxn_rates.cu.o spec_rates.cu.o \
       rxn_rates_pres_mod.cu.o mechanism.o sparse_multiplier.cu.o
OBJ_KRYLOV_GPU = $(patsubst %,$(ODIR)/%,$(_OBJ_KRYLOV_GPU))

_OBJ_GPU_PROFILER = mechanism.cu.o mass_mole.o fd_jacob.cu.o rxn_rates.cu.o spec_rates.cu.o rxn_rates_pres_mod.cu.o chem_utils.cu.o rateOutputTest.cu.o dydt.cu.o gpu_memory.cu.o
OBJ_GPU_PROFILER =  $(patsubst %,$(ODIR)/%,$(_OBJ_GPU_PROFILER))

_OBJ_TEST = unit_tests.o complexInverse.o phiA.o phiAHessenberg.o cf.o krylov.o\
            dydt.o fd_jacob.o chem_utils.o mass_mole.o rxn_rates.o spec_rates.o sparse_multiplier.o rxn_rates_pres_mod.o
OBJ_TEST =  $(patsubst %,$(ODIR)/%,$(_OBJ_TEST))

_OBJ_RATES_TEST = mechanism.o mass_mole.o jacob.o rxn_rates.o spec_rates.o rxn_rates_pres_mod.o chem_utils.o rateOutputTest.o dydt.o
OBJ_RATES_TEST =  $(patsubst %,$(ODIR)/%,$(_OBJ_RATES_TEST))

_OBJ_GPU_RATES_TEST = mechanism.cu.o mass_mole.o fd_jacob.cu.o rxn_rates.cu.o spec_rates.cu.o rxn_rates_pres_mod.cu.o chem_utils.cu.o rateOutputTest.cu.o dydt.cu.o gpu_memory.cu.o
OBJ_GPU_RATES_TEST =  $(patsubst %,$(ODIR)/%,$(_OBJ_GPU_RATES_TEST))


# Paths
INCLUDES = -I. -I$(CUDA_PATH)/include/ -I$(SDK_PATH)
LIBS = -lm -lfftw3 -L$(CUDA_PATH)/lib64 -L/usr/local/lib -lcuda -lcudart -lstdc++ -lsundials_cvodes -lsundials_nvecserial

#flags
#ifeq ("$(CC)", "gcc")
  
ifeq ($(L), 0)
  FLAGS = -O0 -g3 -fbounds-check -Wunused-variable -Wunused-parameter \
  	  -Wall -ftree-vrp -std=c99 -fopenmp -DDEBUG
  NVCCFLAGS = -g -G -arch=sm_20 -m64 -DDEBUG
else ifeq ($(L), 4)
  FLAGS = -O3 -std=c99 -fopenmp -funroll-loops
  NVCCFLAGS = -O3 -arch=sm_20 -m64
endif
ifeq ($(L), 4)
  ifeq ("$(CC)", "gcc")
    FLAGS += -mtune=native
  endif
endif

NVCCFLAGS += --ftz=false --prec-div=true --prec-sqrt=true
# --fmad=false

ifeq ($(CUDA_PROFILER), 4)
  NVCCFLAGS += -Xnvlink -v --ptxas-options=-v -lineinfo -g --keep-dir=keepfiles/
endif

ifeq ($(USE_LAPACK), 4)
  FLAGS += -DSUNDIALS_USE_LAPACK -I${MKLROOT}/include
  CV_LIBS = -L${MKLROOT}/lib/intel64/ -lmkl_rt -lmkl_intel_lp64 -lmkl_core -lmkl_gnu_thread -ldl -lpthread -lmkl_mc -lmkl_def
else ifeq ($(USE_LAPACK), 2)
  FLAGS += -DSUNDIALS_USE_LAPACK
  CV_LIBS = -L/usr/local/lib -llapack -lblas
endif

ratestest : FLAGS += -DRATES_TEST

gpuratestest : NVCCFLAGS += -DRATES_TEST

gpu-profiler : NVCCFLAGS += -DPROFILER

$(ODIR)/%.o : $(SDIR)/%.c $(DEPS)
	$(CC) $(FLAGS) $(INCLUDES) -c -o $@ $<

$(ODIR)/%.cu.o : $(SDIR)/%.cu $(DEPS)
	$(NVCC) -ccbin=$(NCC_BIN) $(NVCCFLAGS) $(INCLUDES) -dc -o $@ $<

default: $(ODIR) all

$(ODIR):
	mkdir $(ODIR)

all: exp-int exp-int-gpu exp-int-cvodes exp-int-krylov exp-int-krylov-gpu tests

print-%  : ; @echo $* = $($*)

exp-int : $(OBJ)
	$(LINK) $(OBJ) $(LIBS) $(FLAGS) -o $@

exp-int-krylov : $(OBJ_KRYLOV)
	$(LINK) $(OBJ_KRYLOV) $(LIBS) $(FLAGS) -o $@

exp-int-rb43 : $(OBJ_RB43)
	$(LINK) $(OBJ_RB43) $(LIBS) $(FLAGS) -o $@

exp-int-rb43-gpu : $(OBJ_RB43_GPU)
	$(NVCC) -ccbin=$(NCC_BIN) $(OBJ_RB43_GPU) $(LIBS) $(NVCCFLAGS) -dlink -o dlink.o
	$(NLINK) $(OBJ_RB43_GPU) dlink.o $(LIBS) $(FLAGS) -o $@

exp-int-gpu : $(OBJ_GPU)
	$(NVCC) -ccbin=$(NCC_BIN) $(OBJ_GPU) $(LIBS) $(NVCCFLAGS) -dlink -o dlink.o
	$(NLINK) $(OBJ_GPU) dlink.o $(LIBS) -llapack $(FLAGS) -o $@

gpu-profiler : $(OBJ_GPU_PROFILER)
	$(NVCC) -ccbin=$(NCC_BIN) $(OBJ_GPU_PROFILER) $(LIBS) $(NVCCFLAGS) -dlink -o dlink.o
	$(NLINK) $(OBJ_GPU_PROFILER) dlink.o $(LIBS) $(FLAGS) -o $@

exp-int-krylov-gpu : $(OBJ_KRYLOV_GPU)
	$(NVCC) -ccbin=$(NCC_BIN) $(OBJ_KRYLOV_GPU) $(LIBS) $(NVCCFLAGS) -dlink -o dlink.o
	$(NLINK) $(OBJ_KRYLOV_GPU) dlink.o $(LIBS) $(FLAGS) -o $@

exp-int-cvodes : $(OBJ_CVODES)
	$(LINK) $(OBJ_CVODES) $(LIBS) $(CV_LIBS) $(FLAGS) -o $@

tests : $(OBJ_TEST)
	$(LINK) $(OBJ_TEST) $(LIBS) $(FLAGS) -o $@

doc : $(DEPS) $(OBJ)
	$(DOXY)

ratestest : $(OBJ_RATES_TEST)
	$(LINK) -DRATES_TEST $(OBJ_RATES_TEST) $(LIBS) $(FLAGS) -o $@

gpuratestest : $(OBJ_GPU_RATES_TEST)
	$(NVCC) -ccbin=$(NCC_BIN) $(OBJ_GPU_RATES_TEST) $(LIBS) $(NVCCFLAGS) -dlink -o dlink.o
	$(NLINK) $(OBJ_GPU_RATES_TEST) dlink.o $(LIBS) $(FLAGS) -o $@

.PHONY : clean		
clean :
	rm -f $(OBJ) $(OBJ_GPU) $(OBJ_CVODES) $(OBJ_KRYLOV) $(OBJ_TEST) $(OBJ_KRYLOV_GPU) $(OBJ_RB43) $(OBJ_RB43_GPU) $(OBJ_GPU_PROFILER) $(OBJ_RATES_TEST) $(OBJ_GPU_RATES_TEST) gpu-profiler exp-int exp-int-gpu exp-int-cvodes exp-int-krylov exp-int-krylov-gpu exp-int-rb43 exp-int-rb43-gpu tests ratestest gpuratestest dlink.o
