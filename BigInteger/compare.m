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
// Comparison functions.
//========================================================================

//--------------------------------------------------------------
// Compares the magnitude of two bigints. The sign is ignored.
//--------------------------------------------------------------

NSComparisonResult bigint_compare_magnitude(BIGINT * a, BIGINT * b)
{
	assert(bigint_validate(a));
	assert(bigint_validate(b));

	// Compare the bit length.

	if (a->length > b->length) return NSOrderedDescending;
	if (a->length < b->length) return NSOrderedAscending;

	// If bit lengts are equal, then compare
	// digit by digit.

	int n = a->length - 1;
	bigint_digit * ta = a->digits + n;
	bigint_digit * tb = b->digits + n;

	for (int i = 0; i <= n; i++)
	{
		if (*ta > *tb) return NSOrderedDescending;
		if (*ta < *tb) return NSOrderedAscending;
		ta--;
		tb--;
	}

	// The two numbers are equal.

	return NSOrderedSame;
}

//--------------------------------------------------------------
// Compares two bigints.
//--------------------------------------------------------------

NSComparisonResult bigint_compare(BIGINT * a, BIGINT * b)
{
	NSComparisonResult	r;

	assert(bigint_validate(a));
	assert(bigint_validate(b));

	if (a->sign != b->sign)
	{
		// Opposite sign. No need to compare
		// the actual digits.

		if (a->sign)	r = NSOrderedAscending;
		else			r = NSOrderedDescending;
	}
	else
	{
		// Same sign. Compare the digits.

		if (a->sign)	r = bigint_compare_magnitude(b, a);
		else			r = bigint_compare_magnitude(a, b);
	}

	return r;
}

//========================================================================
