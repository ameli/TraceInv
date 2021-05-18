#! /usr/bin/env python

# =======
# Imports
# =======

import sys
import time
import numpy
import scipy.sparse
from imate import generate_matrix
from imate import traceinv


# =====================
# test traceinv methods
# =====================

def test_traceinv_methods(K):
    """
    Computes the trace of the inverse of matrix ``K`` with multiple method.

    :param K: Invertible matrix.
    :type K: numpy.ndarray
    """

    # Settings
    num_samples = 30
    lanczos_degree = 30

    # Use Cholesky method with direct inverse
    time10 = time.time()
    trace1 = traceinv(K, method='cholesky', invert_cholesky=False)
    time11 = time.time()

    # Use Cholesky method without direct inverse
    if not scipy.sparse.isspmatrix(K):
        time20 = time.time()
        trace2 = traceinv(K, method='cholesky', invert_cholesky=True)
        time21 = time.time()
    else:
        # Do not use Cholesky with inverse method if K is sparse.
        trace2 = None
        time20 = 0
        time21 = 0

    # Use Hutchinson method
    time30 = time.time()
    trace3 = traceinv(K, method='hutchinson', num_samples=num_samples)
    time31 = time.time()

    # Use Stochastic Lanczos Quadrature method, with tridiagonalization
    time40 = time.time()
    trace4 = traceinv(K, method='SLQ', num_samples=num_samples,
                      lanczos_degree=lanczos_degree, reorthogonalize=-1,
                      symmetric=True)
    time41 = time.time()

    # Use Stochastic Lanczos Quadrature method, with bidiagonalization
    time50 = time.time()
    trace5 = traceinv(K, method='SLQ', num_samples=num_samples,
                      lanczos_degree=lanczos_degree, reorthogonalize=-1,
                      symmetric=False)
    time51 = time.time()

    # Elapsed times
    elapsed_time1 = time11 - time10
    elapsed_time2 = time21 - time20
    elapsed_time3 = time31 - time30
    elapsed_time4 = time41 - time40
    elapsed_time5 = time51 - time50

    # error
    error1 = 0.0
    if trace2 is not None:
        error2 = 100.0 * numpy.abs(trace2 - trace1) / trace1
    error3 = 100.0 * numpy.abs(trace3 - trace1) / trace1
    error4 = 100.0 * numpy.abs(trace4 - trace1) / trace1
    error5 = 100.0 * numpy.abs(trace5 - trace1) / trace1

    # Print results
    print('')
    print('------------------------------------------------------------')
    print('Method      Options                   traceinv   error  time')
    print('----------  ------------------------  --------  ------  ----')
    print('Cholesky    without using inverse     %8.3f  %5.2f%%  %0.2f'
          % (trace1, error1, elapsed_time1))
    if trace2 is not None:
        print('Cholesky    using inverse             %8.3f  %5.2f%%  %0.2f'
              % (trace2, error2, elapsed_time2))
    else:
        print('Cholesky    using inverse             N/A          N/A   N/A')
    print('Hutchinson  N/A                       %8.3f  %5.2f%%  %0.2f'
          % (trace3, error3, elapsed_time3))
    print('SLQ         with tri-diagonalization  %8.3f  %5.2f%%  %0.2f'
          % (trace4, error4, elapsed_time4))
    print('SLQ         with bi-diagonalization   %8.3f  %5.2f%%  %0.2f'
          % (trace5, error5, elapsed_time5))
    print('------------------------------------------------------------')
    print('')


# =============
# test traceinv
# =============

def test_traceinv():
    """
    Test for :mod:`imate.traceinv` sub-package.
    """

    # Compute trace of inverse of K using dense matrix
    print('Using dense matrix')
    K1 = generate_matrix(size=30, dimension=2, correlation_scale=0.05,
                         sparse=False)

    # print(K1)
    test_traceinv_methods(K1)

    # # Compute trace of inverse of K using sparse matrix
    print('Using sparse matrix')
    K2 = generate_matrix(size=30, dimension=2, correlation_scale=0.05,
                         sparse=True, density=2e-1, verbose=True)
    test_traceinv_methods(K2)


# ===========
# System Main
# ===========

if __name__ == "__main__":
    sys.exit(test_traceinv())
