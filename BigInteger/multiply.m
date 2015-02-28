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

#import <Foundation/Foundation.h>

#import "BigInteger.h"
#import "private.h"

//========================================================================
// Multiplication functions. Depending on the magnitude of the operands,
// the operation is either performed using the naive bit-by-bit algorithm
// or either using the more optimised Karatsuba algorithm. The threshold
// that determine which algorithm is used is set by the constant below.
//========================================================================

#define KARATSUBA_CUTOFF		150

//--------------------------------------------------------------
// Perform a Karatsuba multiplication in the specified base.
//--------------------------------------------------------------

static void bigint_karatsuba(BIGINT * r, BIGINT * a, BIGINT * b, int base)
{
	// Extract x0 and x1 such as a = x1 * sizeof(bn_digit)^base + x0

	BIGINT x0, x1;

	bigint_alloc(&x0, base, NO);
	bigint_alloc(&x1, a->length - base, NO);
	x0.sign = x1.sign = NO;
	memcpy(x0.digits, a->digits, base * sizeof(bigint_digit));
	memcpy(x1.digits, a->digits + base, (a->length - base) * sizeof(bigint_digit));
	bigint_clamp(&x0, NO);

	// Extract y0 and y1 such as b = y1 * sizeof(bn_digit)^base + y0

	BIGINT y0, y1;

	bigint_alloc(&y0, base, NO);
	bigint_alloc(&y1, b->length - base, NO);
	y0.sign = y1.sign = NO;
	memcpy(y0.digits, b->digits, base * sizeof(bigint_digit));
	memcpy(y1.digits, b->digits + base, (b->length - base) * sizeof(bigint_digit));
	bigint_clamp(&y0, NO);

	// Compute z0 = x0 * y0 &nd z2 = x1 * y1.

	BIGINT z0, z2;

	bigint_multiply(&z2, &x1, &y1);
	bigint_multiply(&z0, &x0, &y0);

	// Compute z1 = (x0 + x1) * (y0 + y1) - z2 - z0

	BIGINT z1;

	bigint_add_magnitude(&x0, &x0, &x1);
	bigint_add_magnitude(&y0, &y0, &y1);
	bigint_multiply(&z1, &x0, &y0);
	bigint_sub_magnitude(&z1, &z1, &z2);
	bigint_sub_magnitude(&z1, &z1, &z0);

	// Sum all the parts together with the
	// proper shifts.

	bigint_digit * pr = r->digits;
	int j = -base;
	int k = -(base << 1);
	bigint_word carry = 0;

	for (int i = 0; i < r->length; i++, j++, k++)
	{
		bigint_word x = carry;
		if (i < z0.length) x += (bigint_word) z0.digits[i];
		if (j >= 0 && j < z1.length) x += (bigint_word) z1.digits[j];
		if (k >= 0 && k < z2.length) x += (bigint_word) z2.digits[k];

		*pr++ = (bigint_digit) x;
		carry = x >> (sizeof(bigint_digit) * 8);
	}
	
	// We should not have a carry left
	// at this point.

	assert(carry ==	0);

	// Clean up.

	bigint_free(&x0);
	bigint_free(&x1);
	bigint_free(&y0);
	bigint_free(&y1);
	bigint_free(&z0);
	bigint_free(&z1);
	bigint_free(&z2);
}

//--------------------------------------------------------------
// Multiply two BigInteger.
//--------------------------------------------------------------

void bigint_multiply(BIGINT * r, BIGINT * a, BIGINT * b)
{
	assert(r);
	assert(bigint_validate(a));
	assert(bigint_validate(b));
	assert(r != a);
	assert(r != b);
	
	// Eliminates the trivial case where
	// one of the operands is null.

	int n1 = a->length;
	int n2 = b->length;

	if (!n1 || !n2)
	{
		bigint_init32(r, 0, NO);
		return;
	}

	// Check if one of the operands is a
	// power of two.
	
	int k;

	if ((k = bigint_is_power_of_two(a)) >= 0)
	{
		// Operand A is a power of two. Left shift
		// the other operand.

		bigint_shift_left(r, b, k);
	}
	else if ((k = bigint_is_power_of_two(b)) >= 0)
	{
		// Operand B is a power of two. Left shift
		// the other operand.

		bigint_shift_left(r, a, k);
	}
	else
	{
		// No trivial optimisation. Alloc room
		// for the result and check the size
		// of the operands.

		bigint_alloc(r, n1 + n2, NO);

		if (n1 > KARATSUBA_CUTOFF && n2 > KARATSUBA_CUTOFF)
		{
			// Both operands are big. Use the Karatsuba
			// algorithm to perform the multiplication.

			k = (n1 <= n2) ? n1 : n2;
			bigint_karatsuba(r, a, b, k >> 1);
		}
		else
		{
			// One or both operands are small. Perform a
			// naive digit-by-digit multiplication.

			for (int i = 0; i < n1; i++)
			{
				bigint_word t = (bigint_word) a->digits[i];
				bigint_digit * p = r->digits + i;
				bigint_word carry = 0;

				bigint_digit * q = b->digits;
				for (int j = 0; j < n2; j++)
				{
					bigint_word x = (*p) + (t * (bigint_word) (*q++)) + carry;
					*p++ = (bigint_digit) x;
					carry = x >> (sizeof(bigint_digit) * 8);
				}

				if (carry) *p = (bigint_digit) carry;
			}
		}

		// Clamp the result.

		bigint_clamp(r, NO);
	}

	// Set the sign bit and validate.

	r->sign = (a->sign != b->sign) ? YES : NO;
	assert(bigint_validate(r));
}

//========================================================================
