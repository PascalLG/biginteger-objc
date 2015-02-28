//========================================================================
// Mac OS X and iOS BigInteger Library
// Copyright (c) 2012 - 2015, Pascal Levy
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//========================================================================

#ifndef PRIVATE_H
#define PRIVATE_H

//--------------------------------------------------------------
// Allocation / deallocation functions.
//--------------------------------------------------------------

void	bigint_alloc(BIGINT * a, int n, BOOL re);
void	bigint_init32(BIGINT * a, uint32_t x, BOOL sign);
void	bigint_copy(BIGINT * b, BIGINT * a, int extra);
void	bigint_free(BIGINT * a);
void	bigint_clamp(BIGINT * a, BOOL re);

#ifndef NDEBUG
BOOL	bigint_validate(BIGINT * a);
#endif

//--------------------------------------------------------------
// Arithmetic functions.
//--------------------------------------------------------------

NSComparisonResult	bigint_compare(BIGINT * a, BIGINT * b);
NSComparisonResult	bigint_compare_magnitude(BIGINT * a, BIGINT * b);

void	bigint_add_magnitude(BIGINT * r, BIGINT * a, BIGINT * b);
void	bigint_sub_magnitude(BIGINT * r, BIGINT * a, BIGINT * b);
void	bigint_add(BIGINT * r, BIGINT * a, BIGINT * b);
void	bigint_sub(BIGINT * r, BIGINT * a, BIGINT * b);

void	bigint_multiply(BIGINT * r, BIGINT * a, BIGINT * b);
void	bigint_divide(BIGINT * num, BIGINT * div, BIGINT * quo, BIGINT * rem);
void	bigint_exp(BIGINT * r, BIGINT * a, uint32_t b);
void	bigint_expmod(BIGINT * r, BIGINT * a, BIGINT * b, BIGINT * m);

void	bigint_shift_left(BIGINT * r, BIGINT * a, int count);
void	bigint_shift_right(BIGINT * r, BIGINT * a, int count);
int		bigint_is_power_of_two(BIGINT * a);
int		bigint_bitcount(BIGINT * x);

BOOL	bigint_is_prime(BIGINT * a);
void	bigint_euclide(BIGINT * a, BIGINT * b, BIGINT * d, BIGINT * x, BIGINT * y);

//--------------------------------------------------------------
// Bitwise functions.
//--------------------------------------------------------------

void	bigint_and(BIGINT * r, BIGINT * a, BIGINT * b);
void	bigint_or(BIGINT * r, BIGINT * a, BIGINT * b);
void	bigint_xor(BIGINT * r, BIGINT * a, BIGINT * b);
void	bigint_not(BIGINT * r, BIGINT * a, int width);

//--------------------------------------------------------------

#endif

//========================================================================
