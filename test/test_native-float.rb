require File.expand_path(File.join(File.dirname(__FILE__),'test_helper.rb'))
require File.dirname(__FILE__) + '/../lib/float-formats/native.rb'
require 'yaml'

require 'test/unit'

include Flt

class TestNativeFloat < Test::Unit::TestCase
    def test_nextprev
      num_class = Float
      context = num_class.context

      assert context.next_minus(context.minimum_normal)==context.maximum_subnormal
      assert context.minimum_normal==context.next_plus(context.maximum_subnormal)
      assert context.next_minus(context.minimum_nonzero)==context.zero
      assert context.minimum_nonzero==context.next_plus(context.zero)

      assert(context.next_plus(-context.minimum_normal)==-context.maximum_subnormal)
      assert(-context.next_minus(context.minimum_normal)==-context.maximum_subnormal)
      assert(context.next_plus(-context.minimum_nonzero)==context.zero)
      assert((-context.minimum_nonzero)==context.next_minus(context.zero))


      assert(-(context.next_plus(1.0)) == context.next_minus(-1.0))
      assert(context.next_plus(-1.0) == -(context.next_minus(1.0)))
    end

    def test_hex
      if Float::RADIX==2 && Float::MANT_DIG==53
        assert_equal((1.0+Float::EPSILON),hex_to_float('0x1.0000000000001p0'))
        assert_equal '0x1.0000000000001p0', hex_from_float(1.0+Float::EPSILON)
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
      context = Float.context
      assert_equal x-context.next_minus(x), context.ulp(context.next_minus(x))
      assert_equal x-context.next_minus(x), context.ulp(x)
      assert_equal context.next_plus(x)-x, context.ulp(context.next_plus(x))
      assert_equal context.next_plus(context.next_plus(x))-context.next_plus(x), context.ulp(context.next_plus(context.next_plus(x)))
    end

    def test_ulp
      num_class = Float
      context = num_class.context
      r = context.radix
      assert_equal context.minimum_nonzero, context.ulp(context.zero)
      assert_equal context.minimum_nonzero, context.ulp(context.minimum_nonzero)
      assert_equal context.minimum_nonzero, context.ulp(context.next_plus(context.minimum_nonzero))
      assert_equal context.minimum_nonzero, context.ulp((context.minimum_nonzero+context.maximum_subnormal)*0.5)
      assert_equal context.minimum_nonzero, context.ulp(context.next_minus(context.maximum_subnormal))
      assert_equal context.minimum_nonzero, context.ulp(context.maximum_subnormal)
      assert_equal context.minimum_nonzero, context.ulp(context.minimum_normal)
      assert_equal context.minimum_nonzero, context.ulp(context.next_plus(context.minimum_normal))
      assert_equal context.minimum_nonzero, context.ulp(context.next_minus(context.minimum_normal*r))
      assert_equal context.minimum_nonzero, context.ulp(context.minimum_normal*r)
      assert_equal context.minimum_nonzero*r, context.ulp(context.next_plus((context.minimum_normal*r)))
      check_ulp_around 1.0
      assert_equal context.next_plus(1.0)-1.0, context.ulp(1.5)
      check_ulp_around r.to_f
      check_ulp_around Math.ldexp(1,10)
      check_ulp_around Math.ldexp(1,-10)
      check_ulp_around context.maximum_finite/r
      assert_equal context.maximum_finite-context.next_minus(context.maximum_finite), context.ulp(context.next_minus(context.maximum_finite))
      assert_equal context.maximum_finite-context.next_minus(context.maximum_finite), context.ulp(context.maximum_finite)
      assert_equal context.maximum_finite-context.next_minus(context.maximum_finite), context.ulp(1.0/0.0)
      assert(context.nan?(context.ulp(0.0/0.0)))
      x = Math.ldexp(1,10)
      assert_equal x-context.next_minus(x), context.ulp(context.next_minus(x))
    end

end
