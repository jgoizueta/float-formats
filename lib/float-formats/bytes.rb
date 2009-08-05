# Float-Formats
# Support for binary data representations
require 'nio'
require 'nio/sugar'

require 'enumerator'
require 'delegate'

module Flt

class Bits
  # Define a bit string given the number of bits and
  # optinally the initial value (as an integer).
  def initialize(num_bits,v=0)
    @n = num_bits
    @v = v
  end

  # convert to text representation in a given base
  def to_s(base=2)
    n = Bits.power_of_two(base)
    if n
      fmt = Nio::Fmt.default.base(base,true).mode(:fix,:exact)
      digits = (size+n-1)/n
      fmt.pad0s!(digits)
      @v.nio_write(fmt)
    else
      @v.to_s(base)
    end
  end

  # produce bit string from a text representation
  def self.from_s(txt,base=2,len=nil)
    txt = txt.tr('., _','')
    v = txt.to_i(base)
    if len.nil?
      n = power_of_two(base)
      if n
        len = txt.size * n
      end
    end
    from_i v, len
  end

  # convert to integer
  def to_i
    @v
  end

  # produce bit string from an integer
  def self.from_i(v,len=nil)
    len ||= (Math.log(v)/Math.log(2)).ceil # v.to_s(2).size
    Bits.new(len,v)
  end

  # Access a bit value. The least significant bit has index 0.
  def [](i)
    (@v >> i) & 1
  end

  # Set a bit. The least significant bit has index 0. The bit value
  # can be passed as an integer or a boolean value.
  def []=(i,b)
    b = (b && b!=0) ? 1 : 0
    @v &= ~(1 << i)
    @v |=  (b << i)
    b
  end

  # number of bits
  def size
    @n
  end

  protected

  def self.is_power_of_two?(v)
    if v==0
      false
    else
      v &= (v-1)
      if v==0
        true
      else
        false
      end
    end
  end

  def self.power_of_two(v)
    if is_power_of_two?(v)
      n = 0
      while v!=1
        n += 1
        v >>= 1
      end
      n
    else
      nil
    end
  end

end

class Bytes < DelegateClass(String)

  def initialize(bytes)
    case bytes
      when Bytes
        @bytes = bytes.to_s
      when Array
        @bytes = bytes.pack("C*")
      else
        @bytes = bytes.to_str
    end
    @bytes.force_encoding(Encoding::BINARY) if RUBY_VERSION>="1.9.0"
    super @bytes
  end

  def dup
    Bytes.new @bytes.dup
  end

  if RUBY_VERSION>="1.9.0"
    def size
      bytesize
    end
    alias _get_str []
    alias _set_str []=
    def [](*params)
      if params.size == 1 && !params.first.kind_of?(Range)
        _get_str(params.first).ord # bytes.to_a[params.first]
      else
        Bytes.new(_get_str(*params))
      end
    end
    def []=(i,v)
      _set_str i, v.chr(Encoding::BINARY)
    end
  else
    alias _get_str []
    def [](*params)
      if params.size == 1
        _get_str(params.first)
      else
        Bytes.new(_get_str(*params))
      end
    end
  end

  def +(b)
    Bytes.new(to_str + b.to_str)
  end

  # return an hex representation of a byte string
  def to_hex(sep_bytes=false)
    hx = @bytes.unpack('H*')[0].upcase
    if sep_bytes
      sep = ""
      (0...hx.size).step(2) do |i|
        sep << " " unless i==0
        sep << hx[i,2]
      end
      hx = sep
    end
    hx
  end

  # generate a byte string from an hex representation
  def Bytes.from_hex(hex)
    Bytes.new [hex.tr(' ','')].pack('H*')
  end


  # Reverse the order of the bits in each byte.
  def reverse_byte_bits!
    @bytes = @bytes.unpack('b*').pack("B*")[0]
    __setobj__ @bytes
    self
  end
  def reverse_byte_bits
    dup.reverse_byte_bits!
  end


  # Reverse the order of the nibbles in each byte.
  def reverse_byte_nibbles!
    w = ""
    @bytes.each_byte do |b|
      w << ((b >> 4)|((b&0xF)<<4))
    end
    @bytes = w
    __setobj__ @bytes
    self
  end
  def reverse_byte_nibbles
    dup.reverse_byte_nibbles!
  end

  # reverse the order of bytes in 16-bit words
  def reverse_byte_pairs!
      w = ""
      (0...@bytes.size).step(2) do |i|
        w << @bytes[i+1]
        w << @bytes[i]
      end
      @bytes = w
      __setobj__ @bytes
      self
  end

  def reverse_byte_pairs
    dup.reverse_byte_pairs!
  end

  # Supported endianness modes for byte strings are:
  # [<tt>:little_endian</tt>] (Intel order): least significant bytes come first.
  # [<tt>:big_endian</tt>] (Network order): most significant bytes come first.
  # [<tt>:little_big_endian</tt> or <tt>:middle_endian</tt>] (PDP-11 order): each pair of bytes
  #                                                          (16-bit word) has the bytes in little endian order, but the words
  #                                                          are stored in big endian order (we assume the number of bytes is even).
  # Note that the <tt>:big_little_endian</tt> order which would logically complete the set is
  # not currently supported as it has no known uses.
  def convert_endianness!(from_endianness, to_endianness)
    if from_endianness!=to_endianness
      if ([:little_endian,:big_endian]+[from_endianness, to_endianness]).uniq.size==2
        # no middle_endian order
        reverse!
      else
        # from or to is middle_endian
        if [:middle_endian, :little_big_endian].include?(to_endianness)
          # from little_big_endian
          convert_endianness!(from_endianness, :big_endian).reverse_byte_pairs!
        else
          # from little_big_endian
          reverse_byte_pairs!.convert_endianness!(:big_endian, to_endianness)
        end
      end
    end
    self
  end

  def convert_endianness(from_endianness, to_endianness)
    dup.convert_endianness!(from_endianness, to_endianness)
  end

# Binary data is handled here in three representations:
#  as an Integer
#  as a byte sequence (String) (with specific endianness)
#  an an hex-string (nibble values) (with specific endianness)

  # Convert a byte string to an integer
  def to_i(byte_endianness=:little_endian, bits_little_endian=false)
    i = 0
    bytes = convert_endianness(byte_endianness, :big_endian)
    bytes = bytes.reverse_byte_bits if bits_little_endian
    bytes.each_byte do |b|
      i <<= 8
      i |= b
    end
    i
  end

  # Convert an integer to a byte string
  def Bytes.from_i(i, len=0, byte_endianness=:little_endian, bits_little_endian=false)
    return nil if i<0
    bytes = Bytes.new("")
    while i>0
      b = (i&0xFF)
      bytes << b
      i >>= 8
    end
    bytes << 0 while bytes.size<len
    bytes.reverse_byte_bits! if bits_little_endian
    bytes.convert_endianness!(:little_endian, byte_endianness)
    bytes
  end

  # convert a byte string to separate fixed-width bit-fields as integers
  def to_bitfields(lens,byte_endianness=:little_endian, bits_little_endian=false)
    fields = []
    i = to_i(byte_endianness,bits_little_endian)
    for len in lens
      mask = (1<<len)-1
      fields << (i&mask)
      i >>= len
    end
    fields
  end

  # pack fixed-width bit-fields as integers into a byte string
  def Bytes.from_bitfields(lens,fields,byte_endianness=:little_endian, bits_little_endian=false)
    i = 0
    lens = lens.reverse
    fields = fields.reverse

    bits = 0

    (0...lens.size).each do |j|
      i <<= lens[j]
      i |= fields[j]
      bits += lens[j]
    end
    from_i i,(bits+7)/8,byte_endianness, bits_little_endian
  end

  def bits(byte_endianness=:little_endian, bits_little_endian=false,nbits=nil)
    i = to_i(byte_endianness, bits_little_endian)
    nbits ||= 8*size
    Bits.from_i(i,nbits)
  end

  def Bytes.bits(bits,byte_endianness=:little_endian, bits_little_endian=false,nbits=nil)
    nbits ||= (bits.size+7)/8
    from_i bits.to_i, nbits, byte_endianness, bits_little_endian
  end

end


module_function

# DPD (Densely Packed Decimal) encoding

# The bcd2dpd and dpd2bcd methods are adapted from Mike Cowlishaw's Rexx program:
# (mfc 2000.10.03; Rexx version with new equations 2007.02.01)
# available at http://www2.hursley.ibm.com/decimal/DPDecimal.html

# Negate a bit. Auxiliar method for DPD conversions
def bitnot(b)
  (~b)&1
end

# Compress BCD to Densely Packed Decimal
#
# adapted from Mike Cowlishaw's Rexx program:
#   http://www2.hursley.ibm.com/decimal/DPDecimal.html
def bcd2dpd(arg)
  # assign each bit to a variable, named as in the description
  a,b,c,d,e,f,g,h,i,j,k,m = ("%012B"%arg).split('').collect{|bit| bit.to_i}

  # derive the result bits, using boolean expressions only
  #-- [the operators are: '&'=AND, '|'=OR, '\'=NOT.]
  p=b | (a & j) | (a & f & i)
  q=c | (a & k) | (a & g & i)
  r=d
  s=(f & (bitnot(a) | bitnot(i))) | (bitnot(a) & e & j) | (e & i)
  t=g  | (bitnot(a) & e &k) | (a & i)
  u=h
  v=a | e | i
  w=a | (e & i) | (bitnot(e) & j)
  x=e | (a & i) | (bitnot(a) & k)
  y=m

  # concatenate the bits and return
    # result = [p,q,r,s,t,u,v,w,x,y].collect{|bit| bit.to_s}.inject{|aa,bb|aa+bb}.to_i(2)
    result = 0
    [p,q,r,s,t,u,v,w,x,y].each do |bit|
      result <<= 1
      result |= bit
    end
  result
end

# Expand Densely Packed Decimal to BCD
#
# adapted from Mike Cowlishaw's Rexx program:
#   http://www2.hursley.ibm.com/decimal/DPDecimal.html
def dpd2bcd(arg)

  # assign each bit to a variable, named as in the description
  p,q,r,s,t,u,v,w,x,y = ("%010B"%arg).split('').collect{|bit| bit.to_i}

  # derive the result bits, using boolean expressions only
  a= (v & w) & (bitnot(s) | t | bitnot(x))
  b=p & (bitnot(v) | bitnot(w) | (s & bitnot(t) & x))
  c=q & (bitnot(v) | bitnot(w) | (s & bitnot(t) & x))
  d=r
  e=v & ((bitnot(w) & x) | (bitnot(t) & x) | (s & x))
  f=(s & (bitnot(v) | bitnot(x))) | (p & bitnot(s) & t & v & w & x)
  g=(t & (bitnot(v) | bitnot(x))) | (q & bitnot(s) & t & w)
  h=u
  i=v & ((bitnot(w) & bitnot(x)) | (w & x & (s | t)))
  j=(bitnot(v) & w) | (s & v & bitnot(w) & x) | (p & w & (bitnot(x) | (bitnot(s) & bitnot(t))))
  k=(bitnot(v) & x) | (t & bitnot(w) & x) | (q & v & w & (bitnot(x) | (bitnot(s) & bitnot(t))))
  m=y
  # concatenate the bits and return
  # result = [a,b,c,d,e,f,g,h,i,j,k,m].collect{|bit| bit.to_s}.inject{|aa,bb|aa+bb}.to_i(2)
    result = 0
    [a,b,c,d,e,f,g,h,i,j,k,m].each do |bit|
      result <<= 1
      result |= bit
    end
  result
end

# Pack a bcd digits string into DPD
def hexbcd_to_dpd(bcd, endianness=:big_endian)

  n = bcd.size
  dpd = 0
  dpd_bits = 0

  i = 0
  m = n%3
  if m>0
    v = bcd2dpd(bcd[0,m].to_i(16))
    i += m
    n -= m
    bits = m==1 ? 4 : 7
    dpd_bits += bits
    dpd <<= bits
    dpd |= v
  end

  while n>0
    v = bcd2dpd(bcd[i,3].to_i(16))
    i += 3
    n -= 3
    bits = 10
    dpd_bits += bits
    dpd <<= bits
    dpd |= v
  end

  [dpd, dpd_bits]
end

# Unpack DPD digits
def dpd_to_hexbcd(dpd, dpd_bits, endianness=:big_endian)

  bcd = ""

  while dpd_bits>=10
    v = dpd2bcd(dpd & 0x3FF)
    dpd >>= 10
    dpd_bits -= 10
    bcd = ("%03X"%v)+bcd
  end

  if dpd_bits>0
    case dpd_bits
      when 4
        v = dpd & 0xF
        n = 1
      when 7
        v = dpd & 0x7F
        n = 2
      else
        raise "Invalid DPD data"
    end
    v = dpd2bcd(v,true)
    bcd = ("%0#{n}X"%v)+bcd
  end

  bcd = bcd.reverse if endianness==:little_endian

  bcd

end



end