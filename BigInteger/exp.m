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
// Exponentiation functions.
//========================================================================

//--------------------------------------------------------------
// Regular exponentiation.
//--------------------------------------------------------------

void bigint_exp(BIGINT * r, BIGINT * a, uint32_t b)
{
	assert(r);
	assert(bigint_validate(a));
	assert(r != a);

	// Initialize the result.

	bigint_init32(r, 1, NO);

	// Initialize the mask to the leftmost
	// bit of the exponent.

	uint32_t m = ((uint32_t) 1) << (sizeof(uint32_t) * 8 - 1);
	while (m != 0 && (b & m) == 0) m >>= 1;
	
	// Do the exponentiation with the square-and-multiply
	// algorithm.

	while (m)
	{
		BIGINT t;
		bigint_multiply(&t, r, r);
		bigint_free(r);
		memcpy(r, &t, sizeof(BIGINT));

		if ((b & m) != 0)
		{
			bigint_multiply(&t, r, a);
			bigint_free(r);
			memcpy(r, &t, sizeof(BIGINT));
		}

		m >>= 1;
	}

	// Validate the result.

	assert(bigint_validate(r));
}

//--------------------------------------------------------------
// Modular exponentiation.
//--------------------------------------------------------------

void bigint_expmod(BIGINT * r, BIGINT * a, BIGINT * b, BIGINT * m)
{
	assert(r);
	assert(bigint_validate(a));
	assert(bigint_validate(b));
	assert(bigint_validate(m));
	assert(r != a);
	assert(r != b);
	assert(r != m);
	
	// Initialize the result and copy the base
	// in a local variable.

	BIGINT s;
	bigint_copy(&s, a, 0);
	bigint_init32(r, 1, NO);

	// Do the exponentiation with the square-and-multiply
	// algorithm.

	int n = b->length - 1;
	for (int i = 0; i <= n; i++)
	{
		bigint_digit d = b->digits[i];
		for (int j = 0; j < sizeof(bigint_digit) * 8; j++)
		{
			BIGINT x;

			if ((d & 1) != 0)
			{
				bigint_multiply(&x, &s, r);
				bigint_free(r);
				bigint_divide(&x, m, NULL, r);
				bigint_free(&x);
			}

			bigint_multiply(&x, &s, &s);
			bigint_free(&s);
			bigint_divide(&x, m, NULL, &s);
			bigint_free(&x);

			d >>= 1;
			if (i == n && d == 0) break;
		}
	}

	// Validate the result.

	assert(bigint_validate(r));
}

//========================================================================
