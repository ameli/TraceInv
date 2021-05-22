# SPDX-FileCopyrightText: Copyright 2021, Siavash Ameli <sameli@berkeley.edu>
# SPDX-License-Identifier: BSD-3-Clause
# SPDX-FileType: SOURCE
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the license found in the LICENSE.txt file in the root
# directory of this source tree.


# =======
# Imports
# =======

# Python
import numpy
import time
from .trace_estimator_plot_utilities import plot_convergence
from .trace_estimator_utilities import get_operator, \
        get_operator_parameters, check_arguments, get_machine_precision, \
        find_num_inquiries, print_summary
from ..linear_operator import LinearOperator

# Cython
from .._definitions.types cimport IndexType, FlagType
from ..functions cimport pyFunction
cimport openmp

# Type names
cdef char* index_type_name = b'int32'
cdef char* flag_type_name = b'int32'


# ===============
# trace estimator
# ===============

cpdef trace_estimator(
        A,
        parameters,
        pyFunction py_matrix_function,
        symmetric,
        min_num_samples,
        max_num_samples,
        error_atol,
        error_rtol,
        confidence_level,
        outlier_significance_level,
        lanczos_degree,
        lanczos_tol,
        reorthogonalize,
        num_threads,
        verbose,
        plot,
        gpu):
    """
    Computes the trace of inverse of matrix based on stochastic Lanczos
    quadrature (SLQ) method.

    :param A: invertible matrix or linear operator
    :type A: numpy.ndarray, scipy.sparse matrix, or LinearOperator object

    :param max_num_samples: Number of Monte-Carlo trials
    :type max_num_samples: unsigned int

    :param lanczos_degree: Lanczos degree
    :type lanczos_degree: unsigned int

    :param symmetric: If ``True``, the Lanczos tri-diagonalization method is
        used. This is suitable for symmetric matrices. If ``False``, the
        Golub-Kahn bi-diagonalization is used. This should only be used for
        non-symmetric matrices.
    :type symmetric: bool

    :param tolerance: The tolerance for the acceptable error of Lanczos
        tri-diagonalization, or Golub-Kahn bi-diagonalization.
    :type tolerance: DataType

    :return: Trace of ``A``
    :rtype: float

    .. note::

        In Lanczos tri-diagonalization method, :math:`\\theta`` is the
        eigenvalue of ``T``. However, in Golub-Kahn bi-diagonalization method,
        :math:`\\theta` is the singular values of ``B``. The relation between
        these two methods are as follows: ``B.T*B`` is the ``T`` for ``A.T*A``.
        That is, if we have the input matrix ``A.T*T``, its Lanczos
        tri-diagonalization ``T`` is the same matrix as if we bi-diagonalize
        ``A`` (not ``A.T*A``) with Golub-Kahn to get ``B``, then ``T = B.T*B``.
        This has not been highlighted in the above paper.

        To correctly implement Golub-Kahn, here :math:`\\theta` should be the
        singular values of ``B``, **NOT** the square of the singular values of
        ``B`` (as described in the above paper incorrectly!).

    Technical notes:
        This function is a wrapper to a cython function. In cython we cannot
        have function arguments with default values (neither ``cdef``,
        ``cpdef``). As a work around, this function (defined with ``def``)
        accepts default values for arguments, and then calls the cython
        function (defined with ``cdef``).

    Reference:
        * `Ubaru, S., Chen, J., and Saad, Y. (2017)
          <https://www-users.cs.umn.edu/~saad/PDF/ys-2016-04.pdf>`_,
          Fast Estimation of :math:`\\mathrm{tr}(F(A))` Via Stochastic Lanczos
          Quadrature, SIAM J. Matrix Anal. Appl., 38(4), 1075-1099.
    """

    # Set number of parallel openmp threads
    if num_threads < 1:
        num_threads = openmp.omp_get_max_threads()

    # Check operator A, and convert to a linear operator (if not already)
    Aop = get_operator(A)

    # data type name is either float32 (float), float64 double), or float128
    # (long double). This will be used to choose a template function
    data_type_name = Aop.get_data_type_name()

    # Check parameters of operator A, convert its type if needed, and finds the
    # size of given parameters array or scalar
    parameters, parameters_size = get_operator_parameters(
            parameters, data_type_name)

    # Find number of inquiries, which is the number of batches of different set
    # of parameters to produce different linear operators. These batches are
    # concatenated in the "parameters" array.
    cdef IndexType num_inquiries = find_num_inquiries(Aop, parameters_size)

    # Check input arguments have proper type and values
    error_atol, error_rtol = check_arguments(
            symmetric, min_num_samples, max_num_samples, error_atol,
            error_rtol, confidence_level, outlier_significance_level,
            lanczos_degree, lanczos_tol, reorthogonalize, num_threads, verbose,
            plot, gpu)

    # Set the default value for the "epsilon" of the slq algorithm
    if lanczos_tol is None:
        lanczos_tol = get_machine_precision(data_type_name)

    # Allocate output trace as array of size num_inquiries
    trace = numpy.empty((num_inquiries,), dtype=data_type_name)

    # Error of computing trace within a confidence interval
    error = numpy.empty((num_inquiries,), dtype=data_type_name)

    # Array of all Monte-Carlo samples where array trace is averaged based upon
    samples = \
        numpy.empty((max_num_samples, num_inquiries), dtype=data_type_name)
    samples[:, :] = numpy.nan

    # Track the order of process of samples in rows of samples array
    processed_samples_indices = \
        numpy.empty((max_num_samples,), dtype=index_type_name)
    processed_samples_indices[:] = 0

    # Store how many samples used for each inquiry till reaching convergence
    num_samples_used = numpy.zeros((num_inquiries,), dtype=index_type_name)

    # Number of outliers that is removed from num_samples_used in averaging
    num_outliers = numpy.zeros((num_inquiries,), dtype=index_type_name)

    # Flag indicating which of the inquiries were converged below the tolerance
    converged = numpy.zeros((num_inquiries,), dtype=flag_type_name)

    # Initialize gpu device properties
    num_gpu_devices = 0
    num_gpu_multiprocessors = 0
    num_gpu_threads_per_multiprocessor = 0

    # Call SLQ method (actual computation)
    init_wall_time = time.perf_counter()
    init_proc_time = time.process_time()

    cdef FlagType all_converged
    cdef float gpu_proc_time = 0.0

    if gpu:

        # dispatch execution on gpu
        try:
            from .._cu_trace_estimator import pycu_trace_estimator
        except ImportError:
            raise ImportError('This package has not been compiled with GPU ' +
                              'support. Either set "gpu=False" to use the ' +
                              'existing installed package, or export the ' +
                              'environment variable "USE_CUDA=1" and ' +
                              'recompile the source code of the package.')

        pycuAop = Aop.get_linear_operator(gpu=True)

        all_converged, gpu_proc_time = pycu_trace_estimator(
            pycuAop,
            parameters,
            num_inquiries,
            py_matrix_function,
            int(symmetric),
            reorthogonalize,
            lanczos_degree,
            lanczos_tol,
            min_num_samples,
            max_num_samples,
            error_atol,
            error_rtol,
            confidence_level,
            outlier_significance_level,
            num_threads,
            data_type_name,
            trace,
            error,
            samples,
            processed_samples_indices,
            num_samples_used,
            num_outliers,
            converged)

        # Get device properties
        device_properties_dict = pycuAop.get_device_properties()
        num_gpu_devices = device_properties_dict['num_devices']
        num_gpu_multiprocessors = device_properties_dict['num_multiprocessors']
        num_gpu_threads_per_multiprocessor = \
            device_properties_dict['num_threads_per_multiprocessor']

    else:

        # dispatch execution on cpu
        from .._c_trace_estimator import pyc_trace_estimator
        pycAop = Aop.get_linear_operator(gpu=False)

        all_converged = pyc_trace_estimator(
            pycAop,
            parameters,
            num_inquiries,
            py_matrix_function,
            int(symmetric),
            reorthogonalize,
            lanczos_degree,
            lanczos_tol,
            min_num_samples,
            max_num_samples,
            error_atol,
            error_rtol,
            confidence_level,
            outlier_significance_level,
            num_threads,
            data_type_name,
            trace,
            error,
            samples,
            processed_samples_indices,
            num_samples_used,
            num_outliers,
            converged)

    wall_time = time.perf_counter() - init_wall_time
    proc_time = time.process_time() - init_proc_time

    # Dictionary of output info
    info = {
        'matrix':
        {
            'data_type': data_type_name,
            'symmetric': symmetric,
            'num_inquiries': num_inquiries,
            'num_operator_parameters': Aop.get_num_parameters(),
            'parameters': parameters

        },
        'error':
        {
            'absolute_error': None,
            'relative_error': None,
            'error_atol': error_atol,
            'error_rtol': error_rtol,
            'confidence_level': confidence_level,
            'outlier_significance_level': outlier_significance_level
        },
        'convergence':
        {
            'converged': None,
            'all_converged': bool(all_converged),
            'min_num_samples': min_num_samples,
            'max_num_samples': max_num_samples,
            'num_samples_used': None,
            'num_outliers': None,
            'samples': None,
            'samples_mean': None,
            'samples_processed_order': processed_samples_indices
        },
        'cpu':
        {
            'wall_time': wall_time,
            'proc_time': proc_time,
            'num_threads': num_threads,
        },
        'gpu':
        {
            'num_gpu_devices': num_gpu_devices,
            'num_gpu_multiprocessors': num_gpu_multiprocessors,
            'num_gpu_threads_per_multiprocessor':
                num_gpu_threads_per_multiprocessor,
            'proc_time': gpu_proc_time
        },
        'solver':
        {
            'lanczos_degree': lanczos_degree,
            'lanczos_tol': lanczos_tol,
            'reorthogonalize': reorthogonalize,
            'method': 'slq',
        }
    }

    # Determine if the output is array
    if (parameters is None) or numpy.isscalar(parameters):
        output_is_array = False
    else:
        output_is_array = True

    # Fill arrays of info depending on whether output is scalar or array
    if output_is_array:
        info['error']['absolute_error'] = error
        info['error']['relative_error'] = error / numpy.abs(trace)
        info['convergence']['converged'] = converged.astype(bool)
        info['convergence']['num_samples_used'] = num_samples_used
        info['convergence']['num_outliers'] = num_outliers
        info['convergence']['samples'] = samples
        info['convergence']['samples_mean'] = trace
    else:
        info['error']['absolute_error'] = error[0]
        info['error']['relative_error'] = error[0] / numpy.abs(trace[0])
        info['convergence']['converged'] = bool(converged[0])
        info['convergence']['num_samples_used'] = num_samples_used[0]
        info['convergence']['num_outliers'] = num_outliers[0]
        info['convergence']['samples'] = samples[:, 0]
        info['convergence']['samples_mean'] = trace[0]

    # print summary
    if verbose:
        print_summary(info)

    # Plot results
    if plot:
        plot_convergence(info)

    # return output
    if output_is_array:
        return trace, info
    else:
        return trace[0], info