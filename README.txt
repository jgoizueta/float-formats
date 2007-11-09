=Introduction

Float-Formats is a Ruby package with methods to handle diverse floating-point formats.
These are some of the things that can be done with it:

* Enconding and decoding numerical values in specific floating point representations.
* Conversion of floating-point data between different formats.
* Obtaining properties of floating-point formats (ranges, precision, etc.)
* Exploring and learning about floating point representations.
* Definition and testing of new floating-point formats.

=Installation

The easiest way to install Nio is using gems:

<tt>  gem install --remote float-formats -y</tt>

==Requirements

Nio[http://nio.rubyforge.org/] 0.2.0 or later is needed. This 
can be installed as a gem and should be automatically
installed by the command shown above to install float-formats.


==Downloads

The latest version of Float-Formats and its source code can be downloaded from
* http://rubyforge.org/project/showfiles.php?group_id=4684



=Predefined formats

A number of common formats are defined as constants in the FltPnt module:

==IEEE
<b>IEEE 754 binary</b> floating point representations in little endian order:
IEEE_SINGLE, IEEE_DOUBLE, IEEE_EXTENDED, IEEE_128 and
as little endian: IEEE_S_BE, IEEE_D_BE, IEEE_X_BE, IEEE_128_BE.
Note that the standard defines extended formats with either 64 bits or precision
(IEEE_EXTENDED, IEEE_X_BE) or 112 (IEEE_128, IEEE_128_BE).

<b>IEEE 754r decimal</b> formats (using DPD): IEEE_DEC32, IEEE_DEC64 and IEEE_DEC128.

==Legacy
Formats of historical interest, some of which are found
in file formats still in use.

<b>Mainframe/supercomputer</b> formats:
Univac 1100 (UNIVAC_SINGLE, UNIVAC_DOUBLE),
IBM 360 etc. (IBM32, IBM64 and IBM128),
CDC 6600/7600: (CDC_SINGLE, CDC_DOUBLE),
Cray-1: (CRAY).

<b>Minis</b>: PDP11 and Vaxes: (PDP11_F, PDP11_D, VAX_F, VAX_D, VAX_G and VAX_H),
HP3000: (XS256, XS256_DOUBLE),
Wang 2200: (WANG2200).

<b>Microcomputers</b> (software implementations):
Apple II: (APPLE),
Microsoft Basic, Spectrum, etc.: (XS128),
Microsoft Quickbasic: (MBF_SINGLE, MBF_DOUBLE),
Borland Pascal: (BORLAND48).

<b>Embedded systems</b>: 
Formats used in the Intel 8051 by the C51 compiler:
(C51_BCD_FLOAT, C51_BCD_DOUBLE and C51_BCD_LONG_DOUBLE).


==Calculators
Formats used in HP SATURN based calculators (RPL): (SATURN, SATURN_X),
Classic HP 10 digit calculators: (HP_CLASSIC).



=Using the pre-defined formats

  require 'rubygems'
  require 'float-formats'
  include FltPnt

The properties of the floating point formats can be queried (which can be
used for tables or reports comparing different formats):

Size in bits of the representations:
  puts IEEE_SINGLE.total_bits                        -> 32

Numeric radix:
  puts IEEE_SINGLE.radix                             -> 2

Digits of precision (radix-based)
  puts IEEE_SINGLE.significand_digits                -> 24

Minimum and maximum values of the radix-based exponent:
  puts IEEE_SINGLE.radix_min_exp                     -> -126
  puts IEEE_SINGLE.radix_max_exp                     -> 127

Decimal precision
  puts IEEE_SINGLE.decimal_digits_stored             -> 6
  puts IEEE_SINGLE.decimal_digits_necessary          -> 9

Minimum and maximum decimal exponents:
  puts IEEE_SINGLE.decimal_min_exp                   -> -37
  puts IEEE_SINGLE.decimal_max_exp                   -> 38

==Encode and decode numbers

The <tt>from_</tt> methods of the floating-format classes generate a floating point value
stored in a byte string from a variety of definitions:
* <tt>from_integral_sign_significand_exponent</tt> defines the value by three integers:
  the sign (0 for +, 1 for -), the significand (coefficient or mantissa)
  and the exponent.
* <tt>from_fmt</tt> : converts a text numeral (with an optional Nio format specifier)
  to a floating point value
* <tt>from_number</tt> : converts a numerical value
  to a floating point representation.

All these methods return an object of type Value that contains the encoded value (#bytes)
and the Floating point format class (#fp_format).
  
  File.open('binary_file.dat','wb'){|f| f.write IEEE_EXTENDED.from_fmt('0.1').bytes}
  
  puts IEEE_EXTENDED.from_fmt('0.1').to_hex(true)    -> CD CC CC CC CC CC CC CC FB 3F
  puts IEEE_EXTENDED.from_number(0.1).to_hex(true)   -> CD CC CC CC CC CC CC CC FB 3F
  puts IEEE_EXTENDED.from_integral_sign_significand_exponent(0,123,-2).to_hex(true) -> 00 00 00 00 00 00 00 F6 03 40
  puts IEEE_DEC32.from_fmt('1.234').to_hex(true)     -> 22 20 05 34

A floating-point encoded value can be converted to useful formats wit the to_ methods:
* <tt>to_integral_sign_significand_exponent</tt>
* <tt>to_fmt</tt>
* <tt>to_number</tt>

  puts IEEE_EXTENDED.to_number(File.read('binary_file.dat'))
  v = IEEE_EXTENDED.from_fmt('0.1')
  puts v.to_integral_sign_significand_exponent.inspect
  puts v.to_fmt
  puts v.to_number(Float)
    
==Special values:  

Let's show the decimal expression of some interesting values using
3 significative digits:

  fmt = Nio::Fmt.mode(:gen,3)  

  puts IEEE_SINGLE.min_value.to_fmt(fmt)             -> 1.4E-45
  puts IEEE_SINGLE.min_normalized_value.to_fmt(fmt)  -> 1.18E-38
  puts IEEE_SINGLE.max_value.to_fmt(fmt)             -> 3.4E38
  puts IEEE_SINGLE.epsilon.to_fmt(fmt)               -> 1.19E-7

==Convert between formats

  v = IEEE_EXTENDED.from_fmt('1.1')
  v = v.convert_to(IEEE_SINGLE)
  v = v.convert_to(IEEE_DEC64)
  
  
=Tools for the native floating point format
This is an optional module (must be loaded explicitely because
is somewhat intrusive; it adds methods to Float)
that useful to explore or manipulate the native Float format.
  
  require 'float-formats/native'
  include FltPnt

  puts float_shortest_dec(1.0.next)                  -> 1.0000000000000002
  puts float_dec(1.0.prev)                           -> 0.99999999999999988897769753748434595763683319091796875
  puts float_dec(1.0.next)                           -> 1.0000000000000002220446049250313080847263336181640625
  puts float_dec(1.0.prev)                           -> 0.99999999999999988897769753748434595763683319091796875
  puts float_bin(1.0.next)                           -> 1.0000000000000000000000000000000000000000000000000001E0
  puts 1.0.next-1 == Float::EPSILON                  -> true
  puts float_significant_dec(Float::MIN_D)           -> 5E-324
  puts float_significant_dec(Float::MIN_D.next)      -> 1.0E-323
  puts float_significant_dec(Float::MAX_D.prev)      -> 2.2250738585072004E-308
  puts float_significant_dec(Float::MAX_D)           -> 2.2250738585072009E-308
  puts float_significant_dec(Float::MIN_N)           -> 2.2250738585072014E-308
  

=Defining new formats

New formats are defined using one of the classes defined in float-formats/classes.rb
and passing the necessary parameters in a hash to the constructor.

For example, here we define a binary floating point 32-bits format with 
22 bits for the significand, 9 for the exponent and 1 for the sign
(these fields are allocated from least to most significant bits).
We'll use excess notation with bias 127 for the exponent, interpreting
the significand bits as a fractional number with the radix point after
the first bit, which will be hidden:
  MY_FP = BinaryFormat.new(
    :fields=>[:significand,22,:exponent,9,:sign,1],
    :bias=>127, :bias_mode=>:normalized_significand,
    :hidden_bit=>true)
Now we can encode values in this format, decode values, convet to other
formats, query it's range, etc:

     puts MY_FP.from_fmt('0.1').to_bits_text(16)     -> 1ee66666
     puts MY_FP.max_value.to_fmt(Nio::Fmt.prec(3))   -> 7.88E115
  
You can look at float-formats/formats.rb to see how the built-in formats
are defined.

=License

This code is free to use under the terms of the GNU GENERAL PUBLIC LICENSE.

=Contact

Nio has been developed by Javier Goizueta (mailto:javier@goizueta.info).

You can contact me through Rubyforge:http://rubyforge.org/sendmessage.php?touser=25432

