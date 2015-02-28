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
// Routines related to prime numbers.
//========================================================================

//--------------------------------------------------------------
// Table of the 256 first prime numbers.
//--------------------------------------------------------------

static const bigint_digit primeTab[] =
{
	   2,     3,     5,     7,    11,    13,    17,    19,    23,    29,
	  31,    37,    41,    43,    47,    53,    59,    61,    67,    71,
	  73,    79,    83,    89,    97,   101,   103,   107,   109,   113,
	 127,   131,   137,   139,   149,   151,   157,   163,   167,   173,
	 179,   181,   191,   193,   197,   199,   211,   223,   227,   229,
	 233,   239,   241,   251,   257,   263,   269,   271,   277,   281,
	 283,   293,   307,   311,   313,   317,   331,   337,   347,   349,
	 353,   359,   367,   373,   379,   383,   389,   397,   401,   409,
	 419,   421,   431,   433,   439,   443,   449,   457,   461,   463,
	 467,   479,   487,   491,   499,   503,   509,   521,   523,   541,
	 547,   557,   563,   569,   571,   577,   587,   593,   599,   601,
	 607,   613,   617,   619,   631,   641,   643,   647,   653,   659,
	 661,   673,   677,   683,   691,   701,   709,   719,   727,   733,
	 739,   743,   751,   757,   761,   769,   773,   787,   797,   809,
	 811,   821,   823,   827,   829,   839,   853,   857,   859,   863,
	 877,   881,   883,   887,   907,   911,   919,   929,   937,   941,
	 947,   953,   967,   971,   977,   983,   991,   997,  1009,  1013,
	1019,  1021,  1031,  1033,  1039,  1049,  1051,  1061,  1063,  1069,
	1087,  1091,  1093,  1097,  1103,  1109,  1117,  1123,  1129,  1151,
	1153,  1163,  1171,  1181,  1187,  1193,  1201,  1213,  1217,  1223,
	1229,  1231,  1237,  1249,  1259,  1277,  1279,  1283,  1289,  1291,
	1297,  1301,  1303,  1307,  1319,  1321,  1327,  1361,  1367,  1373,
	1381,  1399,  1409,  1423,  1427,  1429,  1433,  1439,  1447,  1451,
	1453,  1459,  1471,  1481,  1483,  1487,  1489,  1493,  1499,  1511,
	1523,  1531,  1543,  1549,  1553,  1559,  1567,  1571,  1579,  1583,
	1597,  1601,  1607,  1609,  1613,  1619
};

//========================================================================

//--------------------------------------------------------------
// The Miller Rabin witness function.
//--------------------------------------------------------------

static BOOL witness(bigint_digit a, BIGINT * bd, BIGINT * bn, BIGINT * bnm1, int s)
{
	// Compute A^D mod N. If it is 1 or N-1 then
	// return probably prime.

	BIGINT	ba;
	ba.length = ba.alloc = 1;
	ba.digits = &a;
	ba.sign = NO;

	BIGINT	bx;
	bigint_expmod(&bx, &ba, bd, bn);
	if ((bx.length == 1 && bx.digits[0] == 1) || (bigint_compare_magnitude(&bx, bnm1) == NSOrderedSame))
	{
		bigint_free(&bx);
		return YES;
	}

	// Try to find A^(2^j) = 1 for 0 < j < s.

	for (int j = 1; j < s; j++)
	{
		BIGINT bt;
		bigint_multiply(&bt, &bx, &bx);
		bigint_free(&bx);
		bigint_divide(&bt, bn, NULL, &bx);
		bigint_free(&bt);

		if (bx.length == 1 && bx.digits[0] == 1)
		{
			bigint_free(&bx);
			return NO;
		}

		if (bigint_compare_magnitude(&bx, bnm1) == NSOrderedSame)
		{
			bigint_free(&bx);
			return YES;
		}
	}

	bigint_free(&bx);
	return NO;
}

//--------------------------------------------------------------
// Checks whether a number is probably prime, using successive
// tests: detection of trivial cases, direct division by small
// primes, and finally Miller Rabin test is several bases.
//--------------------------------------------------------------

BOOL bigint_is_prime(BIGINT * bn)
{
	assert(bigint_validate(bn));
	assert(!bn->sign);

	// Eliminate the trivial case where
	// the number is zero.

	if (!bn->length) return NO;

	// If the number is small enough to occupy only
	// one digit, check it against small primes.

	int sqrt = INT_MAX;
	bigint_digit r;

	if (bn->length == 1)
	{
		r = bn->digits[0];
		if (r < 2) return NO;

		for (int i = 0; i < (sizeof(primeTab) / sizeof(primeTab[0])); i++)
			if (primeTab[i] == r)
				return YES;

		sqrt = (int) sqrtf((float) r);
	}

	// Try to divise the number by the primes in
	// our table, to eliminate trivial composites.

	BIGINT ba;
	ba.length = ba.alloc = 1;
	ba.digits = &r;
	ba.sign = NO;

	for (int i = 0; i < (sizeof(primeTab) / sizeof(primeTab[0])); i++)
	{
		r = primeTab[i];
		if (r > sqrt) break;	// we reach sqrt(bn), no need to continue.

		BIGINT bx;
		bigint_divide(bn, &ba, NULL, &bx);
		int len = bx.length;
		bigint_free(&bx);

		if (!len) return NO;	// The number is divisible by a prime: it is composite.
	}

	// Compute NM1 = N - 1

	r = 1;
	BIGINT bnm1;
	bigint_sub_magnitude(&bnm1, bn, &ba);
	bnm1.sign = NO;

	// Compute S and D so that NM1 = 2^S * D

	int k = 0, i = 0;
	while (bnm1.digits[k] == 0) k++;
	while ((bnm1.digits[k] & (1 << i)) == 0) i++;

	BIGINT bd;
	int s = (k * sizeof(bigint_digit) * 8) + i;
	bigint_shift_right(&bd, &bnm1, s);

	// Determine the number of iterations to perform to
	// obtain a good certainty, depending on the size of
	// the number expressed in bits.

	k = bn->length * sizeof(bigint_digit) * 8;
	int count;

	if		(k < 128)	count = 30;
	else if (k < 256)	count = 18;
	else if (k < 384)	count = 12;
	else if (k < 512)	count = 8;
	else if (k < 640)	count = 7;
	else if (k < 768)	count = 6;
	else				count = 5;

	// Perform the Miller Rabin trials, picking up
	// the base in our prime table. As soon as
	// a witness is found, return composite.

	BOOL prime = YES;
	for (int i = 0; i < count; i++)
	{
		r = primeTab[i * 5];
		if (!witness(r, &bd, bn, &bnm1, s))
		{
			prime = NO;
			break;
		}
	}

	// Cleanup and return.

	bigint_free(&bd);
	bigint_free(&bnm1);
	return prime;
}

//========================================================================
