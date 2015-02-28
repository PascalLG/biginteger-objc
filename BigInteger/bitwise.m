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
// Bitwise operators.
//========================================================================

//--------------------------------------------------------------
// Bitwise AND. Signs are not taken into account.
//--------------------------------------------------------------

void bigint_and(BIGINT * r, BIGINT * a, BIGINT * b)
{
	assert(r);
	assert(bigint_validate(a));
	assert(bigint_validate(b));
	assert(r != a && r != b);

	// Check both parameters are not null.

	if (a->length && b->length)
	{
		// Allocate room for the result. It will not exceed
		// the size of the shortest parameter.

		int n = (a->length <= b->length) ? a->length : b->length;
		bigint_alloc(r, n, NO);

		// Do the bitwise AND.

		bigint_digit * pr = r->digits;
		bigint_digit * pa = a->digits;
		bigint_digit * pb = b->digits;
		while (n--) *pr++ = (*pa++) & (*pb++);
	}
	else
	{
		// One of the parameters is null. The result
		// is zero.

		memset(r, 0, sizeof(BIGINT));
	}

	// Clamp and validate.

	bigint_clamp(r, YES);
	assert(bigint_validate(r));
}

//--------------------------------------------------------------
// Bitwise OR. Signs are not taken into account.
//--------------------------------------------------------------

void bigint_or(BIGINT * r, BIGINT * a, BIGINT * b)
{
	assert(r);
	assert(bigint_validate(a));
	assert(bigint_validate(b));
	assert(r != a && r != b);

	if (!a->length)
	{
		// Parameter A is zero. The result is B.

		bigint_copy(r, b, 0);
	}
	else if (!b->length)
	{
		// Parameter B is zero. The result is A.

		bigint_copy(r, a, 0);
	}
	else
	{
		// Both parameters are non null. The result will
		// be as wide as the largest parameter.

		bigint_digit * pu;
		int n;

		if (a->length >= b->length)
		{
			bigint_copy(r, a, 0);
			pu = b->digits;
			n = b->length;
		}
		else
		{
			bigint_copy(r, b, 0);
			pu = a->digits;
			n = a->length;
		}

		bigint_digit * pr = r->digits;
		while (n--) *pr++ |= *pu++;
	}

	// Validate. No need to clamp, we know the result
	// cannot be shorter than the longest argument.

	assert(bigint_validate(r));
}

//--------------------------------------------------------------
// Bitwise XOR. Signs are not taken into account.
//--------------------------------------------------------------

void bigint_xor(BIGINT * r, BIGINT * a, BIGINT * b)
{
	assert(r);
	assert(bigint_validate(a));
	assert(bigint_validate(b));
	assert(r != a && r != b);

	if (!a->length)
	{
		// Parameter A is zero. The result is B.

		bigint_copy(r, b, 0);
	}
	else if (!b->length)
	{
		// Parameter B is zero. The result is A.

		bigint_copy(r, a, 0);
	}
	else
	{
		// Both parameters are non null. The result will
		// be as wide as the largest parameter.

		bigint_digit * pu;
		int n;

		if (a->length >= b->length)
		{
			bigint_copy(r, a, 0);
			pu = b->digits;
			n = b->length;
		}
		else
		{
			bigint_copy(r, b, 0);
			pu = a->digits;
			n = a->length;
		}

		bigint_digit * pr = r->digits;
		while (n--) *pr++ ^= *pu++;
	}

	// Clamp and validate.

	bigint_clamp(r, YES);
	assert(bigint_validate(r));
}

//--------------------------------------------------------------
// Bitwise NOT. Signs are not taken into account.
//--------------------------------------------------------------

void bigint_not(BIGINT * r, BIGINT * a, int width)
{
	assert(r);
	assert(bigint_validate(a));
	assert(width > 0);

	// Retrieve the bitcount and check the width
	// is enough.

	int n = bigint_bitcount(a);
	if (width < n) width = n;

	// (Re)alloc room for the result.

	n = ((width - 1) / (sizeof(bigint_digit) * 8)) + 1;
	bigint_alloc(r, n, (r == a) ? YES : NO);

	// Perform the bitwise NOT.

	bigint_digit * pv = r->digits;
	bigint_digit * pu = a->digits;

	int i;
	for (i = 0; i < a->length; i++) *pv++ = ~*pu++;
	for ( ; i < n; i++) *pv++ = ~((bigint_digit) 0);

	// Mask the upper bits, if necessary.

	bigint_digit mask = (1 << (width % (sizeof(bigint_digit) * 8))) - 1;
	if (mask) r->digits[r->length - 1] &= mask;

	// Clamp and validate.

	bigint_clamp(r, YES);
	assert(bigint_validate(r));
}

//========================================================================
