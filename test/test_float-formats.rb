require File.dirname(__FILE__) + '/test_helper.rb'
require 'yaml'

include FltPnt

class TestFloatFormats < Test::Unit::TestCase

  def setup
  end
  
    def test_nextprev
      for tn in %w{IEEE_SINGLE IEEE_DOUBLE IEEE_EXTENDED IEEE_DEC32 IEEE_DEC64 IEEE_DEC128}
          t = eval(tn)
          z = t.text('0')
          assert t.min_value.prev==z,"#{tn}: prv min == 0"
          assert z.next==t.min_value,"#{tn}: nxt 0 == min"

          mz = t.text('-0')
          assert t.min_value(-1).next==mz,"#{tn}: nxt -min == -0"
          assert mz.prev==t.min_value(-1),"#{tn}: prv -0 == -min"

          assert z.prev==t.min_value(-1),"#{tn}: prv 0 == -min"
          assert mz.next==t.min_value,"#{tn}: nxt -0 == min"
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
        u = t.text('1')
        mu = t.text('-1')
        assert u.next.neg == mu.prev,"#{tn}: -nxt 1 == prv -1"
        assert mu.next == u.prev.neg,"#{tn}: nxt -1 == -prv 1"
         
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
          v_expr = "#{t}.text('#{v}')"
          expr = base==:bytes ? "(#{v_expr}).as_hex(true)" : "(#{v_expr}).as_bits_text(#{base}).upcase"
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
          expr = base==:bytes ? "(#{v_expr}).as_hex(true)" : "(#{v_expr}).as_bits_text(#{base}).upcase"
          assert_equal rep, eval(expr), "#{expr} == '#{rep}'"
        end
      #puts "end"
        

      td = TEST_DATA[t]['values']
      #puts "def test_#{t}_values"
        for pair in td
          v,rep = pair.to_a.first      
          v_expr = "#{t}.number(#{v})"
          expr = base==:bytes ? "(#{v_expr}).as_hex(true)" : "(#{v_expr}).as_bits_text(#{base}).upcase"
          assert_equal rep, eval(expr), "#{expr} == '#{rep}'"
        end
      #puts "end"


    end  
      
  end 


end
