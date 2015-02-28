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
// Division function.
//========================================================================

//--------------------------------------------------------------
// Performs a bit by bit division.
//--------------------------------------------------------------

static void divide(BIGINT * num, BIGINT * div, BIGINT * quo, BIGINT * rem)
{
	// Allocate room for the quotient and the
	// remainder.

	if (quo) bigint_alloc(quo, num->length - div->length + 1, NO);
	bigint_alloc(rem, div->length + 1, NO);
	rem->length = 0;
	rem->sign = NO;

	// Then perform the division.
	
	for (int i = num->length - 1; i >= 0; i--)
	{
		bigint_digit * pn = num->digits + i;
		bigint_digit * pq = (quo) ? quo->digits + i : NULL;

		for (bigint_digit m = ((bigint_digit) 1) << ((sizeof(bigint_digit) * 8) - 1); m; m >>= 1)
		{
			// Compute R = (R << 1) + N[i].

			bigint_digit * pr = rem->digits;
			bigint_word carry = ((*pn & m) != 0) ? 1 : 0;

			for (int k = 0; k < rem->length; k++)
			{
				bigint_word x = (((bigint_word) *pr) << 1) | carry;
				*pr++ = (bigint_digit) x;
				carry = x >> (sizeof(bigint_digit) * 8);
			}

			if (carry)
			{
				rem->length++;
				*pr = (bigint_digit) carry;
			}

			// Test if R >= D.
			
			if (bigint_compare_magnitude(rem, div) >= NSOrderedSame)
			{
				// Compute R = R - D.

				bigint_digit * pr = rem->digits;
				bigint_digit * pd = div->digits;

				bigint_word carry = 0;
				for (int k = 0; k < div->length; k++)
				{
					bigint_word x = ((bigint_word) *pr) - ((bigint_word) *pd++) - carry;
					*pr++ = (bigint_digit) x;
					carry = x >> ((sizeof(bigint_word) * 8) - 1);
				}

				if (carry)
				{
					(*pr)--;
				}

				while (rem->length && !rem->digits[rem->length - 1]) rem->length--;

				// Update the quotient.

				if (quo) *pq |= m;
			}
		}
	}

	// Clamp and validate.

	assert(bigint_validate(rem));
	if (quo) bigint_clamp(quo, NO);
}

//--------------------------------------------------------------
// Divides two BigInteger and optionaly returns the quotient
// and/or the remainder.
//--------------------------------------------------------------

void bigint_divide(BIGINT * num, BIGINT * div, BIGINT * quo, BIGINT * rem)
{
	assert(bigint_validate(num));
	assert(bigint_validate(div));
	assert(div->length);

	// Choose the algorithm depending on the dividend
	// and divisor.

	if (!num->length)
	{
		// The dividend is zero. Return zero for both
		// the quotient and the remainder.

		if (quo) bigint_init32(quo, 0, NO);
		if (rem) bigint_init32(rem, 0, NO);
	}
	else
	{
		int k = bigint_is_power_of_two(div);

		if (k > 0)
		{
			// The divisor is a power of two. Use a shift
			// right to compute the quotient.

			if (quo)
			{
				bigint_shift_right(quo, num, k);
			}

			// Then use a bitmask to compute the remainder.

			if (rem)
			{
				int n = ((k - 1) / (sizeof(bigint_digit) * 8)) + 1;
				int j = k - (n - 1) * sizeof(bigint_digit) * 8;

				if (n > num->length)
				{
					n = num->length;
					j = sizeof(bigint_digit) * 8;
				}

				bigint_alloc(rem, n, NO);
				memcpy(rem->digits, num->digits, n * sizeof(bigint_digit));
				if (j < sizeof(bigint_digit) * 8) rem->digits[rem->length - 1] &= (((bigint_digit) 1 << (bigint_digit) j) - (bigint_digit) 1);

				bigint_clamp(rem, NO);
			}
		}
		else if (k == 0)
		{
			// The divisor is 1. Copy the dividend to the
			// quotient and set the remainder to 0.

			if (quo) bigint_copy(quo, num, 0);
			if (rem) bigint_init32(rem, 0, NO);
		}
		else
		{
			// Default case. Use a bit by bit division
			// algorithm.

			BIGINT r;
			divide(num, div, quo, (rem) ? rem : &r);
			if (!rem) bigint_free(&r);
		}

		// Set the sign bits of both the quotient and
		// the remainder.

		if (quo) quo->sign = (quo->length != 0 && num->sign != div->sign) ? YES : NO;
		if (rem) rem->sign = (rem->length) ? num->sign : NO;
	}
}

//========================================================================
