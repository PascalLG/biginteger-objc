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

//--------------------------------------------------------------
// Key names to encode a BigInteger into a NSCoder object.
//--------------------------------------------------------------

static NSString * const keySign			= @"sign";
static NSString * const keyLength		= @"length";
static NSString * const keyDigits		= @"digits";

//--------------------------------------------------------------
// Exception messages.
//--------------------------------------------------------------

static NSString * const excNullPointer			= @"Null pointer";
static NSString * const excOutOfBounds			= @"One or more parameters are out of bounds";
static NSString * const excInvalidOperation		= @"Invalid arithmetic operation";
static NSString * const excKeyedArchiverOnly	= @"Only keyed archivers are supported";

//========================================================================
// The BigInteger class itself. This class is the public interface of the
// library. Please refer to the associated documentation for more information
// about its usage.
//
// The actual integer value is stored in a BIGINT structure, on which a
// bunch of bigint_* functions declared in private.h operate. This level
// of encapsulation avoids a lot of object allocations in intermediate
// computations.
//
// Some implementation tricks are based on the layout of integer values
// in memory. Hence:
//
// /!\ COMPILE FOR LITTLE-ENDIAN ARCHITECTURES ONLY /!\
//
//========================================================================

@implementation BigInteger

//--------------------------------------------------------------
// Initializes a BigInteger with a signed 32-bit integer.
//--------------------------------------------------------------

- (id)initWithInt32:(int32_t)x
{
	if ((self = [super init]) == nil) return nil;

	BOOL s;
	if (x < 0)
	{
		s = YES;
		if (x != INT32_MIN) x = -x;
	}
	else
	{
		s = NO;
	}

	bigint_init32(&bn, x, s);
	assert(bigint_validate(&bn));

	return self;
}

//--------------------------------------------------------------
// Initializes a BigInteger with an unsigned 32-bit integer.
//--------------------------------------------------------------

- (id)initWithUnsignedInt32:(uint32_t)x
{
	if ((self = [super init]) == nil) return nil;

	bigint_init32(&bn, x, NO);
	assert(bigint_validate(&bn));

	return self;
}

//--------------------------------------------------------------
// Initializes a BigInteger with another BigInteger.
//--------------------------------------------------------------

- (id)initWithBigInteger:(BigInteger *)bigint
{
	if ((self = [super init]) == nil) return nil;

	if (!bigint) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	bigint_copy(&bn, &bigint->bn, 0);
	assert(bigint_validate(&bn));

	return self;
}

//--------------------------------------------------------------
// Initializes a BigInteger from the textual representation of
// an integer in the specified radix.
//--------------------------------------------------------------

- (id)initWithString:(NSString *)num radix:(int)radix
{
	// Forward the message to the parent class.

	if ((self = [super init]) == nil) return nil;

	// Ensure the parameters are valid.

	if (!num) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	if (radix < 2 || radix > 36) [NSException raise:NSInvalidArgumentException format:excOutOfBounds];

	// Retrieve the string length and initialize
	// the parser.
	
	int n = (int) [num length];
	int neg = NO;
	int k = 0;

	// Skip the minus sign if necessary, then
	// check the string is not empty.
	
	if (n && [num characterAtIndex:0] == '-')
	{
		neg = YES;
		k++;
	}

	if (k >= n)
	{
		[self autorelease];
		return nil;
	}
	
	// Determine the approximate length in digits
	// of the resulting BigInteger.

	int v = (int) (((float) n) * logf(radix) / logf(2.0f));
	bigint_alloc(&bn, 1 + v / (sizeof(bigint_digit) * 8), NO);
	bn.length = 1;

	// Parse the string, appending each digit one
	// by one. If a digit is out of bound or invalid,
	// abort and return NULL.

	while (k < n)
	{
		unichar ch = [num characterAtIndex:k];

		if		(ch >= '0' && ch <='9')		v = ch - '0';
		else if (ch >= 'A' && ch <= 'Z')	v = ch - 'A' + 10;
		else if (ch >= 'a' && ch <= 'z')	v = ch - 'a' + 10;
		else								v = 255;

		if (v < radix)
		{
			bigint_digit * p = bn.digits;
			bigint_word carry = (bigint_word) v;
			
			for (int i = 0; i < bn.length; i++)
			{
				bigint_word mul = ((bigint_word) *p) * (bigint_word) radix + carry;
				*p++ = (bigint_digit) mul;
				carry = mul >> (sizeof(bigint_digit) * 8);
			}
			
			if (carry)
			{
				*p = (bigint_digit) carry;
				bn.length++;
			}
		}
		else
		{
			[self autorelease];
			return nil;
		}
		
		k++;
	}

	// Clamp and set the sign.

	bigint_clamp(&bn, NO);
	if (bn.length) bn.sign = neg;

	// Validate and return the initialized
	// object.

	assert(bigint_validate(&bn));
	return self;
}

//--------------------------------------------------------------
// Creates a random number of the specified size.
//--------------------------------------------------------------

- (id)initWithRandomNumberOfSize:(int)bitcount exact:(BOOL)exact
{
	// Forward the message to the parent class.

	if ((self = [super init]) == nil) return nil;
	
	// Validate the bit count. It should be greater
	// than 2.

	if (bitcount < 2) [NSException raise:NSInvalidArgumentException format:excOutOfBounds];
	
	// Allocate the big integer and fill it with
	// random digits.

	int n = ((bitcount - 1) / (sizeof(bigint_digit) * 8)) + 1;
	bigint_alloc(&bn, n, NO);

	for (int i = 0; i < n; i++) bn.digits[i] = (bigint_digit) arc4random();

	// Mask the higher bits if necessary to get
	// the requested number of bits and set the
	// highest bit to 1.

	int k = bitcount - (n - 1) * sizeof(bigint_digit) * 8;
	if (exact) bn.digits[n - 1] |= ((bigint_digit) 1) << ((bigint_digit) (k - 1));
	if (k != sizeof(bigint_digit) * 8) bn.digits[n - 1] &= (((bigint_digit) 1) << k) - (bigint_digit) 1;

	// Clamp, validate and return the
	// initialized object.

	bigint_clamp(&bn, NO);
	assert(bigint_validate(&bn));

	return self;
}

//--------------------------------------------------------------
// Copies a BigInteger object.
//--------------------------------------------------------------

- (id)copyWithZone:(NSZone *)zone
{
	// The class being immutable, do not create an
	// actual copy and simply return self.

	return [self retain];
}

//--------------------------------------------------------------
// Destructor.
//--------------------------------------------------------------

- (void)dealloc
{
	bigint_free(&bn);
	[super dealloc];
}

//--------------------------------------------------------------
// Initializes a BigInteger object with the content of an archive.
//--------------------------------------------------------------

- (id)initWithCoder:(NSCoder *)decoder
{
	// Forward the message to the parent class.

	if ((self = [super init]) == nil) return nil;

	// Read content from the archive.

	if ([decoder allowsKeyedCoding])
	{
		// Keyed encoding. Read the fields from the archiver.

		int n = [decoder decodeIntForKey:keyLength];
		if (n)
		{
			bn.length = bn.alloc = (((n - 1) / sizeof(bigint_digit)) + 1);
			bn.sign = [decoder decodeBoolForKey:keySign];

			NSUInteger u;
			const void * p = [decoder decodeBytesForKey:keyDigits returnedLength:&u];

			bn.digits = (bigint_digit *) malloc(bn.length * sizeof(bigint_digit));
			memset(bn.digits, 0, bn.length * sizeof(bigint_digit));
			memcpy(bn.digits, p, u);

			bigint_clamp(&bn, YES);
		}
	}
	else
	{
		// Serial encoding. Not supported.

		[NSException raise:NSInvalidArchiveOperationException format:excKeyedArchiverOnly];
	}

	// Return the initialized object.

	return self;
}

//--------------------------------------------------------------
// Writes a BigInteger object to an archive.
//--------------------------------------------------------------

- (void)encodeWithCoder:(NSCoder *)coder
{
	if ([coder allowsKeyedCoding])
	{
		// Keyed encoding. Write the fields to the archiver.

		uint8_t	* p = NULL;
		int n = 0;

		if (bn.length)
		{
			p = (uint8_t *) bn.digits;
			n = bn.length * sizeof(bigint_digit);
			while (p[n - 1] == 0) n--;
		}

		[coder encodeBool:bn.sign forKey:keySign];
		[coder encodeInt:n forKey:keyLength];
		if (n) [coder encodeBytes:p length:n forKey:keyDigits];
	}
	else
	{
		// Serial encoding. Not supported.

		[NSException raise:NSInvalidArchiveOperationException format:excKeyedArchiverOnly];
	}
}

//--------------------------------------------------------------
// Returns an autoreleased BigInteger from a signed 32-bit
// integer.
//--------------------------------------------------------------

+ (BigInteger *)bigintWithInt32:(int32_t)x
{
	return [[[BigInteger alloc] initWithInt32:x] autorelease];
}

//--------------------------------------------------------------
// Returns an autoreleased BigInteger from an unsigned 32-bit
// integer.
//--------------------------------------------------------------

+ (BigInteger *)bigintWithUnsignedInt32:(uint32_t)x
{
	return [[[BigInteger alloc] initWithUnsignedInt32:x] autorelease];
}

//--------------------------------------------------------------
// Returns an autoreleased BigInteger from another BigInteger.
//--------------------------------------------------------------

+ (BigInteger *)bigintWithBigInteger:(BigInteger *)bigint
{
	return [[[BigInteger alloc] initWithBigInteger:bigint] autorelease];
}

//--------------------------------------------------------------
// Returns an autoreleased BigInteger from the textual representation
// of an integer in the specified base.
//--------------------------------------------------------------

+ (BigInteger *)bigintWithString:(NSString *)num radix:(int)radix
{
	return [[[BigInteger alloc] initWithString:num radix:radix] autorelease];
}

//--------------------------------------------------------------
// Returns an autoreleased random BigInteger containing the
// specified number of bits.
//--------------------------------------------------------------

+ (BigInteger *)bigintWithRandomNumberOfSize:(int)bitcount exact:(BOOL)exact
{
	return [[[BigInteger alloc] initWithRandomNumberOfSize:bitcount exact:exact] autorelease];
}

//--------------------------------------------------------------
// Prints a description of the object.
//--------------------------------------------------------------

- (NSString *)description
{
	// Create a buffer to hold the result.

	NSMutableString * buf = [[NSMutableString alloc] initWithCapacity:20];
	if (bn.length)
	{
		// The receiver is not null. Print every bytes,
		// space separated.

		uint8_t * p = ((uint8_t *) (bn.digits + bn.length)) - 1;
		while (!*p) p--;

		if (bn.sign) [buf appendString:@"- "];
		while (p >= (uint8_t *) bn.digits) [buf appendFormat:@"%02X ", *p--];
	}
	else
	{
		// The receiver is null. Simply print 0.

		[buf appendString:@"00"];
	}

	// Trim spaces and return the result.

	NSString * ret = [buf stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	[buf release];
	return ret;
}

//--------------------------------------------------------------
// Print the receiver in the specified radix.
//--------------------------------------------------------------

- (NSString *)toRadix:(int)radix
{
	// Eliminate trivial cases: invalid radix and
	// null receiver.
	
	if (radix < 2 || radix > 36) [NSException raise:NSInvalidArgumentException format:excOutOfBounds];
	if (!bn.length) return @"0";

	// Determine the approximate length of the
	// result string and allocate a buffer.

	int v = 5 + (int) ((float) (bn.length * sizeof(bigint_digit) * 8) * log(2.0) / log(radix));
	char * p = (char *) malloc(v);

	char * q = p + v;
	*--q = '\0';

	// Copy the receiver in a temporary place so
	// we can alter its value.

	BIGINT tmp;
	bigint_copy(&tmp, &bn, 0);

	// While the value is not null, loop to print
	// each digit, starting by the rightmost one.

	while (tmp.length)
	{
		bigint_word div = 0;
		bigint_digit res;

		for (int i = tmp.length - 1; i >= 0; i--)
		{
			div = (div << (sizeof(bigint_digit) * 8)) | ((bigint_word) tmp.digits[i]);

			if (div >= radix)
			{
				res = (bigint_digit) (div / ((bigint_word) radix));
				div -= ((bigint_word) res) * ((bigint_word) radix);
			}
			else
			{
				res = 0;
			}

			tmp.digits[i] = res;
		}

		*--q = div + ((div <= 9) ? '0' : 'A' - 10);
		while (tmp.length > 0 && !tmp.digits[tmp.length - 1]) tmp.length--;
	}

	// Free the temporary number, prepend the sign and convert
	// the C string to a NSString object.

	bigint_free(&tmp);
	if (bn.sign) *--q = '-';

	NSString * string = [NSString stringWithUTF8String:q];
	free(p);

	return string;
}

//--------------------------------------------------------------
// Copies the content of a BigInteger to a byte array. Bytes
// are in the little-endian order.
//--------------------------------------------------------------

- (void)getBytes:(uint8_t *)bytes length:(int)length
{
	// Validate the parameters.

	if (!bytes) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	if (length < 0) [NSException raise:NSInvalidArgumentException format:excOutOfBounds];

	// Determine the number of bytes to copy.

	int n = bn.length * sizeof(bigint_digit);
	if (n > length) n = length;

	// Copy the bytes. If the end of the buffer is
	// not reached, fill up with zeroes.

	uint8_t * p = (uint8_t *) bn.digits;
	memcpy(bytes, p, n);
	memset(bytes + n, 0, length - n);
}

//--------------------------------------------------------------
// Returns the 32-bit integer value of the receiver, if possible.
// In case of overflow, raises an exception.
//--------------------------------------------------------------

- (int32_t)intValue
{
	int k = bn.length * sizeof(bigint_digit);
	int32_t r = 0;

	if (k > sizeof(r))	r = -1;
	else				memcpy(&r, bn.digits, k);

	if ((r & 0x80000000) != 0 && (!bn.sign || r != INT32_MIN)) [NSException raise:NSGenericException format:excInvalidOperation];
	if (bn.sign && r != INT32_MIN) r = -r;

	return r;
}

//--------------------------------------------------------------
// Returns the 64-bit integer value of the receiver, if possible.
// In case of overflow, raises an exception.
//--------------------------------------------------------------

- (int64_t)longValue
{
	int k = bn.length * sizeof(bigint_digit);
	int64_t r = 0;

	if (k > sizeof(r))	r = -1;
	else				memcpy(&r, bn.digits, k);

	if ((r & 0x8000000000000000ll) != 0 && (!bn.sign || r != INT64_MIN)) [NSException raise:NSGenericException format:excInvalidOperation];
	if (bn.sign && r != INT64_MIN) r = -r;

	return r;
}

//--------------------------------------------------------------
// Compares a BigInteger object with the receiver. The return
// value is -1 if receiver < bigint, 0 if they are equal and +1
// if receiver > bigint.
//--------------------------------------------------------------

- (NSComparisonResult)compare:(BigInteger *)bigint
{
	if (!bigint) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	return bigint_compare(&bn, &bigint->bn);
}

//--------------------------------------------------------------
// Tests whether a BigInteger object contains or not the same
// value as the receiver.
//--------------------------------------------------------------

- (BOOL)isEqualToBigInteger:(BigInteger *)bigint
{
	return (bigint && bigint_compare(&bn, &bigint->bn) == NSOrderedSame);
}

//--------------------------------------------------------------
// Tests whether an object is equal to the receiver or not. Two
// bigints are equals if they are both of the same type and contain
// the same value.
//--------------------------------------------------------------

- (BOOL)isEqual:(id)object
{
	if (![object isKindOfClass:[self class]]) return NO;
	if ([self compare:object] != NSOrderedSame) return NO;
	return YES;
}

//--------------------------------------------------------------
// Computes a hash value. The algorithm is expected to portable
// between 32 and 64 bits plateforms, although it won't produce
// the same result.
//--------------------------------------------------------------

- (NSUInteger)hash
{
	// Compute a hash value using the BSD checksum
	// algorithm.

	NSUInteger h = 0;
	bigint_digit * p = bn.digits;

	for (int i = 0; i < bn.length; i++)
	{
		h = (h >> 1) | (h << ((sizeof(NSUInteger) * 8) - 1));
		h += (NSUInteger) (*p++);
	}

	// If the value is negative, complement the result to
	// ensure X and -X have different hash values.

	if (bn.sign) h = ~h;
	return h;
}

//--------------------------------------------------------------
// Sign function. Return 0 if the receiver is null, +1 if it is
// positive, and -1 if it is negative.
//--------------------------------------------------------------

- (int)sign
{
	return (bn.length != 0) ? ((bn.sign) ? -1 : +1) : 0;
}

//--------------------------------------------------------------
// Returns the absolute value of the receiver.
//--------------------------------------------------------------

- (BigInteger *)abs
{
	BigInteger	* r;

	if (bn.sign)
	{
		// The receiver is negative. Copy it and cancel
		// its sign bit.

		r = [[[BigInteger alloc] initWithBigInteger:self] autorelease];
		r->bn.sign = NO;
	}
	else
	{
		// The receiver is already positive. Directly return
		// self.

		r = self;
	}

	return r;
}

//--------------------------------------------------------------
// Returns the opposite of the receiver.
//--------------------------------------------------------------

- (BigInteger *)negate
{
	BigInteger * r = [[BigInteger alloc] initWithBigInteger:self];
	r->bn.sign = !bn.sign;
	return [r autorelease];
}

//--------------------------------------------------------------
// Determines whether the receiver is even or not, by checking
// the last bit of the integer value.
//--------------------------------------------------------------

- (BOOL)isEven
{
	bigint_digit d = (bn.length) ? bn.digits[0] : 0;
	return ((d & 1) == 0) ? YES : NO;
}

//--------------------------------------------------------------
// Determines whether the receiver is odd or not, by checking
// the last bit of the integer value.
//--------------------------------------------------------------

- (BOOL)isOdd
{
	bigint_digit d = (bn.length) ? bn.digits[0] : 0;
	return ((d & 1) != 0) ? YES : NO;
}

//--------------------------------------------------------------
// Determines whether the receiver is zero.
//--------------------------------------------------------------

- (BOOL)isZero
{
	return (bn.length == 0) ? YES : NO;
}

//--------------------------------------------------------------
// Adds the given BigInteger from the receiver.
//--------------------------------------------------------------

- (BigInteger *)add:(BigInteger *)x
{
	if (!x) [NSException raise:NSInvalidArgumentException format:excNullPointer];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_add(&r->bn, &bn, &x->bn);

	return [r autorelease];
}

//--------------------------------------------------------------
// Subtracts the given BigInteger from the receiver.
//--------------------------------------------------------------

- (BigInteger *)sub:(BigInteger *)x
{
	if (!x) [NSException raise:NSInvalidArgumentException format:excNullPointer];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_sub(&r->bn, &bn, &x->bn);

	return [r autorelease];
}

//--------------------------------------------------------------
// Multiplies the receiver with the given BigInteger.
//--------------------------------------------------------------

- (BigInteger *)multiply:(BigInteger *)mul
{
	if (!mul) [NSException raise:NSInvalidArgumentException format:excNullPointer];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_multiply(&r->bn, &bn, &mul->bn);

	return [r autorelease];
}

//--------------------------------------------------------------
// Multiplies the receiver with the given BigInteger and
// returns the result modulo a given BigInteger.
//--------------------------------------------------------------

- (BigInteger *)multiply:(BigInteger *)mul modulo:(BigInteger *)mod
{
	// Validate the parameters.

	if (!mul || ! mod) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	if (mod->bn.sign || !mod->bn.length) [NSException raise:NSGenericException format:excInvalidOperation];

	// Do the multiplication and the modulo.

	BIGINT p;
	bigint_multiply(&p, &bn, &mul->bn);

	BigInteger * r = [[BigInteger alloc] init];
	bigint_divide(&p, &mod->bn, NULL, &r->bn);

	bigint_free(&p);

	// If the result is negative, add the modulus to
	// bring back the result between 0 and mod - 1.

	if (r->bn.sign) bigint_add(&r->bn, &r->bn, &mod->bn);

	// Return the result.

	return [r autorelease];
}

//--------------------------------------------------------------
// Divides the receiver by the given BigInteger and returns the
// result. The remainder is lost.
//--------------------------------------------------------------

- (BigInteger *)divide:(BigInteger *)div
{
	if (!div) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	if (!div->bn.length) [NSException raise:NSGenericException format:excInvalidOperation];

	BigInteger * q = [[BigInteger alloc] init];
	bigint_divide(&bn, &div->bn, &q->bn, NULL);

	return [q autorelease];
}

//--------------------------------------------------------------
// Divides the receiver by the given BigInteger, returns the
// result and optionaly, the remainder.
//--------------------------------------------------------------

- (BigInteger *)divide:(BigInteger *)div remainder:(BigInteger **)rem
{
	if (!div) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	if (!div->bn.length) [NSException raise:NSGenericException format:excInvalidOperation];

	BIGINT * r = NULL;
	if (rem)
	{
		*rem = [[[BigInteger alloc] init] autorelease];
		r = &(*rem)->bn;
	}

	BigInteger * q = [[BigInteger alloc] init];
	bigint_divide(&bn, &div->bn, &q->bn, r);

	return [q autorelease];
}

//--------------------------------------------------------------
// Regular exponentiation.
//--------------------------------------------------------------

- (BigInteger *)exp:(uint32_t)exp
{
	BigInteger * r = [[BigInteger alloc] init];
	bigint_exp(&r->bn, &bn, exp);

	return [r autorelease];
}

//--------------------------------------------------------------
// Modular exponentiation.
//--------------------------------------------------------------

- (BigInteger *)exp:(BigInteger *)exp modulo:(BigInteger *)mod
{
	// Validate the parameters.

	if (!exp || !mod) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	if (exp->bn.sign || mod->bn.sign || !mod->bn.length) [NSException raise:NSGenericException format:excInvalidOperation];

	// Perform the modular exponentiation.

	BigInteger * r = [[BigInteger alloc] init];
	bigint_expmod(&r->bn, &bn, &exp->bn, &mod->bn);

	// If the result is negative, add the modulus to
	// bring back the result between 0 and mod - 1.

	if (r->bn.sign) bigint_add(&r->bn, &r->bn, &mod->bn);

	// Return the result.

	return [r autorelease];
}

//--------------------------------------------------------------
// Shift left by the specified count.
//--------------------------------------------------------------

- (BigInteger *)shiftLeft:(int)count
{
	if (count < 0) [NSException raise:NSInvalidArgumentException format:excOutOfBounds];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_shift_left(&r->bn, &bn, count);

	return [r autorelease];
}

//--------------------------------------------------------------
// Shift right by the specified count.
//--------------------------------------------------------------

- (BigInteger *)shiftRight:(int)count
{
	if (count < 0) [NSException raise:NSInvalidArgumentException format:excOutOfBounds];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_shift_right(&r->bn, &bn, count);

	return [r autorelease];
}

//--------------------------------------------------------------
// Bit count.
//--------------------------------------------------------------

- (int)bitCount
{
	return bigint_bitcount(&bn);
}

//--------------------------------------------------------------
// Bitwise NOT
//--------------------------------------------------------------

- (BigInteger *)bitwiseNotUsingWidth:(int)count
{
	if (count <= 0) [NSException raise:NSInvalidArgumentException format:excInvalidOperation];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_not(&r->bn, &bn, count);

	return [r autorelease];
}

//--------------------------------------------------------------
// Bitwise AND
//--------------------------------------------------------------

- (BigInteger *)bitwiseAnd:(BigInteger *)x
{
	if (!x) [NSException raise:NSInvalidArgumentException format:excNullPointer];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_and(&r->bn, &bn, &x->bn);

	return [r autorelease];
}

//--------------------------------------------------------------
// Bitwise OR
//--------------------------------------------------------------

- (BigInteger *)bitwiseOr:(BigInteger *)x
{
	if (!x) [NSException raise:NSInvalidArgumentException format:excNullPointer];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_or(&r->bn, &bn, &x->bn);

	return [r autorelease];
}

//--------------------------------------------------------------
// Bitwise XOR
//--------------------------------------------------------------

- (BigInteger *)bitwiseXor:(BigInteger *)x
{
	if (!x) [NSException raise:NSInvalidArgumentException format:excNullPointer];

	BigInteger * r = [[BigInteger alloc] init];
	bigint_xor(&r->bn, &bn, &x->bn);

	return [r autorelease];
}

//--------------------------------------------------------------
// Returns the greatest common divisor of the receiver and the
// given BigInteger.
//--------------------------------------------------------------

- (BigInteger *)greatestCommonDivisor:(BigInteger *)bigint
{
	// Validate the parameters.

	if (!bigint) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	if (!bn.length || !bigint->bn.length || bn.sign || bigint->bn.sign) [NSException raise:NSGenericException format:excInvalidOperation];

	// Apply the extended Euclide's algorithm.

	BigInteger * d = [[BigInteger alloc] init];
	bigint_euclide(&bn, &bigint->bn, &d->bn, NULL, NULL);

	// Return the result.

	return [d autorelease];
}

//--------------------------------------------------------------
// Returns the inverse modulo of the receiver.
//--------------------------------------------------------------

- (BigInteger *)inverseModulo:(BigInteger *)mod
{
	// Validate the parameters.

	if (!mod) [NSException raise:NSInvalidArgumentException format:excNullPointer];
	if (mod->bn.sign || !mod->bn.length) [NSException raise:NSInvalidArgumentException format:excInvalidOperation];

	// Apply the extended Euclide's algorithm.

	BIGINT d, x, y;
	bigint_euclide(&bn, &mod->bn, &d, &x, &y);

	BigInteger * r;
	if (d.length == 1 && d.digits[0] == 1)
	{
		// The GCD is equal to 1, so the modular inverse
		// exists. Return it.

		r = [[[BigInteger alloc] init] autorelease];
		memcpy(&r->bn, &x, sizeof(BIGINT));

		// If the result is negative, add the modulus to
		// bring back the result between 0 and mod - 1.

		if (r->bn.sign) bigint_add(&r->bn, &r->bn, &mod->bn);
	}
	else
	{
		// The modular inverse does not exist.

		bigint_free(&x);
		r = nil;
	}

	// Clean up and return the result.

	bigint_free(&d);
	bigint_free(&y);

	return r;
}

//--------------------------------------------------------------
// Determines whether the receiver contains a primer number
// or not. The test is probabilistic only (Miller Rabin).
//--------------------------------------------------------------

- (BOOL)isProbablePrime
{
	// Copy the number to a temporary location and
	// cancel its sign bit.

	BIGINT t;
	memcpy(&t, &bn, sizeof(BIGINT));
	t.sign = NO;

	// Then check for primality of the absolute value
	// of the number.

	return bigint_is_prime(&t);
}

//--------------------------------------------------------------
// Returns the first prime number greater than the actual value
// of the receiver. The test is probabilistic only (Miller Rabin).
//--------------------------------------------------------------

- (BigInteger *)nextProbablePrime
{
	// Copy the number to the result object, set its
	// lower bit to ensure it is odd, and cancel its
	// bit sign.

	BigInteger * r = [[BigInteger alloc] init];
	bigint_copy(&r->bn, &bn, 1);
	r->bn.digits[0] |= 1;
	r->bn.sign = NO;

	// While the number is not prime, add 2 and
	// loop.

	BIGINT t;
	bigint_digit d = 2;
	t.length = t.alloc = 1;
	t.digits = &d;

	while (!bigint_is_prime(&r->bn)) bigint_add_magnitude(&r->bn, &r->bn, &t);

	// Restore the bit sign and return the
	// result.

	r->bn.sign = bn.sign;
	return [r autorelease];
}

//--------------------------------------------------------------

@end

//========================================================================
