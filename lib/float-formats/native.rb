#Float-Formats -- Native Ruby Float support tools

require 'flt'
require 'flt/float'
require 'float-formats/bytes'

module Flt

module_function

# shortest decimal unambiguous reprentation
def float_shortest_dec(x)
  Numerals::Format[:short].write(x)
end

# decimal representation showing all significant digits
def float_significant_dec(x)
  Numerals::Format[:free].write(x)
end

# complete exact decimal representation
def float_dec(x)
  Numerals::Format[:free, :exact_input].write(x)
end

# binary representation
def float_bin(x)
  Numerals::Format[:free, :exact_input, :scientific, base: 2].write(x)
end

# decompose a float into a signed integer significand and exponent (base Float::RADIX)
def float_to_integral_significand_exponent(x)
  Float.context.to_int_scale(x)
end

# compose float from significand and exponent
def float_from_integral_significand_exponent(s,e)
  Float.context.Num(s,e)
end

def float_to_integral_sign_significand_exponent(x)
  Float.context.split(x)
end

def float_from_integral_sign_significand_exponent(sgn,s,e)
  Float.context.Num(sgn,s,e)
end

# convert a float to C99's hexadecimal notation
def hex_from_float(v)
  Numerals::Format[:hexbin].write(v)
end

# convert a string formatted in C99's hexadecimal notation to a float
def hex_to_float(txt)
  # Numerals::Format[:hexbin].read(txt, type: Float)
  # txt.scanf("%A").first
  Float(txt)
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
