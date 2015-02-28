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
// Euclide's algorithm, to efficently determine the greatest common divisor
// of two numbers.
//========================================================================

//--------------------------------------------------------------
// Extended Euclide's algorithm.
//--------------------------------------------------------------

void bigint_euclide(BIGINT * a, BIGINT * b, BIGINT * d, BIGINT * x, BIGINT * y)
{
	assert(bigint_validate(a));
	assert(bigint_validate(b));

	if (!b->length)
	{
		if (d) bigint_copy(d, a, 0);
		if (x) bigint_init32(x, 1, NO);
		if (y) bigint_init32(y, 0, NO);
	}
	else
	{
		BIGINT	q, r, z;

		bigint_divide(a, b, &q, &r);
		bigint_euclide(b, &r, d, x, y);
		bigint_free(&r);

		if (x && y)
		{
			bigint_multiply(&z, &q, y);
			bigint_sub(&z, x, &z);

			bigint_free(x);
			memcpy(x, y, sizeof(BIGINT));
			memcpy(y, &z, sizeof(BIGINT));
		}

		bigint_free(&q);
	}
}

//========================================================================
