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
# * scientific significand: the radix point is after the first digit (after the hidden bit if present)
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

require 'flt'
require 'numerals'
require 'enumerator'
require 'float-formats/bytes.rb'

module Flt

# General Floating Point Format Base class
class FormatBase
  include Flt # make Flt module functions available to instance methods
  extend Flt  # make Flt module functions available to class methods

  def initialize(*args)
    if (args.size == 3 || args.size==4 || args.size==2) &&
       (args.first.kind_of?(Integer) && args[1].kind_of?(Integer))
      sign,significand,exponent,normalize = args
      if normalize.nil?
        if [nil,true,false].include?(exponent)
          normalize = exponent
          exponent = significand
          significand = sign.abs
          sign = sign<0 ? -1 : +1
        end
      end
      @sign,@significand,@exponent = self.class.canonicalized(sign,significand,exponent,normalize)
    else
      v = form_class.nan
      case args.first
        when form_class
          v = args.first
          raise "Too many arguments for FormatBase constructor" if args.size>1
        when Array
          v = args.first
          raise "Too many arguments for FormatBase constructor" if args.size>1
        when FormatBase
          v = args.first.convert_to(form_class)
          raise "Too many arguments for FormatBase constructor" if args.size>1
        when String
          v = form_class.from_text(*args)
        when Bytes
          v = form_class.from_bytes(*args)
        when Bits
          v = form_class.from_bits(*args)
        when Numeric
          v = form_class.from_number(args.first)
          raise "Too many arguments for FormatBase constructor" if args.size>1
        when Symbol
          if args.first.to_s[0..3]!='from'
            args = ["from_#{args.first}".to_sym] + args[1..-1]
          end
          v = form_class.send(*args)
      end
      @sign,@significand,@exponent = v.to_a
    end
  end

  attr_reader :sign, :significand, :exponent

  def to_a
    split
  end

  def split
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

  # from/to integral_sign_significand_exponent

  def to_text(fmt = Numerals::Format[])
    if infinite?
      fmt = fmt[symbols: [show_plus: true]]
    end
    fmt.write(self)
  end

  def to_bytes
    form_class.pack(@sign,@significand,@exponent)
  end
  def to_hex(sep_bytes=false)
    if (form_class.total_bits % 8)==0
      to_bytes.to_hex(sep_bytes)
    else
      to_bits.to_hex
    end
  end
  def to(number_class, mode = :approx)
    if number_class == Bytes
      to_bytes
    elsif number_class == String
      mode = Numerals::Format[] if mode == :approx
      to_text(mode)
    elsif Numerals::Format === number_class
      to_text(number_class)
    elsif number_class == Array
      split
    elsif Symbol === number_class
      send "to_#{number_class}"
    elsif number_class.is_a?(Flt::Num)  && number_class.radix == form_class.radix
      self.to_num
    elsif number_class.is_a?(FormatBase)
      number_class.from_number(self, mode)
    else # assume number_class.ancestors.include?(Numeric) (number_class < Numeric)
      options = {
        type: number_class,
        exact_input: (mode != :approx),
        output_mode: :fixed
      }
      Numerals::Conversions.convert(self, options)
    end
  end
  def to_bits
    to_bytes.to_bits(form_class.endianness,false,form_class.total_bits)
  end
  # Returns the encoded integral value of a floating point number
  # as a text representation in a given base.
  # Accepts either a Value or a byte String.
  def to_bits_text(base)
    to_bits.to_s(base)
    #i = to_bits
    #fmt = Numerals::Format[base: base]
    #if [2,4,8,16].include?(base)
    #  n = (Math.log(base)/Math.log(2)).round.to_i
    #  digits = (form_class.total_bits+n-1)/n
    #  fmt.set_trailing_zeros!(digits)
    #end
    #fmt.writ(i.to_i)
  end

  # Computes the negation of a floating point value (unary minus)
  def minus
    form_class.new(-@sign,@significand,@exponent)
  end

  # Converts a floating point value to another format
  def convert_to(fpclass, options = {})
    Numerals::Conversions.convert(self, options.merge(type: fpclass))
  end

  # Computes the next adjacent floating point value.
  # Accepts either a Value or a byte String.
  # Returns a Value.
  # TODO: use Flt
  def next_plus
    s,f,e = self.class.canonicalized(@sign,@significand,@exponent,true)
    return minus.next_minus.minus if s<0 && e!=:zero
    s = -s if e==:zero && s<0

    if e!=:nan && e!=:infinity
      if f==0
        if form_class.gradual_underflow?
          e = form_class.radix_min_exp(:integral_significand)
          f = 1
        else
          e = form_class.radix_min_exp(:integral_significand)
          f = form_class.minimum_normalized_integral_significand
        end
      else
        f += 1
      end
      if f>=form_class.radix_power(form_class.significand_digits)
        f /= form_class.radix
        if e==:denormal
          e = form_class.radix_min_exp(:integral_significand)
        else
          e += 1
        end
        if e>form_class.radix_max_exp(:integral_significand)
          e = :infinity
          f = 0
        end
      end
      form_class.new s, f, e
    end
  end

  # Computes the previous adjacent floating point value.
  # Accepts either a Value or a byte String.
  # Returns a Value.
  def next_minus
    s,f,e = self.class.canonicalized(@sign,@significand,@exponent,true)
    return minus.next_plus.minus if s<0
    return self.next_plus.minus if e==:zero
    if e!=:nan
      if e == :infinity
        f = form_class.maximum_integral_significand
        e = form_class.radix_max_exp(:integral_significand)
      else
        f -= 1
        if f<form_class.minimum_normalized_integral_significand
          if e!=:denormal && e>form_class.radix_min_exp(:integral_significand)
            e -= 1
            f *= form_class.radix
          else
            if form_class.gradual_underflow?
              e = :denormal
            else
              e = :zero
            end
          end
        end
      end
    end
    form_class.new s, f, e
  end

  # ulp (unit in the last place) according to the definition proposed by J.M. Muller in
  # "On the definition of ulp(x)" INRIA No. 5504
  def ulp
    sign,sig,exp = @sign,@significand,@exponent

    mnexp = form_class.radix_min_exp(:integral_significand)
    mxexp = form_class.radix_max_exp(:integral_significand)
    #prec = form_class.significand_digits

    if exp==:nan
    elsif exp==:infinity
      sign,sig,exp = 1,1,mxexp
    elsif exp==:zero || exp <= mnexp
      return form_class.min_value
    else
      exp -= 1 if sig==form_class.minimum_normalized_integral_significand
      sign,sig,exp = 1,1,exp
    end
    form_class.new sign, sig, exp
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
      mns = form_class.minimum_normalized_integral_significand
      this_normal = this_significand >= mns
      other_normal = other_significand >= mns
      if this_normal && other_normal
        return this_exponent <=> other_exponent
      else
        min_exp = form_class.radix_min_exp(:integral_significand)
        #max_exp = form_class.radix_max_exp(:integral_significand)

        while this_significand<mns && this_exponent>min_exp
          this_exponent -= 1
          this_significand *= form_class.radix
        end

        while other_significand<mns && other_exponent>min_exp
          other_exponent -= 1
          other_significand *= form_class.radix
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
    form_class
  end
  def form_class
    self.class
  end


  # Common parameters for all floating-point formats:
  # [<tt>:bias_mode</tt>] This defines how the significand is interpreted:
  # * <tt>:fractional_significand</tt> The radix point is before the most significant
  #   digit of the significand (including a hidden bit if there's one).
  # * <tt>:scientific_significand</tt> The radix point is after the most significant
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
    @parameters = params

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
        # because of this, IEEE_EXTENDED & 128 formats now specify min_encoded_exp: 1 in it's definitions
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
      @bias_mode = params[:bias_mode] || :scientific_significand
      @min_exp = params[:min_exp]
      @max_exp = params[:max_exp]
      case @bias_mode
        when :integral_significand
          @integral_bias = @bias
          @fractional_bias = @integral_bias-@significand_digits
          @scientific_bias = @fractional_bias+1
        when :fractional_significand
          @fractional_bias = @bias
          @integral_bias = @fractional_bias+@significand_digits
          @scientific_bias = @fractional_bias+1
          @min_exp -= @significand_digits if @min_exp
          @max_exp -= @significand_digits if @max_exp
        when :scientific_significand
          @scientific_bias = @bias
          @fractional_bias = @scientific_bias-1
          @integral_bias = @fractional_bias+@significand_digits
          @min_exp -= @significand_digits-1 if @min_exp
          @max_exp -= @significand_digits-1 if @max_exp
      end
    else
      #@bias_mode = :scientific_significand
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
      @scientific_max_exp = @max_exp+@significand_digits-1
      @scientific_min_exp = @min_exp+@significand_digits-1
    else
      @integral_max_exp = @max_exp - (@significand_digits-1)
      @integral_min_exp = @min_exp - (@significand_digits-1)
      @fractional_max_exp = @max_exp+1
      @fractional_min_exp = @min_exp+1
      @scientific_max_exp = @max_exp
      @scientific_min_exp = @min_exp
    end

    @round = params[:round] # || :half_even

    @neg_mode = params[:neg_mode] || :sign_magnitude

    yield self if block_given?

  end

  class <<self
    # define format properties:
    # [+radix+] Numeric base
    # [+significand_digits+] Number of digits in the significand (precision)
    # [+hidden_bit+] Has the format a hidden bit?
    # [+parameters+] Parameters used to define the class
    attr_reader :radix, :significand_digits, :parameters, :hidden_bit
    # attr_accessor
  end

  def self.normalized?
    @normalized
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
  # [<tt>:half_even</tt>] round to nearest with ties toward an even digits
  # [<tt>:half_up</tt>] round to nearest with ties toward infinity (away from zero)
  # [<tt>:half_down</tt>] round to nearest with ties toward zero
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
  def self.radix_max_exp(significand_mode = :scientific_significand)
    case significand_mode
      when :integral_significand
        @integral_max_exp
      when :fractional_significand
        @fractional_max_exp
      when :scientific_significand
        @scientific_max_exp
    end
  end
  # Mminimum exponent
  def self.radix_min_exp(significand_mode = :scientific_significand)
    case significand_mode
      when :integral_significand
        @integral_min_exp
      when :fractional_significand
        @fractional_min_exp
      when :scientific_significand
        @scientific_min_exp
    end
  end

  def self.num_class
    Num[self.radix]
  end

  def self.numerals_conversion(options = {})
    FltFmtConversion.new(self, options)
  end

  def self.context
    num_class::Context.new(
      precision: significand_digits,
      emin: radix_min_exp(:scientific_significand),
      emax: radix_max_exp(:scientific_significand),
      rounding: @round || :half_even,
      normalized: @normalized
    )
  end

  def to_num
    s, c, e = split
    case e
    when :zero
      e = 0
    when :infinity
      e = :inf
    when :nan
      e = :nan
    end
    form_class.num_class.Num(s, c, e)
  end

  # def to_num
  #   # num_class = Flt::Num[form_class.radix]
  #   num_class = self.class.num_class
  #   case @exponent
  #   when :zero
  #     num_class.zero(@sign)
  #   when :infinity
  #     num_class.infinity(@sign)
  #   when :nan
  #     num_class.nan
  #   else
  #     num_class.new(@sign, @significand, @exponent)
  #   end
  # end

  def self.num(x)
    s, c, e = x.split
    if x.zero?
      e = :zero
    else
      case e
      when :inf
        e = :infinity
      when :nan
        e = :nan
      end
    end
    new([s, c, e])
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
  def self.bias(significand_mode = :scientific_significand)
    case significand_mode
      when :integral_significand
        @integral_bias
      when :fractional_significand
        @fractional_bias
      when :scientific_significand
        @scientific_bias
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
        m /= radix # TODO: round
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
      v = v.to_bytes
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
  # TODO: use Flt::Num
  def self.strict_epsilon(sign=+1, round=nil)
    round ||= @round
    s = sign
    m = minimum_normalized_integral_significand
    e = 2*(1-significand_digits)
    # assume radix is even
    case @round
    when :down, :floor, :any_rounding, nil
      e = 2*(1-significand_digits)
      m = minimum_normalized_integral_significand
    when :half_even, :half_down
      e = 1-2*significand_digits
      m = 1 + radix_power(significand_digits)/2
    when :half_up
      e = 1-2*significand_digits
      m = radix_power(significand_digits)/2
    when :ceiling, :up, :up05
      return min_value
    end
    return_value s,m,e

  end

  # This is the maximum relative error corresponding to 1/2 ulp:
  #  (radix/2)*radix_power(-significand_precision) == epsilon/2
  # This is called "machine epsilon" in [Goldberg]
  # TODO: use Flt::Num
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

  def self.from(*args)
    new(*args)
  end

  def self.from_bytes(b)
    return_value(*unpack(b))
  end

  def self.from_hex(hex)
    from_bytes Bytes.from_hex(hex)
  end

  def self.from_number(v, mode = :approx)
    if v.is_a?(Flt::Num) && v.num_class.radix==self.radix
      self.num(v)
    else
      options = {
        type: self,
        exact_input: (mode != :approx),
        output_mode: @normalized ? :fixed : :short
      }
      Numerals::Conversions.convert(v, options)
    end
  end

  def self.from_text(txt, *args)
    if @normalized
      fmt = Numerals::Format[exact_input: true]
    else
      fmt = Numerals::Format[:short, exact_input: false]
    end
    fmt = fmt[*args]
    fmt.read(txt, type: self)
  end

  def self.join(sign,significand,exponent)
    self.new sign,significand,exponent
  end

  # Defines a floating-point number from the encoded integral value.
  def self.from_bits(i)
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
    from_bytes v
  end

  # Defines a floating-point number from a text representation of the
  # encoded integral value in a given base.
  # Returns a Value.
  def self.from_bits_text(txt, base)
    i = Numerals::Format[].read(txt, type: Integer, base: base)
    from_bits i
  end

  # Converts en ancoded floating point number to hash containing
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

  class FltFmtConversion

    def initialize(form_class, options={})
      @form_class = form_class
      @input_rounding = options[:input_rounding]
    end

    def type
      @form_class
    end

    def order_of_magnitude(value, options={})
      num_conversions.order_of_maginitude(value.to_num, options)
    end

    def number_of_digits(value, options={})
      num_conversions.number_of_digits(value.to_num, options)
    end

    def exact?(value, options={})
      options[:exact]
    end

    def write(number, exact_input, output_rounding)
      # assert_equal @form_class, number.class
      num_conversions.write(number.to_num, exact_input, output_rounding)
    end

    def read(numeral, exact_input, approximate_simplified)
      num = num_conversions.read(numeral, exact_input, approximate_simplified)
      num = num.normalize(@form_class.context) if exact_input && @form_class.normalized?
      @form_class.num(num)
    end

    private

    def num_conversions
      Numerals::Conversions[@form_class.context, input_rounding: @input_rounding]
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
        when :scientific_significand
          e -= @scientific_bias
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
        when :scientific_significand
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
      when :scientific_significand
        e += @scientific_bias
      end
    when :radix_complement
      case mode
      when :integral_significand
        e += (significand_digits-1)
      when :fractional_significand
        e -= 1
      when :scientific_significand
      end
      n = @fields[:exponent]
      v = radix_power(n)
      e = e+v if e < 0
    end
    e
  end
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
    radix_max_exp(:scientific_significand)
  end
  def self.decimal_min_exp
    radix_min_exp(:scientific_significand)
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
      # TODO: try to adjust m to keep e in range if out of valid range
      # TODO: reduce m and adjust e if m too big

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
    pack_fields_hash sign: s, significand: m, exponent: e
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

      params[:bias_mode] = :scientific_significand

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
    #sig_cont_bits = 4*(@significand_digits-1)
    sig_msd = sig_hex[0,1].to_i
    i_significand_continuation,_bits = hexbcd_to_dpd(sig_hex[1..-1])



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
    h = {sign: i_sign, combination: i_combination, exponent_continuation: i_exponent_continuation, significand_continuation: i_significand_continuation}
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
      # TODO: try to adjust m to keep e in range if out of valid range
      # TODO: reduce m and adjust e if m too big

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
    pack_fields_hash sign: s, significand: m, exponent: e, type: t
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
      # TODO: try to adjust m to keep e in range if out of valid range
      # TODO: reduce m and adjust e if m too big

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
    pack_fields_hash sign: s, significand: m, exponent: e
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
      # TODO: try to adjust m to keep e in range if out of valid range
      # TODO: reduce m and adjust e if m too big

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
    pack_fields_hash sign: s, significand: m, exponent: e
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
    minus
  end
  def +(v)
    # TODO: coercion
    if v.form_class==form_class
      form_class.arithmetic do |t|
        x = to(t,:exact) + v.to(t,:exact)
        form_class.from_number(x,:exact)
      end
    else
      # TODO
    end
  end
  def /(v)
    # TODO: coercion
    if v.form_class==form_class
      form_class.arithmetic do |t|
        x = to(t,:exact) / v.to(t,:exact)
        form_class.from_number(x,:exact)
      end
    else
      # TODO
    end
  end
  def -(v)
    # TODO: coercion
    if v.form_class==form_class
      form_class.arithmetic do |t|
        x = to(t,:exact) - v.to(t,:exact)
        form_class.from_number(x,:exact)
      end
    else
      # TODO
    end
  end
  def *(v)
    # TODO: coercion
    if v.form_class==form_class
      form_class.arithmetic do |t|
        x = to(t,:exact) * v.to(t,:exact)
        form_class.from_number(x,:exact)
      end
    else
      # TODO
    end
  end

  class FormatBase
    # Type used internally for arithmetic operations.
    def self.arithmetic_type
      num_class
      # Rational
    end
    # Set up the arithmetic environment; the arithmetic type is passed to the block.
    def self.arithmetic
      at = arithmetic_type
      if at.ancestors.include?(Flt::Num)
        at.context(self.context) do
          yield at
        end
      else
        # Could also use Flt::Decimal with decimal_digits_necessary, decimal_max_exp(:integral_significand), ...
        yield at
      end
    end
  end

# Class to define formats such as "double double" by pairing two floating-point
# values which define a higher precision value by its sum.
# The :half parameter is a format class that defines the type of each part
# of the numbers.
# The formats defined here have a fixed precision, although these formats
# can actually have a variable precision.
# For binary formats there's an option to gain one bit of precision
# by adjusting the sign of the second number. This is enabled by the
# :extra_prec option.
# For example, the "double double" format used in PowerPC is this
#   Flt.define :DoubleDouble, DoubleFormat, half: IEEE_binary64, extra_prec: true
# Although this has a fixed 107 bits precision, the format as used in
# the PowerPC can have greater precision for specific values (by having
# greater separation between the exponents of both halves)
class DoubleFormat < FormatBase

  def self.define(params)
    @half = params[:half]
    params = @half.parameters.merge(params)
    if @half.radix==2
      @extra_prec = params[:extra_prec]
    else
      @extra_prec = false
    end
    params[:significand_digits] = 2*@half.significand_digits
    params[:significand_digits] += 1 if @extra_prec
    @significand_digits = params[:significand_digits]

    @hidden_bit = params[:hidden_bit] = @half.hidden_bit

    fields1 = []
    fields2 = []
    params[:fields].each_slice(2) do |s,v|
      fields1 << s # (s.to_s+"_1").to_sym
      fields1 << v
      fields2 << (s.to_s+"_2").to_sym
      fields2 << v
    end
    params[:fields] = fields1 + fields2

    define_fields params[:fields]

    super params
  end

  def self.radix
    @half.radix
  end

  def self.half
    @half
  end

  def self.unpack(v)
    sz = @half.total_bytes
    v1 = @half.unpack(v[0...sz])
    v2 = @half.unpack(v[sz..-1])
    if v1.last == :nan
      nan
    elsif v1.last == :infinity
      infinity(v1.sign)
    else
      v2 = @half.zero.split if @half.new(*v1).subnormal?
      params = v1 + v2
      join_fp(*params)
    end
  end

  def self.pack(s,m,e)
    if e.kind_of?(Symbol)
      f1 = @half.pack(s,m,e)
      f2 = @half.pack(+1,0,:zero)
    else
      s1,m1,e1,s2,m2,e2 = split_fp(s,m,e)
      f1 = @half.pack(s1,m1,e1)
      f2 = @half.pack(s2,m2,e2)
    end
    f1+f2
  end

  def split_halfs
    b = to_bytes
    sz = form_class.half.total_bytes
    b1 = b[0...sz]
    b2 = b[sz..-1]
    [form_class.half.from_bytes(b1), form_class.half.from_bytes(b2)]
  end

  def self.join_halfs(h1,h2)
    self.from_bytes(h1.to_bytes+h2.to_bytes)
  end

  def self.total_nibbles
    2*total_bytes
  end
  def self.total_bytes
    2*@half.total_bytes
  end
  def self.total_bits
    8*total_bytes
  end

  private
  def self.split_fp(s,m,e)
    n = @half.significand_digits
    if @half.radix==2
      if @extra_prec
        if (m & (1<<n))==0 # m.to_bits[n] == 0
          m1 = m >> (n+1) # m/2**(n+1)
          e1 = e + n + 1
          s1 = s
          m2 = m & ((1<<n) - 1) # m%2**n
          e2 = e
          s2 = s
        else
          m1 = (m >> (n+1)) + 1 # m/2**(n+1) + 1
          e1 = e + n + 1
          s1 = s
          if m1>=(1<<n) # 2**n
            m1 >>= 1
            e1 += 1
          end
          if m2==0
            m2 = (1<<(n-1)) # 2**(n-1)
            e2 = e+1
            s2 = -s
          else
            m2 = -((m & ((1<<n) - 1)) - (1<<n)) # m%2**n - 2**n
            e2 = e
            s2 = -s
          end
        end
      else # m has 2*n bits
        m1 = m >> n
        e1 = e + n
        s1 = s
        m2 = m & ((1<<n) - 1) # m%2**n
        e2 = e
        s2 = s
      end
    else
        m1 = m / @half.radix_power(n)
        e1 = e + n
        s1 = s
        m2 = m % @half.radix_power(n)
        e2 = e
        s2 = s
    end
    [s1,m1,e1,s2,m2,e2]
  end

  def FormatBase.join_fp(s1,m1,e1,s2,m2,e2)
    if m2==0 || e2==:zero
      s = s1
      m = m1
      e = e1
    else
      m = s1*(m1<<(e1-e2)) + s2*m2
      e = e2
    end
    if m<0
      s = -1
      m = -m
    else
      s = +1
    end
    if m!=0 && e1.kind_of?(Numeric)
      # normalize
      nn = significand_digits
      while m >= (1 << nn)
        m >>= 1
        e += 1
      end
      while m>0 && m < (1 << (nn-1))
        m <<= 1
        e -= 1
      end
    end
    [s,m,e]
  end


end



module_function

def define(*arguments)
  raise "Invalid number of arguments for Flt definitions." if arguments.size<2 || arguments.size>3
  if arguments.first.kind_of?(Class)
    base,name,parameters = arguments
  elsif arguments[1].kind_of?(Class)
    name,base,parameters = arguments
  else
    name,parameters = arguments
    base = parameters[:base] || FormatBase
  end
  Flt.const_set name, cls=Class.new(base)
  cls.define parameters
  constructor = lambda { |*args| cls.new(*args) }
  Flt.send :define_method,name,constructor
  Flt.send :module_function, name
  yield cls if block_given?
end



def convert_bytes(bytes,from_format,to_format)
  from_format.from_bytes(bytes).convert_to(to_format)
end




end
