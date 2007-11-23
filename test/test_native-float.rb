require File.dirname(__FILE__) + '/test_helper.rb'
require File.dirname(__FILE__) + '/../lib/float-formats/native.rb'
require 'yaml'

require 'test/unit'

include FltPnt

class TestNativeFloat < Test::Unit::TestCase
    def test_nextprev
      assert Float::MIN_N.prev==Float::MAX_D
      assert Float::MIN_N==Float::MAX_D.next
      assert Float::MIN_D.prev==0.0
      assert Float::MIN_D==0.0.next

      assert((-Float::MIN_N).next==-Float::MAX_D)
      assert(-(Float::MIN_N.prev)==-Float::MAX_D)
      assert((-Float::MIN_D).next==0.0)
      assert((-Float::MIN_D)==0.0.prev)


      assert(-(1.0.next) == (-1.0).prev)
      assert((-1.0).next == -(1.0.prev))
    end
    
    def test_hex
      if Float::RADIX==2 && Float::MANT_DIG==53
        assert_equal((1.0+Float::EPSILON),hex_to_float('0x1.0000000000001p0'))
        assert_equal '0x10000000000001p-52', hex_from_float(1.0+Float::EPSILON)
      end
      assert_equal 1.0, hex_to_float(hex_from_float(1.0))
      assert_equal(-1.0, hex_to_float(hex_from_float(-1.0)))
      assert_equal 1.0e-5, hex_to_float(hex_from_float(1.0e-5))
      assert_equal(-1.0e-5, hex_to_float(hex_from_float(-1.0e-5)))
      
      assert_equal(+1,float_to_integral_sign_significand_exponent(+0.0).first)
      assert_equal(-1,float_to_integral_sign_significand_exponent(-0.0).first)
      assert_not_equal hex_from_float(-0.0), hex_from_float(+0.0)
      assert_equal hex_to_float(hex_from_float(-0.0)), hex_to_float(hex_from_float(+0.0))
      
    end
    
end
