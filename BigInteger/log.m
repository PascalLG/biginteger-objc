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
// Log functions.
//========================================================================

//--------------------------------------------------------------
// Compute the bit count, i.e. ~ log2(x).
//--------------------------------------------------------------

int bigint_bitcount(BIGINT * x)
{
	int c = x->length * sizeof(bigint_digit) * 8;
	if (c)
	{
		bigint_digit t = x->digits[x->length - 1];
		while ((t & (1 << (sizeof(bigint_digit) * 8 - 1))) == 0)
		{
			t <<= 1;
			c--;
		}
	}

	return c;
}

//--------------------------------------------------------------
// Returns the log2 of a big integer if it is an exact power
// of two, or -1 otherwise.
//--------------------------------------------------------------

int bigint_is_power_of_two(BIGINT * a)
{
	assert(bigint_validate(a));

	// Eliminate the trivial case a = 0.

	int n = a->length - 1;
	if (n < 0) return -1;

	// Check that all digits between 0 and length-1 are null.

	bigint_digit * pa = a->digits;
	for (int i = 0; i < n; i++)
		if (*pa++ != 0)
			return -1;

	// Check the last digit contains a power of two.

	for (int i = 0; i < sizeof(bigint_digit) * 8; i++)
		if (*pa == (bigint_digit) (1 << i))
			return i + n * sizeof(bigint_digit) * 8;

	return -1;
}

//========================================================================
