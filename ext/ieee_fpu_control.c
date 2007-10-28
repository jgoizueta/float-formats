#include <ruby.h>

#if HAVE_FENV_H
#include <fenv.h>

static VALUE mIEEE_FPU_fegetround(VALUE self)
{
  return UINT2NUM(fegetround());
}

/*
 * Set the FPU's rounding mode.
 */
static VALUE mIEEE_FPU_fesetround(VALUE self, VALUE mode)
{
  fesetround(NUM2UINT(mode));
  return UINT2NUM(fegetround());
}

#if HAVE_FESETPREC
static VALUE mIEEE_FPU_fegetprec(VALUE self)
{
  return UINT2NUM(fegetprec());
}
static VALUE mIEEE_FPU_fesetprec(VALUE self, VALUE prec)
{
  fesetprec(NUM2UINT(prec));
  return UINT2NUM(fegetprec());
}
#endif


#endif 


#if HAVE_FPU_CONTROL_H

#include <fpu_control.h>

static VALUE mIEEE_FPU_fpu_getround(VALUE self)
{
  fpu_control_t mask = (_FPU_RC_NEAREST|_FPU_RC_DOWN|_FPU_RC_UP|_FPU_RC_ZERO);
  fpu_control_t c;
  _FPU_GETCW(c);  
  return UINT2NUM(c & mask);
}

static VALUE mIEEE_FPU_fpu_setround(VALUE self, VALUE mode)
{
  fpu_control_t mask = (_FPU_RC_NEAREST|_FPU_RC_DOWN|_FPU_RC_UP|_FPU_RC_ZERO);
  fpu_control_t c, new_c;
  _FPU_GETCW(c);  
  new_c = c;
  new_c &= ~mask;
  new_c |= NUM2UINT(mode);
  _FPU_SETCW(new_c);  
  return UINT2NUM(c & mask);
}

static VALUE mIEEE_FPU_fpu_getprec(VALUE self)
{
  fpu_control_t mask = (_FPU_EXTENDED|_FPU_DOUBLE|_FPU_SINGLE);
  fpu_control_t c;
  _FPU_GETCW(c);  
  return UINT2NUM(c & mask);
}
static VALUE mIEEE_FPU_fpu_setprec(VALUE self, VALUE prec)
{
  fpu_control_t mask = (_FPU_EXTENDED|_FPU_DOUBLE|_FPU_SINGLE);
  fpu_control_t c, new_c;
  _FPU_GETCW(c);  
  new_c = c;
  new_c &= ~mask;
  new_c |= NUM2UINT(prec);
  _FPU_SETCW(new_c);  
  return UINT2NUM(c & mask);
}

#endif

static VALUE mIEEE_FPU;

void Init_ieee_fpu_control() {
  mIEEE_FPU = rb_define_module("IEEE_FPU");

  #if HAVE_FPU_CONTROL_H
  rb_define_const(mIEEE_FPU, "FPU_RC_NEAREST", UINT2NUM(_FPU_RC_NEAREST));
  rb_define_const(mIEEE_FPU, "FPU_RC_DOWN", UINT2NUM(_FPU_RC_DOWN));
  rb_define_const(mIEEE_FPU, "FPU_RC_UP", UINT2NUM(_FPU_RC_UP));
  rb_define_const(mIEEE_FPU, "FPU_RC_ZERO", UINT2NUM(_FPU_RC_ZERO));

  rb_define_module_function(mIEEE_FPU, "fpu_getround", mIEEE_FPU_fpu_getround, 0);
  rb_define_module_function(mIEEE_FPU, "fpu_setround", mIEEE_FPU_fpu_setround, 1);
  
  rb_define_const(mIEEE_FPU, "FPU_EXTENDED", UINT2NUM(_FPU_EXTENDED));
  rb_define_const(mIEEE_FPU, "FPU_DOUBLE", UINT2NUM(_FPU_DOUBLE));
  rb_define_const(mIEEE_FPU, "FPU_SINGLE", UINT2NUM(_FPU_SINGLE));

  rb_define_module_function(mIEEE_FPU, "fpu_getprec", mIEEE_FPU_fpu_getprec, 0);
  rb_define_module_function(mIEEE_FPU, "fpu_setprec", mIEEE_FPU_fpu_setprec, 1);
  #endif

  #if HAVE_FENV_H
  rb_define_const(mIEEE_FPU, "FE_DOWNWARD", UINT2NUM(FE_DOWNWARD));
  rb_define_const(mIEEE_FPU, "FE_TONEAREST", UINT2NUM(FE_TONEAREST));
  rb_define_const(mIEEE_FPU, "FE_TOWARDZERO", UINT2NUM(FE_TOWARDZERO));
  rb_define_const(mIEEE_FPU, "FE_UPWARD", UINT2NUM(FE_UPWARD));

  rb_define_module_function(mIEEE_FPU, "fegetround", mIEEE_FPU_fegetround, 0);
  rb_define_module_function(mIEEE_FPU, "fesetround", mIEEE_FPU_fesetround, 1);
  
  #if HAVE_FESETPREC
  rb_define_const(mIEEE_FPU, "FE_FLTPREC", UINT2NUM(FE_FLTPREC));
  rb_define_const(mIEEE_FPU, "FE_DBLPREC", UINT2NUM(FE_DBLPREC));
  rb_define_const(mIEEE_FPU, "FE_LDBLPREC", UINT2NUM(FE_LDBLPREC));

  rb_define_module_function(mIEEE_FPU, "fegetprec", mIEEE_FPU_fegetprec, 0);
  rb_define_module_function(mIEEE_FPU, "fesetprec", mIEEE_FPU_fesetprec, 1);
  #endif
  #endif
}
