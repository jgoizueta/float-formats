#Introduction

Float-Formats is a Ruby package with methods to handle diverse floating-point formats.
These are some of the things that can be done with it:

* Enconding and decoding numerical values in specific floating point representations.
* Conversion of floating-point data between different formats.
* Obtaining properties of floating-point formats (ranges, precision, etc.)
* Exploring and learning about floating point representations.
* Definition and testing of new floating-point formats.

#Installation

To install the gem manually:

    gem install float-formats

You can find the code in GitHub:

* http://github.com/jgoizueta/float-formats/

#Predefined formats

A number of common formats are defined as constants in the Flt module:

##IEEE 754-2008

**Binary** floating point representations in little endian order:

* IEEE_binary16 (half precision),
* IEEE_binary32 (single precision),
* IEEE_binary64 (double precision),
* IEEE_binary80 (extended), IEEE_binary128 (quadruple precision) and
  as little endian: IEEE_binary16_BE, etc.

**Decimal** formats (using DPD):

* IEEE_decimal32, IEEE_decimal64 and IEEE_decimal128.

**Interchange binary & decimal** formats:

* IEEE_binary256, IEEE_binary512, IEEE_binary1024, IEEE_decimal192, IEEE_decimal256.

Others can be defined with IEEE.interchange_binary and IEEE.interchange_decimal
(see the IEEE module).

##Legacy

Formats of historical interest, some of which are found
in file formats still in use.

**Mainframe/supercomputer** formats:
Univac 1100 (UNIVAC_SINGLE, UNIVAC_DOUBLE),
IBM 360 etc. (IBM32, IBM64 and IBM128),
CDC 6600/7600: (CDC_SINGLE, CDC_DOUBLE),
Cray-1: (CRAY).

**Minis**: PDP11 and Vaxes: (PDP11_F, PDP11_D, VAX_F, VAX_D, VAX_G and VAX_H),
HP3000: (XS256, XS256_DOUBLE),
Wang 2200: (WANG2200).

**Microcomputers** (software implementations):
Apple II: (APPLE),
Microsoft Basic, Spectrum, etc.: (XS128),
Microsoft Quickbasic: (MBF_SINGLE, MBF_DOUBLE),
Borland Pascal: (BORLAND48).

**Embedded systems**:
Formats used in the Intel 8051 by the C51 compiler:
(C51_BCD_FLOAT, C51_BCD_DOUBLE and C51_BCD_LONG_DOUBLE).

##Calculators

Formats used in HP RPL calculators: (RPL, RPL_X),
HP-71B formats (HP71B, HP71B_X)
and classic HP 10 digit calculators: (HP_CLASSIC).

#Using the pre-defined formats

    require 'rubygems'
    require 'float-formats'
    include Flt

The properties of the floating point formats can be queried (which can be
used for tables or reports comparing different formats):

Size in bits of the representations:

    puts IEEE_binary32.total_bits                        # -> 32

Numeric radix:

    puts IEEE_binary32.radix                             # -> 2

Digits of precision (radix-based)

    puts IEEE_binary32.significand_digits                # -> 24

Minimum and maximum values of the radix-based exponent:

    puts IEEE_binary32.radix_min_exp                     # -> -126
    puts IEEE_binary32.radix_max_exp                     # -> 127

Decimal precision

    puts IEEE_binary32.decimal_digits_stored             # -> 6
    puts IEEE_binary32.decimal_digits_necessary          # -> 9

Minimum and maximum decimal exponents:

    puts IEEE_binary32.decimal_min_exp                   # -> -37
    puts IEEE_binary32.decimal_max_exp                   # -> 38

##Encode and decode numbers

For each floating-point format class there is a constructor method with the same
name which can build a floating-point value from a variety of parameters:

* Using three integers:
  the sign (+1 for +, -1 for -), the significand (coefficient or mantissa)
  and the exponent.
* From a text numeral (with an optional Nio format specifier)
* From a number : converts a numerical value
  to a floating point representation.

Examples:

    File.open('binary_file.dat','wb'){|f| f.write IEEE_binary80('0.1').to_bytes}
    puts IEEE_binary80('0.1').to_hex(true)           # -> CD CC CC CC CC CC CC CC FB 3F
    puts IEEE_binary80(0.1).to_hex(true)             # -> CD CC CC CC CC CC CC CC FB 3F
    puts IEEE_binary80(+1,123,-2).to_hex(true)       # -> 00 00 00 00 00 00 00 F6 03 40
    puts IEEE_decimal32('1.234').to_hex(true)        # -> 22 20 05 34

A floating-point encoded value can be converted to useful formats with the to_ and similar methods:

* `split` (split as integral sign, significand, exponent)
* `to_text`
* `to(num_class)`

Examples:

    v = IEEE_binary80.from_bytes(File.read('binary_file.dat'))
    puts v.to(Rational)                              # -> 1/10
    puts v.split.inspect                             # -> [1, 14757395258967641293, -67]
    puts v.to_text                                   # -> 0.1
    puts v.to(Float)                                 # -> 0.1
    puts v.to_hex                                    # -> CDCCCCCCCCCCCCCCFB3F
    puts v.to_bits                                   # -> 00111111111110111100110011001100110011001100110011001100110011001100110011001101
    puts v.to_bits_text(16)                          # -> 3ffbcccccccccccccccd

##Special values:  

Let's show the decimal expression of some interesting values using
3 significative digits:

    fmt = Nio::Fmt.mode(:gen,3)  
    puts IEEE_SINGLE.min_value.to_text(fmt)             # -> 2E-45
    puts IEEE_SINGLE.min_normalized_value.to_text(fmt)  # -> 1.18E-38
    puts IEEE_SINGLE.max_value.to_text(fmt)             # -> 3.4E38
    puts IEEE_SINGLE.epsilon.to_text(fmt)               # -> 1.19E-7

##Convert between formats

    v = IEEE_EXTENDED.from_text('1.1')
    v = v.convert_to(IEEE_SINGLE)
    v = v.convert_to(IEEE_DEC64)

#Tools for the native floating point format

This is an optional module to perform conversions and manipulate the native Float format.

    require 'float-formats/native'
    include Flt

    puts float_shortest_dec(0.1)                     # -> 0.1
    puts float_significant_dec(0.1)                  # -> 0.10000000000000001
    puts float_dec(0.1)                              # -> 0.1000000000000000055511151231257827021181583404541015625
    puts float_bin(0.1)                              # -> 1.100110011001100110011001100110011001100110011001101E-4
    puts hex_from_float(0.1)                         # -> 0x1999999999999ap-56

    puts float_significant_dec(Float::MIN_D)           # -> 5E-324
    puts float_significant_dec(Float::MAX_D)           # -> 2.2250738585072009E-308
    puts float_significant_dec(Float::MIN_N)           # -> 2.2250738585072014E-308

Together with flt/sugar (from Flt) can be use to explore or work with Floats:  

    require 'flt/sugar'

    puts 1.0.next_plus-1 == Float::EPSILON              # -> true
    puts float_shortest_dec(1.0.next_plus)              # -> 1.0000000000000002
    puts float_dec(1.0.next_minus)                      # -> 0.99999999999999988897769753748434595763683319091796875
    puts float_dec(1.0.next_plus)                       # -> 1.0000000000000002220446049250313080847263336181640625
    puts float_bin(1.0.next_plus)                       # -> 1.0000000000000000000000000000000000000000000000000001E0
    puts float_bin(1.0.next_minus)                      # -> 1.1111111111111111111111111111111111111111111111111111E-1

    puts float_significant_dec(Float::MIN_D.next_plus)  # -> 1.0E-323
    puts float_significant_dec(Float::MAX_D.next_minus) # -> 2.2250738585072004E-308

#Defining new formats

New formats are defined using one of the classes defined in float-formats/classes.rb
and passing the necessary parameters in a hash to the constructor.

For example, here we define a binary floating point 32-bits format with
22 bits for the significand, 9 for the exponent and 1 for the sign
(these fields are allocated from least to most significant bits).
We'll use excess notation with bias 127 for the exponent, interpreting
the significand bits as a fractional number with the radix point after
the first bit, which will be hidden:

    Flt.define(
      :MY_FP, BinaryFormat,
      :fields=>[:significand,22,:exponent,9,:sign,1],
      :bias=>127, :bias_mode=>:scientific_significand,
      :hidden_bit=>true
    )

Now we can encode values in this format, decode values, convet to other
formats, query it's range, etc:

     puts MY_FP('0.1').to_bits_text(16)              # -> 1ee66666
     puts MY_FP.max_value.to_text(Nio::Fmt.prec(3))  # -> 7.88E115

You can look at float-formats/formats.rb to see how the built-in formats
are defined.

#License

This code is free to use under the terms of the MIT license.

#References

[*Floating Point Representations.* C.B. Silio.](http://www.ece.umd.edu/class/enpm607.S2000/fltngpt.pdf)
  Description of formats used in UNIVAC 1100, CDC 6600/7600, PDP-11, IEEE754, IBM360/370

[*Floating-Point Formats.* John Savard.](http://www.quadibloc.com/comp/cp0201.htm)
  Description of formats used in VAX and PDF-11

###IEEE754 binary formats

[*IEEE-754 References.* Christopher Vickery.](http://babbage.cs.qc.edu/courses/cs341/IEEE-754references.html)

[*What Every Computer Scientist Should Know About Floating-Point Arithmetic.* David Goldberg.](http://docs.sun.com/source/806-3568/ncg_goldberg.html)

###DPD/IEEE754r decimal formats

[*Decimal Arithmetic Encoding. Strawman 4d.* Mike Cowlishaw.](http://www2.hursley.ibm.com/decimal/decbits.pdf)

[*A Summary of Densely Packed Decimal encoding.* Mike Cowlishaw.](http://www2.hursley.ibm.com/decimal/DPDecimal.html)

[*Packed Decimal Encoding IEEE-754-r.* J.H.M. Bonten.](http://home.hetnet.nl/mr_1/81/jhm.bonten/computers/bitsandbytes/wordsizes/ibmpde.htm)

[*DRAFT Standard for Floating-Point Arithmetic P754.* IEEE.](http://www.validlab.com/754R/drafts/archive/2007-10-05.pdf)

###HP 10 digits calculators

[*HP CPU and Programming*. David G.Hicks.](http://www.hpmuseum.org/techcpu.htm)  
  Description of calculator CPUs from the Museum of HP Calculators.

[*HP 35 ROM step by step.* Jacques Laporte](http://www.jacques-laporte.org/HP35%20ROM.htm)
  Description of HP35 registers.

*Scientific Pocket Calculator Extends Range of Built-In Functions.* Eric A. Evett, Paul J. McClellan, Joseph P. Tanzini.
  Hewlett Packard Journal 1983-05 pgs 27-28. Describes format used in HP-15C.

###HP 12 digits calculators

*Software Internal Design Specification Volume I For the HP-71*. Hewlett Packard.
  Available from http://www.hpmuseum.org/cd/cddesc.htm

*RPL PROGRAMMING GUIDE*
  Excerpted from *RPL: A Mathematical Control Language*. by W. C. Wickes.
  Available at http://www.hpcalc.org/details.php?id=1743

###HP-3000

*A Pocket Calculator for Computer Science Professionals.* Eric A. Evett.
  Hewlett Packard Journal 1983-05 pg 37. Describes format used in HP-3000

###IBM

[*IBM Floating Point Architecture.* Wikipedia.](http://en.wikipedia.org/wiki/IBM_Floating_Point_Architecture)

[*The IBM eServer z990 floating-point unit*. G. Gerwig, H. Wetter, E. M. Schwarz, J. Haess, C. A. Krygowski, B. M. Fleischer and M. Kroener.](http://www.research.ibm.com/journal/rd/483/gerwig.html)

###MBF  

[*Microsoft Knowledbase Article 35826*](http://support.microsoft.com/?scid=kb%3Ben-us%3B35826&x=17&y=12)

[*Microsoft MBF2IEEE library*](http://download.microsoft.com/download/vb30/install/1/win98/en-us/mbf2ieee.exe)

###Borland

*An Overview of Floating Point Numbers.* Borland Developer Support Staff

[*Pascal Floating-Point Page.* J R Stockton.](http://www.merlyn.demon.co.uk/pas-real.htm)

###8-bit micros

This is the MS Basic format (BASIC09 for TRS-80 Color Computer, Dragon),
also used in the Sinclair Spectrum.

*Numbers are followed by information not in listings*
  Sinclair User October 1983 http://www.sincuser.f9.co.uk/019/helplne.htm

*Sinclair ZX Spectrum / Basic Programming.*. Steven Vickers.
  Chapter 24. http://www.worldofspectrum.org/ZXBasicManual/zxmanchap24.html

###Apple II

*Floating Point Routines for the 6502* Roy Rankin and Steve Wozniak.
  Dr. Dobb's Journal, August 1976, pages 17-19.

###C51

[*Advanced Development System* Franklin Software, Inc.](http://www.fsinc.com/reference/html/com9anm.htm)

###CDC6600

*CONTROL DATA 6400/6500/6600 COMPUTER SYSTEMS Reference Manual*
  Manuals available at http://bitsavers.org/

###Cray

*CRAY-1 COMPUTER SYSTEM Hardware Reference Manual*
  See pg 3-20 from 2240004 or pg 4-30 from HR-0808 or pg 4-21 from HP-0032.
  Manuals available at http://bitsavers.org/

###Wang 2200

[*Internal Floating Point Representation*](http://www.wang2200.org/fp_format.html)
