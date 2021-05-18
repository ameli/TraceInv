/*
 *  SPDX-FileCopyrightText: Copyright 2021, Siavash Ameli <sameli@berkeley.edu>
 *  SPDX-License-Identifier: BSD-3-Clause
 *  SPDX-FileType: SOURCE
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the license found in the LICENSE.txt file in the root
 *  directory of this source tree.
 */


#ifndef _C_TRACE_ESTIMATOR_C_GOLUB_KAHN_BIDIAGONALIZATION_H_
#define _C_TRACE_ESTIMATOR_C_GOLUB_KAHN_BIDIAGONALIZATION_H_

// =======
// Headers
// =======

#include "../_c_linear_operator/c_linear_operator.h"  // cLinearOperator
#include "../_definitions/types.h"  // IndexType, LongIndexType, FlagType


// ============
// Declarations
// ============

// golub kahn bidiagonalization
template <typename DataType>
IndexType c_golub_kahn_bidiagonalization(
        cLinearOperator<DataType>* A,
        const DataType* v,
        const LongIndexType n,
        const IndexType m,
        const DataType lanczos_tol,
        const FlagType reorthogonalize,
        DataType* alpha,
        DataType* beta);

#endif  // _C_TRACE_ESTIMATOR_C_GOLUB_KAHN_BIDIAGONALIZATION_H_
