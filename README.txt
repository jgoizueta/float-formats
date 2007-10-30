=Introduction

Float-Formats is a Ruby package with methods to handle diverse floating-point formats.

==Purpose

* Enconding and decoding numerical values in specifica floating point formats
* Conversion of floating-point data between different formats
* Obtaining properties of floating-point formats (ranges, precision, etc)
* Exploring and learning about floating point representations
* Definition and testing of new floating-point formats


=Usage

==Using the pre-defined formats

Access properties of a floating-format; generating reports, tables, ...

  puts IEEE_EXTENDED.min_decimal_exp
  ....
  puts 

See FltPnt

===Encode and decode numbers

The from_ methods of the floating-format classes generate a floating point value
stored in a byte string from a variety of defintions:
* from_integral_sign_significand_exponent defines the value by three integers:
  the sign (0 for +, 1 for -), the significand (coefficient or mantissa)
  and the exponent.
* from_fmt : converts a text numeral (with an optional Nio format specifier)
  to a floating point value
* from_value : converts a numerical value
  to a floating point value
This methods return an object of type Value that contains the encoded value (bytes)
and the Floating point format class (fp_format).
  
  File.open('binary_file.dat','wb'){|f| f.write IEEE_EXTENDED.from_fmt('0.1').bytes}
  
  puts IEEE_EXTENDED.from_fmt('0.1').to_hex(true)
  puts IEEE_EXTENDED.from_value(0.1).to_hex(true)
  puts IEEE_EXTENDED.from_integral_sign_significand_exponent(0,123,-2).to_hex(true)

A floating-point encoded value can be converted to useful formats wit the to_ methods:
* to_integral_sign_significand_exponent
* to_fmt
* to_values
  puts IEEE_EXTENDED.to_value(File.read('binary_file.dat'))
  v = IEEE_EXTENDED.from_fmt('0.1')
  puts v.to_integral_sign_significand_exponent.inspect
  puts v.to_fmt
  puts v.to_value(Float)
  
  
===Special values:  
  puts IEEE_SINGLE.min_value.to_fmt
  puts IEEE_SINGLE.min_normalized_value.to_fmt
  puts IEEE_SINGLE.max_value.to_fmt
  puts IEEE_SINGLE.epsilon.to_fmt
  puts IEEE_SINGLE.from_value(1).next.to_fmt



==Convert between formats
  v = IEEE_EXTENDED('1.1')
  v = v.convert_to(IEEE_SINGLE)
  

==Tools for the native floating point format (optional)

==Defining new formats

