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
          assert t.next_float(t.min_value(1))==mz,"#{tn}: nxt -min == -0"
          assert t.prev_float(mz)==t.min_value(1),"#{tn}: prv -0 == -min"

          assert t.prev_float(z)==t.min_value(1),"#{tn}: prv 0 == -min"
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
end