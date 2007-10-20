require File.dirname(__FILE__) + '/test_helper.rb'
require 'yaml'

require 'test/unit'

include FltPnt

class TestNativeFloat < Test::Unit::TestCase
    def test_nextprev
      assert Float::MIN_N.prev==Float::MAX_D
      assert Float::MIN_N==Float::MAX_D.next
      assert Float::MIN_D.prev==0.0
      assert Float::MIN_D==0.0.next

      assert (-Float::MIN_N).next==-Float::MAX_D
      assert -(Float::MIN_N.prev)==-Float::MAX_D
      assert (-Float::MIN_D).next==0.0
      assert (-Float::MIN_D)==0.0.prev


      assert -(1.0.next) == (-1.0).prev
      assert (-1.0).next == -(1.0.prev)
    end
end
