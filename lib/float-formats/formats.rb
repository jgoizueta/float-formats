# Float-Formats
# Definition of common floating-point formats

require 'enumerator'

require 'float-formats/classes.rb'


module Flt


# Floating Point Format Definitions ==========================================

# Helper methods to define IEEE 754r formats
module IEEE
  # Define an IEEE binary format by passing parameters in a hash;
  # :significand and :exponent are used to defined the fields,
  # optional parameters may follow.
  def self.binary(name, parameters)
    significand_bits = parameters[:significand]
    exponent_bits = parameters[:exponent]
    Flt.define(name, {
      base: BinaryFormat,
      fields: [:significand, significand_bits, :exponent, exponent_bits, :sign, 1],
      bias: 2**(exponent_bits-1)-1, bias_mode: :scientific_significand,
      hidden_bit: true,
      endianness: :little_endian,
      round: :half_even,
      gradual_underflow: true,
      infinity: true, nan: true
      }.merge(parameters)
    )
  end

  # Define an IEEE binary interchange format given its width in bits
  def self.interchange_binary(name,width_in_bits, options={})
    unless (width_in_bits%32)==0 && (width_in_bits/32)>=4
      raise "Invalid IEEE binary interchange format definition: size (#{width_in_bits}) is not valid"
    end
    p = width_in_bits - (4*Math.log(width_in_bits)/Math.log(2)).round.to_i + 13
    binary(name, { significand: p-1, exponent: width_in_bits-p }.merge(options))
  end

  # Define an IEEE decimal format by passing parameters in a hash;
  # :significand and :exponent are used to defined the fields,
  # optional parameters may follow.
  def self.decimal(name,parameters)
    significand_continuation_bits = parameters[:significand]
    exponent_continuation_bits = parameters[:exponent]
    Flt.define(name, {
      base: DPDFormat,
      fields: [:significand_continuation, significand_continuation_bits, :exponent_continuation, exponent_continuation_bits, :combination, 5, :sign, 1],
      normalized: false,
      endianness: :big_endian,
      gradual_underflow: true,
      infinity: true, nan: true,
      round: :half_even
    }.merge(parameters))
  end

  # Define an IEEE decimal interchange format given its width in bits
  def self.interchange_decimal(name,width_in_bits, options={})
    raise "Invalid IEEE decimal interchange format definition: size (#{width_in_bits}) is not valid" unless (width_in_bits%32)==0
    p = width_in_bits*9/32 - 2
    t = (p-1)*10/3
    w = width_in_bits - t - 6
    decimal(name,{ significand: t, exponent: w }.merge(options))
  end

end

# IEEE 754 binary types, as stored in little endian architectures such as Intel, Alpha

IEEE.binary :IEEE_binary16, significand: 10, exponent: 5
IEEE.binary :IEEE_binary32, significand: 23,exponent: 8
IEEE.binary :IEEE_binary64, significand: 52,exponent: 11
IEEE.binary :IEEE_binary80, significand: 64,exponent: 15, hidden_bit: false, min_encoded_exp: 1
IEEE.binary :IEEE_binary128, significand: 112,exponent: 15

# IEEE 754 in big endian order (SPARC, Motorola 68k, PowerPC)

IEEE.binary :IEEE_binary16_BE, significand: 10, exponent: 5, endianness: :big_endian
IEEE.binary :IEEE_binary32_BE, significand: 23,exponent: 8, endianness: :big_endian
IEEE.binary :IEEE_binary64_BE, significand: 52,exponent: 11, endianness: :big_endian
IEEE.binary :IEEE_binary80_BE, significand: 64,exponent: 15, endianness: :big_endian, hidden_bit: false, min_encoded_exp: 1
IEEE.binary :IEEE_binary128_BE, significand: 112,exponent: 15, endianness: :big_endian


# some IEEE745r interchange binary formats

IEEE.interchange_binary :IEEE_binary256, 256
IEEE.interchange_binary :IEEE_binary512, 512
IEEE.interchange_binary :IEEE_binary1024, 1024
IEEE.interchange_binary :IEEE_binary256_BE, 256, endianness: :big_endian
IEEE.interchange_binary :IEEE_binary512_BE, 512, endianness: :big_endian
IEEE.interchange_binary :IEEE_binary1024_BE, 1024, endianness: :big_endian

# old names
IEEE_binaryx = IEEE_binary80
IEEE_HALF = IEEE_binary16
IEEE_SINGLE = IEEE_binary32
IEEE_DOUBLE = IEEE_binary64
IEEE_EXTENDED = IEEE_binary80
IEEE_QUAD = IEEE_binary128
IEEE_128 = IEEE_binary128
IEEE_H_BE = IEEE_binary16_BE
IEEE_S_BE = IEEE_binary32_BE
IEEE_D_BE = IEEE_binary64_BE
IEEE_X_BE = IEEE_binary80_BE
IEEE_128_BE = IEEE_binary128_BE
IEEE_Q_BE = IEEE_binary128_BE


# Decimal IEEE 754r formats

IEEE.decimal :IEEE_decimal32, significand: 20, exponent: 6
IEEE.decimal :IEEE_decimal64, significand: 50, exponent: 8
IEEE.decimal :IEEE_decimal128, significand: 110, exponent: 12

# some IEEE745r interchange binary formats

IEEE.interchange_decimal :IEEE_decimal96, 96
IEEE.interchange_decimal :IEEE_decimal192, 192
IEEE.interchange_decimal :IEEE_decimal256, 256

# old names

IEEE_DEC32 = IEEE_decimal32
IEEE_DEC64 = IEEE_decimal64
IEEE_DEC128 = IEEE_decimal128

# Brain Floating Point (bfloat16) - Google Brain 16-bit truncated version of IEEE_binary32
# Google Cloud TPUs, TensorFlow
# Intel AI processors: Nervana NNP-L1000, Xeon processors (AVX-512 BF16 extensions)
# Intel FPGAs
# ARMv8.6-A
# AMD ROCm libraries

IEEE.binary :BFLOAT16, significand: 7, exponent: 8, endianness: :little_endian
IEEE.binary :BFLOAT16_BE, significand: 7, exponent: 8, endianness: :big_endian

# MSFP8-11 Microsoft Floating Point (Project Brainwave)

IEEE.binary :MSFP8, significand: 2, exponent: 5, endianness: :little_endian
IEEE.binary :MSFP9, significand: 3, exponent: 5, endianness: :little_endian
IEEE.binary :MSFP10, significand: 4, exponent: 5, endianness: :little_endian
IEEE.binary :MSFP11, significand: 5, exponent: 5, endianness: :little_endian
IEEE.binary :MSFP8_BE, significand: 2, exponent: 5, endianness: :big_endian
IEEE.binary :MSFP9_BE, significand: 3, exponent: 5, endianness: :big_endian
IEEE.binary :MSFP10_BE, significand: 4, exponent: 5, endianness: :big_endian
IEEE.binary :MSFP11_BE, significand: 5, exponent: 5, endianness: :big_endian

# Khronos Vulkan unsigned minifloat formats

Flt.define BinaryFormat, :KHRONOS_VULKAN_UNSIGNED11,
  fields:[:significand, 6, :exponent, 5], # :sign 1
  bias: 2**(5-1)-1, bias_mode: :scientific_significand,
  hidden_bit: true,
  endianness: :little_endian,
  round: :half_even,
  gradual_underflow: true,
  infinity: true, nan: true

Flt.define BinaryFormat, :KHRONOS_VULKAN_UNSIGNED10,
  fields:[:significand, 5, :exponent, 5], # :sign 1
  bias: 2**(5-1)-1, bias_mode: :scientific_significand,
  hidden_bit: true,
  endianness: :little_endian,
  round: :half_even,
  gradual_underflow: true,
  infinity: true, nan: true

# Excess 128 used by Microsoft Basic in 8-bit micros, Spectrum, ...

Flt.define BinaryFormat, :XS128,
  fields:[:significand,31,:sign,1,:exponent,8],
  bias: 128, bias_mode: :fractional_significand,
  hidden_bit: true,
  endianness: :big_endian, round: :half_up,
  gradual_underflow: false, infinity: false, nan: false

# HP-3000 excess 256 format, HP-Tandem...

Flt.define BinaryFormat, :XS256,
  fields:[:significand,22,:exponent,9,:sign,1],
  bias: 256, bias_mode: :scientific_significand,
  hidden_bit: true, min_encoded_exp: 0,
  endianness: :big_endian, round: :half_up,
  gradual_underflow: false, infinity: false, nan: false

Flt.define :XS256_DOUBLE, BinaryFormat,
  fields:[:significand,54,:exponent,9,:sign,1],
  bias: 256, bias_mode: :scientific_significand,
  hidden_bit: true, min_encoded_exp: 0,
  endianness: :big_endian, round: :half_up,
  gradual_underflow: false, infinity: false, nan: false

# Borland Pascal 48 bits "Real" Format

Flt.define :BORLAND48, BinaryFormat,
  fields:[:exponent,8,:significand,39,:sign,1],
  bias: 128, bias_mode: :fractional_significand,
  hidden_bit: true,
  endianness: :little_endian,
  gradual_underflow: false, infinity: false, nan: false

# Microsoft Binary Floating-point (Quickbasic)

Flt.define :MBF_SINGLE, BinaryFormat,
  fields:[:significand,23,:sign,1,:exponent,8],
  bias: 128, bias_mode: :fractional_significand,
  hidden_bit: true,
  endianness: :little_endian,
  gradual_underflow: false, infinity: false, nan: false

Flt.define :MBF_DOUBLE, BinaryFormat,
  fields:[:significand,55,:sign,1,:exponent,8],
  bias: 128, bias_mode: :fractional_significand,
  hidden_bit: true,
  endianness: :little_endian,
  gradual_underflow: false, infinity: false, nan: false

MBF_EXTENDEND = XS128

# DEC formats (VAX)

Flt.define :VAX_F, BinaryFormat,
  fields:[:significand, 23, :exponent, 8, :sign, 1],
  bias: 128, bias_mode: :fractional_significand,
  hidden_bit: true,
  endianness: :little_big_endian,
  gradual_underflow: false, infinity: false, nan: false

Flt.define :VAX_D, BinaryFormat,
  fields:[:significand, 55, :exponent, 8, :sign, 1],
  bias: 128, bias_mode: :fractional_significand,
  hidden_bit: true,
  endianness: :little_big_endian,
  gradual_underflow: false, infinity: false, nan: false

Flt.define :VAX_G, BinaryFormat,
  fields:[:significand, 52, :exponent, 11, :sign, 1],
  bias: 1024, bias_mode: :fractional_significand,
  hidden_bit: true,
  endianness: :little_big_endian,
  gradual_underflow: false, infinity: false, nan: false

Flt.define :VAX_H, BinaryFormat,
  fields:[:significand, 112, :exponent, 15, :sign, 1],
  bias: 16384, bias_mode: :fractional_significand,
  hidden_bit: true,
  endianness: :little_big_endian,
  gradual_underflow: false, infinity: false, nan: false

# DEC PDP 11 variants (minimum exponent used for normalized values other than zero)

Flt.define :PDP11_F, BinaryFormat,
  fields:[:significand, 23, :exponent, 8, :sign, 1],
  bias: 128, bias_mode: :fractional_significand,
  hidden_bit: true, min_encoded_exp: 0,
  endianness: :little_big_endian,
  gradual_underflow: false, infinity: false, nan: false

Flt.define :PDP11_D, BinaryFormat,
  fields:[:significand, 55, :exponent, 8, :sign, 1],
  bias: 128, bias_mode: :fractional_significand,
  hidden_bit: true, min_encoded_exp: 0,
  endianness: :little_big_endian,
  gradual_underflow: false, infinity: false, nan: false


# Format used in HP Saturn-based RPL calculators (HP48,HP49,HP50, also HP32s, HP42s --which use RPL internally)
# (these formats are not used in the HP-71B which is a Saturn, non-RPL machine)

Flt.define :SATURN, BCDFormat,
  fields:[:prolog,5,:exponent,3,:significand,12,:sign,1],
  fields_handler: lambda{|fields| fields[0]=2933},
  exponent_mode: :radix_complement,
  endianness: :little_endian, round: :half_even,
  gradual_underflow: false, infinity: false, nan: false

Flt.define :SATURN_X, BCDFormat,
  fields:[:prolog,5,:exponent,5,:significand,15,:sign,1],
  fields_handler: lambda{|fields| fields[0]=2955},
  exponent_mode: :radix_complement,
  endianness: :little_endian, round: :half_even,
  gradual_underflow: false, infinity: false, nan: false


RPL = SATURN
RPL_X = SATURN_X

# SATURN HP-71B (IEEE, NON-RPL) formats

# HP-71B REAL format (12-form) which is stored in a single register
Flt.define :HP71B, BCDFormat,
  fields:[:exponent,3,:significand,12,:sign,1],
  exponent_mode: :radix_complement,
  endianness: :little_endian, round: :half_even,
  gradual_underflow: true, infinity: true, nan: true,
  denormal_encoded_exp: 501,
  nan_encoded_exp:"F01", # signaling NaN is F02
  infinite_encoded_exp:"F00"

# HP-71B internal 15-digit format (15-form), stored in a pair of registers
# we use here a little-endian order for the registers, otherwise the
# definition would be [:significand,15,:unused1,1,:exponent,5,:unused2,10,:sign,1]
Flt.define :HP71B_X, BCDFormat,
  fields:[:exponent,5,:unused2,10,:sign,1, :significand,15,:unused1,1],
  exponent_mode: :radix_complement,
  endianness: :little_endian, round: :half_even,
  gradual_underflow: false, infinity: true, nan: true,
  nan_encoded_exp:"00F01",
  infinite_encoded_exp:"00F00"

# Format used in classic HP calculators (HP-35, ... HP-15C)
# Endianness is indeterminate, since these machines have named registers that
# hold a floating-point value in a single 56-bit word.
# (But intra-word field/nibble addressing is little-endian)
Flt.define :HP_CLASSIC, BCDFormat,
  fields:[:exponent,3,:significand,10,:sign,1],
  exponent_mode: :radix_complement,
  min_exp:-99, max_exp: 99, # the most significant nibble of exponent if for sign only
  endianness: :big_endian, round: :half_up,
  gradual_underflow: false, infinity: false, nan: false


# IBM Floating Point Architecture (IBM 360,370, DG Eclipse, ...)

# short
Flt.define :IBM32, HexadecimalFormat,
  fields:[:significand,24,:exponent,7,:sign,1],
  bias: 64, bias_mode: :fractional_significand,
  endianness: :big_endian

# long
Flt.define :IBM64, HexadecimalFormat,
  fields:[:significand,56,:exponent,7,:sign,1],
  bias: 64, bias_mode: :fractional_significand,
  endianness: :big_endian

# extended: two long values pasted together
Flt.define :IBM128, HexadecimalFormat,
  fields:[:significand,14*4,:lo_exponent,7,:lo_sign,1,:significand,14*4,:exponent,7,:sign,1],
  fields_handler: lambda{|fields| fields[1]=(fields[4]>=14&&fields[4]<127) ? fields[4]-14 : fields[4];fields[2]=fields[5] },
  bias: 64, bias_mode: :fractional_significand,
  min_encoded_exp: 14, # to avoid out-of-range exponents in the lower half
  endianness: :big_endian

# It think this has never been used:
Flt.define :IBMX, HexadecimalFormat,
  fields:[:significand,14*4,:exponent,7,:unused_sign,1,:significand,14*4,:exponent,7,:sign,1],
  fields_handler: lambda{|fields| fields[2]=0},
  bias: 8192, bias_mode: :fractional_significand,
  endianness: :big_endian

HFP_SINGLE = IBM32
HFP_DOUBLE = IBM64
HFP_EXTENDED = IBM128

# Cray-1
Flt.define :CRAY, BinaryFormat,
  fields:[:significand,48,:exponent,15,:sign,1],
  bias: 16384, bias_mode: :fractional_significand,
  hidden_bit: false,
  min_encoded_exp: 8192, max_encoded_exp: 24575, zero_encoded_exp: 0,
  endianness: :big_endian,
  gradual_underflow: false, infinity: false, nan: false

# CDC 6600/7600
# Byte endianness is arbitrary, since these machines were word-addressable, in 60-bit words,
# but the two words used in double precision numbers are in big endian order
# TO DO: apply this:
# The exponent encoded value 1023 is used for NaN
# The exponent encoded value    0 is used for underflow
# The exponent encoded value 2047 is used for overflow
#
# The exponent needs special treatment, because instead of excess encoding, which is equivalent to two's complement followed
# by sign bit reversal, one's complement followed by sign bit reversal is used, which is equivalent
# to use a bias diminished by one for negative exponents. Note that the exponent encoded value that equals the bias is
# not used (is used as a NaN indicator)
class CDCFormat < BinaryFormat # :nodoc:
  def self.encode_exponent(e,mode)
    ee = super
    ee -= 1 if e<0
    ee
  end
  def self.decode_exponent(ee,mode)
    e = super
    e += 1 if e<0
    e
  end
end

Flt.define :CDC_SINGLE, CDCFormat,
  fields:[:significand,48, :exponent,11, :sign,1],
  bias: 1024, bias_mode: :integral_significand,
  min_exp:-1023,
  neg_mode: :diminished_radix_complement,
  hidden_bit: false,
  endianess: :big_endian,
  gradual_underflow: false, infinity: false, nan: false

# The CDC_DOUBLE can be splitted in two CDC_SINGLE values:
#   get_bitfields(v,[CDC_SINGLE.total_bits]*2,CDC_DOUBLE.endianness).collect{|x| int_to_bytes(x,0,CDC_SINGLE.endianness)}
# and the value of the double is the sum of the values of the singles.
# Unlike the single, we must use :fractional_significand mode because with :integral_significand
# the exponent would refer to the whole significand, but it must refer only to the most significant half.
# we substract the number of bits in the single to the bias and exponent because of this change,
# and add 48 to the min_exponent to avoid the exponent of the low order single to be out of range
# because the exponent of the low order single is adjusted to
# the position of its digits by substracting 48 from the high order exponent
# when its exponent would be out of range
# Note that when computing the low order exponent with the fields handler we must take into account the sign
# because for negative numbers all the fields are one-complemented.
Flt.define :CDC_DOUBLE, CDCFormat,
  fields:[:significand,48,:lo_exponent,11,:lo_sign,1,:significand,48,:exponent,11,:sign,1],
  fields_handler: lambda{|fields|
        fields[1]=(fields[4]>0&&fields[4]<2047) ? fields[4]-((-1)**fields[5])*48 : fields[4]
        fields[2]=fields[5]
  },
  bias: 1024-48, bias_mode: :fractional_significand,
  min_encoded_exp: 48+1, # + 1 because the bias for negative is 1023
  neg_mode: :diminished_radix_complement,
  hidden_bit: false,
  endianess: :big_endian,
  gradual_underflow: false, infinity: false, nan: false


# Univac 1100
# Byte endianness is arbitrary, since these machines were word-addressable, in 36-bit words,
# but the two words used in double precision numbers are in big endian order
Flt.define :UNIVAC_SINGLE, BinaryFormat,
  fields:[:significand,27, :exponent,8, :sign,1],
  bias: 128, bias_mode: :fractional_significand,
  neg_mode: :diminished_radix_complement,
  hidden_bit: false,
  endianess: :big_endian,
  gradual_underflow: false, infinity: false, nan: false

Flt.define :UNIVAC_DOUBLE, BinaryFormat,
  fields:[:significand,60, :exponent,11, :sign,1],
  bias: 1024, bias_mode: :fractional_significand,
  neg_mode: :diminished_radix_complement,
  hidden_bit: false,
  endianess: :big_endian,
  gradual_underflow: false, infinity: false, nan: false


# :stopdoc: # the next definition is not handled correctly by RDoc
Flt.define(:APPLE_INSANE,BinaryFormat,
  fields:[:significand,23,:sign,1,:exponent,8],
  bias: 128, bias_mode: :scientific_significand,
  hidden_bit: false, min_encoded_exp: 0,
  neg_mode: :radix_complement_significand,
  endianness: :big_endian,
  gradual_underflow: true, infinity: false, nan: false) { |fp|
  # This needs a peculiar treatment for the negative values, which not simply use two's complement
  # but also avoid having the sign and msb of the significand equal.
  # Note that here we have a separate sign bit, but it can also be considered as the msb of the significand
  # in two's complement, in which case the radix point is after the two msbs, which are the ones that
  # should not be equal. (except for zero and other values using the minimum exponent).
  def fp.neg_significand_exponent(s,f,e)
    #puts "before: #{s} #{f.to_s(16)}"
    f,e = super
    s = (s+1)%2
    #print "minus #{f.to_s(16)}"
    if e>@zero_encoded_exp && f==0
      f = 1<<(significand_digits-1)
      e += 1
    else
      while (e>@zero_encoded_exp) && (f>>(significand_digits-1))&1 == s
        e -= 1
        f = (f << 1) & (radix_power(significand_digits)-1)
        #print " << "
      end
    end
    #puts ""
    [f,e]
  end
}
# :startdoc:


# Sofware floating point implementatin for the Apple II (6502)
# the significand & sign are a single field in two's commplement
APPLE = APPLE_INSANE

# Wang 2200 Basic Decimal floating point
Flt.define(:WANG2200,BCDFormat,
  fields:[:significand,13,:exponent,2,:signs,1],
  endiannes: :big_endian,
  bias_mode: :scientific_significand,
  min_exp:-99, max_exp: 99,
  zero_encoded_exp: 0, min_encoded_exp: 0
) { |wang2200|

  # needs special handling because significand and exponent are both stored
  # as sign-magnitude, with both signs combined in a single nibble (decimal digit)
  def wang2200.unpack(v)
    f = unpack_fields_hash(v)
    m = f[:significand]
    e = f[:exponent]
    ss = f[:signs]
    s = (ss==9 || ss==1) ? 9 : 0
    es = (ss==8 || ss==1) ? 9 : 0
    if m==0
      # +-zero
      e = :zero
    elsif @infinite_encoded_exp && e==@infinite_encoded_exp && m==0
      # +-inifinity
      e = :infinity
    elsif @nan_encoded_exp && e==@nan_encoded_exp && m!=0
      # NaN
      e = :nan
    else
      # normalized number
      # reverse exponent nibbles
      e = ("%0#{exponent_digits}d"%e).reverse.to_i
      e = -e if es%2!=0
      e -= (significand_digits-1)
    end
    s = sign_to_unit(s)
    [s,m,e]
  end

  def wang2200.pack(s,m,e)
    s = sign_from_unit(s)
    msb = radix_power(@significand_digits-1)
    es = 0
    if e==:zero
      e = @zero_encoded_exp
      m = 0
    elsif e==:infinity
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      m = 0
    elsif e==:nan
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      s = minus_sign_value # ?
      m = radix_power(@significand_digits-2) if m==0
    elsif e==:denormal
      e = @denormal_encoded_exp
    else
      # to do: try to adjust m to keep e in range if out of valid range
      # to do: reduce m and adjust e if m too big

      min_exp = radix_min_exp(:integral_significand)
      if m>0
        while m<msb && e>min_exp
          e -= 1
          m *= radix
        end
      end
      if m<msb && @denormal_encoded_exp
        e = @denormal_encoded_exp
      elsif m==0 # => && @denormal_encoded_exp.nil?
        e = 0
      else
        e += (significand_digits-1)
        if e<0
          e = -e
          es = 9
        else
          es = 0
        end
      end
    end
    ss = (s%2) + (es==0 ? 0 : 8)
    # reverse exponent nibbles
    e = ("%0#{exponent_digits}d"%e).reverse.to_i
    pack_fields_hash signs: ss, significand: m, exponent: e
  end
}


# C51 (C compiler for the Intel 8051) BCD Floating point formats
class C51BCDFormat < BCDFormat # :nodoc:
  def self.exponent_radix
    2
  end
  def self.exponent_digits
    @fields[:exponent_sign]*4-1
  end
  def self.minus_sign_value
    1
  end
  def self.unpack(v)
    f = unpack_fields_hash(v)
    m = f[:significand]
    e_s = f[:exponent_sign]
    exp_bits = exponent_digits
    e = e_s & (2**exp_bits-1)
    s = e_s >> exp_bits
    if m==0
      # +-zero
      e = :zero
    elsif @infinite_encoded_exp && e==@infinite_encoded_exp && m==0
      # +-inifinity
      e = :infinity
    elsif @nan_encoded_exp && e==@nan_encoded_exp && m!=0
      # NaN
      e = :nan
    else
      # normalized number
      e = decode_exponent(e, :integral_significand)
    end
    s = sign_to_unit(s)
    [s,m,e]
  end
  def self.bcd_field?(i)
    @field_meaning[i]==:significand
  end

  def self.pack(s,m,e)
    s = sign_from_unit(s)
    msb = radix_power(@significand_digits-1)
    es = 0
    if e==:zero
      e = @zero_encoded_exp
      m = 0
    elsif e==:infinity
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      m = 0
    elsif e==:nan
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      s = minus_sign_value # ?
      m = radix_power(@significand_digits-2) if m==0
    elsif e==:denormal
      e = @denormal_encoded_exp
    else
      # to do: try to adjust m to keep e in range if out of valid range
      # to do: reduce m and adjust e if m too big

      min_exp = radix_min_exp(:integral_significand)
      if m>0
        while m<msb && e>min_exp
          e -= 1
          m *= radix
        end
      end
      if m<msb && @denormal_encoded_exp
        e = @denormal_encoded_exp
      elsif m==0 # => && @denormal_encoded_exp.nil?
        e = 0
      else
        e = encode_exponent(e, :integral_significand)
      end
    end
    exp_bits = exponent_digits
    e_s = e + (s << exp_bits)
    pack_fields_hash significand: m, exponent_sign: e_s
  end
end

Flt.define :C51_BCD_FLOAT, C51BCDFormat,
  fields:[:exponent_sign, 2, :significand,6],
  endiannes: :big_endian,
  bias: 64, bias_mode: :fractional_significand,
  zero_encoded_exp: 0, min_encoded_exp: 0,max_encoded_exp: 127

Flt.define :C51_BCD_DOUBLE,C51BCDFormat,
  fields:[:exponent_sign, 2, :significand,10],
  endiannes: :big_endian,
  bias: 64, bias_mode: :fractional_significand,
  zero_encoded_exp: 0, min_encoded_exp: 0,max_encoded_exp: 127

Flt.define :C51_BCD_LONG_DOUBLE, C51BCDFormat,
  fields:[:exponent_sign, 2, :significand,12],
  endiannes: :big_endian,
  bias: 64, bias_mode: :fractional_significand,
  zero_encoded_exp: 0, min_encoded_exp: 0,max_encoded_exp: 127


# double-double format as used in the PowerPC
Flt.define :IEEE_DOUBLE_DOUBLE, DoubleFormat, half: IEEE_binary64, extra_prec: true



end
