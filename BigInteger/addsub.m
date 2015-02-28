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
// Addition and subtraction functions.
//========================================================================

//--------------------------------------------------------------
// Adds two BigInteger, not taking signs into account.
//--------------------------------------------------------------

void bigint_add_magnitude(BIGINT * r, BIGINT * a, BIGINT * b)
{
	assert(r);
	assert(bigint_validate(a));
	assert(bigint_validate(b));

	// Determine which number has the more digits
	// and allocate room for result. Operation can
	// be performed in-place: r may be equal to a or b.

	bigint_digit * pa, * pb;
	int	na, nb;

	if (a->length >= b->length)
	{
		na = a->length;
		nb = b->length;
		bigint_alloc(r, na + 1, (r == a || r == b) ? YES : NO);
		pa = a->digits;	// get theses pointers AFTER reallocating.
		pb = b->digits;
	}
	else
	{
		na = b->length;
		nb = a->length;
		bigint_alloc(r, na + 1, (r == a || r == b) ? YES : NO);
		pa = b->digits;	// get theses pointers AFTER reallocating.
		pb = a->digits;
	}

	// Set the carry to zero, then add the lowest
	// digits of the two numbers.

	bigint_digit * pr = r->digits;
	r->length = na;
	bigint_word carry = 0;

	int i;
	for (i = 0; i < nb; i++)
	{
		bigint_word x = ((bigint_word) *pa++) + ((bigint_word) *pb++) + carry;
		*pr++ = (bigint_digit) x;
		carry = x >> (sizeof(bigint_digit) * 8);
	}

	// Propagate the carry through highest digits
	// of the longest number.

	for ( ; i < na; i++)
	{
		bigint_word x = ((bigint_word) *pa++) + carry;
		*pr++ = (bigint_digit) x;
		carry = x >> (sizeof(bigint_digit) * 8);
	}

	// If we still have a carry, increase the length
	// of the result by one and report the carry.

	if (carry)
	{
		r->length++;
		*pr = (bigint_digit) carry;
	}

	// Validation.

	assert(bigint_validate(r));
}

//--------------------------------------------------------------
// Subtracts two BigInteger, not taking signs into account. This
// methods expects that a > b.
//--------------------------------------------------------------

void bigint_sub_magnitude(BIGINT * r, BIGINT * a, BIGINT * b)
{
	assert(r);
	assert(bigint_validate(a));
	assert(bigint_validate(b));
	assert(bigint_compare_magnitude(a, b) >= 0);

	// Allocate room for the result. Operation can
	// be performed in-place: r may be equal to a or b.

	int na = a->length;
	int nb = b->length;
	bigint_alloc(r, na, (r == a || r == b) ? YES : NO);

	// Set the carry to zero, then subtract the
	// lowest digits of the two numbers.

	bigint_digit * pr = r->digits;
	bigint_digit * pa = a->digits;
	bigint_digit * pb = b->digits;
	bigint_word carry = 0;

	int i;
	for (i = 0; i < nb; i++)
	{
		bigint_word x = ((bigint_word) *pa++) - ((bigint_word) *pb++) - carry;
		*pr++ = (bigint_digit) x;
		carry = x >> ((sizeof(bigint_word) * 8) - 1);
	}

	// Propagate the carry through highest digits
	// of the longer number.

	for ( ; i < na; i++)
	{
		bigint_word x = ((bigint_word) *pa++) - carry;
		*pr++ = (bigint_digit) x;
		carry = x >> ((sizeof(bigint_word) * 8) - 1);
	}

	// By definition, the result is lower than the initial
	// value, so we cannot have a carry left here.

	assert(carry == 0);

	// Clamp and validate.

	bigint_clamp(r, YES);
	assert(bigint_validate(r));
}

//--------------------------------------------------------------
// Adds two BigInteger, taking signs into account.
//--------------------------------------------------------------

void bigint_add(BIGINT * r, BIGINT * a, BIGINT * b)
{
	NSComparisonResult	cmp;

	if (a->sign == b->sign)
	{
		// The two operands have the same sign. Just
		// add them.

		bigint_add_magnitude(r, a, b);
		r->sign = a->sign;
	}
	else
	{
		// The two operands have different signs. Subtract
		// the greatest from the lowest and set the result
		// sign accordingly.

		cmp = bigint_compare_magnitude(a, b);
		if (cmp >= 0)
		{
			bigint_sub_magnitude(r, a, b);
			r->sign = a->sign;
		}
		else
		{
			bigint_sub_magnitude(r, b, a);
			r->sign = b->sign;
		}
	}

	// Cancel the sign bit if the result is
	// zero and validate.

	if (!r->length) r->sign = NO;
	assert(bigint_validate(r));
}

//--------------------------------------------------------------
// Subtract two BigInteger, taking sign into account.
//--------------------------------------------------------------

void bigint_sub(BIGINT * r, BIGINT * a, BIGINT * b)
{
	NSComparisonResult	cmp;

	if (a->sign == b->sign)
	{
		// The two operands have the same sign. Subtract
		// the greatest from the lowest and set the sign
		// accordingly.

		cmp = bigint_compare_magnitude(a, b);
		if (cmp >= 0)
		{
			bigint_sub_magnitude(r, a, b);
			r->sign = a->sign;
		}
		else
		{
			bigint_sub_magnitude(r, b, a);
			r->sign = !a->sign;
		}
	}
	else
	{
		// The two operands have opposite signs. Add them
		// and set the sign accordingly.

		bigint_add_magnitude(r, a, b);
		r->sign = a->sign;
	}

	// Cancel the sign bit if the result is
	// zero and validate.

	if (!r->length) r->sign = NO;
	assert(bigint_validate(r));
}

//========================================================================
