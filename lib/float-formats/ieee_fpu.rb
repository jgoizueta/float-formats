# IEEE_FPU -- IEEE FPU control
# Javier Goizueta 2007

begin
  require 'ieee_fpu_control'
  IEEE_FPU_FENV = IEEE_FPU.respond_to?(:fesetround)
  IEEE_FPU_CONTROL = IEEE_FPU.respond_to?(:fpu_setprec)
  rescue LoadError
  IEEE_FPU_FENV = false
  IEEE_FPU_CONTROL = false
end

unless IEEE_FPU_FENV || IEEE_FPU_CONTROL
    
require 'Win32API'

# Control of IEEE compliant FPUs rounding mode
# and precision (if available).
# IEEE_FPU has two writeable properties:
# * rounding which has values :even, :up, :down and :zero
# * precision with values :single, :double and :extended
# The latter property is not available in all IEEE FPUs
# The scope method can be used to set up an scope in which
# FPU properties are modified; when the scope is exited
# the FPU state is restored.
# Examples:
#   puts IEEE_FPU.rounding                # -> even
#   puts "%.20f"%(1.0+Float::EPSILON/2)   # -> 1.00000000000000000000
#   IEEE_FPU.scope {
#     IEEE_FPU.rounding = :down
#     puts IEEE_FPU.rounding              # -> down
#     puts "%.20f"%(1.0+Float::EPSILON/2) # -> 1.00000000000000000000
#   }
#   IEEE_FPU.scope { |fpu|
#     fpu.rounding = :up
#     puts IEEE_FPU.rounding              # -> up
#     puts "%.20f"%(1.0+Float::EPSILON/2) # -> 1.0000000000000002220
#   }
#   puts IEEE_FPU.rounding                # -> even
#   puts "%.20f"%(1.0+Float::EPSILON/2)   # -> 1.00000000000000000000
#
#   expr = '(3.2-2.0)-1.2'
#   IEEE_FPU.scope {
#     IEEE_FPU.precision = :single           # -> 0.0
#     puts eval(expr)
#   }
#   IEEE_FPU.scope {
#     IEEE_FPU.precision = :double
#     puts eval(expr)                        # -> 2.22044604925031e-16
#   }
#
# Note: IEEE_FPU.precision=:extended has a very limited influence in Ruby
# because all results are casted to Float (double) values. 
# Its effect is more noticeable in C/C++ extensions.

# FPU parameters can be assigneed passign a hash to the scope method:
#   IEEE_FPU.scope(:precision=>:single) {
#     puts eval(expr)
#   }
# An array can be passed for one (only one) of the parameters;
# the block will be repeated with every value of the parameter
# and the results will be collected in an array. 
# For example this checks the result of an expression in all
# the rounding modes:
#  puts IEEE_FPU.scope(:rounding=>[:even,:up,:down,:zero]) {
#    1.0 + Float::EPSILON/2
#  }.inspect
#
# Different parameters can be passed to each call of the block
# by assigning an array to :parameters
# For example, interval arithmetic could be implementes like this:
#  def sum_intervals(i1,i2)
#    IEEE_FPU.scope(:rounding=>[:down,:up],:parameters=>[0,1]) do |fpu,i|
#      i1[i]+i2[i]
#    end
#  end
#  i = sum_intervals([1.0]*2, [Float::EPSILON/2]*2)


module IEEE_FPU

  class Error < StandardError
  end

  def self.get_status
    Controlfp.call(0,0)
  end
  def self.set_status(s)
    Controlfp.call(s,MCW_DN|MCW_EM|MCW_IC|MCW_RC|MCW_PC)
  end
  def self.scope(assignments={})
    v = nil
    s = get_status
    prc = assignments[:precision]
    rnd = assignments[:rounding]
    self.precision = prc if prc && !(Array===prc)
    self.rounding =rnd if rnd && !(Array===rnd)
    if Array===prc      
      param = assignments[:parameters] || [nil]*prc.size
      v = []
      i = 0
      prc.each do |p|
        self.precision = p
        v << yield(self, param[i])
        i += 1
      end
    elsif Array===rnd
      param = assignments[:parameters] || [nil]*rnd.size
      v = []
      i = 0
      rnd.each do |r|
        self.rounding = r
        v << yield(self, param[i])
        i += 1
      end
    else
      v = yield(self)
    end
    v
    ensure
      set_status s
  end
  
  def self.precision
    v = get_status & MCW_PC
    p = nil
    case v
      when PC_24
        p = :single
      when PC_53
        p = :double
      when PC_64
        p = :extended
    end
    p
  end
  def self.precision=(p)
    v = nil
    case p
      when :single, 24
        v = PC_24
      when :double, 53
        v = PC_53
      when :extended, 64, 112
        v = PC_64
      else
        raise Error, "Invalid precision #{p.inspect}"
    end
    Controlfp.call(v,MCW_PC) unless v.nil?
    p
  end

  def self.rounding
    v = get_status & MCW_RC
    r = nil
    case v
      when RC_UP
        r = :up
      when RC_DOWN
        r = :down
      when RC_CHOP
        r = :zero
      when RC_NEAR
        r = :even
    end
    r  
  end

  def self.rounding=(r)
    v = nil
    case r
      when :up, :plus_infinity, :positive_infinity
        v = RC_UP
      when :down, :minus_inifinity, :negative_infinity
        v = RC_DOWN
      when :zero, :truncate, :chop
        v = RC_CHOP
      when :even, :near, :unbiased
        v = RC_NEAR
      else
        raise Error, "Invalid rounding mode #{r}"
      end
    Controlfp.call(v,MCW_RC) unless v.nil?
    r
  end


 	Controlfp = Win32API.new('msvcrt', '_controlfp', 'II', 'I')
  MCW_DN = 0x03000000 # Denormal control mask
    DN_SAVE  = 0x00000000
    DN_FLUSH = 0x01000000
  MCW_EM = 0x0008001F # Interrupt exception mask
    EM_INVALID =    0x00000010
    EM_DENORMAL =   0x00080000
    EM_ZERODIVIDE = 0x00000008
    EM_OVERFLOW =   0x00000004
    EM_UNDERFLOW =  0x00000002
    EM_INEXACT =    0x00000001
  MCW_IC = 0x00040000 # Infinity control mask
    IC_AFFINE     = 0x00040000
    IC_PROJECTIVE = 0x00000000
  MCW_RC = 0x00000300 # Rounding control mask
    RC_CHOP = 0x00000300
    RC_UP   = 0x00000200
    RC_DOWN = 0x00000100
    RC_NEAR = 0x00000000
  MCW_PC = 0x00030000 # Precision control mask
    PC_24 = 0x00020000 # 24 bits
    PC_53 = 0x00010000 # 53 bits
    PC_64 = 0x00000000 # 64 bits
end    
  
else
  
# use ieee_fpu extension
module IEEE_FPU

  class Error < StandardError
  end

  def self.get_status
    status = []
    if IEEE_FPU_FENV
      status << fegetround
      if self.respond_to?(:fegetprec)
        status << fegetprec
      elsif IEEE_FPU_CONTROL
        status << fpu_getprec
      end
    else
      status << fpu_getround
      status << fpu_getprec
    end            
    status
  end
  def self.set_status(s)
    r_s,p_s = s
    if IEEE_FPU_FENV
      fesetround r_s
      if self.respond_to?(:fesetprec)
        fesetprec  p_s
      elsif IEEE_FPU_CONTROL
        fpu_setprec  p_s
      end
    else
      fpu_setround r_s
      fpu_setprec p_s
    end
    
  end
  
  def self.scope
    s = get_status
    yield self
    ensure
      set_status s
  end
  
  def self.precision
    p = nil
    if IEEE_FPU_FENV && self.respond_to?(:fegetprec)
      v = fegetprec
      case v
        when FE_FLTPREC
          p = :single
        when FE_DBLPREC
          p = :double
        when FE_LDBLPREC
          p = :extended
      end
    elsif IEEE_FPU_CONTROL
      v = fpu_getprec
      case v
        when FPU_SINGLE
          p = :single
        when FPU_DOUBLE
          p = :double
        when FPU_EXTENDED
          p = :extended
      end
    end
    p
  end
  def self.precision=(p)
    if IEEE_FPU_FENV &&  self.respond_to?(:fesetprec)      
      v = nil
      case p
        when :single,24
          v = FE_FLTPREC
        when :double,53
          v = FE_DBLPREC
        when :extended,64,112
          v = FE_LDBLPREC
        else
          raise Error, "Invalid precision #{p.inspect}"
      end
      fesetprec v
    elsif IEEE_FPU_CONTROL
      v = nil
      case p
        when :single,24
          v = FPU_SINGLE
        when :double,53
          v = FPU_DOUBLE
        when :extended,64,112
          v = FPU_EXTENDED
        else
          raise Error, "Invalid precision #{p.inspect}"
      end
      fpu_setprec v
    else
      raise Error, "Precision not supported"
    end
    p
  end

  def self.rounding
    if IEEE_FPU_FENV
      v = fegetround
      r = nil
      case v
        when FE_UPWARD
          r = :up
        when FE_DOWNWARD
          r = :down
        when FE_TOWARDZERO
          r = :zero
        when FE_TONEAREST
          r = :even
      end
    else
      v = fpu_getround
      r = nil
      case v
        when FPU_RC_UP
          r = :up
        when FPU_RC_DOWN
          r = :down
        when FPU_RC_ZERO
          r = :zero
        when FPU_RC_NEAREST
          r = :even
      end
    end
    r  
  end

  def self.rounding=(r)
    v = nil
    if IEEE_FPU_FENV
      case r
        when :up, :plus_infinity, :positive_infinity
          v = FE_UPWARD
        when :down, :minus_inifinity, :negative_infinity
          v = FE_DOWNWARD
        when :zero, :truncate, :chop
          v = FE_TOWARDZERO
        when :even, :near, :unbiased
          v = FE_TONEAREST
        else
          raise Error, "Invalid rounding mode #{r}"
        end
      fesetround v unless v.nil?
    else
      case r
        when :up, :plus_infinity, :positive_infinity
          v = FPU_RC_UP
        when :down, :minus_inifinity, :negative_infinity
          v = FPU_RC_DOWN
        when :zero, :truncate, :chop
          v = FPU_RC_ZERO
        when :even, :near, :unbiased
          v = FPU_RC_NEAREST
        else
          raise Error, "Invalid rounding mode #{r}"
      end
      fpu_setround v unless v.nil?
    end  
    r
  end
end  
  
end


  
  
  