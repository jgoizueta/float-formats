# Float-Formats
# Floating-point classes -- tools to handle floating point formats

# Nomenclature:
# * radix: the numerical base of the floating point notation
# * significand: the digits part of the number; also called coefficient or, arguably, mantissa.
# * exponent: the radix exponent, also called characteristic;
# * encoded exponent: the value stored in the f.p. format to denote the exponent
#
# Significand modes determine the interpretation of the significand value and also
# of the exponent values. For excess-notation encoded exponents this means that
# the value of the bias depends upon the interpretation of the significand.
# * integral significand: the significand is interpreted as an integer, i.e. the radix
#   point is at the right (after the last digit); 
#   Some examples of this pont of view:
#   - HP-50G LONGFLOAT library
#   - HP-16C Floating Point-Integer conversion
# * fractional significand: the radix point is at the left, before the first significand digit
#   (before the hidden bit if there is one); the value v of a normalized significand is 1/r<=v<1
#   Examples: 
#   - The C standard library frexp/ldexp uses this interpretation, and the <float.h> constants.
#     (and so this is also used by Ruby's Math.frexp and the constants defined in Float)
#   - Don Knuth's The Art of Computer Programming, Vol.2
#   - BigDecimal#split
# * normalized significand: the radix point is after the first digit (after the hidden bit if present)
#   the value v of a normalized significand is 1<=v<r
#   Examples:
#   - IEEE 754 definitions
#   - RPL's MANT/XPON
#   - HP calculators SCI mode
#
# zero representation in hidden bit formats:
# * with gradual underflow: the minimium encoded exponent (0) is used for zero and denormal numbers;
#   i.e. the minimum encoded exponent implies the hidden bit is 0
# * minimum encoded exponent reserved for zero (nonzero significands are not used with it)
# * special all zeros representation: minimun encoded exponent is a regular exponent except for 0

require 'nio'
require 'nio/sugar'
require 'enumerator'
require 'float-formats/bytes.rb'

module FltPnt

# General Floating Point Format Base class
class FormatBase
  include FltPnt  
  
  # Common parameters for all floating-point formats:  
  # [<tt>:bias_mode</tt>] This defines how the significand is interpreted:
  # * <tt>:fractional_significand</tt> The radix point is before the most significant
  #   digit of the significand (including a hidden bit if there's one).
  # * <tt>:normalized_significand</tt> The radix point is after the most significant
  #   digit of the significand (including a hidden bit if there's one).
  # * <tt>:integral_significand</tt> The significand is assumed to be an integer, i.e. 
  #   the radix point is after the least significant digit.
  # [<tt>:bias</tt>] Defines the exponent encoding method to be excess notation
  #                  and defines the bias.
  # [<tt>:endianness</tt>] Defines the byte endianness. One of:
  # * <tt>:little_endian</tt> Least significant bytes come first. (Intel etc.)
  # * <tt>:big_endian</tt> (Network order): most significant bytes come first. (Motorola, SPARC,...)
  # * <tt>:little_big_endian</tt> (Middle endian) Each pair of bytes (16-bit word) has the bytes in
  #   little endian order, but the words are stored in big endian order
  #   (we assume the number of bytes is even). (PDP-11).  
  def initialize(params={})
    
    @fields_handler = params[:fields_handler]
    
    @exponent_radix = params[:exponent_radix] || radix
    
    @zero_encoded_exp = params[:zero_encoded_exp] || 0
    @min_encoded_exp = params[:min_encoded_exp] || 0
    @denormal_encoded_exp = params[:denormal_encoded_exp]
    @gradual_underflow = params[:gradual_underflow] || (@denormal_encoded_exp ? true : false)
    if @gradual_underflow         
      @denormal_encoded_exp = 0 if !@denormal_encoded_exp
      if @denormal_encoded_exp>=@min_encoded_exp
        @min_encoded_exp = @denormal_encoded_exp
        # originally, we incremented min_encoded_exp here unconditionally, but
        # now we don't if there's no hidden bit
        # (we assume the minimum exponent can be used for normalized and denormalized numbers)
        # because of this, IEEE_EXTENDED & 128 formats now specify :min_encoded_exp=>1 in it's definitions
        @min_encoded_exp += 1 if @hidden_bit
      end
    end
    # Note that if there's a hidden bit and no gradual underflow, the minimum encoded exponent will only
    # be used for zero unless a parameter :min_encoded_exp (=0) is passed. In this case all numbers with
    # minimun exponent and nonzero encoded significand will have a 1-valued hidden bit. Otherwise
    # the only valid encoded significand with minimun encoded exponent is 0.
    # In case of gradual underflow, the minimum exponent implies a hidden bit value of 0
    @min_encoded_exp += 1 if @min_encoded_exp==@zero_encoded_exp && (@hidden_bit && params[:min_encoded_exp].nil?)
    
    @infinite_encoded_exp = params[:infinite_encoded_exp]
    @nan_encoded_exp = params[:nan_encoded_exp]
    
    @infinity = params[:infinity] || (@infinite_encoded_exp ? true : false)
    @max_encoded_exp = params[:max_encoded_exp] || @exponent_radix**@fields[:exponent]-1 # maximum regular exponent, encoded
    if @infinity      
      @infinite_encoded_exp = @nan_encoded_exp || @max_encoded_exp if !@infinite_encoded_exp
      @max_encoded_exp = @infinite_encoded_exp - 1 if @infinite_encoded_exp.kind_of?(Integer) && @infinite_encoded_exp<=@max_encoded_exp
    end
    @nan = params[:nan] || (@nan_encoded_exp ? true : false)
    if @nan
      @nan_encoded_exp = @infinite_encoded_exp || @max_encoded_exp if !@nan_encoded_exp
      @max_encoded_exp = @nan_encoded_exp - 1 if @nan_encoded_exp.kind_of?(Integer) && @nan_encoded_exp<=@max_encoded_exp
    end
        
    @exponent_mode = params[:exponent_mode]
    if @exponent_mode.nil?
      if params[:bias]
        @exponent_mode = :excess
      else
        @exponent_mode = :radix_complement
      end
    end
    @exponent_digits = @fields[:exponent]
      
    if @exponent_mode==:excess
      @bias = params[:bias] || (@exponent_radix**(@fields[:exponent]-1)-1)
      @bias_mode = params[:bias_mode] || :normalized_significand
      @min_exp = params[:min_exp]
      @max_exp = params[:max_exp]
      case @bias_mode
        when :integral_significand
          @integral_bias = @bias
          @fractional_bias = @integral_bias-@significand_digits
          @normalized_bias = @fractional_bias+1
        when :fractional_significand
          @fractional_bias = @bias
          @integral_bias = @fractional_bias+@significand_digits
          @normalized_bias = @fractional_bias+1
          @min_exp -= @significand_digits if @min_exp
          @max_exp -= @significand_digits if @max_exp
        when :normalized_significand
          @normalized_bias = @bias
          @fractional_bias = @normalized_bias-1
          @integral_bias = @fractional_bias+@significand_digits
          @min_exp -= @significand_digits-1 if @min_exp
          @max_exp -= @significand_digits-1 if @max_exp
      end         
    else
      #@bias_mode = :normalized_significand
      @min_exp = params[:min_exp] || (-(@exponent_radix**@exponent_digits)/2 + 1)
      @max_exp = params[:max_exp] || ((@exponent_radix**@exponent_digits)/2 - 1)
    end
    @endianness = params[:endianness] || :little_endian
    
    @min_exp = @min_encoded_exp - @integral_bias if @min_exp.nil?
    @max_exp = @max_encoded_exp - @integral_bias if @max_exp.nil?
    
    if @exponent_mode==:excess
      @integral_max_exp = @max_exp
      @integral_min_exp = @min_exp
      @fractional_max_exp = @max_exp+@significand_digits
      @fractional_min_exp = @min_exp+@significand_digits
      @normalized_max_exp = @max_exp+@significand_digits-1
      @normalized_min_exp = @min_exp+@significand_digits-1
    else
      @integral_max_exp = @max_exp - (@significand_digits-1)
      @integral_min_exp = @min_exp - (@significand_digits-1)
      @fractional_max_exp = @max_exp+1
      @fractional_min_exp = @min_exp+1
      @normalized_max_exp = @max_exp
      @normalized_min_exp = @min_exp
    end
   
    @round = params[:round] # || :even      
    
    @neg_mode = params[:neg_mode] || :sign_magnitude
    
    yield self if block_given?
    
  end
  
  # compute a power of the radix (base)
  def radix_power(n)
    radix**n
  end
  
  # base-10 logarithm of the radix
  def radix_log10
    Math.log(radix)/Math.log(10)
  end
  # radix-base logarithm
  def radix_log(x)
    Math.log(x)/Math.log(radix)
  end  
  # number of decimal digits that can be stored in a floating point value and restored unaltered
  def decimal_digits_stored
    ((significand_digits-1)*radix_log10).floor
  end
  # number of decimal digits necessary to unambiguosly define any floating point value
  def decimal_digits_necessary
    (significand_digits*radix_log10).ceil+1
  end

  # Maximum integer such that 10 raised to that power
  # is in the range of the normalised floating point numbers
  def decimal_max_exp
    (radix_max_exp(:fractional_significand)*radix_log10+(1-radix_power(-significand_digits))*radix_log10).floor
    #(Math.log((1-radix**(significand_digits))*radix**radix_max_exp(:fractional_significand))/Math.log(10)).floor
  end
  # Minimum negative integer such that 10 raised to that power
  # is in the range of the normalised floating point numbers
  def decimal_min_exp
    (radix_min_exp(:fractional_significand)*radix_log10).ceil
  end
  # Stored (integral) value for the minus sign
  def minus_sign_value
    (-1) % radix
  end
  # switch between the encodings of minus and plus
  def switch_sign_value(v)
    (v==0) ? minus_sign_value : 0
  end

  # Rounding mode use for this floating-point format; can be one of:
  # [<tt>:even</tt>] round to nearest with ties toward an even digits
  # [<tt>:inf</tt>] round to nearest with ties toward infinity (away from zero)
  # [<tt>:zero</tt>] round to nearest with ties toward zero
  # [<tt>nil</tt>] rounding mode not specified  
  def rounding_mode
    @round
  end
  
  # Number of digits in the significand (precision)
  def significand_digits
    @significand_digits
  end

  # This is a helper to handle floating point values with the auxiliar class Value:
  # it is used to return an encoded floating point value as a Value.
  def return_bytes(v)
    if v.kind_of?(Value)
      v
    else
      Value.new self, v
    end
  end
  # This is a helper to handle floating point values with the auxiliar class Value:
  # it is used to get a bytes string from either a Value or a String
  def input_bytes(v)
    if v.kind_of?(Value)
      raise "Invalid f.p. format" if v.fp_format!=self
      v = v.bytes 
    elsif !v.kind_of?(String)
      raise "Invalid f.p. object"
      v = nil
    end
    v 
  end  

  # Greatest finite normalized floating point number in the representation.
  # It can be made negative by passing the sign (a so this would be the smallest
  # finite number).
  def max_value(sign=0)
    s = sign
    m = radix_power(significand_digits)-1
    e = radix_max_exp(:integral_significand)
    from_integral_sign_significand_exponent(s,m,e)
  end
  # Smallest normalized floating point number greater than zero in the representation.
  # It can be made negative by passing the sign.
  def min_normalized_value(sign=0)
    s = sign
    m = 1
    e = radix_min_exp(:normalized_significand)
    if @hidden_bit && (@min_encoded_exp==@zero_encoded_exp)
      m = 1 + radix_power(significand_digits - 1)
      e = radix_min_exp(:integral_significand)
    else
      m = 1
      e = radix_min_exp(:normalized_significand)
    end    
    from_integral_sign_significand_exponent(s,m,e)
  end
  # Smallest floating point number greater than zero in the representation, including
  # denormalized values if the representation supports it.
  # It can be made negative by passing the sign.
  def min_value(sign=0)
    if @denormal_encoded_exp
      s = sign
      m = 1
      e = :denormal
      from_integral_sign_significand_exponent(s,m,e)
    else
      min_normalized_value(sign)
    end
  end
  # This is the difference between 1.0 and the smallest floating-point
  # value greater than 1.0, radix_power(1-significand_precision)
  def epsilon(sign=0)
    s = sign
    #m = 1
    #e = 1-significand_digits
    m = radix_power(significand_digits-1)
    e = 2*(1-significand_digits)
    from_integral_sign_significand_exponent(s,m,e)
  end  
  # The strict epsilon is the smallest value that produces something different from 1.0
  # wehen added to 1.0. It may be smaller than the general epsilon, because
  # of the particular rounding rules used with the floating point format.
  # This is only meaningful when well-defined rules are used for rounding the result
  # of floating-point addition.
  # Note that (in pseudo-code): 
  #  ((1.0+strict_epsilon)-1.0)==epsilon
  def strict_epsilon(sign=0, round=nil)
    round ||= @round
    s = sign
    m = radix_power(significand_digits-1)
    e = 2*(1-significand_digits)
    # assume radix is even
    case @round      
      when :even, :zero, :any_rounding
        e -= 1
        m /= 2
        m *= radix
        m += 1        
      when :inf
        # note that here :inf means "round to nearest with ties tower infinity"
        e -= 1
        m /= 2
        m *= radix
      when :ceiling, :up
        # this is the IEEE "toward infinity" rounding
        return min_value
    end
    from_integral_sign_significand_exponent(s,m,e)
  end  
  # This is the maximum relative error corresponding to 1/2 ulp:
  #  (radix/2)*radix_power(-significand_precision) == epsilon/2
  # This is called "machine epsilon" in [Goldberg]
  def half_epsilon(sign=0)
    s = sign
    m = radix/2
    e = -significand_digits
    # normalize:
      m *= radix_power(significand_digits-1)
      e -= significand_digits-1
    from_integral_sign_significand_exponent(s,m,e)
  end    
  
  # Floating point representation of zero.
  def zero(sign=0)
    from_integral_sign_significand_exponent sign, 0, :zero
  end
  # Floating point representation of infinity.
  def infinity(sign=0)
    if @infinite_encoded_exp
      from_integral_sign_significand_exponent sign, 0, :infinity
    else
      nil
    end
  end
  # Floating point representation of Not-a-Number.
  def nan
    if @nan_encoded_exp
      from_integral_sign_significand_exponent 0, 0, :nan
    else
      nil
    end      
  end
  
  # Maximum exponent
  def radix_max_exp(significand_mode=:normalized_significand)
    case significand_mode
      when :integral_significand
        @integral_max_exp
      when :fractional_significand
        @fractional_max_exp
      when :normalized_significand
        @normalized_max_exp
    end
  end
  # Mminimum exponent
  def radix_min_exp(significand_mode=:normalized_significand)
    case significand_mode
      when :integral_significand
        @integral_min_exp
      when :fractional_significand
        @fractional_min_exp
      when :normalized_significand
        @normalized_min_exp
    end
  end

  # Endianness of the format (:little_endian, :big_endian or :little_big_endian)
  def endianness
    @endianness
  end
  
  # Does the format support gradual underflow? (denormalized numbers)
  def gradual_underflow?
    @gradual_underflow
  end
  
  # Exponent bias for excess notation exponent encoding
  # The argument defines the interpretation of the significand and so
  # determines the actual bias value.
  def bias(significand_mode=:normalized_significand)
    case significand_mode
      when :integral_significand
        @integral_bias
      when :fractional_significand
        @fractional_bias
      when :normalized_significand
        @normalized_bias
    end
  end
  
  # Produce an encoded floating point value using a number defined by a
  # formatted text string (using Nio formats). Returns a Value.
  def from_fmt(txt,fmt=Nio::Fmt.default)    
       neutral = fmt.nio_read_formatted(txt)
       if neutral.special?
          case neutral.special
            when :nan
              return nan
            when :inf
              return infinity(neutral.sign=='-' ? minus_sign_value : 0)
          end
       end
       if neutral.rep_pos<neutral.digits.length
         nd = fmt.get_base==10 ? decimal_digits_necessary : (significand_digits*Math.log(radix)/Math.log(fmt.get_base)).ceil+1
         fmt = fmt.mode(:sig,nd)
         neutral = fmt.nio_read_formatted(fmt.nio_write_formatted(fmt.nio_read_formatted(txt)))
       end
       f = neutral.digits.to_i(neutral.base)
       e = neutral.dec_pos-neutral.digits.length
       rounding = neutral.rounding    
       if neutral.base==radix
         x = from_integral_sign_significand_exponent(0,f,e)
       else         
         x = algM(f,e,rounding,neutral.base)
       end
       if neutral.sign=='-'
         x = neg(x)
       end 
       x
  end
  # Formats an encoded floating point value as a text string (using Nio formats)
  # Accepts either a Value or a byte String.
  def to_fmt(v,fmt=Nio::Fmt.default)
    # this always treats the floating-point values as exact quantities
    s,m,e = to_integral_sign_significand_exponent(v)
    case e
      when :zero
        v = 0.0/(s==0 ? +1 : -1)
      when :infinity
        v = (s==0 ? +1.0 : -1.0)/0.0
      when :nan
        v = 0.0/0.0
      else
        v = m*radix_power(e)*((-1)**s)
    end        
    v.nio_write(fmt)  
  end
  
  # Produce an encoded floating point value using a numeric value.
  # Returns a Value.
  def from_number(v, mode=:approx)
    fmt = mode==:approx ? Nio::Fmt::CONV_FMT : Nio::Fmt::CONV_FMT_STRICT
    from_fmt(v.nio_write(fmt),fmt)
  end
  # Computes the value in a specified numeric class (Float, Integer, Rational, BigDecimal)
  # of an encoded floating point number.
  # Accepts either a Value or a byte String.
  def to_number(v, number_class, mode=:approx)
    fmt = mode==:approx ? Nio::Fmt::CONV_FMT : Nio::Fmt::CONV_FMT_STRICT
    v = to_fmt(v,fmt)
    number_class.nio_read(v,fmt)
  end
    
  # Converts an ancoded floating point number to an hexadecimal representation;
  # bytes are separated if the second argument is true.
  # Accepts either a Value or a byte String.
  def to_hex(v,sep_bytes=false)
    bytes_to_hex(input_bytes(v),sep_bytes)
  end
  # Produce an encoded floating point value using an hexadecimal representation.
  # Returns a Value.
  def from_hex(hex)
    return_bytes hex_to_bytes(hex)
  end

  # Converts an ancoded floating point number to hash containing
  # the internal fields that define the number.
  # Accepts either a Value or a byte String.
  def to_fields_hash(v)
    a = to_fields(v)
    h = {}
    if @splitted_fields.nil?
      (0...a.size).each do |i|
        h[@field_meaning[i]] = a[i]
      end
    else
      
      @fields.each_key do |f|
        splits = @splitted_fields[f]
        if splits
          v = 0
          k = 1
          splits.each do |i|
            v += k*a[i]
            k *= fields_radix**(@field_lengths[i])
          end            
          h[f] = v
        else
          h[f] = a[@field_meaning.index(f)]
        end
      end
    end
    h
  end
  # Produce an encoded floating point value using hash of the internal field values.
  # Returns a Value.  
  def from_fields_hash(h)
    if @splitted_fields.nil?
      from_fields @field_meaning.collect{|f| h[f]}
    else
      flds = [nil]*@field_meaning.size
      @fields.each_key do |f|
        splits = @splitted_fields[f]
        if splits
          v = h[f]
          splits.each do |i|
            k = fields_radix**(@field_lengths[i])
            flds[i] = v % k
            v /= k            
          end            
        else
          flds[@field_meaning.index(f)] = h[f]
        end
      end      
      from_fields flds
    end
  end
    
  # Computes the next adjacent floating point value.
  # Accepts either a Value or a byte String.
  # Returns a Value.  
  def next_float(v)   
    s,f,e = to_integral_sign_significand_exponent(v)
    return neg(prev_float(neg(v))) if s!=0 && e!=:zero
    s = switch_sign_value(s) if e==:zero && s!=0
    
    if e!=:nan && e!=:infinity      
      if f==0
        if @gradual_underflow
          e = radix_min_exp(:integral_significand)
          f = 1
        else
          e = radix_min_exp(:integral_significand)
          f = radix_power(@significand_digits-1)
        end
      else
        f += 1        
      end
      if f>=radix_power(@significand_digits)
        f /= radix
        e += 1
        if e>radix_max_exp(:integral_significand)
          e = :infinity
          f = 0
        end
      end
      from_integral_sign_significand_exponent(s,f,e)
    end
  end
      
  # Computes the previous adjacent floating point value.
  # Accepts either a Value or a byte String.
  # Returns a Value.  
  def prev_float(v)    
    s,f,e = to_integral_sign_significand_exponent(v)
    return neg(next_float(neg(v))) if s!=0
    return neg(next_float(v)) if e==:zero
    if e!=:nan && e!=:infinity      
      f -= 1
      if f<radix_power(@significand_digits-1)
        if e>radix_min_exp(:integral_significand)
          e -= 1
          f *= radix
        else
          if @gradual_underflow
            e = :denormal
          else
            e = :zero
          end
        end
      end
      from_integral_sign_significand_exponent(s,f,e)
    end
  end      
  
  # ulp (unit in the last place) according to the definition proposed by J.M. Muller in
  # "On the definition of ulp(x)" INRIA No. 5504
  def ulp(v)
    sign,sig,exp = to_integral_sign_significand_exponent(v)
        
    mnexp = radix_min_exp(:integral_significand)
    mxexp = radix_max_exp(:integral_significand)
    prec = significand_digits
      
    if exp==:nan
      return_bytes v
    elsif exp==:infinity
      from_integral_sign_significand_exponent(1,1,mxexp) # from_integral_sign_significand_exponent(1,fmt.radix_power(prec-1),mxexp-prec+1)    
    elsif exp==:zero || exp <= mnexp
      min_value
    else
      exp -= 1 if sig==radix_power(prec-1) # minimum normalized significand      
      from_integral_sign_significand_exponent(1,1,exp)
    end 
  end
      
  # Produce an encoded floating point value from the integral value
  # of the sign, significand and exponent.
  # Returns a Value.  
  def from_fractional_sign_significand_exponent(sign,fraction,exponent)
    msb = radix_power(@significand_digits-1)
    while fraction<msb
      fraction *= radix
      exponent -= 1
    end
    from_integral_sign_significand_exponent(sign,fraction.to_i,exponent)    
  end
  # Computes an encoded floating-point value from the integral value
  # Accepts either a Value or a byte String.
  def to_fractional_sign_significand_exponent(v,significand_mode=:normalized_significand)
    s,m,e = to_integral_sign_significand_exponent(v)
    case significand_mode
      when :integral_significand
      when :fractional_significand
        m = Rational(m,radix_power(@significand_digits))
      when :normalized_significand
        m = Rational(m,radix_power(@significand_digits-1))
    end
    [s,m,e]
  end  
  
  # Returns the encoded value of a floating-point number as an integer
  # Accepts either a Value or a byte String.
  def to_bits_integer(v)
    bytes_to_int(input_bytes(v), @endianness)    
  end
  # Defines a floating-point number from the encoded integral value.
  # Returns a Value.  
  def from_bits_integer(i)
    v = int_to_bytes(i)
    if v.size<total_bytes
      fill = (0.chr*(total_bytes-v.size))
      if @endianness==:little_endian
        bytes = fill
      else
        bytes = fill + bytes
      end
    elsif v.size>total_bytes  
      raise "Invalid floating point value"             
    end
    return_bytes v
  end
  # Returns the encoded integral value of a floating point number
  # as a text representation in a given base.
  # Accepts either a Value or a byte String.
  def to_bits_text(v,base)
    i = to_bits_integer(v)
    fmt = Nio::Fmt.default.base(base,true).mode(:fix,:exact)
    if [2,4,8,16].include?(base)
      n = (Math.log(base)/Math.log(2)).round.to_i
      digits = (total_bits+n-1)/n
      fmt.pad0s!(digits)      
    end
    i.nio_write(fmt)
  end
  # Defines a floating-point number from a text representation of the
  # encoded integral value in a given base.
  # Returns a Value.  
  def from_bits_text(txt,base)
    i = Integer.nio_read(txt,Nio::Fmt.base(base))
    from_bits_integer i
  end

  # Computes the negation of a floating point value
  # Accepts either a Value or a byte String.
  # Returns a Value.  
  def neg(v)
    s,f,e = to_integral_sign_significand_exponent(v)
    s = switch_sign_value(s)
    from_integral_sign_significand_exponent(s,f,e)
  end  
  
  # Converts a floating point value to another format
  def convert_to(v,fpclass)
    fpclass.from_fmt(to_fmt(v))
  end
        
  # :stopdoc: 
  protected
  def define_fields(field_definitions)
    
    @field_lengths = []
    @field_meaning = []
    @fields = {}
    @splitted_fields = nil
    field_definitions.each_slice(2) do |m,l|
      @field_lengths << l
      @field_meaning << m
      if @fields[m].nil?
        @fields[m] = l
      else  
        @splitted_fields ||= {}
        @splitted_fields[m] = [@field_meaning.index(m)]
        @fields[m] += l
        @splitted_fields[m] <<= @field_meaning.size-1
      end
    end            
    raise "Invalid format" if @splitted_fields && !@splitted_fields_supported
  end
  def handle_fields(fields)
    if @fields_handler
      @fields_handler.call(fields)
    end
  end

  # s is the sign of f,e
  def neg_significand_exponent(s,f,e)
    case @neg_mode
      when :diminished_radix_complement
        if exponent_radix==radix
          f = (radix_power(significand_digits)-1) - f
          e = (radix_power(exponent_digits)-1) - e   
        else
          # unsupported case; we could use the exponent radix for
          # the complement (so for hexadecimal significand/binary exponent we would use binary which is OK)
          raise "Unsupported format"
        end
      when :radix_complement_significand
        f = ((radix_power(significand_digits)-1) - f + 1) % radix_power(significand_digits)      
      when :radix_complement
        if exponent_radix==radix
          if @field_meaning.index(:exponent) < @field_meaning.index(:significand)
            ls,ms = e,f
            ls_digits = exponent_digits
          else
            ls,ms = f,e
            ls_digits = significand_digits
          end
          comb = ls + ms*radix_power(ls_digits)
          comb = ((radix_power(significand_digits)-1) - comb + 1) % radix_power(significand_digits)
          ls = comb % radix_power(ls_digits)
          ms = comb / radix_power(ls_digits)
          if @field_meaning.index(:exponent) < @field_meaning.index(:significand)
            e,f = ls,ms
          else
            e,f = ms,ls
          end          
        else
          # unsupported case; we could use the exponent radix for
          # the complement (so for hexadecimal significand/binary exponent we would use binary which is OK)
          raise "Unsupported format"
        end
    end      
    [f,e]          
  end
  def exponent_digits
    @fields[:exponent]
  end
  def exponent_radix
    @exponent_radix
  end
  # radix of the field sizes, used for splitted fields
  def fields_radix 
    radix
  end
  
  def decode_exponent(e,mode)
    case @exponent_mode
      when :excess
        case mode
          when :integral_significand
            e -= @integral_bias
          when :fractional_significand
            e -= @fractional_bias
          when :normalized_significand
            e -= @normalized_bias
        end  
      when :radix_complement
        n = @fields[:exponent]
        v = radix_power(n)
        e = e-v if e >= v/2        
        case mode
          when :integral_significand
            e -= (significand_digits-1)
          when :fractional_significand
            e += 1
          when :normalized_significand
        end  
      end
    e
  end
  def encode_exponent(e,mode)
    case @exponent_mode
      when :excess
        case mode
          when :integral_significand
            e += @integral_bias
          when :fractional_significand
            e += @fractional_bias
          when :normalized_significand
            e += @normalized_bias
        end  
      when :radix_complement
        case mode
          when :integral_significand
            e += (significand_digits-1)
          when :fractional_significand
            e -= 1
          when :normalized_significand
        end  
        n = @fields[:exponent]
        v = radix_power(n)
        e = e+v if e < 0
    end
    e
  end
    
  # these are functions from Nio::Clinger, generalized for arbitrary floating point formats
  def ratio_float(u,v,k,round_mode)        
    q = u.div v
    r = u-q*v
    v_r = v-r
    z = from_integral_sign_significand_exponent(0,q,k)
    if r<v_r
    elsif r>v_r
      q += 1
    elsif (round_mode==:even && q.even?) || (round_mode==:zero)
    else
      q += 1
    end
    if q==radix_power(significand_digits)
      q = radix_power(significand_digits-1)
      k += 1
    end
    from_integral_sign_significand_exponent(0,q,k)
  end
  
  def algM(f,e,round_mode,eb=10)

    if e<0
     u,v,k = f,eb**(-e),0
    else
      u,v,k = f*(eb**e),1,0
    end
    
    n = significand_digits
    min_e = radix_min_exp(:integral_significand)
    max_e = radix_max_exp(:integral_significand)
    
    rp_n = radix_power(n)
    rp_n_1 = radix_power(n-1)
    r = radix
    
    loop do
       x = u.div(v) # bottleneck
       # overflow if k>=max_e 
       if (x>=rp_n_1 && x<rp_n) || k==min_e || k==max_e
          return ratio_float(u,v,k,round_mode)
       elsif x<rp_n_1
         u *= r
         k -= 1
       elsif x>=rp_n
         v *= r
         k += 1         
       end     
    end

  end  
  # :startdoc:     
end

# Base class for decimal floating point formats
class DecimalFormatBase < FormatBase
  # :stopdoc:       
  def initialize(params)
    @hidden_bit = false
    super params
  end
  def radix
    10
  end
  def radix_power(n)
    10**n
  end
  
  def radix_log10
    1
  end
  def radix_log(x)
    Math.log(x)/Math.log(10)
  end  
  
  def decimal_digits_stored
    significand_digits
  end
  def decimal_digits_necessary
    significand_digits
  end
  def decimal_max_exp
    radix_max_exp(:normalized_significand)
  end
  def decimal_min_exp
    radix_min_exp(:normalized_significand)
  end

  def to_fmt(v,fmt=Nio::Fmt.default)
    # this always treats the floating-point values as exact quantities
    s,m,e = to_integral_sign_significand_exponent(v)
    case e
      when :zero
        v = 0.0/(s==0 ? +1 : -1)
      when :infinity
        v = (s==0 ? +1.0 : -1.0)/0.0
      when :nan
        v = 0.0/0.0
      else
        sign = s==0 ? '' : '-'
        v = BigDecimal("#{sign}#{m}E#{e}")
    end        
    v.nio_write(fmt)  
  end
  # :startdoc:     
end

# BCD (Binary-Coded-Decimal) floating point formats
class BCDFormat < DecimalFormatBase
  # The fields lengths are defined in decimal digits
  def initialize(params)    

    @splitted_fields_supported = false
    define_fields params[:fields]
    
    @significand_digits = @fields[:significand]
    super  params

  end
  # :stopdoc:         
  def total_nibbles
    @field_lengths.inject{|x,y| x+y}
  end
  def total_bytes
    (total_nibbles+1)/2
  end
  def total_bits
    4*total_nibbles
  end

  def to_fields(v)
    # bytes have always nibbles in big-endian order
    v = reverse_byte_nibbles(convert_endianness(input_bytes(v),@endianness,:little_endian))
    nibbles = bytes_to_hex(v)    
    # now we have a little endian nibble string        
    nibble_fields = []
    i = 0
    for l in @field_lengths
      nibble_fields << nibbles[i,l]
      i += l
    end
    # now we conver the nibble strings to numbers
    i = -1
    nibble_fields.collect do |ns| 
      i+=1
      if bcd_field?(i)
        if /\A\d+\Z/.match(ns)
          ns.reverse.to_i
        else
          ns.reverse
        end
      else
        ns.reverse.to_i(16)
      end
    end
  end
  def from_fields(*fields)    
    fields = fields[0] if fields.size==1 and fields[0].kind_of?(Array)
    handle_fields fields
    i = 0
    nibbles = ""
    for l in @field_lengths
      f = fields[i] 
      unless f.kind_of?(String)      
        fmt = bcd_field?(i) ? 'd' : 'X'
        f = "%0#{l}#{fmt}" % fields[i]
      end
      nibbles << f.reverse
      i += 1
    end
    v = hex_to_bytes(nibbles)
    v = convert_endianness(reverse_byte_nibbles(v),:little_endian,@endianness)
    return_bytes v
  end
  # this has beed added to allow some fields to contain binary integers rather than bcd
  def bcd_field?(i)
    true
  end
  
  # assume @exponent_mode==:radix_complement

  def to_integral_sign_significand_exponent(v)
    f = to_fields_hash(v)
    m = f[:significand]
    e = f[:exponent]
    s = f[:sign]
    m,e = neg_significand_exponent(s,m,e) if s%2==1
    if @infinite_encoded_exp && e==@infinite_encoded_exp
      # +-infinity
      e = :infinity
    elsif @nan_encoded_exp && e==@nan_encoded_exp
      # NaN
      e = :nan
    elsif m==0
      # +-zero
      e = :zero
    else
      # normalized number
        e = decode_exponent(e, :integral_significand)
    end
    [s,m,e]    
  end

  def from_integral_sign_significand_exponent(s,m,e)
    msb = radix_power(@significand_digits-1)
    if e==:zero
      e = @zero_encoded_exp
      m = 0
    elsif e==:infinity
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      m = 0
    elsif e==:nan
      e = @nan_encoded_exp || radix_power(@fields[:exponent])-1
      #s = minus_sign_value # ?
      #m = radix_power(@significand_digits-2) if m==0
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
    m,e = neg_significand_exponent(0,m,e) if s%2==1
    from_fields_hash :sign=>s, :significand=>m, :exponent=>e
  end
  # :startdoc:             
end

# DPD (Densely-Packed-Decimal) formats
class DPDFormat < DecimalFormatBase
  # The field that need to be defined (with lenghts given in decimal digits) are
  # * :sign
  # * :combination
  # * :exponent_continuation
  # * :significand_continuation
  def initialize(params)    
    
    @splitted_fields_supported = false
    define_fields params[:fields]    
    @internal_field_lengths = @field_lengths
    @internal_field_meaning = @field_meaning
    @internal_fields = @fields
    raise "Unsupported DPD format" unless @internal_fields[:combination]==5 && @internal_fields[:sign]==1 && [0,4,7].include?(@internal_fields[:significand_continuation]%10)
    
    
    @exponent_bits = 2 + @internal_fields[:exponent_continuation]
    
    extra_bits = (@internal_fields[:significand_continuation] % 10)
    extra_digits = (extra_bits==0) ? 0 : ((extra_bits==4) ? 1 : 2)    
    @significand_digits = 1 + 3*(@internal_fields[:significand_continuation]/10) + extra_digits
    
    define_fields [:type,1,:sign,1,:exponent,@exponent_bits,:significand,@significand_digits]

    if params[:bias].nil?
            
      params[:bias_mode] = :normalized_significand
      
      @exp_limit = 3*(2**@internal_fields[:exponent_continuation])-1
            
      params[:max_exp] = @exp_limit/2
      params[:min_exp] = -params[:max_exp]
      params[:max_exp] += 1 if (@exp_limit%2)==1
      params[:bias]= -params[:min_exp]
      
    end

    super  params

  end
  
  # :stopdoc:               
  def total_bits
    @internal_field_lengths.inject{|x,y| x+y}
  end
  def total_bytes
    (total_bits+7)/8
  end
  
  
  def to_fields(v)
    # convert internal binary fields to bcd decoded fields
    a = get_bitfields(input_bytes(v),@internal_field_lengths,@endianness)
    h = {}
    (0...a.size).each do |i|
      h[@internal_field_meaning[i]] = a[i]
    end
    
    i_sign = h[:sign]
    i_combination = h[:combination]
    i_exponent_continuation = h[:exponent_continuation]
    i_significand_continuation = h[:significand_continuation]


    type = nil
    sign = i_sign==0 ? 0 : 9
    
    a,b,c,d,e = ("%05B"%i_combination).split('').collect{|bit| bit.to_i}
    
    exp_msb = 0
    sig_msd = 0
    
    if a==0 || b==0
      exp_msb = (a<<1)|b
      sig_msd = (c<<2)|(d<<1)|e
    elsif c==0 || d==0 
      exp_msb = (c<<1)|d
      sig_msd = (1<<3)|e
    elsif e==0
      type = :infinity
    else
      type = :nan
    end        
    
    
    hex_sig = sig_msd.to_s
    hex_sig << dpd_to_hexbcd(i_significand_continuation,@internal_fields[:significand_continuation])
    significand = hex_sig.to_i

    exponent = i_exponent_continuation | (exp_msb << (@exponent_bits-2))
    [type,sign,exponent,significand]            
  end
  def from_fields(*fields)
    fields = fields[0] if fields.size==1 and fields[0].kind_of?(Array)
    handle_fields fields
    type,sign,exponent,significand = fields
        
    sig_hex = "%0#{@significand_digits-1}d"%significand
    sig_cont_bits = 4*(@significand_digits-1)
    sig_msd = sig_hex[0,1].to_i
    i_significand_continuation,bits = hexbcd_to_dpd(sig_hex[1..-1])
    
    
    
    exp_msb = exponent>>(@exponent_bits-2)
    i_exponent_continuation = exponent&((1<<(@exponent_bits-2))-1)
    
    i_sign = ((sign==0) ? 0 : 1)
            
            
    case type
      when :infinity
        i_combination = 0x1E
      when :nan
        i_combination = 0x1F
      else
        if sig_msd&0x8==0
          i_combination = sig_msd|(exp_msb<<3)
        else
          i_combination = sig_msd|(1<<4)|(exp_msb<<1)
        end
      end    
    h = {:sign=>i_sign, :combination=>i_combination, :exponent_continuation=>i_exponent_continuation, :significand_continuation=>i_significand_continuation}
    fields =  @internal_field_meaning.collect{|f| h[f]}
    return_bytes set_bitfields(@internal_field_lengths,fields,@endianness)        
  end
  

  def to_integral_sign_significand_exponent(v)
    f = to_fields_hash(v)
    m = f[:significand]
    e = f[:exponent]
    s = f[:sign]
    t = f[:type]
    m,e = neg_significand_exponent(s,m,e) if s%2==1    
    if m==0
      # +-zero
      e = :zero
    elsif t==:infinity
      # +-inifinity
      e = :infinity
    elsif t==:nan
      # NaN
      e = :nan
    else
      # normalized number
       e = decode_exponent(e, :integral_significand)
    end
    [s,m,e]    
  end

  def from_integral_sign_significand_exponent(s,m,e)
    msb = radix_power(@significand_digits-1)
    t = nil
    if e==:zero
      e = @zero_encoded_exp
      m = 0
    elsif e==:infinity
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      m = 0
      t = :infinity
    elsif e==:nan
      t = :nan
      e = 0
      s = 0
      m = 0
    elsif e==:denormal
      e = @denormal_encoded_exp || @zero_encoded_exp
    else
      # to do: try to adjust m to keep e in range if out of valid range
      # to do: reduce m and adjust e if m too big
      
      min_exp = radix_min_exp(:integral_significand)
      if m>0 && false
        while m<msb && e>min_exp
          e -= 1
          m *= radix
        end      
      end
      if m<msb && @denormal_encoded_exp && false
        e = @denormal_encoded_exp
      elsif m==0 # => && @denormal_encoded_exp.nil?
        e = 0
      else
        e = encode_exponent(e, :integral_significand)
      end
    end
    m,e = neg_significand_exponent(0,m,e) if s%2==1    
    from_fields_hash :sign=>s, :significand=>m, :exponent=>e, :type=>t
  end
      
  # :startdoc:             
      
  
end

# This is a base class for formats that specify the field lengths in bits
class FieldsInBitsFormatBase < FormatBase
  # :stopdoc:    
  def fields_radix
    2
  end
  def to_fields(v)
    get_bitfields(input_bytes(v),@field_lengths,@endianness)
  end
  def from_fields(*fields)
    fields = fields[0] if fields.size==1 and fields[0].kind_of?(Array)
    handle_fields fields
    return_bytes set_bitfields(@field_lengths,fields,@endianness)
  end  
  # :startdoc:               
end

# Binary floating point formats
class BinaryFormat < FieldsInBitsFormatBase
  # a hidden bit can be define with :hidden_bit
  def initialize(params)    
    @hidden_bit = params[:hidden_bit]
    @hidden_bit = true if @hidden_bit.nil?

    @splitted_fields_supported = true
    define_fields params[:fields]
    @significand_digits = @fields[:significand] + (@hidden_bit ? 1 : 0)
    super  params

  end
  
  # :stopdoc:               
  
  def radix
    2
  end
  def radix_power(n)
    if n>=0
      1 << n
    else
      2**n
    end
  end
      
  def total_bits
    @field_lengths.inject{|x,y| x+y}
  end
  def total_bytes
    (total_bits+7)/8
  end

  def to_integral_sign_significand_exponent(v)
    f = to_fields_hash(v)
    m = f[:significand]
    e = f[:exponent]
    s = f[:sign]
    m,e = neg_significand_exponent(s,m,e) if s%2==1    
    if (m==0 && !@hidden_bit) || 
       (m==0 && (e==@zero_encoded_exp || e==@denormal_encoded_exp)) || 
       (e==@zero_encoded_exp && @min_encoded_exp>@zero_encoded_exp && !@denormal_encoded_exp)
       # +-zero
       e = :zero
    elsif (e==@denormal_encoded_exp)
      e = decode_exponent(e, :integral_significand)
      e += 1 if @denormal_encoded_exp==@zero_encoded_exp
    elsif @infinite_encoded_exp && e==@infinite_encoded_exp && m==0
      # +-inifinity
      e = :infinity
    elsif @nan_encoded_exp && e==@nan_encoded_exp && m!=0 
      # NaN
      e = :nan
    else
      # normalized number
      e = decode_exponent(e, :integral_significand)
      m |= radix_power(@significand_digits-1) if @hidden_bit
    end
    [s,m,e]    
  end

  def from_integral_sign_significand_exponent(s,m,e)
    msb = radix_power(@significand_digits-1)
    
    if e==:zero
      e = @zero_encoded_exp || @denormal_encoded_exp
      m = 0
    elsif e==:infinity
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      m = 0
    elsif e==:nan
      e = @nan_encoded_exp || radix_power(@fields[:exponent])-1
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
          m <<= 1 # m *= radix
        end      
      end
      if m<msb && @denormal_encoded_exp
        e = @denormal_encoded_exp
      elsif m==0 # => && @denormal_encoded_exp.nil?
        e = 0
      else
        m &= (radix_power(@significand_digits-1)-1) if @hidden_bit
        e = encode_exponent(e, :integral_significand)
      end
    end
    m,e = neg_significand_exponent(0,m,e) if s%2==1    
    from_fields_hash :sign=>s, :significand=>m, :exponent=>e      
  end
  # :startdoc:               
    
end

# Hexadecimal floating point format
class HexadecimalFormat < FieldsInBitsFormatBase
  def initialize(params)    
    @hidden_bit = false    
    @splitted_fields_supported = true
    define_fields params[:fields]    
    @significand_digits = @fields[:significand]/4
    params[:exponent_radix] = 2
    super  params
  end
  
  # :stopdoc:               
  
  def radix
    16
  end
  def fields_radix
    exponent_radix
  end

  def total_bits
    @field_lengths.inject{|x,y| x+y}
  end
  def total_bytes
    (total_bits+7)/8
  end


  def to_integral_sign_significand_exponent(v)
    f = to_fields_hash(v)
    m = f[:significand]
    e = f[:exponent]
    s = f[:sign]
    m,e = neg_significand_exponent(s,m,e) if s%2==1    
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
    [s,m,e]    
  end

  def from_integral_sign_significand_exponent(s,m,e)
    msb = radix_power(@significand_digits-1)
    
    if e==:zero
      e = @zero_encoded_exp
      m = 0
    elsif e==:infinity
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      m = 0
    elsif e==:nan
      e = @nan_encoded_exp || radix_power(@fields[:exponent])-1
      s = minus_sign_value # ?
      m = radix_power(@significand_digits-2) if m==0
    elsif e==:denormal
      e = @denormal_encoded_exp || @zero_encoded_exp      
    else
      # to do: try to adjust m to keep e in range if out of valid range
      # to do: reduce m and adjust e if m too big
      
      min_exp = radix_min_exp(:integral_significand)
      if m>0
        while m<msb && e>min_exp
          e -= 1
          m <<= 4 # m *= radix
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
    m,e = neg_significand_exponent(0,m,e) if s%2==1    
    from_fields_hash :sign=>s, :significand=>m, :exponent=>e      
  end
    

  def minus_sign_value
    (-1) % 2
  end

  def exponent_digits    
    @fields[exponent]/4
  end
  
  # :startdoc:               
  
end


# A class to handle a floating-point representation (bytes) and its format class in a single object.
# This eases the definition and manipulation of floating-point values:
#
#   v = FltPnt::Value.from_fmt(FltPnt::IEEE_DOUBLE, '1.1')
#   # or:
#   v = FltPnt::IEEE_DOUBLE.from_fmt('1.1')
#   puts v.to_fields_hash.inspect       # -> {:sign=>0, :significand=>450359962737050, :exponent=>1023}
#   puts v.next.to_hex(true)            # -> 9B 99 99 99 99 99 F1 3F
#   w = v.convert_to(FltPnt::IEEE_SINGLE)
#   puts w.next.to_hex(true)            # -> CE CC 8C 3F
#  
class Value
  def initialize(fptype,value)
    @fptype = fptype
    @value = value
  end
  def self.from_fmt(fptype,txt,fmt=Nio::Fmt.default)
    self.new fptype, fptype.from_fmt(txt,fmt)
  end
  def self.from_hex(fptype,hx)
    self.new fptype, fptype.from_hex(hx)
  end
  def self.from_fields(fptype, *fields)
    self.new fptype, fptype.from_fields(*fields)
  end
  def self.from_fields_hash(fptype, fields)
    self.new fptype, fptype.from_fields_hash(fields)
  end
  def self.from_integral_sign_significand_exponent(fptype,s,m,e)
    self.new fptype, fptype.from_integral_sign_significand_exponent(s,m,e)
  end
  def self.from_fractional_sign_significand_exponent(fptype,sign,fraction,exponent)
    self.new fptype, fptype.from_fractional_sign_significand_exponent(sign,fraction,exponent)
  end
  def self.from_number(fptype,v,mode=:approx)
    self.new fptype, fptype.from_number(v,mode)
  end
  def self.from_bits_integer(i)
    self.new fptype, fptype.from_bits_integer(i)
  end
  def self.from_bits_text(txt,base)
    self.new fptype, fptype.from_bits_text(txt,base)
  end
  
  def to_fmt(fmt=Nio::Fmt.default)
    @fptype.to_fmt(@value,fmt)
  end
  def to_hex(sep_bytes=false)
    @fptype.to_hex(@value,sep_bytes)
  end
  def to_fields
    @fptype.to_fields(@value)
  end
  def to_fields_hash
    @fptype.to_fields_hash(@value)
  end
  def to_integral_sign_significand_exponent
    @fptype.to_integral_sign_significand_exponent(@value)
  end
  def to_fractional_sign_significand_exponent(significand_mode=:normalized_significand)
    @fptype.to_fractional_sign_significand_exponent(@value, significand_mode)
  end
  def to_number(number_class, mode=:approx)
    @fptype.to_number(@value, number_class, mode)
  end
  def to_bits_integer
    @fptype.to_bits_integer @value
  end
  def to_bits_text(base)
    @fptype.to_bits_text @value, base
  end
  
  def convert_to(fptype2)
    self.class.new fptype2, fptype2.from_fmt(to_fmt)
  end
  
  def next
    self.class.new(@fptype, @fptype.next_float(@value))
  end  
  def prev
    self.class.new(@fptype, @fptype.prev_float(@value))
  end  
  
  def neg
    @fptype.neg(@value)
  end
  
  def ulp
    @fptype.ulp(@value)    
  end
  
  def fp_format
    @fptype
  end
  def bytes
    @value
  end
  
  def ==(obj); test_equal(obj); end
  def eql?(obj); test_equal(obj); end
  def ===(obj); test_equal(obj); end
  
  private
  def test_equal(v)
    @fptype==v.fp_format && @value==v.bytes
  end

  
end  




end

