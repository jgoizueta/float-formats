#!/usr/bin/ruby
require 'mkmf'

fenv = control = false

if have_header('fenv.h')
  fenv = true
  #$defs.push "IEEE_FPU_FENV=1"
  have_func('fesetprec','fenv.h')
end

if have_header('fpu_control.h')
  control = true
  #$defs.push "IEEE_FPU_CONTROL=1"
end
create_makefile("ieee_fpu_control") if fenv || control

