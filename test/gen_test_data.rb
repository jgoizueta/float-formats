require File.dirname(__FILE__) + '/../lib/float-formats'
require 'yaml'

include FltPnt
include Nio


TVALUES = [
  '+0', '-0', '+1','-1','+0.1','-0.1',
  '0.5','-0.5',
  '29.2','-29.2','0.03125','-0.03125','-0.3125',
  '1.234E2','-1.234E-6','65536.0','-65536.0',
  '-7.50'
]

VALUES = [
  Rational(1,3),
  Rational(1,10),
  Rational(2,3),
  Rational(1,1024),
  Rational(1,1000),
  Rational(1024,1),
  Rational(1024,1)
]

TEST_DATA = {}

def is_power_of_two(n)
  nbits = 0
  while n>0
    nbits += 1 if n&1==1
    n >>= 1
  end
  nbits==1
end

EXCEPTIONS = {
  UNIVAC_DOUBLE=>16,
  UNIVAC_SINGLE=>16,
  SATURN_X=>16
}
def rep_mode(type)
  m = EXCEPTIONS[type]
  if m.nil?
    if type.total_bits % 8 == 0 # is_power_of_two(flt.total_bits)
      m = :bytes
    elsif type.total_bits % 4 == 0
      m  = 16
    elsif type.total_bits % 3 == 0
      m  = 8
    else
      m  = 2
    end
  end
  m
end

%w{IEEE_SINGLE IEEE_DOUBLE IEEE_EXTENDED IEEE_128 XS128 XS256 XS256_DOUBLE
BORLAND48
MBF_SINGLE MBF_DOUBLE 
VAX_F VAX_D VAX_G VAX_H
PDP11_F PDP11_D
SATURN SATURN_X HP_CLASSIC
IEEE_DEC32 IEEE_DEC64 IEEE_DEC128
IBM32 IBM64 IBM128
CRAY
UNIVAC_SINGLE UNIVAC_DOUBLE
CDC_SINGLE CDC_DOUBLE
APPLE
WANG2200
C51_BCD_FLOAT C51_BCD_DOUBLE C51_BCD_LONG_DOUBLE
}.each do |t|
  
  puts t
  flt = eval(t)
  
  base = rep_mode(flt)
  TEST_DATA[t] = {'base'=>base}

print "."

  TEST_DATA[t]['parameters'] = []
  for attrb in [:total_bits, :radix, :significand_digits, :radix_min_exp, :radix_max_exp,
   :decimal_digits_stored, :decimal_digits_necessary,:decimal_min_exp,:decimal_max_exp]
    TEST_DATA[t]['parameters'] << {attrb.to_s=>flt.send(attrb)}
  end
  
print "."
  TEST_DATA[t]['numerals'] = []
  fmt = Fmt.mode(:gen,flt.decimal_digits_necessary)
  #fmt = Fmt.default
  for v in TVALUES + [:min_normalized_value, :max_value, :epsilon, :strict_epsilon].collect{|s| flt.to_fmt(flt.send(s),fmt)}
    val = flt.from_fmt(v)
    rep = base==:bytes ? flt.to_hex(val,true) : flt.to_bits_text(val,base).upcase
    TEST_DATA[t]['numerals'] << {v => rep}
  end

print "."
  TEST_DATA[t]['special'] = []
    [:min_value, :min_normalized_value, :max_value, :epsilon, :strict_epsilon].each do |v|
      val = flt.send(v)
      rep = base==:bytes ? flt.to_hex(val,true) : flt.to_bits_text(val,base).upcase      
      TEST_DATA[t]['special'] << {v.to_s=>rep}
    end

print "."
  TEST_DATA[t]['values'] = []  
  for v in VALUES
      val = flt.from_number(v)
      rep = base==:bytes ? flt.to_hex(val,true) : flt.to_bits_text(val,base).upcase      
      TEST_DATA[t]['values'] << {v.inspect=>rep}
  end
puts ""


end  
  
File.open(File.join(File.dirname(__FILE__),"test_data0.yaml"),"w"){|f| f.write TEST_DATA.to_yaml}
  
