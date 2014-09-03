#define PERL_EXT_POSIX

#ifdef NETWARE
	#define _POSIX_
	/*
	 * Ideally this should be somewhere down in the includes
	 * but putting it in other places is giving compiler errors.
	 * Also here I am unable to check for HAS_UNAME since it wouldn't have
	 * yet come into the file at this stage - sgp 18th Oct 2000
	 */
	#include <sys/utsname.h>
#endif	/* NETWARE */

#define PERL_NO_GET_CONTEXT

#include "EXTERN.h"
#define PERLIO_NOT_STDIO 1
#include "perl.h"
#include "XSUB.h"
#if defined(PERL_IMPLICIT_SYS)
#  undef signal
#  undef open
#  undef setmode
#  define open PerlLIO_open3
#endif
#include <ctype.h>
#ifdef I_DIRENT    /* XXX maybe better to just rely on perl.h? */
#include <dirent.h>
#endif
#include <errno.h>
#ifdef WIN32
#include <sys/errno2.h>
#endif
#ifdef I_FLOAT
#include <float.h>
#endif
#ifdef I_FENV
#include <fenv.h>
#endif
#ifdef I_LIMITS
#include <limits.h>
#endif
#include <locale.h>
#include <math.h>
#ifdef I_PWD
#include <pwd.h>
#endif
#include <setjmp.h>
#include <signal.h>
#include <stdarg.h>

#ifdef I_STDDEF
#include <stddef.h>
#endif

#ifdef I_UNISTD
#include <unistd.h>
#endif

#ifndef M_E
#  define M_E		2.71828182845904523536028747135266250
#endif
#ifndef M_LOG2E
#  define M_LOG2E	1.44269504088896340735992468100189214
#endif
#ifndef M_LOG10E
#  define M_LOG10E	0.434294481903251827651128918916605082
#endif
#ifndef M_LN2
#  define M_LN2		0.693147180559945309417232121458176568
#endif
#ifndef M_LN10
#  define M_LN10	2.30258509299404568401799145468436421
#endif
#ifndef M_PI
#  define M_PI		3.14159265358979323846264338327950288
#endif
#ifndef M_PI_2
#  define M_PI_2	1.57079632679489661923132169163975144
#endif
#ifndef M_PI_4
#  define M_PI_4	0.785398163397448309615660845819875721
#endif
#ifndef M_1_PI
#  define M_1_PI	0.318309886183790671537767526745028724
#endif
#ifndef M_2_PI
#  define M_2_PI	0.636619772367581343075535053490057448
#endif
#ifndef M_2_SQRTPI
#  define M_2_SQRTPI	1.12837916709551257389615890312154517
#endif
#ifndef M_SQRT2
#  define M_SQRT2	1.41421356237309504880168872420969808
#endif
#ifndef M_SQRT1_2
#  define M_SQRT1_2	0.707106781186547524400844362104849039
#endif

#if !defined(INFINITY) && defined(NV_INF)
#  define INFINITY NV_INF
#endif

#if !defined(NAN) && defined(NV_NAN)
#  define NAN NV_NAN
#endif

#if !defined(Inf) && defined(NV_INF)
#  define Inf NV_INF
#endif

#if !defined(NaN) && defined(NV_NAN)
#  define NaN NV_NAN
#endif

/* We will have an emulation. */
#ifndef FP_INFINITE
#  define FP_INFINITE	0
#  define FP_NAN	1
#  define FP_NORMAL	2
#  define FP_SUBNORMAL	3
#  define FP_ZERO	4
#endif

/* C89 math.h:

   acos asin atan atan2 ceil cos cosh exp fabs floor fmod frexp ldexp
   log log10 modf pow sin sinh sqrt tan tanh

 * Implemented in core:

   atan2 cos exp log pow sin sqrt

 * C99 math.h added:

   acosh asinh atanh cbrt copysign erf erfc exp2 expm1 fdim fma fmax
   fmin fpclassify hypot ilogb isfinite isgreater isgreaterequal isinf
   isless islessequal islessgreater isnan isnormal isunordered lgamma
   log1p log2 logb lrint nan nearbyint nextafter nexttoward remainder
   remquo rint round scalbn signbit tgamma trunc

 * Berkeley/SVID extensions:

   j0 j1 jn y0 y1 yn

 * Configure already (5.21.0) scans for:

   fpclassify isfinite isinf isnan ilogb*l* signbit

 * For floating-point round mode (which matters for e.g. lrint and rint)

   fegetround fesetround

*/

/* XXX Constant FP_FAST_FMA (if true, FMA is faster) */

/* XXX Add ldiv(), lldiv()?  It's C99, but from stdlib.h, not math.h  */

/* XXX Beware old gamma() -- one cannot know whether that is the
 * gamma or the log of gamma, that's why the new tgamma and lgamma.
 * Though also remember tgamma_r and lgamma_r. */

/* XXX The truthiness of acosh() is the canary for all of the
 * C99 math.  This is very likely wrong, especially in non-UNIX lands
 * like Win32 and VMS, but also older UNIXes have issues.  For Win32,
 * and other non-fully-C99, we later do some undefines for these interfaces.
 *
 * But we are very trying very hard to avoid introducing separate Configure
 * symbols for all the 40-ish new math symbols.  Especially since the set
 * of missing functions doesn't seem to follow any patterns. */

#ifdef HAS_ACOSH
#  if defined(USE_LONG_DOUBLE) && defined(HAS_ILOGBL)
/* There's already a symbol for ilogbl, we will use its truthiness
 * as the canary for all the *l variants being defined. */
#    define c99_acosh	acoshl
#    define c99_asinh	asinhl
#    define c99_atanh	atanhl
#    define c99_cbrt	cbrtl
#    define c99_copysign	copysignl
#    define c99_erf	erfl
#    define c99_erfc	erfcl
#    define c99_exp2	exp2l
#    define c99_expm1	expm1l
#    define c99_fdim	fdiml
#    define c99_fma	fmal
#    define c99_fmax	fmaxl
#    define c99_fmin	fminl
#    define c99_hypot	hypotl
#    define c99_ilogb	ilogbl
#    define c99_lgamma	lgammal
#    define c99_log1p	log1pl
#    define c99_log2	log2l
#    define c99_logb	logbl
#    if defined(USE_64_BIT_INT) && QUADKIND == QUAD_IS_LONG_LONG
#      define c99_lrint	llrintl
#    else
#      define c99_lrint	lrintl
#    endif
#    define c99_nan	nanl
#    define c99_nearbyint	nearbyintl
#    define c99_nextafter	nextafterl
#    define c99_nexttoward	nexttowardl
#    define c99_remainder	remainderl
#    define c99_remquo	remquol
#    define c99_rint	rintl
#    define c99_round	roundl
#    define c99_scalbn	scalbnl
#    ifdef HAS_SIGNBIT /* possibly bad assumption */
#      define c99_signbit	signbitl
#    endif
#    define c99_tgamma	tgammal
#    define c99_trunc	truncl
#  else
#    define c99_acosh	acosh
#    define c99_asinh	asinh
#    define c99_atanh	atanh
#    define c99_cbrt	cbrt
#    define c99_copysign	copysign
#    define c99_erf	erf
#    define c99_erfc	erfc
#    define c99_exp2	exp2
#    define c99_expm1	expm1
#    define c99_fdim	fdim
#    define c99_fma	fma
#    define c99_fmax	fmax
#    define c99_fmin	fmin
#    define c99_hypot	hypot
#    define c99_ilogb	ilogb
#    define c99_lgamma	lgamma
#    define c99_log1p	log1p
#    define c99_log2	log2
#    define c99_logb	logb
#    if defined(USE_64_BIT_INT) && QUADKIND == QUAD_IS_LONG_LONG
#      define c99_lrint	llrint
#    else
#      define c99_lrint	lrint
#    endif
#    define c99_nan	nan
#    define c99_nearbyint	nearbyint
#    define c99_nextafter	nextafter
#    define c99_nexttoward	nexttoward
#    define c99_remainder	remainder
#    define c99_remquo	remquo
#    define c99_rint	rint
#    define c99_round	round
#    define c99_scalbn	scalbn
/* We already define Perl_signbit in perl.h. */
#    ifdef HAS_SIGNBIT
#      define c99_signbit	signbit
#    endif
#    define c99_tgamma	tgamma
#    define c99_trunc	trunc
#  endif

#  ifndef isunordered
#    ifdef Perl_isnan
#      define isunordered(x, y) (Perl_isnan(x) || Perl_isnan(y))
#    elif defined(HAS_UNORDERED)
#      define isunordered(x, y) unordered(x, y)
#    endif
#  endif

#  if !defined(isgreater) && defined(isunordered)
#    define isgreater(x, y)         (!isunordered((x), (y)) && (x) > (y))
#    define isgreaterequal(x, y)    (!isunordered((x), (y)) && (x) >= (y))
#    define isless(x, y)            (!isunordered((x), (y)) && (x) < (y))
#    define islessequal(x, y)       (!isunordered((x), (y)) && (x) <= (y))
#    define islessgreater(x, y)     (!isunordered((x), (y)) && \
                                     ((x) > (y) || (y) > (x)))
#  endif

/* Check both the Configure symbol and the macro-ness (like C99 promises). */ 
#  if defined(HAS_FPCLASSIFY) && defined(fpclassify)
#    define c99_fpclassify	fpclassify
#  endif
/* Like isnormal(), the isfinite(), isinf(), and isnan() are also C99
   and also (sizeof-arg-aware) macros, but they are already well taken
   care of by Configure et al, and defined in perl.h as
   Perl_isfinite(), Perl_isinf(), and Perl_isnan(). */
#  ifdef isnormal
#    define c99_isnormal	isnormal
#  endif
#  ifdef isgreater /* canary for all the C99 is*<cmp>* macros. */
#    define c99_isgreater	isgreater
#    define c99_isgreaterequal	isgreaterequal
#    define c99_isless		isless
#    define c99_islessequal	islessequal
#    define c99_islessgreater	islessgreater
#    define c99_isunordered	isunordered
#  endif
#endif

/* If on legacy platforms, and not using gcc, some C99 math interfaces
 * might be missing, turn them off so that the emulations hopefully
 * kick in.  This is admittedly nasty, and fragile, but the alternative
 * is to have Configure scans for all the 40+ interfaces.
 *
 * In other words: if you have an incomplete (or broken) C99 math interface,
 * #undef the c99_foo here, and let the emulations kick in. */

#ifndef __GNUC__

/* HP-UX on PA-RISC is missing certain C99 math functions,
 * but on IA64 (Integrity) these do exist. */
#  if defined(__hpux) && defined(__hppa)
#    undef c99_exp2
#    undef c99_fdim
#    undef c99_fma
#    undef c99_fmax
#    undef c99_fmin
#    undef c99_fpclassify
#    undef c99_lrint
#    undef c99_nan
#    undef c99_nearbyint
#    undef c99_nexttoward
#    undef c99_remquo
#    undef c99_round
#    undef c99_scalbn
#    undef c99_tgamma
#    undef c99_trunc
#  endif

#  if defined(__irix__)
#    undef c99_ilogb
#    undef c99_exp2
#  endif

#  if defined(__osf__) /* Tru64 */
#    undef c99_fdim
#    undef c99_fma
#    undef c99_fmax
#    undef c99_fmin
#    undef c99_fpclassify
#    undef c99_isfinite
#    undef c99_isinf
#    undef c99_isunordered
#    undef c99_lrint
#    undef c99_nearbyint
#    undef c99_nexttoward
#    undef c99_remquo
#    undef c99_rint
#    undef c99_round
#    undef c99_scalbn
#  endif

#endif

/* XXX Regarding C99 math.h, VMS seems to be missing these:

  nan nearbyint round scalbn llrint
 */

#ifdef __VMS
#    undef c99_nan
#    undef c99_nearbyint
#    undef c99_round
#    undef c99_scalbn
/* Have lrint but not llrint. */
#    if defined(USE_64_BIT_INT) && QUADKIND == QUAD_IS_LONG_LONG
#      undef c99_lrint
#    endif
#endif

/* XXX Regarding C99 math.h, Win32 seems to be missing these:

  exp2 fdim fma fmax fmin fpclassify ilogb lgamma log1p log2 lrint
  remquo rint signbit tgamma trunc

  Win32 does seem to have these:

  acosh asinh atanh cbrt copysign cosh erf erfc expm1 hypot log10 nan
  nearbyint nextafter nexttoward remainder round scalbn

  And the Bessel functions are defined like _this.
*/

#ifdef WIN32
#  undef c99_exp2
#  undef c99_fdim
#  undef c99_fma
#  undef c99_fmax
#  undef c99_fmin
#  undef c99_ilogb
#  undef c99_lgamma
#  undef c99_log1p
#  undef c99_log2
#  undef c99_lrint
#  undef c99_remquo
#  undef c99_rint
#  undef c99_signbit
#  undef c99_tgamma
#  undef c99_trunc

/* Some APIs exist under Win32 with "underbar" names. */
#  undef c99_hypot
#  undef c99_logb
#  undef c99_nextafter
#  define c99_hypot _hypot
#  define c99_logb _logb
#  define c99_nextafter _nextafter

#  define bessel_j0 _j0
#  define bessel_j1 _j1
#  define bessel_jn _jn
#  define bessel_y0 _y0
#  define bessel_y1 _y1
#  define bessel_yn _yn

#endif

/* The Bessel functions: BSD, SVID, XPG4, and POSIX.  But not C99. */
#ifdef HAS_J0
#  if defined(USE_LONG_DOUBLE) && defined(HAS_J0L)
#    define bessel_j0 j0l
#    define bessel_j1 j1l
#    define bessel_jn jnl
#    define bessel_y0 y0l
#    define bessel_y1 y1l
#    define bessel_yn ynl
#  else
#    define bessel_j0 j0
#    define bessel_j1 j1
#    define bessel_jn jn
#    define bessel_y0 y0
#    define bessel_y1 y1
#    define bessel_yn yn
#  endif
#endif

/* Emulations for missing math APIs.
 *
 * Keep in mind that the point of many of these functions is that
 * they, if available, are supposed to give more precise/more
 * numerically stable results.
 *
 * See e.g. http://www.johndcook.com/math_h.html
 */

#ifndef c99_acosh
static NV my_acosh(NV x)
{
  return Perl_log(x + Perl_sqrt(x * x - 1));
}
#  define c99_acosh my_acosh
#endif

#ifndef c99_asinh
static NV my_asinh(NV x)
{
  return Perl_log(x + Perl_sqrt(x * x + 1));
}
#  define c99_asinh my_asinh
#endif

#ifndef c99_atanh
static NV my_atanh(NV x)
{
  return (Perl_log(1 + x) - Perl_log(1 - x)) / 2;
}
#  define c99_atanh my_atanh
#endif

#ifndef c99_cbrt
static NV my_cbrt(NV x)
{
  static const NV one_third = (NV)1.0/3;
  return x >= 0.0 ? Perl_pow(x, one_third) : -Perl_pow(-x, one_third);
}
#  define c99_cbrt my_cbrt
#endif

#ifndef c99_copysign
static NV my_copysign(NV x, NV y)
{
  return y >= 0 ? (x < 0 ? -x : x) : (x < 0 ? x : -x);
}
#  define c99_copysign my_copysign
#endif

/* XXX cosh (though c89) */

#ifndef c99_erf
static NV my_erf(NV x)
{
  /* http://www.johndcook.com/cpp_erf.html -- public domain */
  NV a1 =  0.254829592;
  NV a2 = -0.284496736;
  NV a3 =  1.421413741;
  NV a4 = -1.453152027;
  NV a5 =  1.061405429;
  NV p  =  0.3275911;

  int sign = x < 0 ? -1 : 1; /* Save the sign. */
  x = PERL_ABS(x);

  /* Abramowitz and Stegun formula 7.1.26 */
  NV t = 1.0 / (1.0 + p * x);
  NV y = 1.0 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1) * t * exp(-x*x);

  return sign * y;
}
#  define c99_erf my_erf
#endif

#ifndef c99_erfc
static NV my_erfc(NV x) {
  /* This is not necessarily numerically stable, but better than nothing. */
  return 1.0 - c99_erf(x);
}
#  define c99_erfc my_erfc
#endif

#ifndef c99_exp2
static NV my_exp2(NV x)
{
  return Perl_pow((NV)2.0, x);
}
#  define c99_exp2 my_exp2
#endif

#ifndef c99_expm1
static NV my_expm1(NV x)
{
  if (PERL_ABS(x) < 1e-5)
    /* http://www.johndcook.com/cpp_expm1.html -- public domain.
     * Also including the cubic term. */
    /* Probably not enough for long doubles. */
    return x * (1.0 + x * (0.5 + x / 6.0)); /* Taylor series */
  else
    return Perl_exp(x) - 1;
}
#  define c99_expm1 my_expm1
#endif

#ifndef c99_fdim
static NV my_fdim(NV x, NV y)
{
  return x > y ? x - y : 0;
}
#  define c99_fdim my_fdim
#endif

#ifndef c99_fmax
static NV my_fmax(NV x, NV y)
{
  if (Perl_isnan(x)) {
    return Perl_isnan(y) ? NV_NAN : y;
  } else if (Perl_isnan(y)) {
    return x;
  }
  return x > y ? x : y;
}
#  define c99_fmax my_fmax
#endif

#ifndef c99_fmin
static NV my_fmin(NV x, NV y)
{
  if (Perl_isnan(x)) {
    return Perl_isnan(y) ? NV_NAN : y;
  } else if (Perl_isnan(y)) {
    return x;
  }
  return x < y ? x : y;
}
#  define c99_fmin my_fmin
#endif

#ifndef c99_fpclassify

static IV my_fpclassify(NV x)
{
#if defined(HAS_FPCLASSIFY) && defined(FP_PLUS_INF) /* E.g. HP-UX */
  switch (Perl_fp_class(x)) {
  case FP_PLUS_INF:    case FP_MINUS_INF:    return FP_INFINITE;
  case FP_SNAN:        case FP_QNAN:         return FP_NAN;
  case FP_PLUS_NORM:   case FP_MINUS_NORM:   return FP_NORMAL;
  case FP_PLUS_DENORM: case FP_MINUS_DENORM: return FP_SUBNORMAL;
  case FP_PLUS_ZERO:   case FP_MINUS_ZERO:   return FP_ZERO;
  default: return -1;
  }
#  define c99_fpclassify my_fpclassify
#elif (defined(HAS_FPCLASS) || defined(HAS_FPCLASSL)) && defined(FP_CLASS_SNAN)
  switch (Perl_fp_class(x)) {
  case FP_CLASS_NINF:    case FP_CLASS_PINF:    return FP_INFINITE;
  case FP_CLASS_SNAN:    case FP_CLASS_QNAN:    return FP_NAN;
  case FP_CLASS_NNORM:   case FP_CLASS_PNORM:   return FP_NORMAL;
  case FP_CLASS_NDENORM: case FP_CLASS_PDENORM: return FP_SUBNORMAL;
  case FP_CLASS_NZERO:   case FP_CLASS_PZERO:   return FP_ZERO;
  default: return -1;
  }
#  define c99_fpclassify my_fpclassify
#elif (defined(HAS_FPCLASS) || defined(HAS_FP_CLASSL)) && defined(FP_SNAN)
  switch (Perl_fp_class(x)) {
  case FP_NINF:    case FP_PINF:    return FP_INFINITE;
  case FP_SNAN:    case FP_QNAN:    return FP_NAN;
  case FP_NNORM:   case FP_PNORM:   return FP_NORMAL;
  case FP_NDENORM: case FP_PDENORM: return FP_SUBNORMAL;
  case FP_NZERO:   case FP_PZERO:   return FP_ZERO;
  default: return -1;
  }
#  define c99_fpclassify my_fpclassify
#elif defined(HAS_FP_CLASS) && defined(FP_POS_INF)
  switch (Perl_fp_class(x)) {
  case FP_NEG_INF:    case FP_POS_INF:    return FP_INFINITE;
  case FP_SNAN:       case FP_QNAN:       return FP_NAN;
  case FP_NEG_NORM:   case FP_POS_NORM:   return FP_NORMAL;
  case FP_NEG_DENORM: case FP_POS_DENORM: return FP_SUBNORMAL;
  case FP_NEG_ZERO:   case FP_POS_ZERO:   return FP_ZERO;
  default: return -1;
  }
#  define c99_fpclassify my_fpclassify
#elif defined(HAS_CLASS) && defined(FP_PLUS_INF)
  switch (Perl_fp_class(x)) {
  case FP_MINUS_INF:    case FP_PLUS_INF:    return FP_INFINITE;
  case FP_SNAN:         case FP_QNAN:        return FP_NAN;
  case FP_MINUS_NORM:   case FP_PLUS_NORM:   return FP_NORMAL;
  case FP_MINUS_DENORM: case FP_PLUS_DENORM: return FP_SUBNORMAL;
  case FP_MINUS_ZERO:   case FP_PLUS_ZERO:   return FP_ZERO;
  default: return -1;
  }
#  define c99_fpclassify my_fpclassify
#elif defined(HAS_FP_CLASSIFY)
  return Perl_fp_class(x);
#  define c99_fpclassify my_fpclassify
#elif defined(WIN32)
  int fpclass = _fpclass(x);
  if (Perl_fp_class_inf(x))    return FP_INFINITE;
  if (Perl_fp_class_nan(x))    return FP_NAN;
  if (Perl_fp_class_norm(x))   return FP_NORMAL;
  if (Perl_fp_class_denorm(x)) return FP_SUBNORMAL;
  if (Perl_fp_class_zero(x))   return FP_ZERO;
  return -1;
#  define c99_fpclassify my_fpclassify
#else
  return -1;
#endif
}

#endif

#ifndef c99_hypot
static NV my_hypot(NV x, NV y)
{
  /* http://en.wikipedia.org/wiki/Hypot */
  NV t;
  x = PERL_ABS(x); /* Take absolute values. */
  if (y == 0)
    return x;
  if (Perl_isnan(y))
    return NV_INF;
  y = PERL_ABS(y);
  if (x < y) { /* Swap so that y is less. */
    t = x;
    x = y;
    y = t;
  }
  t = y / x;
  return x * sqrt(1.0 + t * t);
}
#  define c99_hypot my_hypot
#endif

#ifndef c99_ilogb
static IV my_ilogb(NV x)
{
  return (IV)(Perl_log(x) * M_LOG2E);
}
#  define c99_ilogb my_ilogb
#endif

/* XXX lgamma -- non-trivial */

#ifndef c99_log1p
static NV my_log1p(NV x)
{
  /* http://www.johndcook.com/cpp_log_one_plus_x.html -- public domain.
   * Including also quadratic term. */
  if (PERL_ABS(x) > 1e-4)
    return Perl_log(1.0 + x);
  else
    /* Probably not enough for long doubles. */
    return x * (1.0 - x * (-x / 2.0 + x / 3.0)); /* Taylor series */
}
#  define c99_log1p my_log1p
#endif

#ifndef c99_log2
static NV my_log2(NV x)
{
  return Perl_log(x) * M_LOG2E;
}
#  define c99_log2 my_log2
#endif

/* XXX nextafter */

/* XXX nexttoward */

static int my_fegetround()
{
#ifdef HAS_FEGETROUND
  return fegetround();
#elif defined(FLT_ROUNDS)
  return FLT_ROUNDS;
  /* XXX emulate using fpgetround() (HAS_FPGETROUND):
   * FP_RN to nearest, FP_RM down, FP_RP, up, FP_RZ truncate */
#else
  return -1;
#endif
}

static NV my_rint(NV x)
{
#ifdef FE_TONEAREST
  switch (my_fegetround()) {
  default:
  case FE_TONEAREST:
    return (NV)((IV)(x >= 0.0 ? x + 0.5 : x - 0.5)); /* like round() */
  case FE_TOWARDZERO:
    return (NV)((IV)(x)); /* like trunc() */
  case FE_DOWNWARD:
    return (NV)((IV)(x >= 0.0 ? x : x - 0.5));
  case FE_UPWARD:
    return (NV)((IV)(x >= 0.0 ? x + 0.5 : x));
  }
#else
  /* XXX emulate using fpsetround() (HAS_FPGETROUND):
   * FP_RN to nearest, FP_RM down, FP_RP, up, FP_RZ truncate */
  return NV_NAN;
#endif
}

/* XXX nearbyint() and rint() are not really identical -- but the difference
 * is messy: nearbyint is defined NOT to raise FE_INEXACT floating point
 * exceptions, while rint() is defined to MAYBE raise them.  At the moment
 * Perl is blissfully unaware of such fine detail of floating point. */
#ifndef c99_nearbyint
#  ifdef FE_TONEAREST
#    define c99_nearbyrint my_rint
#  endif
#endif

#ifndef c99_lrint
#  ifdef FE_TONEAREST
static IV lrint(NV x)
{
  return (IV)my_rint(x);
}
#    define c99_lrint my_lrint
#  endif
#endif

/* XXX remainder */

/* XXX remquo */

#ifndef c99_rint
#  ifdef FE_TONEAREST
#    define c99_rint my_rint
#  endif
#endif

#ifndef c99_round
static NV my_round(NV x)
{
  return (NV)((IV)(x >= 0.0 ? x + 0.5 : x - 0.5));
}
#  define c99_round my_round
#endif

#ifndef c99_scalbn
#   if defined(Perl_ldexp) && FLT_RADIX == 2
static NV my_scalbn(NV x, int y)
{
  return Perl_ldexp(x, y);
}
#    define c99_scalbn my_scalbn
#  endif
#endif

/* XXX sinh (though c89) */

#ifndef c99_tgamma
#  ifdef c99_lgamma
static NV my_tgamma(NV x)
{
  double l = c99_lgamma(x);
  return signgam * Perl_exp(l); /* XXX evil global signgam, need lgamma_r */
}
#    define c99_tgamma my_tgamma
/* XXX tgamma without lgamma -- non-trivial */
#  endif
#endif

/* XXX tanh (though c89) */

#ifndef c99_trunc
static NV my_trunc(NV x)
{
  return (NV)((IV)(x));
}
#  define c99_trunc my_trunc
#endif

/* XXX This comment is just to make I_TERMIO and I_SGTTY visible to
   metaconfig for future extension writers.  We don't use them in POSIX.
   (This is really sneaky :-)  --AD
*/
#if defined(I_TERMIOS)
#include <termios.h>
#endif
#ifdef I_STDLIB
#include <stdlib.h>
#endif
#ifndef __ultrix__
#include <string.h>
#endif
#include <sys/stat.h>
#include <sys/types.h>
#include <time.h>
#ifdef I_UNISTD
#include <unistd.h>
#endif
#include <fcntl.h>

#ifdef HAS_TZNAME
#  if !defined(WIN32) && !defined(__CYGWIN__) && !defined(NETWARE) && !defined(__UWIN__)
extern char *tzname[];
#  endif
#else
#if !defined(WIN32) && !defined(__UWIN__) || (defined(__MINGW32__) && !defined(tzname))
char *tzname[] = { "" , "" };
#endif
#endif

#if defined(__VMS) && !defined(__POSIX_SOURCE)

#  include <utsname.h>

#  undef mkfifo
#  define mkfifo(a,b) (not_here("mkfifo"),-1)

   /* The POSIX notion of ttyname() is better served by getname() under VMS */
   static char ttnambuf[64];
#  define ttyname(fd) (isatty(fd) > 0 ? getname(fd,ttnambuf,0) : NULL)

#else
#if defined (__CYGWIN__)
#    define tzname _tzname
#endif
#if defined (WIN32) || defined (NETWARE)
#  undef mkfifo
#  define mkfifo(a,b) not_here("mkfifo")
#  define ttyname(a) (char*)not_here("ttyname")
#  define sigset_t long
#  define pid_t long
#  ifdef _MSC_VER
#    define mode_t short
#  endif
#  ifdef __MINGW32__
#    define mode_t short
#    ifndef tzset
#      define tzset()		not_here("tzset")
#    endif
#    ifndef _POSIX_OPEN_MAX
#      define _POSIX_OPEN_MAX	FOPEN_MAX	/* XXX bogus ? */
#    endif
#  endif
#  define sigaction(a,b,c)	not_here("sigaction")
#  define sigpending(a)		not_here("sigpending")
#  define sigprocmask(a,b,c)	not_here("sigprocmask")
#  define sigsuspend(a)		not_here("sigsuspend")
#  define sigemptyset(a)	not_here("sigemptyset")
#  define sigaddset(a,b)	not_here("sigaddset")
#  define sigdelset(a,b)	not_here("sigdelset")
#  define sigfillset(a)		not_here("sigfillset")
#  define sigismember(a,b)	not_here("sigismember")
#ifndef NETWARE
#  undef setuid
#  undef setgid
#  define setuid(a)		not_here("setuid")
#  define setgid(a)		not_here("setgid")
#endif	/* NETWARE */
#  define strtold(s1,s2)	not_here("strtold")
#else

#  ifndef HAS_MKFIFO
#    if defined(OS2)
#      define mkfifo(a,b) not_here("mkfifo")
#    else	/* !( defined OS2 ) */
#      ifndef mkfifo
#        define mkfifo(path, mode) (mknod((path), (mode) | S_IFIFO, 0))
#      endif
#    endif
#  endif /* !HAS_MKFIFO */

#  ifdef I_GRP
#    include <grp.h>
#  endif
#  include <sys/times.h>
#  ifdef HAS_UNAME
#    include <sys/utsname.h>
#  endif
#  include <sys/wait.h>
#  ifdef I_UTIME
#    include <utime.h>
#  endif
#endif /* WIN32 || NETWARE */
#endif /* __VMS */

typedef int SysRet;
typedef long SysRetLong;
typedef sigset_t* POSIX__SigSet;
typedef HV* POSIX__SigAction;
#ifdef I_TERMIOS
typedef struct termios* POSIX__Termios;
#else /* Define termios types to int, and call not_here for the functions.*/
#define POSIX__Termios int
#define speed_t int
#define tcflag_t int
#define cc_t int
#define cfgetispeed(x) not_here("cfgetispeed")
#define cfgetospeed(x) not_here("cfgetospeed")
#define tcdrain(x) not_here("tcdrain")
#define tcflush(x,y) not_here("tcflush")
#define tcsendbreak(x,y) not_here("tcsendbreak")
#define cfsetispeed(x,y) not_here("cfsetispeed")
#define cfsetospeed(x,y) not_here("cfsetospeed")
#define ctermid(x) (char *) not_here("ctermid")
#define tcflow(x,y) not_here("tcflow")
#define tcgetattr(x,y) not_here("tcgetattr")
#define tcsetattr(x,y,z) not_here("tcsetattr")
#endif

/* Possibly needed prototypes */
#ifndef WIN32
START_EXTERN_C
double strtod (const char *, char **);
long strtol (const char *, char **, int);
unsigned long strtoul (const char *, char **, int);
#ifdef HAS_STRTOLD
long double strtold (const char *, char **);
#endif
END_EXTERN_C
#endif

#ifndef HAS_DIFFTIME
#ifndef difftime
#define difftime(a,b) not_here("difftime")
#endif
#endif
#ifndef HAS_FPATHCONF
#define fpathconf(f,n)	(SysRetLong) not_here("fpathconf")
#endif
#ifndef HAS_MKTIME
#define mktime(a) not_here("mktime")
#endif
#ifndef HAS_NICE
#define nice(a) not_here("nice")
#endif
#ifndef HAS_PATHCONF
#define pathconf(f,n)	(SysRetLong) not_here("pathconf")
#endif
#ifndef HAS_SYSCONF
#define sysconf(n)	(SysRetLong) not_here("sysconf")
#endif
#ifndef HAS_READLINK
#define readlink(a,b,c) not_here("readlink")
#endif
#ifndef HAS_SETPGID
#define setpgid(a,b) not_here("setpgid")
#endif
#ifndef HAS_SETSID
#define setsid() not_here("setsid")
#endif
#ifndef HAS_STRCOLL
#define strcoll(s1,s2) not_here("strcoll")
#endif
#ifndef HAS_STRTOD
#define strtod(s1,s2) not_here("strtod")
#endif
#ifndef HAS_STRTOLD
#define strtold(s1,s2) not_here("strtold")
#endif
#ifndef HAS_STRTOL
#define strtol(s1,s2,b) not_here("strtol")
#endif
#ifndef HAS_STRTOUL
#define strtoul(s1,s2,b) not_here("strtoul")
#endif
#ifndef HAS_STRXFRM
#define strxfrm(s1,s2,n) not_here("strxfrm")
#endif
#ifndef HAS_TCGETPGRP
#define tcgetpgrp(a) not_here("tcgetpgrp")
#endif
#ifndef HAS_TCSETPGRP
#define tcsetpgrp(a,b) not_here("tcsetpgrp")
#endif
#ifndef HAS_TIMES
#ifndef NETWARE
#define times(a) not_here("times")
#endif	/* NETWARE */
#endif
#ifndef HAS_UNAME
#define uname(a) not_here("uname")
#endif
#ifndef HAS_WAITPID
#define waitpid(a,b,c) not_here("waitpid")
#endif

#ifndef HAS_MBLEN
#ifndef mblen
#define mblen(a,b) not_here("mblen")
#endif
#endif
#ifndef HAS_MBSTOWCS
#define mbstowcs(s, pwcs, n) not_here("mbstowcs")
#endif
#ifndef HAS_MBTOWC
#define mbtowc(pwc, s, n) not_here("mbtowc")
#endif
#ifndef HAS_WCSTOMBS
#define wcstombs(s, pwcs, n) not_here("wcstombs")
#endif
#ifndef HAS_WCTOMB
#define wctomb(s, wchar) not_here("wcstombs")
#endif
#if !defined(HAS_MBLEN) && !defined(HAS_MBSTOWCS) && !defined(HAS_MBTOWC) && !defined(HAS_WCSTOMBS) && !defined(HAS_WCTOMB)
/* If we don't have these functions, then we wouldn't have gotten a typedef
   for wchar_t, the wide character type.  Defining wchar_t allows the
   functions referencing it to compile.  Its actual type is then meaningless,
   since without the above functions, all sections using it end up calling
   not_here() and croak.  --Kaveh Ghazi (ghazi@noc.rutgers.edu) 9/18/94. */
#ifndef wchar_t
#define wchar_t char
#endif
#endif

#ifndef HAS_LOCALECONV
#   define localeconv() not_here("localeconv")
#else
struct lconv_offset {
    const char *name;
    size_t offset;
};

const struct lconv_offset lconv_strings[] = {
#ifdef USE_LOCALE_NUMERIC
    {"decimal_point",     STRUCT_OFFSET(struct lconv, decimal_point)},
    {"thousands_sep",     STRUCT_OFFSET(struct lconv, thousands_sep)},
#  ifndef NO_LOCALECONV_GROUPING
    {"grouping",          STRUCT_OFFSET(struct lconv, grouping)},
#  endif
#endif
#ifdef USE_LOCALE_MONETARY
    {"int_curr_symbol",   STRUCT_OFFSET(struct lconv, int_curr_symbol)},
    {"currency_symbol",   STRUCT_OFFSET(struct lconv, currency_symbol)},
    {"mon_decimal_point", STRUCT_OFFSET(struct lconv, mon_decimal_point)},
#  ifndef NO_LOCALECONV_MON_THOUSANDS_SEP
    {"mon_thousands_sep", STRUCT_OFFSET(struct lconv, mon_thousands_sep)},
#  endif
#  ifndef NO_LOCALECONV_MON_GROUPING
    {"mon_grouping",      STRUCT_OFFSET(struct lconv, mon_grouping)},
#  endif
    {"positive_sign",     STRUCT_OFFSET(struct lconv, positive_sign)},
    {"negative_sign",     STRUCT_OFFSET(struct lconv, negative_sign)},
#endif
    {NULL, 0}
};

#ifdef USE_LOCALE_NUMERIC

/* The Linux man pages say these are the field names for the structure
 * components that are LC_NUMERIC; the rest being LC_MONETARY */
#   define isLC_NUMERIC_STRING(name) (strcmp(name, "decimal_point")     \
                                      || strcmp(name, "thousands_sep")  \
                                                                        \
                                      /* There should be no harm done   \
                                       * checking for this, even if     \
                                       * NO_LOCALECONV_GROUPING */      \
                                      || strcmp(name, "grouping"))
#else
#   define isLC_NUMERIC_STRING(name) (0)
#endif

const struct lconv_offset lconv_integers[] = {
#ifdef USE_LOCALE_MONETARY
    {"int_frac_digits",   STRUCT_OFFSET(struct lconv, int_frac_digits)},
    {"frac_digits",       STRUCT_OFFSET(struct lconv, frac_digits)},
    {"p_cs_precedes",     STRUCT_OFFSET(struct lconv, p_cs_precedes)},
    {"p_sep_by_space",    STRUCT_OFFSET(struct lconv, p_sep_by_space)},
    {"n_cs_precedes",     STRUCT_OFFSET(struct lconv, n_cs_precedes)},
    {"n_sep_by_space",    STRUCT_OFFSET(struct lconv, n_sep_by_space)},
    {"p_sign_posn",       STRUCT_OFFSET(struct lconv, p_sign_posn)},
    {"n_sign_posn",       STRUCT_OFFSET(struct lconv, n_sign_posn)},
#endif
    {NULL, 0}
};

#endif /* HAS_LOCALECONV */

#ifdef HAS_LONG_DOUBLE
#  if LONG_DOUBLESIZE > NVSIZE
#    undef HAS_LONG_DOUBLE  /* XXX until we figure out how to use them */
#  endif
#endif

#ifndef HAS_LONG_DOUBLE
#ifdef LDBL_MAX
#undef LDBL_MAX
#endif
#ifdef LDBL_MIN
#undef LDBL_MIN
#endif
#ifdef LDBL_EPSILON
#undef LDBL_EPSILON
#endif
#endif

/* Background: in most systems the low byte of the wait status
 * is the signal (the lowest 7 bits) and the coredump flag is
 * the eight bit, and the second lowest byte is the exit status.
 * BeOS bucks the trend and has the bytes in different order.
 * See beos/beos.c for how the reality is bent even in BeOS
 * to follow the traditional.  However, to make the POSIX
 * wait W*() macros to work in BeOS, we need to unbend the
 * reality back in place. --jhi */
/* In actual fact the code below is to blame here. Perl has an internal
 * representation of the exit status ($?), which it re-composes from the
 * OS's representation using the W*() POSIX macros. The code below
 * incorrectly uses the W*() macros on the internal representation,
 * which fails for OSs that have a different representation (namely BeOS
 * and Haiku). WMUNGE() is a hack that converts the internal
 * representation into the OS specific one, so that the W*() macros work
 * as expected. The better solution would be not to use the W*() macros
 * in the first place, though. -- Ingo Weinhold
 */
#if defined(__HAIKU__)
#    define WMUNGE(x) (((x) & 0xFF00) >> 8 | ((x) & 0x00FF) << 8)
#else
#    define WMUNGE(x) (x)
#endif

static int
not_here(const char *s)
{
    croak("POSIX::%s not implemented on this architecture", s);
    return -1;
}

#include "const-c.inc"

static void
restore_sigmask(pTHX_ SV *osset_sv)
{
     /* Fortunately, restoring the signal mask can't fail, because
      * there's nothing we can do about it if it does -- we're not
      * supposed to return -1 from sigaction unless the disposition
      * was unaffected.
      */
     sigset_t *ossetp = (sigset_t *) SvPV_nolen( osset_sv );
     (void)sigprocmask(SIG_SETMASK, ossetp, (sigset_t *)0);
}

static void *
allocate_struct(pTHX_ SV *rv, const STRLEN size, const char *packname) {
    SV *const t = newSVrv(rv, packname);
    void *const p = sv_grow(t, size + 1);

    SvCUR_set(t, size);
    SvPOK_on(t);
    return p;
}

#ifdef WIN32

/*
 * (1) The CRT maintains its own copy of the environment, separate from
 * the Win32API copy.
 *
 * (2) CRT getenv() retrieves from this copy. CRT putenv() updates this
 * copy, and then calls SetEnvironmentVariableA() to update the Win32API
 * copy.
 *
 * (3) win32_getenv() and win32_putenv() call GetEnvironmentVariableA() and
 * SetEnvironmentVariableA() directly, bypassing the CRT copy of the
 * environment.
 *
 * (4) The CRT strftime() "%Z" implementation calls __tzset(). That
 * calls CRT tzset(), but only the first time it is called, and in turn
 * that uses CRT getenv("TZ") to retrieve the timezone info from the CRT
 * local copy of the environment and hence gets the original setting as
 * perl never updates the CRT copy when assigning to $ENV{TZ}.
 *
 * Therefore, we need to retrieve the value of $ENV{TZ} and call CRT
 * putenv() to update the CRT copy of the environment (if it is different)
 * whenever we're about to call tzset().
 *
 * In addition to all that, when perl is built with PERL_IMPLICIT_SYS
 * defined:
 *
 * (a) Each interpreter has its own copy of the environment inside the
 * perlhost structure. That allows applications that host multiple
 * independent Perl interpreters to isolate environment changes from
 * each other. (This is similar to how the perlhost mechanism keeps a
 * separate working directory for each Perl interpreter, so that calling
 * chdir() will not affect other interpreters.)
 *
 * (b) Only the first Perl interpreter instantiated within a process will
 * "write through" environment changes to the process environment.
 *
 * (c) Even the primary Perl interpreter won't update the CRT copy of the
 * the environment, only the Win32API copy (it calls win32_putenv()).
 *
 * As with CPerlHost::Getenv() and CPerlHost::Putenv() themselves, it makes
 * sense to only update the process environment when inside the main
 * interpreter, but we don't have access to CPerlHost's m_bTopLevel member
 * from here so we'll just have to check PL_curinterp instead.
 *
 * Therefore, we can simply #undef getenv() and putenv() so that those names
 * always refer to the CRT functions, and explicitly call win32_getenv() to
 * access perl's %ENV.
 *
 * We also #undef malloc() and free() to be sure we are using the CRT
 * functions otherwise under PERL_IMPLICIT_SYS they are redefined to calls
 * into VMem::Malloc() and VMem::Free() and all allocations will be freed
 * when the Perl interpreter is being destroyed so we'd end up with a pointer
 * into deallocated memory in environ[] if a program embedding a Perl
 * interpreter continues to operate even after the main Perl interpreter has
 * been destroyed.
 *
 * Note that we don't free() the malloc()ed memory unless and until we call
 * malloc() again ourselves because the CRT putenv() function simply puts its
 * pointer argument into the environ[] array (it doesn't make a copy of it)
 * so this memory must otherwise be leaked.
 */

#undef getenv
#undef putenv
#undef malloc
#undef free

static void
fix_win32_tzenv(void)
{
    static char* oldenv = NULL;
    char* newenv;
    const char* perl_tz_env = win32_getenv("TZ");
    const char* crt_tz_env = getenv("TZ");
    if (perl_tz_env == NULL)
        perl_tz_env = "";
    if (crt_tz_env == NULL)
        crt_tz_env = "";
    if (strcmp(perl_tz_env, crt_tz_env) != 0) {
        newenv = (char*)malloc((strlen(perl_tz_env) + 4) * sizeof(char));
        if (newenv != NULL) {
            sprintf(newenv, "TZ=%s", perl_tz_env);
            putenv(newenv);
            if (oldenv != NULL)
                free(oldenv);
            oldenv = newenv;
        }
    }
}

#endif

/*
 * my_tzset - wrapper to tzset() with a fix to make it work (better) on Win32.
 * This code is duplicated in the Time-Piece module, so any changes made here
 * should be made there too.
 */
static void
my_tzset(pTHX)
{
#ifdef WIN32
#if defined(USE_ITHREADS) && defined(PERL_IMPLICIT_SYS)
    if (PL_curinterp == aTHX)
#endif
        fix_win32_tzenv();
#endif
    tzset();
}

typedef int (*isfunc_t)(int);
typedef void (*any_dptr_t)(void *);

/* This needs to be ALIASed in a custom way, hence can't easily be defined as
   a regular XSUB.  */
static XSPROTO(is_common); /* prototype to pass -Wmissing-prototypes */
static XSPROTO(is_common)
{
    dXSARGS;

    if (items != 1)
       croak_xs_usage(cv,  "charstring");

    {
	dXSTARG;
	STRLEN	len;
        /*int	RETVAL = 0;   YYY means uncomment this to return false on an
                            * empty string input */
	int	RETVAL;
	unsigned char *s = (unsigned char *) SvPV(ST(0), len);
	unsigned char *e = s + len;
	isfunc_t isfunc = (isfunc_t) XSANY.any_dptr;

        if (ckWARN_d(WARN_DEPRECATED)) {

            /* Warn exactly once for each lexical place this function is
             * called.  See thread at
             * http://markmail.org/thread/jhqcag5njmx7jpyu */

	    HV *warned = get_hv("POSIX::_warned", GV_ADD | GV_ADDMULTI);
	    if (! hv_exists(warned, (const char *)&PL_op, sizeof(PL_op))) {
                Perl_warner(aTHX_ packWARN(WARN_DEPRECATED),
                            "Calling POSIX::%"HEKf"() is deprecated",
                            HEKfARG(GvNAME_HEK(CvGV(cv))));
		hv_store(warned, (const char *)&PL_op, sizeof(PL_op), &PL_sv_yes, 0);
            }
        }

        /*if (e > s) { YYY */
	for (RETVAL = 1; RETVAL && s < e; s++)
	    if (!isfunc(*s))
		RETVAL = 0;
        /*} YYY */
	XSprePUSH;
	PUSHi((IV)RETVAL);
    }
    XSRETURN(1);
}

MODULE = POSIX		PACKAGE = POSIX

BOOT:
{
    CV *cv;
    const char *file = __FILE__;


    /* silence compiler warning about not_here() defined but not used */
    if (0) not_here("");

    /* Ensure we get the function, not a macro implementation. Like the C89
       standard says we can...  */
#undef isalnum
    cv = newXS("POSIX::isalnum", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &isalnum;
#undef isalpha
    cv = newXS("POSIX::isalpha", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &isalpha;
#undef iscntrl
    cv = newXS("POSIX::iscntrl", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &iscntrl;
#undef isdigit
    cv = newXS("POSIX::isdigit", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &isdigit;
#undef isgraph
    cv = newXS("POSIX::isgraph", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &isgraph;
#undef islower
    cv = newXS("POSIX::islower", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &islower;
#undef isprint
    cv = newXS("POSIX::isprint", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &isprint;
#undef ispunct
    cv = newXS("POSIX::ispunct", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &ispunct;
#undef isspace
    cv = newXS("POSIX::isspace", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &isspace;
#undef isupper
    cv = newXS("POSIX::isupper", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &isupper;
#undef isxdigit
    cv = newXS("POSIX::isxdigit", is_common, file);
    XSANY.any_dptr = (any_dptr_t) &isxdigit;
}

MODULE = SigSet		PACKAGE = POSIX::SigSet		PREFIX = sig

void
new(packname = "POSIX::SigSet", ...)
    const char *	packname
    CODE:
	{
	    int i;
	    sigset_t *const s
		= (sigset_t *) allocate_struct(aTHX_ (ST(0) = sv_newmortal()),
					       sizeof(sigset_t),
					       packname);
	    sigemptyset(s);
	    for (i = 1; i < items; i++)
		sigaddset(s, SvIV(ST(i)));
	    XSRETURN(1);
	}

SysRet
addset(sigset, sig)
	POSIX::SigSet	sigset
	int		sig
   ALIAS:
	delset = 1
   CODE:
	RETVAL = ix ? sigdelset(sigset, sig) : sigaddset(sigset, sig);
   OUTPUT:
	RETVAL

SysRet
emptyset(sigset)
	POSIX::SigSet	sigset
   ALIAS:
	fillset = 1
   CODE:
	RETVAL = ix ? sigfillset(sigset) : sigemptyset(sigset);
   OUTPUT:
	RETVAL

int
sigismember(sigset, sig)
	POSIX::SigSet	sigset
	int		sig

MODULE = Termios	PACKAGE = POSIX::Termios	PREFIX = cf

void
new(packname = "POSIX::Termios", ...)
    const char *	packname
    CODE:
	{
#ifdef I_TERMIOS
	    void *const p = allocate_struct(aTHX_ (ST(0) = sv_newmortal()),
					    sizeof(struct termios), packname);
	    /* The previous implementation stored a pointer to an uninitialised
	       struct termios. Seems safer to initialise it, particularly as
	       this implementation exposes the struct to prying from perl-space.
	    */
	    memset(p, 0, 1 + sizeof(struct termios));
	    XSRETURN(1);
#else
	    not_here("termios");
#endif
	}

SysRet
getattr(termios_ref, fd = 0)
	POSIX::Termios	termios_ref
	int		fd
    CODE:
	RETVAL = tcgetattr(fd, termios_ref);
    OUTPUT:
	RETVAL

# If we define TCSANOW here then both a found and not found constant sub
# are created causing a Constant subroutine TCSANOW redefined warning
#ifndef TCSANOW
#  define DEF_SETATTR_ACTION 0
#else
#  define DEF_SETATTR_ACTION TCSANOW
#endif
SysRet
setattr(termios_ref, fd = 0, optional_actions = DEF_SETATTR_ACTION)
	POSIX::Termios	termios_ref
	int		fd
	int		optional_actions
    CODE:
	/* The second argument to the call is mandatory, but we'd like to give
	   it a useful default. 0 isn't valid on all operating systems - on
	   Solaris (at least) TCSANOW, TCSADRAIN and TCSAFLUSH have the same
	   values as the equivalent ioctls, TCSETS, TCSETSW and TCSETSF.  */
	RETVAL = tcsetattr(fd, optional_actions, termios_ref);
    OUTPUT:
	RETVAL

speed_t
getispeed(termios_ref)
	POSIX::Termios	termios_ref
    ALIAS:
	getospeed = 1
    CODE:
	RETVAL = ix ? cfgetospeed(termios_ref) : cfgetispeed(termios_ref);
    OUTPUT:
	RETVAL

tcflag_t
getiflag(termios_ref)
	POSIX::Termios	termios_ref
    ALIAS:
	getoflag = 1
	getcflag = 2
	getlflag = 3
    CODE:
#ifdef I_TERMIOS /* References a termios structure member so ifdef it out. */
	switch(ix) {
	case 0:
	    RETVAL = termios_ref->c_iflag;
	    break;
	case 1:
	    RETVAL = termios_ref->c_oflag;
	    break;
	case 2:
	    RETVAL = termios_ref->c_cflag;
	    break;
	case 3:
	    RETVAL = termios_ref->c_lflag;
	    break;
        default:
	    RETVAL = 0; /* silence compiler warning */
	}
#else
	not_here(GvNAME(CvGV(cv)));
	RETVAL = 0;
#endif
    OUTPUT:
	RETVAL

cc_t
getcc(termios_ref, ccix)
	POSIX::Termios	termios_ref
	unsigned int	ccix
    CODE:
#ifdef I_TERMIOS /* References a termios structure member so ifdef it out. */
	if (ccix >= NCCS)
	    croak("Bad getcc subscript");
	RETVAL = termios_ref->c_cc[ccix];
#else
     not_here("getcc");
     RETVAL = 0;
#endif
    OUTPUT:
	RETVAL

SysRet
setispeed(termios_ref, speed)
	POSIX::Termios	termios_ref
	speed_t		speed
    ALIAS:
	setospeed = 1
    CODE:
	RETVAL = ix
	    ? cfsetospeed(termios_ref, speed) : cfsetispeed(termios_ref, speed);
    OUTPUT:
	RETVAL

void
setiflag(termios_ref, flag)
	POSIX::Termios	termios_ref
	tcflag_t	flag
    ALIAS:
	setoflag = 1
	setcflag = 2
	setlflag = 3
    CODE:
#ifdef I_TERMIOS /* References a termios structure member so ifdef it out. */
	switch(ix) {
	case 0:
	    termios_ref->c_iflag = flag;
	    break;
	case 1:
	    termios_ref->c_oflag = flag;
	    break;
	case 2:
	    termios_ref->c_cflag = flag;
	    break;
	case 3:
	    termios_ref->c_lflag = flag;
	    break;
	}
#else
	not_here(GvNAME(CvGV(cv)));
#endif

void
setcc(termios_ref, ccix, cc)
	POSIX::Termios	termios_ref
	unsigned int	ccix
	cc_t		cc
    CODE:
#ifdef I_TERMIOS /* References a termios structure member so ifdef it out. */
	if (ccix >= NCCS)
	    croak("Bad setcc subscript");
	termios_ref->c_cc[ccix] = cc;
#else
	    not_here("setcc");
#endif


MODULE = POSIX		PACKAGE = POSIX

INCLUDE: const-xs.inc

int
WEXITSTATUS(status)
	int status
    ALIAS:
	POSIX::WIFEXITED = 1
	POSIX::WIFSIGNALED = 2
	POSIX::WIFSTOPPED = 3
	POSIX::WSTOPSIG = 4
	POSIX::WTERMSIG = 5
    CODE:
#if !defined(WEXITSTATUS) || !defined(WIFEXITED) || !defined(WIFSIGNALED) \
      || !defined(WIFSTOPPED) || !defined(WSTOPSIG) || !defined(WTERMSIG)
        RETVAL = 0; /* Silence compilers that notice this, but don't realise
		       that not_here() can't return.  */
#endif
	switch(ix) {
	case 0:
#ifdef WEXITSTATUS
	    RETVAL = WEXITSTATUS(WMUNGE(status));
#else
	    not_here("WEXITSTATUS");
#endif
	    break;
	case 1:
#ifdef WIFEXITED
	    RETVAL = WIFEXITED(WMUNGE(status));
#else
	    not_here("WIFEXITED");
#endif
	    break;
	case 2:
#ifdef WIFSIGNALED
	    RETVAL = WIFSIGNALED(WMUNGE(status));
#else
	    not_here("WIFSIGNALED");
#endif
	    break;
	case 3:
#ifdef WIFSTOPPED
	    RETVAL = WIFSTOPPED(WMUNGE(status));
#else
	    not_here("WIFSTOPPED");
#endif
	    break;
	case 4:
#ifdef WSTOPSIG
	    RETVAL = WSTOPSIG(WMUNGE(status));
#else
	    not_here("WSTOPSIG");
#endif
	    break;
	case 5:
#ifdef WTERMSIG
	    RETVAL = WTERMSIG(WMUNGE(status));
#else
	    not_here("WTERMSIG");
#endif
	    break;
	default:
	    Perl_croak(aTHX_ "Illegal alias %d for POSIX::W*", (int)ix);
	}
    OUTPUT:
	RETVAL

SysRet
open(filename, flags = O_RDONLY, mode = 0666)
	char *		filename
	int		flags
	Mode_t		mode
    CODE:
	if (flags & (O_APPEND|O_CREAT|O_TRUNC|O_RDWR|O_WRONLY|O_EXCL))
	    TAINT_PROPER("open");
	RETVAL = open(filename, flags, mode);
    OUTPUT:
	RETVAL


HV *
localeconv()
    CODE:
#ifndef HAS_LOCALECONV
	localeconv(); /* A stub to call not_here(). */
#else
	struct lconv *lcbuf;

        /* localeconv() deals with both LC_NUMERIC and LC_MONETARY, but
         * LC_MONETARY is already in the correct locale */
        STORE_NUMERIC_STANDARD_FORCE_LOCAL();

	RETVAL = newHV();
	sv_2mortal((SV*)RETVAL);
	if ((lcbuf = localeconv())) {
	    const struct lconv_offset *strings = lconv_strings;
	    const struct lconv_offset *integers = lconv_integers;
	    const char *ptr = (const char *) lcbuf;

	    do {
                /* This string may be controlled by either LC_NUMERIC, or
                 * LC_MONETARY */
                bool is_utf8_locale
#if defined(USE_LOCALE_NUMERIC) && defined(USE_LOCALE_MONETARY)
                 = _is_cur_LC_category_utf8((isLC_NUMERIC_STRING(strings->name))
                                             ? LC_NUMERIC
                                             : LC_MONETARY);
#elif defined(USE_LOCALE_NUMERIC)
                 = _is_cur_LC_category_utf8(LC_NUMERIC);
#elif defined(USE_LOCALE_MONETARY)
                 = _is_cur_LC_category_utf8(LC_MONETARY);
#else
                 = FALSE;
#endif

		const char *value = *((const char **)(ptr + strings->offset));

		if (value && *value) {
		    (void) hv_store(RETVAL,
                        strings->name,
                        strlen(strings->name),
                        newSVpvn_utf8(value,
                                      strlen(value),

                                      /* We mark it as UTF-8 if a utf8 locale
                                       * and is valid, non-ascii UTF-8 */
                                      is_utf8_locale
                                        && ! is_ascii_string((U8 *) value, 0)
                                        && is_utf8_string((U8 *) value, 0)),
                        0);
                  }
	    } while ((++strings)->name);

	    do {
		const char value = *((const char *)(ptr + integers->offset));

		if (value != CHAR_MAX)
		    (void) hv_store(RETVAL, integers->name,
				    strlen(integers->name), newSViv(value), 0);
	    } while ((++integers)->name);
	}
        RESTORE_NUMERIC_STANDARD();
#endif  /* HAS_LOCALECONV */
    OUTPUT:
	RETVAL

char *
setlocale(category, locale = 0)
	int		category
	const char *    locale
    PREINIT:
	char *		retval;
    CODE:
#ifdef USE_LOCALE_NUMERIC
        /* A 0 (or NULL) locale means only query what the current one is.  We
         * have the LC_NUMERIC name saved, because we are normally switched
         * into the C locale for it.  Switch back so an LC_ALL query will yield
         * the correct results; all other categories don't require special
         * handling */
        if (locale == 0) {
            if (category == LC_NUMERIC) {
                XSRETURN_PV(PL_numeric_name);
            }
#   ifdef LC_ALL
            else if (category == LC_ALL) {
                SET_NUMERIC_LOCAL();
            }
#   endif
        }
#endif
#ifdef WIN32    /* Use wrapper on Windows */
	retval = Perl_my_setlocale(aTHX_ category, locale);
#else
	retval = setlocale(category, locale);
#endif
	if (! retval) {
            /* Should never happen that a query would return an error, but be
             * sure and reset to C locale */
            if (locale == 0) {
                SET_NUMERIC_STANDARD();
            }
            XSRETURN_UNDEF;
        }

        /* Save retval since subsequent setlocale() calls may overwrite it. */
        retval = savepv(retval);

        /* For locale == 0, we may have switched to NUMERIC_LOCAL.  Switch back
         * */
        if (locale == 0) {
            SET_NUMERIC_STANDARD();
            XSRETURN_PV(retval);
        }
        else {
	    RETVAL = retval;
#ifdef USE_LOCALE_CTYPE
	    if (category == LC_CTYPE
#ifdef LC_ALL
		|| category == LC_ALL
#endif
		)
	    {
		char *newctype;
#ifdef LC_ALL
		if (category == LC_ALL)
		    newctype = setlocale(LC_CTYPE, NULL);
		else
#endif
		    newctype = RETVAL;
		new_ctype(newctype);
	    }
#endif /* USE_LOCALE_CTYPE */
#ifdef USE_LOCALE_COLLATE
	    if (category == LC_COLLATE
#ifdef LC_ALL
		|| category == LC_ALL
#endif
		)
	    {
		char *newcoll;
#ifdef LC_ALL
		if (category == LC_ALL)
		    newcoll = setlocale(LC_COLLATE, NULL);
		else
#endif
		    newcoll = RETVAL;
		new_collate(newcoll);
	    }
#endif /* USE_LOCALE_COLLATE */
#ifdef USE_LOCALE_NUMERIC
	    if (category == LC_NUMERIC
#ifdef LC_ALL
		|| category == LC_ALL
#endif
		)
	    {
		char *newnum;
#ifdef LC_ALL
		if (category == LC_ALL)
		    newnum = setlocale(LC_NUMERIC, NULL);
		else
#endif
		    newnum = RETVAL;
		new_numeric(newnum);
	    }
#endif /* USE_LOCALE_NUMERIC */
	}
    OUTPUT:
	RETVAL
    CLEANUP:
        Safefree(RETVAL);

NV
acos(x)
	NV		x
    ALIAS:
	acosh = 1
	asin = 2
	asinh = 3
	atan = 4
	atanh = 5
	cbrt = 6
	ceil = 7
	cosh = 8
	erf = 9
	erfc = 10
	exp2 = 11
	expm1 = 12
	floor = 13
	j0 = 14
	j1 = 15
	lgamma = 16
	log10 = 17
	log1p = 18
	log2 = 19
	logb = 20
	nearbyint = 21
	rint = 22
	round = 23
	sinh = 24
	tan = 25
	tanh = 26
	tgamma = 27
	trunc = 28
	y0 = 29
	y1 = 30
    CODE:
	RETVAL = NV_NAN;
	switch (ix) {
	case 0:
	    RETVAL = acos(x); /* C89 math */
	    break;
	case 1:
#ifdef c99_acosh
	    RETVAL = c99_acosh(x);
#else
	    not_here("acosh");
#endif
	    break;
	case 2:
	    RETVAL = asin(x); /* C89 math */
	    break;
	case 3:
#ifdef c99_asinh
	    RETVAL = c99_asinh(x);
#else
	    not_here("asinh");
#endif
	    break;
	case 4:
	    RETVAL = atan(x); /* C89 math */
	    break;
	case 5:
#ifdef c99_atanh
	    RETVAL = c99_atanh(x);
#else
	    not_here("atanh");
#endif
	    break;
	case 6:
#ifdef c99_cbrt
	    RETVAL = c99_cbrt(x);
#else
	    not_here("cbrt");
#endif
	    break;
	case 7:
	    RETVAL = ceil(x); /* C89 math */
	    break;
	case 8:
	    RETVAL = cosh(x); /* C89 math */
	    break;
	case 9:
#ifdef c99_erf
	    RETVAL = c99_erf(x);
#else
	    not_here("erf");
#endif
	    break;
	case 10:
#ifdef c99_erfc
	    RETVAL = erfc(x);
#else
	    not_here("erfc");
#endif
	    break;
	case 11:
#ifdef c99_exp2
	    RETVAL = c99_exp2(x);
#else
	    not_here("exp2");
#endif
	    break;
	case 12:
#ifdef c99_expm1
	    RETVAL = c99_expm1(x);
#else
	    not_here("expm1");
#endif
	    break;
	case 13:
	    RETVAL = floor(x); /* C89 math */
	    break;
	case 14:
#ifdef bessel_j0
	    RETVAL = bessel_j0(x);
#else
	    not_here("j0");
#endif
	    break;
	case 15:
#ifdef bessel_j1
	    RETVAL = bessel_j1(x);
#else
	    not_here("j1");
#endif
	    break;
	case 16:
        /* XXX lgamma_r -- the lgamma accesses a global variable (signgam),
         * which is evil.  Some platforms have lgamma_r, which has
         * extra parameter instead of the global variable. */
#ifdef c99_lgamma
	    RETVAL = c99_lgamma(x);
#else
	    not_here("lgamma");
#endif
	    break;
	case 17:
	    RETVAL = log10(x); /* C89 math */
	    break;
	case 18:
#ifdef c99_log1p
	    RETVAL = c99_log1p(x);
#else
	    not_here("log1p");
#endif
	    break;
	case 19:
#ifdef c99_log2
	    RETVAL = c99_log2(x);
#else
	    not_here("log2");
#endif
	    break;
	case 20:
#ifdef c99_logb
	    RETVAL = c99_logb(x);
#else
	    not_here("logb");
#endif
	    break;
	case 21:
#ifdef c99_nearbyint
	    RETVAL = c99_nearbyint(x);
#else
	    not_here("nearbyint");
#endif
	    break;
	case 22:
#ifdef c99_rint
	    RETVAL = c99_rint(x);
#else
	    not_here("rint");
#endif
	    break;
	case 23:
#ifdef c99_round
	    RETVAL = c99_round(x);
#else
	    not_here("round");
#endif
	    break;
	case 24:
	    RETVAL = sinh(x); /* C89 math */
	    break;
	case 25:
	    RETVAL = tan(x); /* C89 math */
	    break;
	case 26:
	    RETVAL = tanh(x); /* C89 math */
	    break;
	case 27:
        /* XXX tgamma_r -- the lgamma accesses a global variable (signgam),
         * which is evil.  Some platforms have tgamma_r, which has
         * extra parameter instead of the global variable. */
#ifdef c99_tgamma
	    RETVAL = c99_tgamma(x);
#else
	    not_here("tgamma");
#endif
	    break;
	case 28:
#ifdef c99_trunc
	    RETVAL = c99_trunc(x);
#else
	    not_here("trunc");
#endif
	    break;
	case 29:
#ifdef bessel_y0
	    RETVAL = bessel_y0(x);
#else
	    not_here("y0");
#endif
	    break;
        case 30:
	default:
#ifdef bessel_y1
	    RETVAL = bessel_y1(x);
#else
	    not_here("y1");
#endif
	}
    OUTPUT:
	RETVAL

IV
fegetround()
    CODE:
#ifdef HAS_FEGETROUND
	RETVAL = my_fegetround();
#else
	RETVAL = -1;
	not_here("fegetround");
#endif
    OUTPUT:
	RETVAL

IV
fesetround(x)
	IV	x
    CODE:
#ifdef HAS_FEGETROUND /* canary for fesetround */
	RETVAL = fesetround(x);
#else
	RETVAL = -1;
	not_here("fesetround");
#endif
    OUTPUT:
	RETVAL

IV
fpclassify(x)
	NV		x
    ALIAS:
	ilogb = 1
	isfinite = 2
	isinf = 3
	isnan = 4
	isnormal = 5
	lrint = 6
        signbit = 7
    CODE:
	RETVAL = -1;
	switch (ix) {
	case 0:
#ifdef c99_fpclassify
	    RETVAL = c99_fpclassify(x);
#else
	    not_here("fpclassify");
#endif
	    break;
	case 1:
#ifdef c99_ilogb
	    RETVAL = c99_ilogb(x);
#else
	    not_here("ilogb");
#endif
	    break;
	case 2:
	    RETVAL = Perl_isfinite(x);
	    break;
	case 3:
	    RETVAL = Perl_isinf(x);
	    break;
	case 4:
	    RETVAL = Perl_isnan(x);
	    break;
	case 5:
#ifdef c99_isnormal
	    RETVAL = c99_isnormal(x);
#else
	    not_here("isnormal");
#endif
	    break;
	case 6:
#ifdef c99_lrint
	    RETVAL = c99_lrint(x);
#else
	    not_here("lrint");
#endif
	    break;
	case 7:
	default:
#ifdef Perl_signbit
	    RETVAL = Perl_signbit(x);
#endif
	    break;
	}
    OUTPUT:
	RETVAL

NV
copysign(x,y)
	NV		x
	NV		y
    ALIAS:
	fdim = 1
	fmax = 2
	fmin = 3
	fmod = 4
	hypot = 5
	isgreater = 6
	isgreaterequal = 7
	isless = 8
	islessequal = 9
	islessgreater = 10
	isunordered = 11
	nextafter = 12
	nexttoward = 13
	remainder = 14
    CODE:
	RETVAL = NV_NAN;
	switch (ix) {
	case 0:
#ifdef c99_copysign
	    RETVAL = c99_copysign(x, y);
#else
	    not_here("copysign");
#endif
	    break;
	case 1:
#ifdef c99_fdim
	    RETVAL = c99_fdim(x, y);
#else
	    not_here("fdim");
#endif
	    break;
	case 2:
#ifdef c99_fmax
	    RETVAL = c99_fmax(x, y);
#else
	    not_here("fmax");
#endif
	    break;
	case 3:
#ifdef c99_fmin
	    RETVAL = c99_fmin(x, y);
#else
	    not_here("fmin");
#endif
	    break;
	case 4:
	    RETVAL = fmod(x, y); /* C89 math */
	    break;
	case 5:
#ifdef c99_hypot
	    RETVAL = c99_hypot(x, y);
#else
	    not_here("hypot");
#endif
	    break;
	case 6:
#ifdef c99_isgreater
	    RETVAL = c99_isgreater(x, y);
#else
	    not_here("isgreater");
#endif
	    break;
	case 7:
#ifdef c99_isgreaterequal
	    RETVAL = c99_isgreaterequal(x, y);
#else
	    not_here("isgreaterequal");
#endif
	    break;
	case 8:
#ifdef c99_isless
	    RETVAL = c99_isless(x, y);
#else
	    not_here("isless");
#endif
	    break;
	case 9:
#ifdef c99_islessequal
	    RETVAL = c99_islessequal(x, y);
#else
	    not_here("islessequal");
#endif
	    break;
	case 10:
#ifdef c99_islessgreater
	    RETVAL = c99_islessgreater(x, y);
#else
	    not_here("islessgreater");
#endif
	    break;
	case 11:
#ifdef c99_isunordered
	    RETVAL = c99_isunordered(x, y);
#else
	    not_here("isunordered");
#endif
	    break;
	case 12:
#ifdef c99_nextafter
	    RETVAL = c99_nextafter(x, y);
#else
	    not_here("nextafter");
#endif
	    break;
	case 13:
#ifdef c99_nexttoward
	    RETVAL = c99_nexttoward(x, y);
#else
	    not_here("nexttoward");
#endif
	    break;
	case 14:
	default:
#ifdef c99_remainder
	    RETVAL = c99_remainder(x, y);
#else
	    not_here("remainder");
#endif
	    break;
	}
	OUTPUT:
	    RETVAL

void
frexp(x)
	NV		x
    PPCODE:
	int expvar;
	/* (We already know stack is long enough.) */
	PUSHs(sv_2mortal(newSVnv(Perl_frexp(x,&expvar)))); /* C89 math */
	PUSHs(sv_2mortal(newSViv(expvar)));

NV
ldexp(x,exp)
	NV		x
	int		exp

void
modf(x)
	NV		x
    PPCODE:
	NV intvar;
	/* (We already know stack is long enough.) */
	PUSHs(sv_2mortal(newSVnv(Perl_modf(x,&intvar)))); /* C89 math */
	PUSHs(sv_2mortal(newSVnv(intvar)));

void
remquo(x,y)
	NV		x
	NV		y
    PPCODE:
#ifdef c99_remquo
        int intvar;
        PUSHs(sv_2mortal(newSVnv(c99_remquo(x,y,&intvar))));
        PUSHs(sv_2mortal(newSVnv(intvar)));
#else
	not_here("remquo");
#endif

NV
scalbn(x,y)
	NV		x
	IV		y
    CODE:
#ifdef c99_scalbn
	RETVAL = c99_scalbn(x, y);
#else
	RETVAL = NV_NAN;
	not_here("scalbn");
#endif
    OUTPUT:
	RETVAL

NV
fma(x,y,z)
	NV		x
	NV		y
	NV		z
    CODE:
#ifdef c99_fma
	RETVAL = c99_fma(x, y, z);
#else
	RETVAL = NV_NAN;
	not_here("fma");
#endif
    OUTPUT:
	RETVAL

NV
nan(s = "0")
	char*	s;
    CODE:
#ifdef c99_nan
	RETVAL = c99_nan(s);
#else
	RETVAL = NV_NAN;
	not_here("nan");
#endif
    OUTPUT:
	RETVAL

NV
jn(x,y)
	IV		x
	NV		y
    ALIAS:
	yn = 1
    CODE:
	RETVAL = NV_NAN;
        switch (ix) {
	case 0:
#ifdef bessel_jn
	    RETVAL = bessel_jn(x, y);
#else
	    not_here("jn");
#endif
            break;
	case 1:
	default:
#ifdef bessel_yn
	    RETVAL = bessel_yn(x, y);
#else
	    not_here("yn");
#endif
            break;
	}
    OUTPUT:
	RETVAL

SysRet
sigaction(sig, optaction, oldaction = 0)
	int			sig
	SV *			optaction
	POSIX::SigAction	oldaction
    CODE:
#if defined(WIN32) || defined(NETWARE)
	RETVAL = not_here("sigaction");
#else
# This code is really grody because we're trying to make the signal
# interface look beautiful, which is hard.

	{
	    dVAR;
	    POSIX__SigAction action;
	    GV *siggv = gv_fetchpvs("SIG", GV_ADD, SVt_PVHV);
	    struct sigaction act;
	    struct sigaction oact;
	    sigset_t sset;
	    SV *osset_sv;
	    sigset_t osset;
	    POSIX__SigSet sigset;
	    SV** svp;
	    SV** sigsvp;

            if (sig < 0) {
                croak("Negative signals are not allowed");
            }

	    if (sig == 0 && SvPOK(ST(0))) {
	        const char *s = SvPVX_const(ST(0));
		int i = whichsig(s);

	        if (i < 0 && memEQ(s, "SIG", 3))
		    i = whichsig(s + 3);
	        if (i < 0) {
	            if (ckWARN(WARN_SIGNAL))
		        Perl_warner(aTHX_ packWARN(WARN_SIGNAL),
                                    "No such signal: SIG%s", s);
	            XSRETURN_UNDEF;
		}
	        else
		    sig = i;
            }
#ifdef NSIG
	    if (sig > NSIG) { /* NSIG - 1 is still okay. */
	        Perl_warner(aTHX_ packWARN(WARN_SIGNAL),
                            "No such signal: %d", sig);
	        XSRETURN_UNDEF;
	    }
#endif
	    sigsvp = hv_fetch(GvHVn(siggv),
			      PL_sig_name[sig],
			      strlen(PL_sig_name[sig]),
			      TRUE);

	    /* Check optaction and set action */
	    if(SvTRUE(optaction)) {
		if(sv_isa(optaction, "POSIX::SigAction"))
			action = (HV*)SvRV(optaction);
		else
			croak("action is not of type POSIX::SigAction");
	    }
	    else {
		action=0;
	    }

	    /* sigaction() is supposed to look atomic. In particular, any
	     * signal handler invoked during a sigaction() call should
	     * see either the old or the new disposition, and not something
	     * in between. We use sigprocmask() to make it so.
	     */
	    sigfillset(&sset);
	    RETVAL=sigprocmask(SIG_BLOCK, &sset, &osset);
	    if(RETVAL == -1)
               XSRETURN_UNDEF;
	    ENTER;
	    /* Restore signal mask no matter how we exit this block. */
	    osset_sv = newSVpvn((char *)(&osset), sizeof(sigset_t));
	    SAVEFREESV( osset_sv );
	    SAVEDESTRUCTOR_X(restore_sigmask, osset_sv);

	    RETVAL=-1; /* In case both oldaction and action are 0. */

	    /* Remember old disposition if desired. */
	    if (oldaction) {
		svp = hv_fetchs(oldaction, "HANDLER", TRUE);
		if(!svp)
		    croak("Can't supply an oldaction without a HANDLER");
		if(SvTRUE(*sigsvp)) { /* TBD: what if "0"? */
			sv_setsv(*svp, *sigsvp);
		}
		else {
			sv_setpvs(*svp, "DEFAULT");
		}
		RETVAL = sigaction(sig, (struct sigaction *)0, & oact);
		if(RETVAL == -1) {
                   LEAVE;
                   XSRETURN_UNDEF;
                }
		/* Get back the mask. */
		svp = hv_fetchs(oldaction, "MASK", TRUE);
		if (sv_isa(*svp, "POSIX::SigSet")) {
		    sigset = (sigset_t *) SvPV_nolen(SvRV(*svp));
		}
		else {
		    sigset = (sigset_t *) allocate_struct(aTHX_ *svp,
							  sizeof(sigset_t),
							  "POSIX::SigSet");
		}
		*sigset = oact.sa_mask;

		/* Get back the flags. */
		svp = hv_fetchs(oldaction, "FLAGS", TRUE);
		sv_setiv(*svp, oact.sa_flags);

		/* Get back whether the old handler used safe signals. */
		svp = hv_fetchs(oldaction, "SAFE", TRUE);
		sv_setiv(*svp,
		/* compare incompatible pointers by casting to integer */
		    PTR2nat(oact.sa_handler) == PTR2nat(PL_csighandlerp));
	    }

	    if (action) {
		/* Safe signals use "csighandler", which vectors through the
		   PL_sighandlerp pointer when it's safe to do so.
		   (BTW, "csighandler" is very different from "sighandler".) */
		svp = hv_fetchs(action, "SAFE", FALSE);
		act.sa_handler =
			DPTR2FPTR(
			    void (*)(int),
			    (*svp && SvTRUE(*svp))
				? PL_csighandlerp : PL_sighandlerp
			);

		/* Vector new Perl handler through %SIG.
		   (The core signal handlers read %SIG to dispatch.) */
		svp = hv_fetchs(action, "HANDLER", FALSE);
		if (!svp)
		    croak("Can't supply an action without a HANDLER");
		sv_setsv(*sigsvp, *svp);

		/* This call actually calls sigaction() with almost the
		   right settings, including appropriate interpretation
		   of DEFAULT and IGNORE.  However, why are we doing
		   this when we're about to do it again just below?  XXX */
		SvSETMAGIC(*sigsvp);

		/* And here again we duplicate -- DEFAULT/IGNORE checking. */
		if(SvPOK(*svp)) {
			const char *s=SvPVX_const(*svp);
			if(strEQ(s,"IGNORE")) {
				act.sa_handler = SIG_IGN;
			}
			else if(strEQ(s,"DEFAULT")) {
				act.sa_handler = SIG_DFL;
			}
		}

		/* Set up any desired mask. */
		svp = hv_fetchs(action, "MASK", FALSE);
		if (svp && sv_isa(*svp, "POSIX::SigSet")) {
		    sigset = (sigset_t *) SvPV_nolen(SvRV(*svp));
		    act.sa_mask = *sigset;
		}
		else
		    sigemptyset(& act.sa_mask);

		/* Set up any desired flags. */
		svp = hv_fetchs(action, "FLAGS", FALSE);
		act.sa_flags = svp ? SvIV(*svp) : 0;

		/* Don't worry about cleaning up *sigsvp if this fails,
		 * because that means we tried to disposition a
		 * nonblockable signal, in which case *sigsvp is
		 * essentially meaningless anyway.
		 */
		RETVAL = sigaction(sig, & act, (struct sigaction *)0);
		if(RETVAL == -1) {
                    LEAVE;
		    XSRETURN_UNDEF;
                }
	    }

	    LEAVE;
	}
#endif
    OUTPUT:
	RETVAL

SysRet
sigpending(sigset)
	POSIX::SigSet		sigset
    ALIAS:
	sigsuspend = 1
    CODE:
	RETVAL = ix ? sigsuspend(sigset) : sigpending(sigset);
    OUTPUT:
	RETVAL
    CLEANUP:
    PERL_ASYNC_CHECK();

SysRet
sigprocmask(how, sigset, oldsigset = 0)
	int			how
	POSIX::SigSet		sigset = NO_INIT
	POSIX::SigSet		oldsigset = NO_INIT
INIT:
	if (! SvOK(ST(1))) {
	    sigset = NULL;
	} else if (sv_isa(ST(1), "POSIX::SigSet")) {
	    sigset = (sigset_t *) SvPV_nolen(SvRV(ST(1)));
	} else {
	    croak("sigset is not of type POSIX::SigSet");
	}

	if (items < 3 || ! SvOK(ST(2))) {
	    oldsigset = NULL;
	} else if (sv_isa(ST(2), "POSIX::SigSet")) {
	    oldsigset = (sigset_t *) SvPV_nolen(SvRV(ST(2)));
	} else {
	    croak("oldsigset is not of type POSIX::SigSet");
	}

void
_exit(status)
	int		status

SysRet
dup2(fd1, fd2)
	int		fd1
	int		fd2
    CODE:
#ifdef WIN32
	/* RT #98912 - More Microsoft muppetry - failing to actually implemented
	   the well known documented POSIX behaviour for a POSIX API.
	   http://msdn.microsoft.com/en-us/library/8syseb29.aspx   */
	RETVAL = dup2(fd1, fd2) == -1 ? -1 : fd2;
#else
	RETVAL = dup2(fd1, fd2);
#endif
    OUTPUT:
	RETVAL

SV *
lseek(fd, offset, whence)
	int		fd
	Off_t		offset
	int		whence
    CODE:
	Off_t pos = PerlLIO_lseek(fd, offset, whence);
	RETVAL = sizeof(Off_t) > sizeof(IV)
		 ? newSVnv((NV)pos) : newSViv((IV)pos);
    OUTPUT:
	RETVAL

void
nice(incr)
	int		incr
    PPCODE:
	errno = 0;
	if ((incr = nice(incr)) != -1 || errno == 0) {
	    if (incr == 0)
		XPUSHs(newSVpvs_flags("0 but true", SVs_TEMP));
	    else
		XPUSHs(sv_2mortal(newSViv(incr)));
	}

void
pipe()
    PPCODE:
	int fds[2];
	if (pipe(fds) != -1) {
	    EXTEND(SP,2);
	    PUSHs(sv_2mortal(newSViv(fds[0])));
	    PUSHs(sv_2mortal(newSViv(fds[1])));
	}

SysRet
read(fd, buffer, nbytes)
    PREINIT:
        SV *sv_buffer = SvROK(ST(1)) ? SvRV(ST(1)) : ST(1);
    INPUT:
        int             fd
        size_t          nbytes
        char *          buffer = sv_grow( sv_buffer, nbytes+1 );
    CLEANUP:
        if (RETVAL >= 0) {
            SvCUR_set(sv_buffer, RETVAL);
            SvPOK_only(sv_buffer);
            *SvEND(sv_buffer) = '\0';
            SvTAINTED_on(sv_buffer);
        }

SysRet
setpgid(pid, pgid)
	pid_t		pid
	pid_t		pgid

pid_t
setsid()

pid_t
tcgetpgrp(fd)
	int		fd

SysRet
tcsetpgrp(fd, pgrp_id)
	int		fd
	pid_t		pgrp_id

void
uname()
    PPCODE:
#ifdef HAS_UNAME
	struct utsname buf;
	if (uname(&buf) >= 0) {
	    EXTEND(SP, 5);
	    PUSHs(newSVpvn_flags(buf.sysname, strlen(buf.sysname), SVs_TEMP));
	    PUSHs(newSVpvn_flags(buf.nodename, strlen(buf.nodename), SVs_TEMP));
	    PUSHs(newSVpvn_flags(buf.release, strlen(buf.release), SVs_TEMP));
	    PUSHs(newSVpvn_flags(buf.version, strlen(buf.version), SVs_TEMP));
	    PUSHs(newSVpvn_flags(buf.machine, strlen(buf.machine), SVs_TEMP));
	}
#else
	uname((char *) 0); /* A stub to call not_here(). */
#endif

SysRet
write(fd, buffer, nbytes)
	int		fd
	char *		buffer
	size_t		nbytes

SV *
tmpnam()
    PREINIT:
	STRLEN i;
	int len;
    CODE:
	RETVAL = newSVpvs("");
	SvGROW(RETVAL, L_tmpnam);
	/* Yes, we know tmpnam() is bad.  So bad that some compilers
	 * and linkers warn against using it.  But it is here for
	 * completeness.  POSIX.pod warns against using it.
	 *
	 * Then again, maybe this should be removed at some point.
	 * No point in enabling dangerous interfaces. */
	len = strlen(tmpnam(SvPV(RETVAL, i)));
	SvCUR_set(RETVAL, len);
    OUTPUT:
	RETVAL

void
abort()

int
mblen(s, n)
	char *		s
	size_t		n

size_t
mbstowcs(s, pwcs, n)
	wchar_t *	s
	char *		pwcs
	size_t		n

int
mbtowc(pwc, s, n)
	wchar_t *	pwc
	char *		s
	size_t		n

int
wcstombs(s, pwcs, n)
	char *		s
	wchar_t *	pwcs
	size_t		n

int
wctomb(s, wchar)
	char *		s
	wchar_t		wchar

int
strcoll(s1, s2)
	char *		s1
	char *		s2

void
strtod(str)
	char *		str
    PREINIT:
	double num;
	char *unparsed;
    PPCODE:
        STORE_NUMERIC_STANDARD_FORCE_LOCAL();
	num = strtod(str, &unparsed);
	PUSHs(sv_2mortal(newSVnv(num)));
	if (GIMME == G_ARRAY) {
	    EXTEND(SP, 1);
	    if (unparsed)
		PUSHs(sv_2mortal(newSViv(strlen(unparsed))));
	    else
		PUSHs(&PL_sv_undef);
	}
        RESTORE_NUMERIC_STANDARD();

#ifdef HAS_STRTOLD

void
strtold(str)
	char *		str
    PREINIT:
	long double num;
	char *unparsed;
    PPCODE:
        STORE_NUMERIC_STANDARD_FORCE_LOCAL();
	num = strtold(str, &unparsed);
	PUSHs(sv_2mortal(newSVnv(num)));
	if (GIMME == G_ARRAY) {
	    EXTEND(SP, 1);
	    if (unparsed)
		PUSHs(sv_2mortal(newSViv(strlen(unparsed))));
	    else
		PUSHs(&PL_sv_undef);
	}
        RESTORE_NUMERIC_STANDARD();

#endif

void
strtol(str, base = 0)
	char *		str
	int		base
    PREINIT:
	long num;
	char *unparsed;
    PPCODE:
	num = strtol(str, &unparsed, base);
#if IVSIZE <= LONGSIZE
	if (num < IV_MIN || num > IV_MAX)
	    PUSHs(sv_2mortal(newSVnv((double)num)));
	else
#endif
	    PUSHs(sv_2mortal(newSViv((IV)num)));
	if (GIMME == G_ARRAY) {
	    EXTEND(SP, 1);
	    if (unparsed)
		PUSHs(sv_2mortal(newSViv(strlen(unparsed))));
	    else
		PUSHs(&PL_sv_undef);
	}

void
strtoul(str, base = 0)
	const char *	str
	int		base
    PREINIT:
	unsigned long num;
	char *unparsed;
    PPCODE:
	num = strtoul(str, &unparsed, base);
#if IVSIZE <= LONGSIZE
	if (num > IV_MAX)
	    PUSHs(sv_2mortal(newSVnv((double)num)));
	else
#endif
	    PUSHs(sv_2mortal(newSViv((IV)num)));
	if (GIMME == G_ARRAY) {
	    EXTEND(SP, 1);
	    if (unparsed)
		PUSHs(sv_2mortal(newSViv(strlen(unparsed))));
	    else
		PUSHs(&PL_sv_undef);
	}

void
strxfrm(src)
	SV *		src
    CODE:
	{
          STRLEN srclen;
          STRLEN dstlen;
          STRLEN buflen;
          char *p = SvPV(src,srclen);
          srclen++;
          buflen = srclen * 4 + 1;
          ST(0) = sv_2mortal(newSV(buflen));
          dstlen = strxfrm(SvPVX(ST(0)), p, (size_t)buflen);
          if (dstlen >= buflen) {
              dstlen++;
              SvGROW(ST(0), dstlen);
              strxfrm(SvPVX(ST(0)), p, (size_t)dstlen);
              dstlen--;
          }
          SvCUR_set(ST(0), dstlen);
	    SvPOK_only(ST(0));
	}

SysRet
mkfifo(filename, mode)
	char *		filename
	Mode_t		mode
    ALIAS:
	access = 1
    CODE:
	if(ix) {
	    RETVAL = access(filename, mode);
	} else {
	    TAINT_PROPER("mkfifo");
	    RETVAL = mkfifo(filename, mode);
	}
    OUTPUT:
	RETVAL

SysRet
tcdrain(fd)
	int		fd
    ALIAS:
	close = 1
	dup = 2
    CODE:
	RETVAL = ix == 1 ? close(fd)
	    : (ix < 1 ? tcdrain(fd) : dup(fd));
    OUTPUT:
	RETVAL


SysRet
tcflow(fd, action)
	int		fd
	int		action
    ALIAS:
	tcflush = 1
	tcsendbreak = 2
    CODE:
	RETVAL = ix == 1 ? tcflush(fd, action)
	    : (ix < 1 ? tcflow(fd, action) : tcsendbreak(fd, action));
    OUTPUT:
	RETVAL

void
asctime(sec, min, hour, mday, mon, year, wday = 0, yday = 0, isdst = -1)
	int		sec
	int		min
	int		hour
	int		mday
	int		mon
	int		year
	int		wday
	int		yday
	int		isdst
    ALIAS:
	mktime = 1
    PPCODE:
	{
	    dXSTARG;
	    struct tm mytm;
	    init_tm(&mytm);	/* XXX workaround - see init_tm() in core util.c */
	    mytm.tm_sec = sec;
	    mytm.tm_min = min;
	    mytm.tm_hour = hour;
	    mytm.tm_mday = mday;
	    mytm.tm_mon = mon;
	    mytm.tm_year = year;
	    mytm.tm_wday = wday;
	    mytm.tm_yday = yday;
	    mytm.tm_isdst = isdst;
	    if (ix) {
	        const time_t result = mktime(&mytm);
		if (result == (time_t)-1)
		    SvOK_off(TARG);
		else if (result == 0)
		    sv_setpvn(TARG, "0 but true", 10);
		else
		    sv_setiv(TARG, (IV)result);
	    } else {
		sv_setpv(TARG, asctime(&mytm));
	    }
	    ST(0) = TARG;
	    XSRETURN(1);
	}

long
clock()

char *
ctime(time)
	Time_t		&time

void
times()
	PPCODE:
	struct tms tms;
	clock_t realtime;
	realtime = times( &tms );
	EXTEND(SP,5);
	PUSHs( sv_2mortal( newSViv( (IV) realtime ) ) );
	PUSHs( sv_2mortal( newSViv( (IV) tms.tms_utime ) ) );
	PUSHs( sv_2mortal( newSViv( (IV) tms.tms_stime ) ) );
	PUSHs( sv_2mortal( newSViv( (IV) tms.tms_cutime ) ) );
	PUSHs( sv_2mortal( newSViv( (IV) tms.tms_cstime ) ) );

double
difftime(time1, time2)
	Time_t		time1
	Time_t		time2

#XXX: if $xsubpp::WantOptimize is always the default
#     sv_setpv(TARG, ...) could be used rather than
#     ST(0) = sv_2mortal(newSVpv(...))
void
strftime(fmt, sec, min, hour, mday, mon, year, wday = -1, yday = -1, isdst = -1)
	SV *		fmt
	int		sec
	int		min
	int		hour
	int		mday
	int		mon
	int		year
	int		wday
	int		yday
	int		isdst
    CODE:
	{
	    char *buf;
            SV *sv;

            /* allowing user-supplied (rather than literal) formats
             * is normally frowned upon as a potential security risk;
             * but this is part of the API so we have to allow it */
            GCC_DIAG_IGNORE(-Wformat-nonliteral);
	    buf = my_strftime(SvPV_nolen(fmt), sec, min, hour, mday, mon, year, wday, yday, isdst);
            GCC_DIAG_RESTORE;
            sv = sv_newmortal();
	    if (buf) {
                STRLEN len = strlen(buf);
		sv_usepvn_flags(sv, buf, len, SV_HAS_TRAILING_NUL);
		if (SvUTF8(fmt)
                    || (! is_ascii_string((U8*) buf, len)
                        && is_utf8_string((U8*) buf, len)
#ifdef USE_LOCALE_TIME
                        && _is_cur_LC_category_utf8(LC_TIME)
#endif
                )) {
		    SvUTF8_on(sv);
		}
            }
            else {  /* We can't distinguish between errors and just an empty
                     * return; in all cases just return an empty string */
                SvUPGRADE(sv, SVt_PV);
                SvPV_set(sv, (char *) "");
                SvPOK_on(sv);
                SvCUR_set(sv, 0);
                SvLEN_set(sv, 0);   /* Won't attempt to free the string when sv
                                       gets destroyed */
            }
            ST(0) = sv;
	}

void
tzset()
  PPCODE:
    my_tzset(aTHX);

void
tzname()
    PPCODE:
	EXTEND(SP,2);
	PUSHs(newSVpvn_flags(tzname[0], strlen(tzname[0]), SVs_TEMP));
	PUSHs(newSVpvn_flags(tzname[1], strlen(tzname[1]), SVs_TEMP));

char *
ctermid(s = 0)
	char *          s = 0;
    CODE:
#ifdef HAS_CTERMID_R
	s = (char *) safemalloc((size_t) L_ctermid);
#endif
	RETVAL = ctermid(s);
    OUTPUT:
	RETVAL
    CLEANUP:
#ifdef HAS_CTERMID_R
	Safefree(s);
#endif

char *
cuserid(s = 0)
	char *		s = 0;
    CODE:
#ifdef HAS_CUSERID
  RETVAL = cuserid(s);
#else
  RETVAL = 0;
  not_here("cuserid");
#endif
    OUTPUT:
  RETVAL

SysRetLong
fpathconf(fd, name)
	int		fd
	int		name

SysRetLong
pathconf(filename, name)
	char *		filename
	int		name

SysRet
pause()
    CLEANUP:
    PERL_ASYNC_CHECK();

unsigned int
sleep(seconds)
	unsigned int	seconds
    CODE:
	RETVAL = PerlProc_sleep(seconds);
    OUTPUT:
	RETVAL

SysRet
setgid(gid)
	Gid_t		gid

SysRet
setuid(uid)
	Uid_t		uid

SysRetLong
sysconf(name)
	int		name

char *
ttyname(fd)
	int		fd

void
getcwd()
    PPCODE:
      {
	dXSTARG;
	getcwd_sv(TARG);
	XSprePUSH; PUSHTARG;
      }

SysRet
lchown(uid, gid, path)
       Uid_t           uid
       Gid_t           gid
       char *          path
    CODE:
#ifdef HAS_LCHOWN
       /* yes, the order of arguments is different,
        * but consistent with CORE::chown() */
       RETVAL = lchown(path, uid, gid);
#else
       RETVAL = not_here("lchown");
#endif
    OUTPUT:
       RETVAL
