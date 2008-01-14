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
  include FltPnt # make FltPnt module functions available to instance methods
  extend FltPnt  # make FltPnt module functions available to class methods
  
  def initialize(*args)
    if args.size == 3 || args.size==4 # && args.first.kind_of?(Integer) && args[1].kind_of?(Integer) && args.last.kind_of?(Integer)
      sign,significand,exponent,normalize = args    
      @sign,@significand,@exponent = self.class.canonicalized(sign,significand,exponent,normalize)    
    else
      v = fptype.nan
      case args.first
        when fptype
          v = args.first
          raise "Too many arguments for FormatBase constructor" if args.size>1
        when Array
          v = args.first
          raise "Too many arguments for FormatBase constructor" if args.size>1
        when FormatBase
          v = args.first.convert_to(fptype)
          raise "Too many arguments for FormatBase constructor" if args.size>1
        when String
          v = fptype.text(*args)
        when Bytes
          v = fptype.bytes(*args)
        when Numeric
          v = fptype.number(args.first)          
          raise "Too many arguments for FormatBase constructor" if args.size>1
        when Symbol
          v = fptype.send(*args)
      end      
      @sign,@significand,@exponent = v.to_a
    end
  end
  attr_reader :sign, :significand, :exponent
  def to_a
    split
  end
  def split # to_a parts ? 
    return [@sign,@significand,@exponent]
  end
  
  
  def nan?
    @exponent == :nan
  end
  def zero?
    return @exponent==:zero || @significand==0
  end
  def infinite?
    return @exponent==:infinity
  end
  def subnormal?
    return @exponent==:denormal || (@significand.kind_of?(Integer) && @significand<self.class.minimum_normalized_integral_significand)
  end
  def normal?
    @exponend.kind_of?(Integer) && @significand>=self.class.minimum_normalized_integral_significand
  end
  
  include Nio::Formattable
  
  # from/to integral_sign_significand_exponent 
  
  def nio_write_neutral(fmt)
    # this always treats the floating-point values as exact quantities
    case @exponent
      when :zero
        v = 0.0/@sign
      when :infinity
        v = @sign/0.0
      when :nan
        v = 0.0/0.0
      else
        if fptype.radix==10
          s = @sign<0 ? '-' : ''
          v = BigDecimal("#{s}#{@significand}E#{@exponent}")
        else
          v = @significand*fptype.radix_power(@exponent)*@sign
        end
    end        
    v.nio_write_neutral(fmt)  
  end
  def as_text(fmt=Nio::Fmt.default)
    nio_write(fmt)
  end
  def as_bytes
    fptype.pack(@sign,@significand,@exponent)
  end
  def as_hex(sep_bytes=false)
    as_bytes.to_hex(sep_bytes)
  end
  def as(number_class, mode=:approx)
    if number_class==Bytes    
      as_bytes
    elsif number_class==String
      mode = Nio::Fmt.default if mode==:approx
      as_text(mode)  
    elsif Nio::Fmt===number_class
      as_text(number_class)           
    elsif number_class==Array
      split
    elsif Symbol===number_class
      send "as_#{number_class}"      
    else # assume number_class.ancestors.include?(Numeric)
        fmt = mode==:approx ? Nio::Fmt::CONV_FMT : Nio::Fmt::CONV_FMT_STRICT
        v = nio_write(fmt)
        number_class.nio_read(v,fmt)    
    end
  end
  def as_bits
    as_bytes.to_i(fptype.endianness)    
  end        
  # Returns the encoded integral value of a floating point number
  # as a text representation in a given base.
  # Accepts either a Value or a byte String.
  def as_bits_text(base)
    i = as_bits
    fmt = Nio::Fmt.default.base(base,true).mode(:fix,:exact)
    if [2,4,8,16].include?(base)
      n = (Math.log(base)/Math.log(2)).round.to_i
      digits = (fptype.total_bits+n-1)/n
      fmt.pad0s!(digits)      
    end
    i.nio_write(fmt)
  end

  # Computes the negation of a floating point value
  def neg
    fptype.new(-@sign,@significand,@exponent)
  end  
  
  # Converts a floating point value to another format
  def convert_to(fpclass)
    fpclass.nio_read(nio_write)
  end


  # Computes the next adjacent floating point value.
  # Accepts either a Value or a byte String.
  # Returns a Value.  
  def next
    s,f,e = self.class.canonicalized(@sign,@significand,@exponent,true)
    return neg.prev.neg if s<0 && e!=:zero
    s = -s if e==:zero && s<0
    
    if e!=:nan && e!=:infinity      
      if f==0
        if fptype.gradual_underflow?
          e = fptype.radix_min_exp(:integral_significand)
          f = 1
        else
          e = fptype.radix_min_exp(:integral_significand)
          f = fptype.minimum_normalized_integral_significand
        end
      else
        f += 1        
      end
      if f>=fptype.radix_power(fptype.significand_digits)
        f /= fptype.radix
        if e==:denormal
          e = fptype.radix_min_exp(:integral_significand)
        else
          e += 1
        end
        if e>fptype.radix_max_exp(:integral_significand)
          e = :infinity
          f = 0
        end
      end
      fptype.new s, f, e
    end
  end
      
  # Computes the previous adjacent floating point value.
  # Accepts either a Value or a byte String.
  # Returns a Value.  
  def prev 
    s,f,e = self.class.canonicalized(@sign,@significand,@exponent,true)
    return neg.next.neg if s<0
    return self.next.neg if e==:zero
    if e!=:nan && e!=:infinity      
      f -= 1
      if f<fptype.minimum_normalized_integral_significand
        if e!=:denormal && e>fptype.radix_min_exp(:integral_significand)
          e -= 1
          f *= fptype.radix
        else
          if fptype.gradual_underflow?
            e = :denormal
          else
            e = :zero
          end
        end
      end
    end
    # to do: handle infinity.prev = max_value etc.
    fptype.new s, f, e
  end      
  
  # ulp (unit in the last place) according to the definition proposed by J.M. Muller in
  # "On the definition of ulp(x)" INRIA No. 5504
  def ulp
    sign,sig,exp = @sign,@significand,@exponent
        
    mnexp = fptype.radix_min_exp(:integral_significand)
    mxexp = fptype.radix_max_exp(:integral_significand)
    prec = fptype.significand_digits
      
    if exp==:nan      
    elsif exp==:infinity
      sign,sig,exp = 1,1,mexp
    elsif exp==:zero || exp <= mnexp
      fptype.min_value
    else
      exp -= 1 if sig==fptype.minimum_normalized_integral_significand
      sign,sig,exp = 1,1,exp
    end 
    fptype.new s, f, e
  end
    
  

  def <=>(other)
    return 1 if nan? || other.nan?
    return 0 if zero? && other.zero?
    this_sign,this_significand,this_exponent = split
    other_sign, other_significand, other_exponent = other.split
    return -1 if other_sign < this_sign
    return 1 if other_sign > this_sign
    return 0 if infinite? && other.infinite?
    
    if this_sign<0
      this_significand,other_significand = other_significand,this_significand
      this_exponent,other_exponent = other_exponent,this_exponent    
    end
    
    if this_exponent==other_exponent
      return this_significand <=> other_significand
    else
      mns = fptype.minimum_normalized_integral_significand
      this_normal = this_significand >= mns
      other_normal = other_significand >= mns
      if this_normal && other_normal
        return this_exponent <=> other_exponent
      else
        while this_significand<mns && this_exponent>min_exp
          this_exponent -= 1
          this_significand *= radix
        end      
        while other_significand<mns && other_exponent>min_exp
          other_exponent -= 1
          other_significand *= radix
        end    
        if this_exponent==other_exponent
          return this_significand <=> other_significand
        else
          return this_exponent <=> other_exponent
        end                
      end
    end      
  end
  include Comparable

  #todo hash cononicalizing first

  
  def fp_format
    fptype
  end
  def fptype
    self.class
  end
      
  
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
  def self.define(params={})
    
    @normalized = params[:normalized]
    @normalized = true if @normalized.nil?
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
  
  class <<self
    # define format properties:
    # [+radix+] Numeric base
    # [+significand_digits+] Number of digits in the significand (precision)
    attr_reader :radix, :significand_digits
    # attr_accessor
  end
  
  # compute a power of the radix (base)
  def self.radix_power(n)
    radix**n
  end
  
  # base-10 logarithm of the radix
  def self.radix_log10
    Math.log(radix)/Math.log(10)
  end
  # radix-base logarithm
  def self.radix_log(x)
    Math.log(x)/Math.log(radix)
  end  
  # number of decimal digits that can be stored in a floating point value and restored unaltered
  def self.decimal_digits_stored
    ((significand_digits-1)*radix_log10).floor
  end
  # number of decimal digits necessary to unambiguosly define any floating point value
  def self.decimal_digits_necessary
    (significand_digits*radix_log10).ceil+1
  end

  # Maximum integer such that 10 raised to that power
  # is in the range of the normalised floating point numbers
  def self.decimal_max_exp
    (radix_max_exp(:fractional_significand)*radix_log10+(1-radix_power(-significand_digits))*radix_log10).floor
    #(Math.log((1-radix**(significand_digits))*radix**radix_max_exp(:fractional_significand))/Math.log(10)).floor
  end
  # Minimum negative integer such that 10 raised to that power
  # is in the range of the normalised floating point numbers
  def self.decimal_min_exp
    (radix_min_exp(:fractional_significand)*radix_log10).ceil
  end
  # Stored (integral) value for the minus sign
  def self.minus_sign_value
    (-1) % radix
  end
  # switch between the encodings of minus and plus
  def self.switch_sign_value(v)
    (v==0) ? minus_sign_value : 0
  end
  
  def self.sign_to_unit(s)
    s==0 ? +1 : -1 # ((-1)**s)
  end
  
  def self.sign_from_unit(u)
    u<0 ? minus_sign_value : 0
  end

  # Rounding mode use for this floating-point format; can be one of:
  # [<tt>:even</tt>] round to nearest with ties toward an even digits
  # [<tt>:inf</tt>] round to nearest with ties toward infinity (away from zero)
  # [<tt>:zero</tt>] round to nearest with ties toward zero
  # [<tt>nil</tt>] rounding mode not specified  
  def self.rounding_mode
    @round
  end
    
  def self.minimum_normalized_integral_significand
    radix_power(significand_digits-1)
  end
  def self.maximum_integral_significand
    radix_power(significand_digits)-1
  end
  
  # Maximum exponent
  def self.radix_max_exp(significand_mode=:normalized_significand)
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
  def self.radix_min_exp(significand_mode=:normalized_significand)
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
  def self.endianness
    @endianness
  end
  
  # Does the format support gradual underflow? (denormalized numbers)
  def self.gradual_underflow?
    @gradual_underflow
  end
  
  # Exponent bias for excess notation exponent encoding
  # The argument defines the interpretation of the significand and so
  # determines the actual bias value.
  def self.bias(significand_mode=:normalized_significand)
    case significand_mode
      when :integral_significand
        @integral_bias
      when :fractional_significand
        @fractional_bias
      when :normalized_significand
        @normalized_bias
    end
  end  
  
  def self.canonicalized(s,m,e,normalize=nil)
    #puts "s=#{s} m=#{m} e=#{e}"
    #return [s,m,e]
    normalize = @normalized if normalize.nil? 
    min_exp = radix_min_exp(:integral_significand)
    e = min_exp if e==:denormal
    if m.kind_of?(Integer) && m>0 && e.kind_of?(Integer)      
      while e<min_exp
        e += 1
        f /= radix # to do round
      end
    end
    s,m,e = normalized(s,m,e) if normalize

    if m==0 && e.kind_of?(Integer)
      e=:zero
    end
    #puts " -> s=#{s} m=#{m} e=#{e}"
    [s,m,e]    
  end
  

  protected
  
  
  def self.normalized(s,m,e)
    if m.kind_of?(Integer) && e.kind_of?(Integer)
      min_exp = radix_min_exp(:integral_significand)
      if m>0
        while m<minimum_normalized_integral_significand && e>min_exp
          e -= 1
          m *= radix
        end      
        if @normalized && !@gradual_underflow
          if e<=min_exp && m<minimum_normalized_integral_significand
            m = 0
            e = :zero
          end
        end
      end
    end
    [s,m,e]
  end

  def self.return_value(s,m,e,normalize=nil)    
    self.new s,m,e,normalize
  end
  def self.input_bytes(v)
    if v.kind_of?(FormatBase)
      raise "Invalid f.p. format" if v.fp_format!=self
      v = v.as_bytes 
    elsif !v.kind_of?(Bytes)
      v = Bytes.new(v)
    end
    v 
  end    
  
  public
  

  # Greatest finite normalized floating point number in the representation.
  # It can be made negative by passing the sign (a so this would be the smallest
  # finite number).
  def self.max_value(sign=+1)
    s = sign
    m = maximum_integral_significand
    e = radix_max_exp(:integral_significand)
    return_value s,m,e, false
  end
  # Smallest normalized floating point number greater than zero in the representation.
  # It can be made negative by passing the sign.
  def self.min_normalized_value(sign=+1)
    s = sign
    m = minimum_normalized_integral_significand
    e = radix_min_exp(:integral_significand)
    m += 1 if @hidden_bit && (@min_encoded_exp==@zero_encoded_exp)
    return_value s,m,e, true
  end
  # Smallest floating point number greater than zero in the representation, including
  # denormalized values if the representation supports it.
  # It can be made negative by passing the sign.
  def self.min_value(sign=+1)
    if @denormal_encoded_exp
      s = sign
      m = 1
      e = :denormal
      return_value s,m,e, false
    else
      min_normalized_value(sign)
    end
  end
  # This is the difference between 1.0 and the smallest floating-point
  # value greater than 1.0, radix_power(1-significand_precision)
  def self.epsilon(sign=+1)
    s = sign
    #m = 1
    #e = 1-significand_digits
    m = minimum_normalized_integral_significand
    e = 2*(1-significand_digits)
    return_value s,m,e, false
  end  
  # The strict epsilon is the smallest value that produces something different from 1.0
  # wehen added to 1.0. It may be smaller than the general epsilon, because
  # of the particular rounding rules used with the floating point format.
  # This is only meaningful when well-defined rules are used for rounding the result
  # of floating-point addition.
  # Note that (in pseudo-code): 
  #  ((1.0+strict_epsilon)-1.0)==epsilon
  def self.strict_epsilon(sign=+1, round=nil)
    round ||= @round
    s = sign
    m = minimum_normalized_integral_significand
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
    return_value s,m,e
  end  
  # This is the maximum relative error corresponding to 1/2 ulp:
  #  (radix/2)*radix_power(-significand_precision) == epsilon/2
  # This is called "machine epsilon" in [Goldberg]
  def self.half_epsilon(sign=+1)
    s = sign
    m = radix/2
    e = -significand_digits
    # normalize:
      m *= minimum_normalized_integral_significand
      e -= significand_digits-1
    return_value s,m,e, false
  end    
  
  # Floating point representation of zero.
  def self.zero(sign=+1)
    return_value sign, 0, :zero
  end
  # Floating point representation of infinity.
  def self.infinity(sign=+1)
    if @infinite_encoded_exp
      return_value sign, 0, :infinity
    else
      nil
    end
  end
  # Floating point representation of Not-a-Number.
  def self.nan
    if @nan_encoded_exp
      return_value(+1, 0, :nan)
    else
      nil
    end      
  end
  
  # from methods
  
  
  def self.nio_read_neutral(neutral)
       if neutral.special?
          case neutral.special
            when :nan
              return nan
            when :inf
              return infinity(neutral.sign=='-' ? -1 : +1)
          end
       end
       if neutral.rep_pos<neutral.digits.length
         nd = neutral.base==10 ? decimal_digits_necessary : (significand_digits*Math.log(radix)/Math.log(fmt.get_base)).ceil+1
         neutral = neutral.round(nd,:sig)
       end
       f = neutral.digits.to_i(neutral.base)
       e = neutral.dec_pos-neutral.digits.length
       rounding = neutral.rounding    
       if neutral.base==radix
         s = +1
       else    
         s,f,e = algM(f,e,rounding,neutral.base).split
       end
       if neutral.sign=='-'
         s = -s
       end 
       return_value s,f,e
    
  end
  def self.bytes(b)
    return_value(*unpack(b))
  end
  def self.hex(hex)
    bytes Bytes.from_hex(hex)
  end  
  def self.number(v, mode=:approx)
    fmt = mode==:approx ? Nio::Fmt::CONV_FMT : Nio::Fmt::CONV_FMT_STRICT
    nio_read(v.nio_write(fmt),fmt)
  end
  def self.text(txt, fmt=Nio::Fmt.default) # ?
    nio_read(txt,fmt)
  end
  def self.splitted(sign,significand,exponent) # from_a parts join ?
    self.new sign,significand,exponent
  end

  # Defines a floating-point number from the encoded integral value.
  def self.bits(i)
    v = Bytes.from_i(i)
    if v.size<total_bytes
      fill = (0.chr*(total_bytes-v.size))
      if @endianness==:little_endian
        v << fill
      else
        v = Bytes.new(fill) + bytes
      end
    elsif v.size>total_bytes  
      raise "Invalid floating point value"             
    end
    bytes v
  end
  # Defines a floating-point number from a text representation of the
  # encoded integral value in a given base.
  # Returns a Value.  
  def self.bits_text(txt,base)
    i = Integer.nio_read(txt,Nio::Fmt.base(base))
    bits i
  end

  
  



  # Converts an ancoded floating point number to hash containing
  # the internal fields that define the number.
  # Accepts either a Value or a byte String.
  def self.unpack_fields_hash(v)
    a = unpack_fields(v)
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
  def self.pack_fields_hash(h)
    if @splitted_fields.nil?
      pack_fields @field_meaning.collect{|f| h[f]}
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
      pack_fields flds
    end
  end
    
      

        
  # :stopdoc: 
  protected
  def self.define_fields(field_definitions)
    
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
  def self.handle_fields(fields)
    if @fields_handler
      @fields_handler.call(fields)
    end
  end

  # s is the sign of f,e
  def self.neg_significand_exponent(s,f,e)
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
  def self.exponent_digits
    @fields[:exponent]
  end
  def self.exponent_radix
    @exponent_radix
  end
  # radix of the field sizes, used for splitted fields
  def self.fields_radix 
    radix
  end
  
  def self.decode_exponent(e,mode)
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
  def self.encode_exponent(e,mode)
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
  def self.ratio_float(u,v,k,round_mode)        
    q = u.div v
    r = u-q*v
    v_r = v-r
    z = self.new(+1,q,k)
    if r<v_r
      z
    elsif r>v_r
      z.next
    elsif (round_mode==:even && q.even?) || (round_mode==:zero)
      z
    else
      z.next
    end
  end
  
  def self.algM(f,e,round_mode,eb=10)

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
  def self.define(params)    
    @hidden_bit = false
    super params
  end
  def self.radix
    10
  end
  def self.radix_power(n)
    10**n
  end
  
  def self.radix_log10
    1
  end
  def self.radix_log(x)
    Math.log(x)/Math.log(10)
  end  
  
  def self.decimal_digits_stored
    significand_digits
  end
  def self.decimal_digits_necessary
    significand_digits
  end
  def self.decimal_max_exp
    radix_max_exp(:normalized_significand)
  end
  def self.decimal_min_exp
    radix_min_exp(:normalized_significand)
  end
  # :startdoc:     
end

# BCD (Binary-Coded-Decimal) floating point formats
class BCDFormat < DecimalFormatBase
  # The fields lengths are defined in decimal digits
  def self.define(params)    

    @splitted_fields_supported = false
    define_fields params[:fields]
    
    @significand_digits = @fields[:significand]
    super  params

  end
  # :stopdoc:         
  def self.total_nibbles
    @field_lengths.inject{|x,y| x+y}
  end
  def self.total_bytes
    (total_nibbles+1)/2
  end
  def self.total_bits
    4*total_nibbles
  end

  def self.unpack_fields(v)
    # bytes have always nibbles in big-endian order
    v = input_bytes(v).convert_endianness(@endianness,:little_endian).reverse_byte_nibbles
    nibbles = v.to_hex
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
  def self.pack_fields(*fields)    
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
    Bytes.from_hex(nibbles).reverse_byte_nibbles.convert_endianness(:little_endian,@endianness)
  end
  # this has beed added to allow some fields to contain binary integers rather than bcd
  def self.bcd_field?(i)
    true
  end
  
  # assume @exponent_mode==:radix_complement

  def self.unpack(v)
    f = unpack_fields_hash(v)
    m = f[:significand]
    e = f[:exponent]
    s = f[:sign]
    m,e = neg_significand_exponent(s,m,e) if s%2==1
    s = sign_to_unit(s)
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

  def self.pack(s,m,e)
    msb = radix_power(@significand_digits-1)
    if e==:zero
      e = @zero_encoded_exp
      m = 0
    elsif e==:infinity
      e = @infinite_encoded_exp || radix_power(@fields[:exponent])-1
      m = 0
    elsif e==:nan
      e = @nan_encoded_exp || radix_power(@fields[:exponent])-1
      #s = -1 # ?
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
    s = sign_from_unit(s)
    m,e = neg_significand_exponent(0,m,e) if s%2==1
    pack_fields_hash :sign=>s, :significand=>m, :exponent=>e
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
  def self.define(params)    
    
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
  def self.total_bits
    @internal_field_lengths.inject{|x,y| x+y}
  end
  def self.total_bytes
    (total_bits+7)/8
  end
  
  
  def self.unpack_fields(v)
    # convert internal binary fields to bcd decoded fields
    a = input_bytes(v).to_bitfields(@internal_field_lengths,@endianness)
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
  def self.pack_fields(*fields)
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
    Bytes.from_bitfields(@internal_field_lengths,fields,@endianness)        
  end
  

  def self.unpack(v)
    f = unpack_fields_hash(v)
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
    s = sign_to_unit(s)
    [s,m,e]    
  end

  def self.pack(s,m,e)
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
    s = sign_from_unit(s)
    m,e = neg_significand_exponent(0,m,e) if s%2==1    
    pack_fields_hash :sign=>s, :significand=>m, :exponent=>e, :type=>t
  end
      
  # :startdoc:             
      
  
end

# This is a base class for formats that specify the field lengths in bits
class FieldsInBitsFormatBase < FormatBase
  # :stopdoc:    
  def self.fields_radix
    2
  end
  def self.unpack_fields(v)
    input_bytes(v).to_bitfields(@field_lengths,@endianness)
  end
  def self.pack_fields(*fields)
    fields = fields[0] if fields.size==1 and fields[0].kind_of?(Array)
    handle_fields fields
    Bytes.from_bitfields(@field_lengths,fields,@endianness)
  end  
  # :startdoc:               
end

# Binary floating point formats
class BinaryFormat < FieldsInBitsFormatBase
  # a hidden bit can be define with :hidden_bit
  def self.define(params)    
    @hidden_bit = params[:hidden_bit]
    @hidden_bit = true if @hidden_bit.nil?

    @splitted_fields_supported = true
    define_fields params[:fields]
    
    @significand_digits = @fields[:significand] + (@hidden_bit ? 1 : 0)
    super  params

  end
  
  # :stopdoc:               
  
  def self.radix
    2
  end
  def self.radix_power(n)
    if n>=0
      1 << n
    else
      2**n
    end
  end
      
  def self.total_bits
    @field_lengths.inject{|x,y| x+y}
  end
  def self.total_bytes
    (total_bits+7)/8
  end

  def self.unpack(v)
    f = unpack_fields_hash(v)
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
    s = sign_to_unit(s)
    [s,m,e]    
  end

  def self.pack(s,m,e)
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
    s = sign_from_unit(s)
    m,e = neg_significand_exponent(0,m,e) if s%2==1    
    pack_fields_hash :sign=>s, :significand=>m, :exponent=>e      
  end
  # :startdoc:               
    
end

# Hexadecimal floating point format
class HexadecimalFormat < FieldsInBitsFormatBase
  def self.define(params)    
    @hidden_bit = false    
    @splitted_fields_supported = true
    define_fields params[:fields]    
    @significand_digits = @fields[:significand]/4
    params[:exponent_radix] = 2
    super  params
  end
  
  # :stopdoc:               
  
  def self.radix
    16
  end
  def self.fields_radix
    exponent_radix
  end

  def self.total_bits
    @field_lengths.inject{|x,y| x+y}
  end
  def self.total_bytes
    (total_bits+7)/8
  end


  def self.unpack(v)
    f = unpack_fields_hash(v)
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
    s = sign_to_unit(s)
    [s,m,e]    
  end

  def self.pack(s,m,e)
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
    s = sign_from_unit(s)
    m,e = neg_significand_exponent(0,m,e) if s%2==1    
    pack_fields_hash :sign=>s, :significand=>m, :exponent=>e      
  end
    

  def self.minus_sign_value
    (-1) % 2
  end

  def self.exponent_digits    
    @fields[exponent]/4
  end
  
  # :startdoc:               
  
end


  def -@
    neg
  end
  def +(v)
    # TODO: coercion
    if v.fptype==fptype
      t = BigDecimal
      x = as(BigDecimal,:exact) + v.as(BigDecimal,:exact)
      fptype.number(x)        
    else
      # TODO
    end
  end
  def /(v)
    # TODO: coercion
    if v.fptype==fptype
      t = BigDecimal
      prec = fptype.decimal_digits_necessary
      x = as(BigDecimal,:exact).div(v.as(BigDecimal,:exact),prec)
      fptype.number(x)        
    else
      # TODO
    end
  end
  def -(v)
    # TODO: coercion
    if v.fptype==fptype
      t = BigDecimal
      x = as(BigDecimal,:exact) - v.as(BigDecimal,:exact)
      fptype.number(x)        
    else
      # TODO
    end
  end
  def *(v)
    # TODO: coercion
    if v.fptype==fptype
      t = BigDecimal
      x = as(BigDecimal,:exact) * v.as(BigDecimal,:exact)
      fptype.number(x)        
    else
      # TODO
    end
  end

module_function

def define(*arguments)
  raise "Invalid number of arguments for FltPnt definitions." if arguments.size<2 || arguments.size>3
  if arguments.first.kind_of?(Class)
    base,name,parameters = arguments
  elsif arguments[1].kind_of?(Class)
    name,base,parameters = arguments
  else
    name,parameters = arguments  
    base = parameters[:base] || FormatBase
  end
  FltPnt.const_set name, cls=Class.new(base)
  cls.define parameters
  constructor = lambda { |*args| cls.new(*args) }
  FltPnt.send :define_method,name,constructor
  FltPnt.send :module_function, name
  yield cls if block_given?
end    



def convert_bytes(bytes,from_format,to_format)
  from_format.bytes(bytes).convert_to(to_format)
end




end

