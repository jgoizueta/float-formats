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
    
    
    def check_ulp_around(x)
      assert_equal x-x.prev, x.prev.ulp
      assert_equal x-x.prev, x.ulp
      assert_equal x.next-x, x.next.ulp
      assert_equal x.next.next-x.next, x.next.next.ulp
    end
    
    def test_ulp
      r = Float::RADIX
      assert_equal Float::MIN_D, 0.0.ulp
      assert_equal Float::MIN_D, Float::MIN_D.ulp
      assert_equal Float::MIN_D, Float::MIN_D.next.ulp
      assert_equal Float::MIN_D, (0.5*(Float::MIN_D+Float::MAX_D)).ulp
      assert_equal Float::MIN_D, Float::MAX_D.prev.ulp
      assert_equal Float::MIN_D, Float::MAX_D.ulp
      assert_equal Float::MIN_D, Float::MIN_N.ulp
      assert_equal Float::MIN_D, Float::MIN_N.next.ulp
      assert_equal Float::MIN_D, (r*Float::MIN_N).prev.ulp
      assert_equal Float::MIN_D, (r*Float::MIN_N).ulp
      assert_equal r*Float::MIN_D, (r*Float::MIN_N).next.ulp
      check_ulp_around 1.0
      assert_equal 1.0.next-1.0, 1.5.ulp
      check_ulp_around r.to_f
      check_ulp_around Math.ldexp(1,10)
      check_ulp_around Math.ldexp(1,-10)
      check_ulp_around Float::MAX/r
      assert_equal Float::MAX-Float::MAX.prev, Float::MAX.prev.ulp
      assert_equal Float::MAX-Float::MAX.prev, Float::MAX.ulp
      assert_equal Float::MAX-Float::MAX.prev, (1.0/0.0).ulp
      assert((0.0/0.0).ulp.nan?)
      assert_equal Math.ldexp(1,10)-Math.ldexp(1,10).prev, Math.ldexp(1,10).prev.ulp
    end
    
end
