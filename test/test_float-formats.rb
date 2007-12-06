require File.dirname(__FILE__) + '/test_helper.rb'
require 'yaml'

include FltPnt

class TestFloatFormats < Test::Unit::TestCase

  def setup
  end
  
    def test_nextprev
      for tn in %w{IEEE_SINGLE IEEE_DOUBLE IEEE_EXTENDED IEEE_DEC32 IEEE_DEC64 IEEE_DEC128}
          t = eval(tn)
          z = t.from_fmt('0')
          assert t.prev_float(t.min_value)==z,"#{tn}: prv min == 0"
          assert t.next_float(z)==t.min_value,"#{tn}: nxt 0 == min"

          mz = t.from_fmt('-0')
          assert t.next_float(t.min_value(-1))==mz,"#{tn}: nxt -min == -0"
          assert t.prev_float(mz)==t.min_value(-1),"#{tn}: prv -0 == -min"

          assert t.prev_float(z)==t.min_value(-1),"#{tn}: prv 0 == -min"
          assert t.next_float(mz)==t.min_value,"#{tn}: nxt -0 == min"
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
        u = t.from_fmt('1')
        mu = t.from_fmt('-1')
        assert t.neg(t.next_float(u)) == t.prev_float(mu),"#{tn}: -nxt 1 == prv -1"
        assert t.next_float(mu) == t.neg(t.prev_float(u)),"#{tn}: nxt -1 == -prv 1"
         
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
          v_expr = "#{t}.from_fmt('#{v}')"
          expr = base==:bytes ? "#{t}.to_hex(#{v_expr},true)" : "#{t}.to_bits_text(#{v_expr},#{base}).upcase"
          #puts "  assert_equal '#{rep}', #{expr}"
          assert_equal rep, eval(expr), "#{expr} == '#{rep}'"
        end
      #puts "end"


      td = TEST_DATA[t]['special']
      #puts "def test_#{t}_special"
        for pair in td
          v,rep = pair.to_a.first            
          #next if v=='epsilon'
          v_expr = "#{t}.#{v}"
          expr = base==:bytes ? "#{t}.to_hex(#{v_expr},true)" : "#{t}.to_bits_text(#{v_expr},#{base}).upcase"
          assert_equal rep, eval(expr), "#{expr} == '#{rep}'"
        end
      #puts "end"
        

      td = TEST_DATA[t]['values']
      #puts "def test_#{t}_values"
        for pair in td
          v,rep = pair.to_a.first      
          v_expr = "#{t}.from_number(#{v})"
          expr = base==:bytes ? "#{t}.to_hex(#{v_expr},true)" : "#{t}.to_bits_text(#{v_expr},#{base}).upcase"
          assert_equal rep, eval(expr), "#{expr} == '#{rep}'"
        end
      #puts "end"


    end  
      
  end 

  def test_hp71b
    assert_equal(-499, HP71B.radix_min_exp)
    assert_equal(499, HP71B.radix_max_exp)

    fmt = Nio::Fmt.prec(12)
    assert_equal  '9.99999999999E499', HP71B.max_value.to_fmt(fmt)
    assert_equal '0000000000001501', HP71B.min_value.to_bits_text(16)
    assert_equal '1E-510', HP71B.min_value.to_fmt(fmt)
    assert_equal '1E-499', HP71B.min_normalized_value.to_fmt(fmt)

    assert_equal '9210000000000999',HP71B.from_fmt('-0.21').to_bits_text(16)
    assert_equal '0100000000000001',HP71B.from_fmt('10').to_bits_text(16)
    assert_equal '9000000000000000',HP71B.from_fmt('-0').to_bits_text(16)
    assert_equal '0000510000000501', HP71B.from_fmt('0.0051E-499').to_bits_text(16)

    assert_equal '0000000000000F01',HP71B.nan.to_bits_text(16).upcase
    assert_equal 'NAN', HP71B.nan.to_fmt.upcase
    assert_equal '0000000000000F00', HP71B.infinity.to_bits_text(16).upcase
    assert_equal '+INFINITY', HP71B.infinity.to_fmt.upcase
    assert_equal '9000000000000F00', HP71B.infinity.neg.to_bits_text(16).upcase
  end
  def test_quad
    assert_equal "3fff 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.from_fmt('1').to_hex.downcase
    assert_equal "7ffe ffff ffff ffff ffff ffff ffff ffff".tr(' ',''), IEEE_binary128_BE.max_value.to_hex.downcase
    assert_equal '1.19E4932', IEEE_binary128.max_value.to_fmt(Nio::Fmt.prec(4))
    assert_equal "c000 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.from_fmt('-2').to_hex.downcase
    assert_equal "0000 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.from_fmt('0').to_hex.downcase
    assert_equal "8000 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.from_fmt('-0').to_hex.downcase
    assert_equal "7fff 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.infinity.to_hex.downcase
    assert_equal "ffff 0000 0000 0000 0000 0000 0000 0000".tr(' ',''), IEEE_binary128_BE.infinity(-1).to_hex.downcase
    assert_equal "3ffd 5555 5555 5555 5555 5555 5555 5555".tr(' ',''), IEEE_binary128_BE.from_number(Rational(1,3)).to_hex.downcase
    assert_equal "3fff 0000 0000 0000 0000 0000 0000 0001".tr(' ',''), IEEE_binary128_BE.from_fmt('1').next.to_hex.downcase    
  end
  def test_half
    assert_equal "3c00", IEEE_binary16_BE.from_fmt('1').to_hex.downcase
    assert_equal "7bff", IEEE_binary16_BE.max_value.to_hex.downcase
    assert_equal '65504', IEEE_binary16_BE.max_value.to_fmt
    assert_equal "0400", IEEE_binary16_BE.min_normalized_value.to_hex.downcase
    assert_equal "6.103515625E-5", IEEE_binary16_BE.min_normalized_value.to_fmt
    assert_equal "0001", IEEE_binary16_BE.min_value.to_hex.downcase
    assert_equal "5.9604644775390625E-8", IEEE_binary16_BE.min_value.to_fmt
    assert_equal "0000", IEEE_binary16_BE.from_fmt('0').to_hex.downcase
    assert_equal "8000", IEEE_binary16_BE.from_fmt('-0').to_hex.downcase
    assert_equal "7c00".tr(' ',''), IEEE_binary16_BE.infinity.to_hex.downcase
    assert_equal "fc00".tr(' ',''), IEEE_binary16_BE.infinity(-1).to_hex.downcase
  end
  def test_special
    assert_equal '+Infinity', IEEE_binary32.from_number(1.0/0.0).to_fmt 
    assert_equal '-Infinity', IEEE_binary32.from_number(-1.0/0.0).to_fmt 
    assert_equal '+Infinity', IEEE_binary32.from_fmt('+Infinity').to_fmt 
    assert_equal '-Infinity', IEEE_binary32.from_fmt('-Infinity').to_fmt 
    assert_equal 'NAN', IEEE_binary32.from_number(0.0/0.0).to_fmt.upcase
    assert_equal 'NAN', IEEE_binary32.from_fmt('NaN').to_fmt.upcase
  end
  

end
