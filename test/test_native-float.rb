require File.dirname(__FILE__) + '/test_helper.rb'
require File.dirname(__FILE__) + '/../lib/float-formats/native.rb'
require 'yaml'

require 'test/unit'

include Flt

class TestNativeFloat < Test::Unit::TestCase
    def test_nextprev
      num_class = Flt.NumClass(Float)
      
      assert num_class.context.minimum_normal.prev==num_class.context.maximum_subnormal
      assert num_class.context.minimum_normal==num_class.context.maximum_subnormal.next
      assert num_class.context.minimum_nonzero.prev==num_class.zero
      assert num_class.context.minimum_nonzero==num_class.zero.next

      assert((-num_class.context.minimum_normal).next==-num_class.context.maximum_subnormal)
      assert(-(num_class.context.minimum_normal.prev)==-num_class.context.maximum_subnormal)
      assert((-num_class.context.minimum_nonzero).next==num_class.zero)
      assert((-num_class.context.minimum_nonzero)==num_class.zero.prev)


      assert(-(Flt.Num(1.0).next) == Flt.Num(-1.0).prev)
      assert(Flt.Num(-1.0).next == -(Flt.Num(1.0).prev))
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
      x = Flt.Num(x)
      assert_equal x-x.prev, x.prev.ulp
      assert_equal x-x.prev, x.ulp
      assert_equal x.next-x, x.next.ulp
      assert_equal x.next.next-x.next, x.next.next.ulp
    end
    
    def test_ulp
      num_class = Flt.NumClass(Float)
      r = num_class.radix
      assert_equal num_class.minimum_nonzero, num_class.zero.ulp
      assert_equal num_class.minimum_nonzero, num_class.minimum_nonzero.ulp
      assert_equal num_class.minimum_nonzero, num_class.minimum_nonzero.next.ulp
      assert_equal num_class.minimum_nonzero, ((num_class.minimum_nonzero+num_class.maximum_subnormal)*0.5).ulp
      assert_equal num_class.minimum_nonzero, num_class.maximum_subnormal.prev.ulp
      assert_equal num_class.minimum_nonzero, num_class.maximum_subnormal.ulp
      assert_equal num_class.minimum_nonzero, num_class.minimum_normal.ulp
      assert_equal num_class.minimum_nonzero, num_class.minimum_normal.next.ulp
      assert_equal num_class.minimum_nonzero, (num_class.minimum_normal*r).prev.ulp
      assert_equal num_class.minimum_nonzero, (num_class.minimum_normal*r).ulp
      assert_equal num_class.minimum_nonzero*r, (num_class.minimum_normal*r).next.ulp
      check_ulp_around 1.0
      assert_equal Flt.Num(1.0).next-1.0, Flt.Num(1.5).ulp
      check_ulp_around r.to_f
      check_ulp_around Math.ldexp(1,10)
      check_ulp_around Math.ldexp(1,-10)
      check_ulp_around num_class.maximum_finite/r
      assert_equal num_class.maximum_finite-num_class.maximum_finite.prev, num_class.maximum_finite.prev.ulp
      assert_equal num_class.maximum_finite-num_class.maximum_finite.prev, num_class.maximum_finite.ulp
      assert_equal num_class.maximum_finite-num_class.maximum_finite.prev, Flt.Num(1.0/0.0).ulp
      assert(Flt.Num(0.0/0.0).ulp.nan?)
      x = Flt.Num(Math.ldexp(1,10))
      assert_equal x-x.prev, x.prev.ulp
    end
    
end
