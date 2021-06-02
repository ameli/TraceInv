/*
 *  SPDX-FileCopyrightText: Copyright 2021, Siavash Ameli <sameli@berkeley.edu>
 *  SPDX-License-Identifier: BSD-3-Clause
 *  SPDX-FileType: SOURCE
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the license found in the LICENSE.txt file in the root
 *  directory of this source tree.
 */


#ifndef _C_TRACE_ESTIMATOR_C_TRACE_ESTIMATOR_H_
#define _C_TRACE_ESTIMATOR_C_TRACE_ESTIMATOR_H_

// ======
// Headers
// ======

#include "../functions/functions.h"  // Function
#include "../_c_linear_operator/c_linear_operator.h"  // cLinearOperator
#include "../_definitions/types.h"  // IndexType, FlagType


// =================
// c Trace Estimator
// =================

/// \class cTraceEstimator
///
/// \brief A static class to compute the trace of implicit matrix functions
///        using stochastic Lanczos quadrature method. This class acts as a
///        templated namespace, where the member methods is *public* and
///        *static*. The internal private member functions are also static.
///
/// \sa    Diagonalization

template <typename DataType>
class cTraceEstimator
{
    public:

        // c trace estimator
        static FlagType c_trace_estimator(
                cLinearOperator<DataType>* A,
                DataType* parameters,
                const IndexType num_inquiries,
                const Function* matrix_function,
                const DataType exponent,
                const FlagType symmetric,
                const FlagType orthogonalize,
                const IndexType lanczos_degree,
                const DataType lanczos_tol,
                const IndexType min_num_samples,
                const IndexType max_num_samples,
                const DataType error_atol,
                const DataType error_rtol,
                const DataType confidence_level,
                const DataType outlier_significance_level,
                const IndexType num_threads,
                DataType* trace,
                DataType* error,
                DataType** samples,
                IndexType* processed_samples_indices,
                IndexType* num_samples_used,
                IndexType* num_outliers,
                FlagType* converged);

    private:

        // _c stochastic lanczos quadrature
        static void _c_stochastic_lanczos_quadrature(
                cLinearOperator<DataType>* A,
                DataType* parameters,
                const IndexType num_inquiries,
                const Function* matrix_function,
                const DataType exponent,
                const FlagType symmetric,
                const DataType* random_vector,
                const FlagType orthogonalize,
                const IndexType lanczos_degree,
                const DataType lanczos_tol,
                FlagType* converged,
                DataType* trace_estimate);
};

#endif  // _C_TRACE_ESTIMATOR_C_TRACE_ESTIMATOR_H_
