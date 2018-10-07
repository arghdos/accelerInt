# distutils: language = c++

import cython
import numpy as np
cimport numpy as np
from libcpp cimport bool as bool_t
from libcpp cimport string as string_t
from libcpp cimport size_t, vector
from libcpp.memory cimport unique_ptr
from cython.operator cimport dereference as deref

cdef extern from "solver_types.hpp" namespace "opencl_solvers":
    cpdef enum IntegratorType:
        ROSENBROCK,
        RKF45

cdef extern from "error_codes.hpp" namespace "opencl_solvers":
    cpdef enum ErrorCode:
        SUCCESS,
        TOO_MUCH_WORK,
        TDIST_TOO_SMALL,
        MAX_STEPS_EXCEEDED

cdef extern from "rkf45_solver.hpp" namespace "opencl_solvers":
    cdef cppclass RKF45SolverOptions:
        RKF45SolverOptions(size_t, size_t, int, double, double,
                            bool, double, bool, char,
                            size_t, size_t) except +

cdef extern from "solver_interface.hpp" namespace "opencl_solvers":
    cdef cppclass IntegratorBase:
        IntegratorBase(int, int, const IVP&,
                       const SolverOptions&) except +
        const double atol() except +
        const double rtol() except +
        const double neq() except +
        void getLog(const int, double*, double*) except +
        size_t numSteps() except +

    cdef cppclass IVP:
        IVP(const vector<string_t>&, size_t) except +

    cdef cppclass SolverOptions:
        SolverOptions(size_t, size_t, int, double, double,
                            bool, double, bool, char) except +

    cdef unique_ptr[IntegratorBase] init(IntegratorType, int, int,
                                         const IVP&, const SolverOptions&) except +
    cdef unique_ptr[IntegratorBase] init(IntegratorType, int, int, const IVP&) except +

    cdef double integrate(Integrator&, const int, const double, const double,
                          const double, double * __restrict__,
                          const double * __restrict__)

    cdef double integrate(Integrator&, const int, const double * __restrict__,
                          const double * __restrict__,
                          const double, double * __restrict__,
                          const double * __restrict__)


cdef class PyIntegrator:
    cdef unique_ptr[IntegratorBase] integrator  # hold our integrator
    cdef num # number of IVPs
    cdef neq # number of equations

    def __cinit__(self, IntegratorType itype, int neq, size_t numThreads,
                  PyIVP ivp, PySolverOptions options=None):
        if options is not None:
            self.integrator.reset(init(itype, neq, numThreads, deref(ivp.ivp.get()),
                                       deref(options.options.get())))
        else:
            self.integrator.reset(init(itype, neq, numThreads, deref(ivp.ivp.get())))
        self.num = -1
        self.neq = neq

    cpdef integrate(self, np.int32_t num, np.float64_t t_start,
                    np.float64_t t_end, np.ndarray[np.float64_t] y_host,
                    np.ndarray[np.float64_t] var_host, np.float64_t step=-1):\
        """
        Integrate :param:`num` IVPs, with varying start (:param:`t_start`) and
        end-times (:param:`t_end`)

        Parameters
        ----------
        num: int
            The number of IVPs to integrate
        t_start: double
            The integration start time
        t_end: double
            The integration end time
        phi_host: array of doubles
            The state vectors
        param: array of doubles
            The constant parameter
        step: double
            If supplied, use global integration time-steps of size :param:`step`.
            Useful for logging.
        """

        # store # of IVPs
        self.num = num
        return integrate(deref(self.integrator.get()), num, t_start,
                         t_end, step, &y_host[0], &var_host[0])

    cpdef integrate_varying(
                    self, np.int32_t num, np.ndarray[np.float64_t] t_start,
                    np.np.ndarray[np.float64_t] t_end,
                    np.ndarray[np.float64_t] phi_host,
                    np.ndarray[np.float64_t] param_host, np.float64_t step=-1):
        """
        Integrate :param:`num` IVPs, with varying start (:param:`t_start`) and
        end-times (:param:`t_end`)

        Parameters
        ----------
        num: int
            The number of IVPs to integrate
        t_start: array of doubles
            The integration start times
        t_end: array of doubles
            The integration end times
        phi_host: array of doubles
            The state vectors
        param: array of doubles
            The constant parameter
        step: double
            If supplied, use global integration time-steps of size :param:`step`.
            Useful for logging.
        """

        # store # of IVPs
        self.num = num
        return integrate(deref(self.integrator.get()), num, t_start,
                         t_end, step, &y_host[0], &var_host[0])


    def state(self):
        """
        Returns
        -------
        times: np.ndarray
            The array of times that this integrator has reached
        state: np.ndarray
            The state vectors at each time, shape is
            (:attr:`num`, :attr:`neq`, times.size)
        """
        assert self.num > 0 and self.neq > 0
        n_steps = deref(self.integrator.get()).numSteps()
        cdef np.ndarray[np.float64_t, ndim=1] phi = np.zeros(
            self.num * self.neq * n_steps, dtype=np.float64)
        cdef np.ndarray[np.float64_t, ndim=1] times = np.zeros(
            n_steps, dtype=np.float64)
        # get phi
        deref(self.integrator.get()).getLog(self.num, &times[0], &phi[0])
        # and reshape
        return times, np.reshape(phi, (self.num, self.neq, n_steps), order='F')


cdef class PySolverOptions:
    cdef unique_ptr[SolverOptions] options # hold our options

    def __cinit__(self, size_t vectorSize=1, size_t blockSize=1,
                  int numBlocks=-1, double atol=1e-10, double rtol=1e-6,
                  bool logging=False, double h_init=1e-6,
                  bool use_queue=True, char order='C',
                  size_t minIters=1, size_t maxIters = 1000):
        if itype in [IntegratorType.EXP4, IntegratorType.EXPRB43]:
            self.options.reset(
                new EXPSolverOptions(atol, rtol, logging, h_init,
                                     num_rational_approximants,
                                     max_krylov_subspace_dimension))
        else:
            self.options.reset(new SolverOptions(atol, rtol, logging, h_init))

cdef class PyIVP:
    cdef unique_ptr[IVP] ivp # hold our ivp implementation
    cdef vector[string_t] source
    cdef int mem

    def __cinit__(self, kernel_source, required_memory):
        """
        Create an IVP implementation object, from:

        Parameters
        ----------
        kernel_source: iterable of str
            The paths to the kernel source files to use
        required_memory: int
            The amount of memory (measured in double-precision floating-point values)
            required per-IVP.  Note: this should _not_ include any vectorization
            considerations.
        """

        for x in kernel_source:
            assert isinstance(x, str), "Kernel path ({}) not string!".format(x)
            source.push_back(x)

        mem = required_memory

        ivp = unique_ptr[IntegratorBase](new IVP())