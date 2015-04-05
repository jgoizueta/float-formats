require File.expand_path(File.join(File.dirname(__FILE__),'test_helper.rb'))
require 'yaml'

include Flt

class TestFloatFormats < Test::Unit::TestCase

  def setup
  end

    def test_nextprev
      for tn in %w{IEEE_SINGLE IEEE_DOUBLE IEEE_EXTENDED IEEE_DEC32 IEEE_DEC64 IEEE_DEC128}
          t = eval(tn)
          z = t.from_text('0')
          assert t.min_value.next_minus==z,"#{tn}: prv min == 0"
          assert z.next_plus==t.min_value,"#{tn}: nxt 0 == min"

          mz = t.from_text('-0')
          assert t.min_value(-1).next_plus==mz,"#{tn}: nxt -min == -0"
          assert mz.next_minus==t.min_value(-1),"#{tn}: prv -0 == -min"

          assert z.next_minus==t.min_value(-1),"#{tn}: prv 0 == -min"
          assert mz.next_plus==t.min_value,"#{tn}: nxt -0 == min"
      end

      for tn in %w{
            APPLE XS128
            BORLAND48
            MBF_SINGLE MBF_DOUBLE
            IEEE_SINGLE IEEE_DOUBLE IEEE_EXTENDED IEEE_128
            IEEE_DEC32 IEEE_DEC64 IEEE_DEC128
            XS256 XS256_DOUBLE
            SATURN SATURN_X HP_CLASSIC
            VAX_F VAX_D PDP11_F PDP11_D VAX_G VAX_H
            IBM32 IBM64 IBM128 IBMX
            CDC_SINGLE CDC_DOUBLE
            CRAY
            UNIVAC_SINGLE UNIVAC_DOUBLE
            WANG2200
            C51_BCD_FLOAT C51_BCD_DOUBLE C51_BCD_LONG_DOUBLE
            }
        t = eval(tn)
        u = t.from_text('1')
        mu = t.from_text('-1')
        assert u.next_plus.minus == mu.next_minus,"#{tn}: -nxt 1 == prv -1"
        assert mu.next_plus == u.next_minus.minus,"#{tn}: nxt -1 == -prv 1"

      end

    end

  TEST_DATA = YAML.load(File.read(File.join(File.dirname(__FILE__),'test_data.yaml')))


  def test_all

    TEST_DATA.keys.each do |t|

        flt = eval(t)

        base = TEST_DATA[t]['base']

      td = TEST_DATA[t]['parameters']

      #puts "def test_#{t}_parameters"
        for pair in td
          attrb,v = pair.to_a.first
          #puts "  assert_equal #{v}, #{t}.#{attrb}"
          assert_equal v, flt.send(attrb), "#{t}.#{attrb} == #{v}"
        end
      #puts "end"


      td = TEST_DATA[t]['numerals']
      #puts "def test_#{t}_numerals"
        for pair in td
          v,rep = pair.to_a.first
          # v_expr = "#{t}.from_text('#{v}', :free, exact_input: false)"
          v_expr = "#{t}.from_text('#{v}')"

          expr = base==:bytes ? "(#{v_expr}).to_hex(true)" : "(#{v_expr}).to_bits_text(#{base}).upcase"
          #puts "  assert_equal '#{rep}', #{expr}"
          assert_equal rep, eval(expr), "#{expr} == '#{rep}'"
          #puts "---"
        end
      #puts "end"


      td = TEST_DATA[t]['special']
      #puts "def test_#{t}_special"
        for pair in td
          v,rep = pair.to_a.first
          #next if v=='epsilon'
          v_expr = "#{t}.#{v}"
          expr = base==:bytes ? "(#{v_expr}).to_hex(true)" : "(#{v_expr}).to_bits_text(#{base}).upcase"
          assert_equal rep, eval(expr), "#{expr} == '#{rep}'"
        end
      #puts "end"


      td = TEST_DATA[t]['values']
      #puts "def test_#{t}_values"
        for pair in td
          v,rep = pair.to_a.first
          v_expr = "#{t}.from_number(#{v})"
          expr = base==:bytes ? "(#{v_expr}).to_hex(true)" : "(#{v_expr}).to_bits_text(#{base}).upcase"
          assert_equal rep, eval(expr), "#{expr} == '#{rep}'"
        end
      #puts "end"


    end

  end



  def test_hp71b
    assert_equal(-499, HP71B.radix_min_exp)
    assert_equal(499, HP71B.radix_max_exp)

    fmt = Numerals::Format[precision: 12, symbols: [uppercase: true]]
    assert_equal  '9.99999999999E499', HP71B.max_value.to_text(fmt)
    assert_equal '0000000000001501', HP71B.min_value.to_bits_text(16)
    assert_equal '1.0E-510', HP71B.min_value.to_text(fmt)
    assert_equal '1.00000000000E-499', HP71B.min_normalized_value.to_text(fmt)

    assert_equal '9210000000000999',HP71B.from_text('-0.21').to_bits_text(16)
    assert_equal '0100000000000001',HP71B.from_text('10').to_bits_text(16)
    assert_equal '9000000000000000',HP71B.from_text('-0').to_bits_text(16)
    assert_equal '0000510000000501', HP71B.from_text('0.0051E-499').to_bits_text(16)

    assert_equal '0000000000000F01',HP71B.nan.to_bits_text(16).upcase
    assert_equal 'NAN', HP71B.nan.to_text.upcase
    assert_equal '0000000000000F00', HP71B.infinity.to_bits_text(16).upcase
    assert_equal '+INFINITY', HP71B.infinity.to_text.upcase
    assert_equal '9000000000000F00', HP71B.infinity.minus.to_bits_text(16).upcase
  end
  def test_quad
    assert_equal "3fff 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.from_text('1').to_hex.downcase
    assert_equal "7ffe ffff ffff ffff ffff ffff ffff ffff".tr(' ',''), IEEE_binary128_BE.max_value.to_hex.downcase
    assert_equal '1.190e4932', IEEE_binary128.max_value.to_text(Numerals::Format[precision: 4])
    assert_equal "c000 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.from_text('-2').to_hex.downcase
    assert_equal "0000 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.from_text('0').to_hex.downcase
    assert_equal "8000 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.from_text('-0').to_hex.downcase
    assert_equal "7fff 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.infinity.to_hex.downcase
    assert_equal "ffff 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.infinity(-1).to_hex.downcase
    assert_equal "3ffd 5555 5555 5555 5555 5555 5555 5555".tr(' ',''), IEEE_binary128_BE.from_number(Rational(1,3)).to_hex.downcase
    assert_equal "3fff 0000 0000 0000 0000 0000 0000 0001".tr(' ',''), IEEE_binary128_BE.from_text('1').next_plus.to_hex.downcase
  end
  def test_half
    assert_equal "3c00", IEEE_binary16_BE.from_text('1').to_hex.downcase
    assert_equal "7bff", IEEE_binary16_BE.max_value.to_hex.downcase
    assert_equal '65504', IEEE_binary16_BE.max_value.to_text(Numerals::Format[:exact_input])
    assert_equal "0400", IEEE_binary16_BE.min_normalized_value.to_hex.downcase
    assert_equal "6.103515625e-5", IEEE_binary16_BE.min_normalized_value.to_text(Numerals::Format[:sci, :exact_input])
    assert_equal "0001", IEEE_binary16_BE.min_value.to_hex.downcase
    assert_equal "5.9604644775390625e-8", IEEE_binary16_BE.min_value.to_text(Numerals::Format[:sci, :exact_input])
    assert_equal "0000", IEEE_binary16_BE.from_text('0').to_hex.downcase
    assert_equal "8000", IEEE_binary16_BE.from_text('-0').to_hex.downcase
    assert_equal "7c00".tr(' ',''), IEEE_binary16_BE.infinity.to_hex.downcase
    assert_equal "fc00".tr(' ',''), IEEE_binary16_BE.infinity(-1).to_hex.downcase
  end
  def test_special
    assert_equal '+Infinity', IEEE_binary32.from_number(1.0/0.0).to_text
    assert_equal '-Infinity', IEEE_binary32.from_number(-1.0/0.0).to_text
    assert_equal '+Infinity', IEEE_binary32.from_text('+Infinity').to_text
    assert_equal '-Infinity', IEEE_binary32.from_text('-Infinity').to_text
    assert_equal 'NAN', IEEE_binary32.from_number(0.0/0.0).to_text.upcase
    assert_equal 'NAN', IEEE_binary32.from_text('NaN').to_text.upcase
  end

  def test_double_double

    assert_equal 128, IEEE_DOUBLE_DOUBLE.total_bits
    assert_equal 16, IEEE_DOUBLE_DOUBLE.total_bytes
    assert_equal 107, IEEE_DOUBLE_DOUBLE.significand_digits
    assert_equal 31, IEEE_DOUBLE_DOUBLE.decimal_digits_stored
    assert_equal 34, IEEE_DOUBLE_DOUBLE.decimal_digits_necessary
    assert_equal 308, IEEE_DOUBLE_DOUBLE.decimal_max_exp
    assert_equal(-307, IEEE_DOUBLE_DOUBLE.decimal_min_exp)
    assert_equal 1023, IEEE_DOUBLE_DOUBLE.radix_max_exp
    assert_equal(-1022, IEEE_DOUBLE_DOUBLE.radix_min_exp)
    fmt = Numerals::Format[:exact_input, precision: 2, symbols:[uppercase: true]]
    assert_equal '1.8E308', IEEE_DOUBLE_DOUBLE.max_value.to_text(fmt)
    assert_equal '2.2E-308', IEEE_DOUBLE_DOUBLE.min_normalized_value.to_text(fmt)
    assert_equal '4.9E-324', IEEE_DOUBLE_DOUBLE.half.min_value.to_text(fmt)

    assert_equal "0.5", IEEE_DOUBLE_DOUBLE('0.5').to_text
    assert_equal "000000000000E03F0000000000000000", IEEE_DOUBLE_DOUBLE('0.5').to_hex
    assert_equal "000000000000E03F0000000000004039", IEEE_DOUBLE_DOUBLE('0.5').next_plus.to_hex
    assert_equal "9A9999999999B93F9A999999999959BC", IEEE_DOUBLE_DOUBLE('0.1').to_hex
    assert_equal "9A9999999999B93F99999999999959BC", IEEE_DOUBLE_DOUBLE('0.1').next_plus.to_hex

    assert_equal IEEE_DOUBLE_DOUBLE('0.5'), IEEE_DOUBLE_DOUBLE.join_halfs(*IEEE_DOUBLE_DOUBLE('0.5').split_halfs)
    assert_equal IEEE_DOUBLE_DOUBLE('0.5').next_plus, IEEE_DOUBLE_DOUBLE.join_halfs(*IEEE_DOUBLE_DOUBLE('0.5').next_plus.split_halfs)
    assert_equal IEEE_DOUBLE_DOUBLE('0.1'), IEEE_DOUBLE_DOUBLE.join_halfs(*IEEE_DOUBLE_DOUBLE('0.1').split_halfs)
    assert_equal IEEE_DOUBLE_DOUBLE('0.1').next_plus, IEEE_DOUBLE_DOUBLE.join_halfs(*IEEE_DOUBLE_DOUBLE('0.1').next_plus.split_halfs)

    assert_equal "00000000000050390000000000000000", IEEE_DOUBLE_DOUBLE.epsilon.to_hex
    assert_equal "000000000000F87F0000000000000000", IEEE_DOUBLE_DOUBLE.nan.to_hex
    assert_equal "NAN", IEEE_DOUBLE_DOUBLE.nan.to_text.upcase
    assert_equal "000000000000F07F0000000000000000", IEEE_DOUBLE_DOUBLE.infinity.to_hex
    assert_equal "+INFINITY", IEEE_DOUBLE_DOUBLE.infinity.to_text.upcase
    assert_equal "00000000000000000000000000000000", IEEE_DOUBLE_DOUBLE.zero.to_hex
    assert_equal "0", IEEE_DOUBLE_DOUBLE.zero.to_text.upcase
  end


end
