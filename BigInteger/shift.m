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
// Shift functions.
//========================================================================

//--------------------------------------------------------------
// Left shift.
//--------------------------------------------------------------

void bigint_shift_left(BIGINT * r, BIGINT * a, int count)
{
	assert(r);
	assert(bigint_validate(a));
	assert(count >= 0);
	
	// Determine the required shift in term of
	// digits and in term of bits.

	int digitoff = count / (sizeof(bigint_digit) * 8);
	int bitoff = count - digitoff * (sizeof(bigint_digit) * 8);

	// Allocate room for the result, taking into account
	// an extra digit may be required if the highest digit
	// overflows on the left.

	int na = a->length;
	int n = na + digitoff;
	if (na && bitoff && (a->digits[na - 1] >> ((sizeof(bigint_digit) * 8) - bitoff)) != 0) n++;

	bigint_alloc(r, n, (r == a) ? YES : NO);
	r->sign = a->sign;

	// Shift the digits. This step can be bypassed if
	// the shift is null and the operation is performed
	// in place, i.e. R and A are the same.

	if (digitoff || r != a)
	{
		bigint_digit * pa = a->digits + na;
		bigint_digit * pr = r->digits + digitoff + na;

		int i;
		for (i = 0; i < na; i++) *--pr = *--pa;
		for (i = 0; i < digitoff; i++) *--pr = 0;
	}

	// Shift the bits. This step can be bypassed if
	// the shift value is null.

	if (bitoff)
	{
		bigint_digit * pr = r->digits + digitoff;
		bigint_word carry = 0;

		for (int i = digitoff; i < r->length; i++)
		{
			bigint_word x = (((bigint_word) *pr) << bitoff) | carry;
			*pr++ = (bigint_digit) x;
			carry = x >> (sizeof(bigint_digit) * 8);
		}
	}

	// Final validation.

	assert(bigint_validate(r));
}

//--------------------------------------------------------------
// Right shift.
//--------------------------------------------------------------

void bigint_shift_right(BIGINT * r, BIGINT * a, int count)
{
	assert(r);
	assert(bigint_validate(a));
	assert(count >= 0);

	// Determine the required shift in term of
	// digits and in term of bits.

	int digitoff = count / (sizeof(bigint_digit) * 8);
	int bitoff = count - digitoff * (sizeof(bigint_digit) * 8);

	// Allocate room for the result. If the result
	// is to have no digits, return 0 immediately.

	int na = a->length;
	int n = na - digitoff;
	if (n < 0) n = 0;

	bigint_alloc(r, n, (r == a) ? YES : NO);
	if (n == 0) return;

	r->sign = a->sign;

	// Shift the digits. This step can be bypassed if
	// the shift is null and the operation is performed
	// in place, i.e. R and A are the same.

	if (digitoff || r != a)
	{
		bigint_digit * pa = a->digits + digitoff;
		bigint_digit * pr = r->digits;

		int i;
		for (i = digitoff; i < na; i++) *pr++ = *pa++;
		for ( ; i < r->length; i++) *pr++ = 0;
	}

	// Shift the bits. This step can be bypassed if
	// the shift value is null.

	if (bitoff)
	{
		bigint_digit * pr = r->digits + r->length - 1;
		bigint_word carry = 0;
		
		for (int i = 0; i < r->length; i++)
		{
			bigint_word x = ((bigint_word) *pr) | carry;
			*pr-- = (bigint_digit) (x >> bitoff);
			carry = x << (sizeof(bigint_digit) * 8);
		}
	}

	// Clamp and validate.

	bigint_clamp(r, NO);
	assert(bigint_validate(r));
}

//========================================================================
