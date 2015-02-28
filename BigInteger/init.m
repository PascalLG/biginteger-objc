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
// Memory management routines.
//========================================================================

//--------------------------------------------------------------
// Allocates or reallocates the digit buffer to hold the specified
// number of digits. The buffer is zero'ed before the function returns.
//--------------------------------------------------------------

void bigint_alloc(BIGINT * a, int n, BOOL re)
{
	assert(a);
	assert(n >= 0);

	if (n > 0)
	{
		if (re)
		{
			if (n > a->alloc)
			{
				a->digits = (bigint_digit *) realloc(a->digits, n * sizeof(bigint_digit));
				memset(a->digits + a->alloc, 0, (n - a->alloc) * sizeof(bigint_digit));
			}
		}
		else
		{
			a->digits = (bigint_digit *) malloc(n * sizeof(bigint_digit));
			memset(a->digits, 0, n * sizeof(bigint_digit));
		}

		a->alloc = a->length = n;
	}
	else
	{
		if (re && a->alloc) free(a->digits);
		memset(a, 0, sizeof(BIGINT));
	}
}

//--------------------------------------------------------------
// Initializes a big integer with an unsigned 32-bit value.
//--------------------------------------------------------------

void bigint_init32(BIGINT * a, uint32_t x, BOOL sign)
{
	assert(a);

	if (x)
	{
#if SIZEOF_DIGIT == 2

		uint32_t hi = x >> 16;
		if (hi)
		{
			bigint_alloc(a, 2, NO);
			a->digits[0] = (bigint_digit) x;
			a->digits[1] = (bigint_digit) hi;
		}
		else
		{
			bigint_alloc(a, 1, NO);
			a->digits[0] = (bigint_digit) x;
		}

#elif SIZEOF_DIGIT == 4

		bigint_alloc(a, 1, NO);
		a->digits[0] = x;

#endif

		a->sign = sign;
	}
	else
	{
		memset(a, 0, sizeof(BIGINT));
	}

	assert(bigint_validate(a));
}

//--------------------------------------------------------------
// Copies a BigInteger to another BigInteger. Optionaly an extra
// space can be specified so the new BigInteger can accomodate
// new digits.
//--------------------------------------------------------------

void bigint_copy(BIGINT * b, BIGINT * a, int extra)
{
	assert(b);
	assert(bigint_validate(a));
	assert(a != b);
	assert(extra >= 0);

	b->sign = a->sign;
	b->length = a->length;
	b->alloc = a->length + extra;

	if (b->alloc)
	{
		b->digits = (bigint_digit *) malloc(b->alloc * sizeof(bigint_digit));
		memcpy(b->digits, a->digits, b->length * sizeof(bigint_digit));
		memset(b->digits + b->length, 0, (b->alloc - b->length) * sizeof(bigint_digit));
	}

	assert(bigint_validate(b));
}

//--------------------------------------------------------------
// Deallocates a BigInteger.
//--------------------------------------------------------------

void bigint_free(BIGINT * a)
{
	assert(a);

	if (a->digits) free(a->digits);
	memset(a, 0, sizeof(BIGINT));
}

//--------------------------------------------------------------
// Updates the number of digit actually used by a big integer.
// Optionaly the digit buffer can be reallocated to save space.
//--------------------------------------------------------------

void bigint_clamp(BIGINT * a, BOOL re)
{
	assert(a);

	// Find the last used digit.

	int k = a->alloc;
	while (k > 0 && !a->digits[k - 1]) k--;
	a->length = k;

	// If all digits are zero, cancel
	// the sign bit.

	if (!k) a->sign = NO;

	// Reallocate the buffer to save space, if
	// specified.

	if (re)
	{
		if (k)
		{
			a->digits = (bigint_digit *) realloc(a->digits, k * sizeof(bigint_digit));
			a->alloc = k;
		}
		else
		{
			bigint_free(a);
		}
	}
}

//--------------------------------------------------------------
// Validates a BigInteger. This function is used to check
// consistency when unit testing the debug version of the
// library.
//--------------------------------------------------------------

#ifndef NDEBUG
BOOL bigint_validate(BIGINT * a)
{
	// Check the BIGINT value exists.

	if (!a)
	{
		return NO;
	}
	
	// Check the length of the integer
	// is consistent.

	int k = a->alloc;
	while (k > 0 && !a->digits[k - 1]) k--;

	if (k != a->length)
	{
		return NO;
	}

	// Check zero is always positive.

	if (!k && a->sign)
	{
		return NO;
	}

	return YES;
}
#endif

//========================================================================
