require File.dirname(__FILE__) + '/test_helper.rb'
require 'yaml'

include Flt

def test_bits
  assert_equal 11, Bits.new(11).size
  assert_equal "00000", Bits.new(5).to_s
  assert_equal "011010101010", Bits.from_s("011010101010").to_s
  assert_equal 0b011010101010, Bits.from_s("011010101010").to_i
  assert_equal 0b011010101010, Bits.from_i(0b011010101010).to_i
  assert_equal "011010101010", Bits.from_i(0b011010101010).to_s
  b = Bits.from_s("0111010100110")
  assert_equal 0,b[0]
  assert_equal 1,b[1]
  assert_equal 1,b[2]
  assert_equal 0,b[3]
  assert_equal 0,b[4]
  assert_equal 1,b[5]
  assert_equal 0,b[12]
  assert_equal 0,b[13]
  b[1] = 0
  assert_equal 0,b[0]
  assert_equal 0,b[1]
  assert_equal 1,b[2]
  assert_equal 0,b[3]
  b[1] = 1
  assert_equal 0,b[0]
  assert_equal 1,b[1]
  assert_equal 1,b[2]
  assert_equal 0,b[3]  
end

def test_bytes
  b = Bytes.from_hex("AF237B93")
  assert_equal "AF237B93", b.to_hex
  assert_equal 0xAF237B93, b.to_bits.to_i
  assert_equal 0xAF237B93, b.to_i
  b = Bytes.from_bits(Bits.from_i(0xAF237B93))
  assert_equal "AF237B93", b.to_hex
  assert_equal 0xAF237B93, b.to_bits.to_i
  assert_equal 0xAF237B93, b.to_i    
end
