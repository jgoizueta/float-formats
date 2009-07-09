#Float-Formats -- Native Ruby Float support tools

require 'nio'
require 'nio/sugar'
require 'flt'
require 'flt/float'
require 'float-formats/bytes'

module Flt

module_function

# shortest decimal unambiguous reprentation
def float_shortest_dec(x)
  x.nio_write(Nio::Fmt.prec(:exact))
end

# decimal representation showing all significant digits
def float_significant_dec(x)
  x.nio_write(Nio::Fmt.prec(:exact).show_all_digits(true))
end

# complete exact decimal representation
def float_dec(x)
  x.nio_write(Nio::Fmt.prec(:exact).approx_mode(:exact))
end

# binary representation
def float_bin(x)
  x.nio_write(Nio::Fmt.mode(:sci,:exact).base(2))
end

# decompose a float into a signed integer significand and exponent (base Float::RADIX)
def float_to_integral_significand_exponent(x)
  s,e = Math.frexp(x)
  [Math.ldexp(s,Float::MANT_DIG).to_i,e-Float::MANT_DIG]
end

# compose float from significand and exponent
def float_from_integral_significand_exponent(s,e)
  Math.ldexp(s,e)
end

def float_to_integral_sign_significand_exponent(x)
  if x==0.0
    sign = (1/x<0) ? -1 : +1
  else
    sign = x<0 ? -1 : +1
  end
  x = -x if sign<0
  s,e = Math.frexp(x)
  [sign,Math.ldexp(s,Float::MANT_DIG).to_i,e-Float::MANT_DIG]
end

def float_from_integral_sign_significand_exponent(sgn,s,e)
  f = Math.ldexp(s,e)
  f = -f if sgn<0
  f
end

# convert a float to C99's hexadecimal notation
def hex_from_float(v)
  if Float::RADIX==2
    sgn,s,e = float_to_integral_sign_significand_exponent(v)
  else
    txt = v.nio_write(Fmt.base(2).sep('.')).upcase
    p = txt.index('E')
    exp = 0
    if p
      exp = rep[p+1..-1].to_i
      txt = rep[0...p]
    end
    p = txt.index('.')
    if p
      exp -= (txt.size-p-1)
      txt.tr!('.','')
    end
    s = txt.to_i(2)
    e = exp
  end
  "0x#{sgn<0 ? '-' : ''}#{s.to_s(16)}p#{e}"
end

# convert a string formatted in C99's hexadecimal notation to a float
def hex_to_float(txt)
  txt = txt.strip.upcase
  txt = txt[2..-1] if txt[0,2]=='0X'
  p = txt.index('P')
  if p
    exp = txt[p+1..-1].to_i
    txt = txt[0...p]
  else
    exp = 0
  end
  p = txt.index('.')
  if p
    exp -= (txt.size-p-1)*4
    txt.tr!('.','')
  end
  if Float::RADIX==2
    v = txt.to_i(16)
    if v==0 && txt.include?('-')
      sign = -1
    elsif v<0
      sign = -1
      v = -v
    else
      sign = +1
    end
    float_from_integral_sign_significand_exponent(sign,v,exp)
  else
    (txt.to_i(16)*(2**exp)).to_f
  end
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