/*
 *  SPDX-FileCopyrightText: Copyright 2021, Siavash Ameli <sameli@berkeley.edu>
 *  SPDX-License-Identifier: BSD-3-Clause
 *  SPDX-FileType: SOURCE
 *
 *  This program is free software: you can redistribute it and/or modify it
 *  under the terms of the license found in the LICENSE.txt file in the root
 *  directory of this source tree.
 */


// =======
// Headers
// =======

#include "./cu_dense_affine_matrix_function.h"
#include <cstddef>  // NULL
#include <cassert>  // assert
#include "../_definitions/debugging.h"  // ASSERT


// =============
// constructor 1
// =============

/// \brief Constructor. Matrix \c B is assumed to be the identity matrix.
///

template <typename DataType>
cuDenseAffineMatrixFunction<DataType>::cuDenseAffineMatrixFunction(
        const DataType* A_,
        const FlagType A_is_row_major_,
        const LongIndexType num_rows_,
        const LongIndexType num_columns_):

    // Base class constructor
    cLinearOperator<DataType>(num_rows_, num_columns_),

    // Initializer list
    A(A_, num_rows_, num_columns_, A_is_row_major_)
{
    // This constructor is called assuming B is identity
    this->B_is_identity = true;

    // When B is identity, the eigenvalues of A+tB are known for any t
    this->eigenvalue_relation_known = 1;

    // Set gpu device
    this->initialize_cublas_handle();
}


// =============
// constructor 2
// =============

template <typename DataType>
cuDenseAffineMatrixFunction<DataType>::cuDenseAffineMatrixFunction(
        const DataType* A_,
        const FlagType A_is_row_major_,
        const LongIndexType num_rows_,
        const LongIndexType num_columns_,
        const DataType* B_,
        const FlagType B_is_row_major_):

    // Base class constructor
    cLinearOperator<DataType>(num_rows_, num_columns_),

    // Initializer list
    A(A_, num_rows_, num_columns_, A_is_row_major_),
    B(B_, num_rows_, num_columns_, B_is_row_major_)
{
    // Matrix B is assumed to be non-zero. Check if it is identity or generic
    if (this->B.is_identity_matrix())
    {
        this->B_is_identity = true;
        this->eigenvalue_relation_known = 1;
    }

    // Set gpu device
    this->initialize_cublas_handle();
}


// ==========
// destructor
// ==========

template <typename DataType>
cuDenseAffineMatrixFunction<DataType>::~cuDenseAffineMatrixFunction()
{
}


// ===
// dot
// ===

/// \brief      Computes the matrix vector product:
///             \f[
///                 \boldsymbol{c} = (\mathbf{A} + t \mathbf{B})
///                 \boldsymbol{b}.
///             \f]
///
/// \param[in]  vector
///             The input vector :math:`\\boldsymbol{b}` is given by \c vector.
///             If \f$ \mathbf{A} \f$ and \f$ \mathbf{B} \f$ are \f$ m \times n
///             \f$ matrices, the length of input c vector is \c n.
/// \param[out] product
///             The output of the product, \f$ \boldsymbol{c} \f$, is written
///             in-place into this array. Let \n m be the number of rows of \f$
///             \mathbf{A} \f$ and \f$ \mathbf{B} \f$, then, the output vector
///             \c product is 1D column array of length \c m.

template <typename DataType>
void cuDenseAffineMatrixFunction<DataType>::dot(
        const DataType* vector,
        DataType* product)
{
    // Matrix A times vector
    this->A.dot(vector, product);
    LongIndexType min_vector_size;

    // Matrix B times vector to be added to the product
    if (this->B_is_identity)
    {
        // Check parameter is set
        ASSERT((this->parameters != NULL), "Parameter is not set.");

        // Find minimum of the number of rows and columns
        min_vector_size = \
            (this->num_rows < this->num_columns) ? \
            this->num_rows : this->num_columns;

        // Adding input vector to product
        this->_add_scaled_vector(vector, min_vector_size,
                                 this->parameters[0], product);
    }
    else
    {
        // Check parameter is set
        ASSERT((this->parameters != NULL), "Parameter is not set.");

        // Adding parameter times B times input vector to the product
        this->B.dot_plus(vector, this->parameters[0], product);
    }
}


// =============
// transpose dot
// =============

/// \brief      Computes the matrix vector product:
///             \f[
///                 \boldsymbol{c} = (\mathbf{A} + t \mathbf{B})^{\intercal}
///                 \boldsymbol{b}.
///             \f]
///
/// \param[in]  vector
///             The input vector \f$ \boldsymbol{b} \f$ is given by \c vector.
///             If \f$ \mathbf{A} \f$ and \f$ \mathbf{B} \f$ are \f$ m \times n
///             \f$ matrices, the length of input \c vector is \c n.
///
/// \param[out] product
///             The output of the product, \f$ \boldsymbol{c} \f$, is written
///             in-place into this array. Let \c n be the number of columns of
///             \f$ \mathbf{A} \f$ and \f$ \mathbf{B} \f$, then, the output
///             vector \c product is 1D column array of length \c m.

template <typename DataType>
void cuDenseAffineMatrixFunction<DataType>::transpose_dot(
        const DataType* vector,
        DataType* product)
{
    // Matrix A times vector
    this->A.transpose_dot(vector, product);
    LongIndexType min_vector_size;

    // Matrix B times vector to be added to the product
    if (this->B_is_identity)
    {
        // Check parameter is set
        ASSERT((this->parameters != NULL), "Parameter is not set.");

        // Find minimum of the number of rows and columns
        min_vector_size = \
            (this->num_rows < this->num_columns) ? \
            this->num_rows : this->num_columns;

        // Adding input vector to product
        this->_add_scaled_vector(vector, min_vector_size,
                                 this->parameters[0], product);
    }
    else
    {
        // Check parameter is set
        ASSERT((this->parameters != NULL), "Parameter is not set.");

        // Adding "parameter * B * input vector" to the product
        this->B.transpose_dot_plus(vector, this->parameters[0], product);
    }
}


// ===============================
// Explicit template instantiation
// ===============================

template class cuDenseAffineMatrixFunction<float>;
template class cuDenseAffineMatrixFunction<double>;
