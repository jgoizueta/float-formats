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

A number of common formats are defined as constants in the Flt module:

==IEEE 754r
<b>binary</b> floating point representations in little endian order:
IEEE_binary16 (half precision), 
IEEE_binary32 (single precision),
IEEE_binary64 (double precision),
IEEE_binary80 (extended), IEEE_binary128 (quadruple precision) and
as little endian: IEEE_binary16_BE, etc.

<b>decimal</b> formats (using DPD): 
IEEE_decimal32, IEEE_decimal64 and IEEE_decimal128.

<b>interchange binary & decimal</b> formats: 
IEEE_binary256, IEEE_binary512, IEEE_binary1024, IEEE_decimal192, IEEE_decimal256.
Others can be defined with IEEE.interchange_binary and IEEE.interchange_decimal
(see the IEEE module).


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
Formats used in HP RPL calculators: (RPL, RPL_X),
HP-71B formats (HP71B, HP71B_X)
and classic HP 10 digit calculators: (HP_CLASSIC).


=Using the pre-defined formats

  require 'rubygems'
  require 'float-formats'
  include Flt

The properties of the floating point formats can be queried (which can be
used for tables or reports comparing different formats):

Size in bits of the representations:
  puts IEEE_binary32.total_bits                        -> 32

Numeric radix:
  puts IEEE_binary32.radix                             -> 2

Digits of precision (radix-based)
  puts IEEE_binary32.significand_digits                -> 24

Minimum and maximum values of the radix-based exponent:
  puts IEEE_binary32.radix_min_exp                     -> -126
  puts IEEE_binary32.radix_max_exp                     -> 127

Decimal precision
  puts IEEE_binary32.decimal_digits_stored             -> 6
  puts IEEE_binary32.decimal_digits_necessary          -> 9

Minimum and maximum decimal exponents:
  puts IEEE_binary32.decimal_min_exp                   -> -37
  puts IEEE_binary32.decimal_max_exp                   -> 38

==Encode and decode numbers

For each floating-point format class there is a constructor method with the same
name which can build a floating-point value from a variety of parameters:
* Using three integers:
  the sign (+1 for +, -1 for -), the significand (coefficient or mantissa)
  and the exponent.
* From a text numeral (with an optional Nio format specifier)
* From a number : converts a numerical value
  to a floating point representation.
  
    File.open('binary_file.dat','wb'){|f| f.write IEEE_binary80('0.1').as_bytes}
    
    puts IEEE_binary80('0.1').as_hex(true)           -> CD CC CC CC CC CC CC CC FB 3F
    puts IEEE_binary80(0.1).as_hex(true)             -> CD CC CC CC CC CC CC CC FB 3F
    puts IEEE_binary80(+1,123,-2).as_hex(true)       -> 00 00 00 00 00 00 00 F6 03 40
    puts IEEE_decimal32('1.234').as_hex(true)        -> 22 20 05 34

A floating-point encoded value can be converted to useful formats with the as_ methods:
* <tt>to_integral_sign_significand_exponent</tt>
* <tt>to_fmt</tt>
* <tt>to_number</tt>
 
    v = IEEE_binary80.bytes(File.read('binary_file.dat'))
    puts v.as(Rational)                              -> 14757395258967641293/147573952589676412928
    puts v.split.inspect                             -> [1, 14757395258967641293, -67]
    puts v.as_text                                   -> 0.1000000000000000000013552527156068805425093160010874271392822265625
    puts v.as(Float)                                 -> 0.1
    puts v.as_hex                                    -> CDCCCCCCCCCCCCCCFB3F
    puts v.as_bits                                   -> 302153978578547713559757
    puts v.as_bits_text(16)                          -> 3ffbcccccccccccccccd
    
==Special values:  

Let's show the decimal expression of some interesting values using
3 significative digits:

  fmt = Nio::Fmt.mode(:gen,3)  

  puts IEEE_SINGLE.min_value.as_text(fmt)             -> 1.4E-45
  puts IEEE_SINGLE.min_normalized_value.as_text(fmt)  -> 1.18E-38
  puts IEEE_SINGLE.max_value.as_text(fmt)             -> 3.4E38
  puts IEEE_SINGLE.epsilon.as_text(fmt)               -> 1.19E-7

==Convert between formats

  v = IEEE_EXTENDED.text('1.1')
  v = v.convert_to(IEEE_SINGLE)
  v = v.convert_to(IEEE_DEC64)
  
  
=Tools for the native floating point format
This is an optional module (must be loaded explicitely because
is somewhat intrusive; it adds methods to Float)
that useful to explore or manipulate the native Float format.
  
  require 'float-formats/native'
  include Flt

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
  Flt.define(:MY_FP, BinaryFormat,
    :fields=>[:significand,22,:exponent,9,:sign,1],
    :bias=>127, :bias_mode=>:scientific_significand,
    :hidden_bit=>true)
Now we can encode values in this format, decode values, convet to other
formats, query it's range, etc:

     puts MY_FP('0.1').as_bits_text(16)              -> 1ee66666
     puts MY_FP.max_value.as_text(Nio::Fmt.prec(3))   -> 7.88E115
  
You can look at float-formats/formats.rb to see how the built-in formats
are defined.

=License

This code is free to use under the terms of the GNU GENERAL PUBLIC LICENSE.

=Contact

Nio has been developed by Javier Goizueta (mailto:javier@goizueta.info).

You can contact me through Rubyforge:http://rubyforge.org/sendmessage.php?touser=25432

=References


[<i>Floating Point Representations.</i> C.B. Silio.]
  http://www.ece.umd.edu/class/enpm607.S2000/fltngpt.pdf  
  Description of formats used in UNIVAC 1100, CDC 6600/7600, PDP-11, IEEE754, IBM360/370
  
[<i>Floating-Point Formats.</i> John Savard.]  
  http://www.quadibloc.com/comp/cp0201.htm
  Description of formats used in VAX and PDF-11


===IEEE754 binary formats
[<i>IEEE-754 References.</i> Christopher Vickery.]
  http://babbage.cs.qc.edu/courses/cs341/IEEE-754references.html

[<i>What Every Computer Scientist Should Know About Floating-Point Arithmetic.</i> David Goldberg.]
  http://docs.sun.com/source/806-3568/ncg_goldberg.html


===DPD/IEEE754r decimal formats
[<i>Decimal Arithmetic Encoding. Strawman 4d.</i> Mike Cowlishaw.]
  http://www2.hursley.ibm.com/decimal/decbits.pdf

[<i>A Summary of Densely Packed Decimal encoding.</i> Mike Cowlishaw.]
  http://www2.hursley.ibm.com/decimal/DPDecimal.html
  
[<i>Packed Decimal Encoding IEEE-754-r.</i> J.H.M. Bonten.]
  http://home.hetnet.nl/mr_1/81/jhm.bonten/computers/bitsandbytes/wordsizes/ibmpde.htm

[<i>DRAFT Standard for Floating-Point Arithmetic P754.</i> IEEE.]
  http://www.validlab.com/754R/drafts/archive/2007-10-05.pdf
  


===HP 10 digits calculators

[<i>HP CPU and Programming</i>. David G.Hicks.]
  http://www.hpmuseum.org/techcpu.htm  Description of calculator CPUs from the Museum of HP Calculators.
[<i>HP 35 ROM step by step.</i> Jacques Laporte]
  http://www.jacques-laporte.org/HP35%20ROM.htm
  Description of HP35 registers.
[<i>Scientific Pocket Calculator Extends Range of Built-In Functions.</i> Eric A. Evett, Paul J. McClellan, Joseph P. Tanzini.]
  Hewlett Packard Journal 1983-05 pgs 27-28. Describes format used in HP-15C.


===HP 12 digits calculators
[<i>Software Internal Design Specification Volume I For the HP-71</i>. Hewlett Packard.]
  Available from http://www.hpmuseum.org/cd/cddesc.htm
[<i>RPL PROGRAMMING GUIDE</i>]
  Excerpted from <i>RPL: A Mathematical Control Language</i>. by W. C. Wickes.
  Available at http://www.hpcalc.org/details.php?id=1743

===HP-3000
[<i>A Pocket Calculator for Computer Science Professionals.</i> Eric A. Evett.]
  Hewlett Packard Journal 1983-05 pg 37. Describes format used in HP-3000

===IBM
[<i>IBM Floating Point Architecture.</i> Wikipedia.]
  http://en.wikipedia.org/wiki/IBM_Floating_Point_Architecture
[<i>The IBM eServer z990 floating-point unit</i>. G. Gerwig, H. Wetter, E. M. Schwarz, J. Haess, C. A. Krygowski, B. M. Fleischer and M. Kroener.]
  http://www.research.ibm.com/journal/rd/483/gerwig.html
  
===MBF  
[<i>Microsoft Knowledbase Article 35826</i>]
  http://support.microsoft.com/?scid=kb%3Ben-us%3B35826&x=17&y=12
[<i>Microsoft MBF2IEEE library</i>]
  http://download.microsoft.com/download/vb30/install/1/win98/en-us/mbf2ieee.exe

===Borland
[<i>An Overview of Floating Point Numbers.</i> Borland Developer Support Staff]

[<i>Pascal Floating-Point Page.<i> J R Stockton.]
  http://www.merlyn.demon.co.uk/pas-real.htm

===8-bit micros
This is the MS Basic format (BASIC09 for TRS-80 Color Computer, Dragon),
also used in the Sinclair Spectrum.

[<i>Numbers are followed by information not in listings</i>]
  Sinclair User October 1983 http://www.sincuser.f9.co.uk/019/helplne.htm

[<i>Sinclair ZX Spectrum / Basic Programming.</i>. Steven Vickers.]
  Chapter 24. http://www.worldofspectrum.org/ZXBasicManual/zxmanchap24.html



===Apple II
[<i>Floating Point Routines for the 6502</i> Roy Rankin and Steve Wozniak.]
  Dr. Dobb's Journal, August 1976, pages 17-19.

===C51
[<i>Advanced Development System</i> Franklin Software, Inc.]
  http://www.fsinc.com/reference/html/com9anm.htm

===CDC6600
[<i>CONTROL DATA 6400/6500/6600 COMPUTER SYSTEMS Reference Manual</i>]
  Manuals available at http://bitsavers.org/
 

===Cray
[<i>CRAY-1 COMPUTER SYSTEM Hardware Reference Manual</i>]
  See pg 3-20 from 2240004 or pg 4-30 from HR-0808 or pg 4-21 from HP-0032.
  Manuals available at http://bitsavers.org/

===Wang 2200
[<i>Internal Floating Point Representation</i>] http://www.wang2200.org/fp_format.html
