require File.dirname(__FILE__) + '/test_helper.rb'

include Flt

class TestArithmetic < Test::Unit::TestCase

  def setup
    @all_types = Flt.constants.map{|c| Flt.class_eval(c.to_s)}.select{|c| c.ancestors.include?(Flt::FormatBase)&& !(c.to_s.downcase.include?('format'))}
  end

  def test_precision
      @all_types.each do |t|
        one = t.new('1')
        three = t.new('3')
        four = t.new('4')
        nine = t.new('9')
        ten = t.new('10')

        x = one - (four/three - one)*three

        check = t.splitted(x.sign,1,1-t.significand_digits)

        assert x==check, "#{t}: 1-(4/3-1)*3 = +/-#{t.radix}^#{1-t.significand_digits}"

      end
  end

  def test_epsilon
      @all_types.each do |t|
        one = t.number(1)
        assert((one + t.strict_epsilon)==one.next, "#{t}: 1+epsilon=1.next")
        assert((one.next - one) == t.epsilon, "#{t}: 1.next-1=epsilon")
      end
  end

end
