# Float-Formats
# Native Ruby Float support tools

require 'nio'
require 'nio/sugar'

require 'float-formats/bytes.rb'

# ========== Native type ==================================================================
# Float::RADIX : b = Radix of exponent representation,2

# Float::MANT_DIG : p = bits (base-RADIX digits) in the significand

# Float::DIG : q = Number of decimal digits such that any floating-point number with q
#              decimal digits can be rounded into a floating-point number with p radix b
#              digits and back again without change to the q decimal digits,
#	               q = p * log10(b)			if b is a power of 10
#               	q = floor((p - 1) * log10(b))	otherwise

# Float::MIN_EXP : emin = Minimum int x such that Float::RADIX**(x-1) is a normalized float

# Float::MIN_10_EXP : Minimum negative integer such that 10 raised to that power is in the
#                    range of normalized floating-point numbers,
#                      ceil(log10(b) * (emin - 1))

# Float::MAX_EXP : emax = Maximum int x such that Float::RADIX**(x-1) is a representable float

# Float::MAX_10_EXP : Maximum integer such that 10 raised to that power is in the range of
#                     representable finite floating-point numbers,
#                       floor(log10((1 - b**-p) * b**emax))

# Float::MAX : Maximum representable finite floating-point number
#                (1 - b**-p) * b**emax

# Float::EPSILON : The difference between 1 and the least value greater than 1 that is
#                  representable in the given floating point type
#                    b**(1-p) 

# Float::MIN  : Minimum normalized positive floating-point number
#                  b**(emin - 1).

# Float::ROUNDS : Addition rounds to 0: zero, 1: nearest, 2: +inf, 3: -inf, -1: unknown. 

# defined by NFmt: (in some systems this is called DECIMAL_DIG)
# Float::DIGITS2 :  Number of decimal digits, n, such that any floating-point number can be rounded
#                   to a floating-point number with n decimal digits and back again without
#                   change to the value,
#                     pmax * log10(b)			if b is a power of 10
#                     ceil(1 + pmax * log10(b))	otherwise

# Note that this uses the "fractional significand" interpretation

class Float
  def neighbours
    f,e = Math.frexp(self)  
    e = Float::MIN_EXP if f==0
    e = [Float::MIN_EXP,e].max
    dx = Math.ldexp(1,e-Float::MANT_DIG) #Math.ldexp(Math.ldexp(1.0,-Float::MANT_DIG),e)  
    
    min_f = 0.5 #0.5==Math.ldexp(2**(bits-1),-Float::MANT_DIG)
    max_f = 1.0 - Math.ldexp(1,-Float::MANT_DIG)
    
    if f==max_f
      high = self + dx*2
    elsif f==-min_f && e!=Float::MIN_EXP
      high = self + dx/2
    else
      high = self + dx
    end
    if e==Float::MIN_EXP || f!=min_f
      low = self - dx
    elsif f==-max_f
      high = self - dx*2
    else
      low = self - dx/2
    end
    [low, high]  
  end

  def prev
     neighbours[0]
  end
  def next
     neighbours[1]
  end
  
  # mínimo numero normalizado: = nxt(MAX_D)
  MIN_N = Math.ldexp(0.5,Float::MIN_EXP) # == nxt(MAX_D) == Float::MIN
  # máximo número denormalizado: = prv(MIN_N)
  MAX_D = Math.ldexp(Math.ldexp(1,Float::MANT_DIG-1)-1,Float::MIN_EXP-Float::MANT_DIG)
  # mínimo número denormalizado no nulo: = nxt(0)
  MIN_D = Math.ldexp(1,Float::MIN_EXP-Float::MANT_DIG);
  # maximum significand: = MAX_F = Math.frexp(Float::MAX)[0]   # == Math.ldexp(Math.ldexp(1,Float::MANT_DIG)-1,-Float::MANT_DIG) == Float::RADIZ
     
end


module FltPnt

# shortest decimal unanbiguous reprentation
def float_shortest_dec(x)
  x.nio_write(Fmt.prec(:exact))
end

# decimal representation showing all significant digits
def float_significant_dec(x)
  x.nio_write(Fmt.prec(:exact).show_all_digits(true))
end

# complete exact decimal representation
def float_dec(x)
  x.nio_write(Fmt.prec(:exact).approx_mode(:exact))
end

# binary representation
def float_bin(x)
  x.nio_write(Fmt.mode(:sci,:exact).base(2))
end

# ===== IEEE types =====================================================================================
 
# generate a SGL value stored in a byte string given a decimal value formatted as text
def sgl_from_text(txt, little_endian=true)
  code = little_endian ? 'e':'g'
  [txt].pack(code)
end

# generate a SGL value stored in a byte string given a Float value
def sgl_from_float(val, little_endian=true)
  code = little_endian ? 'e':'g'
  [val].pack(code)
end

# convert a SGL value stored in a byte string to a Float value
def sgl_to_float(sgl, littel_endian=true)
  code = little_endian ? 'e':'g'
  sgl.unpack(code)[0]
end


# generate a DBL value stored in a byte string given a decimal value formatted as text
def dbl_from_text(txt, little_endian=true)
  code = little_endian ? 'E':'G'
  [txt].pack(code)
end

# generate a DBL value stored in a byte string given a Float value
def dbl_from_float(val, little_endian=true)
  code = little_endian ? 'E':'G'
  [val].pack(code)
end

# convert a DBL value stored in a byte string to a Float value
def dbl_to_float(sgl, little_endian=true)
  code = little_endian ? 'E':'G'
  sgl.unpack(code)[0]
end

end