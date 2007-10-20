# Float-Formats
# Support for binary data representations

require 'nio'
require 'nio/sugar'

require 'enumerator'

module FltPnt

# return an hex representation of a byte string
def bytes_to_hex(sgl,sep_bytes=false)
  hx = sgl.unpack('H*')[0].upcase
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
def hex_to_bytes(hex)  
  [hex.tr(' ','')].pack('H*')
end
  
# ===== Byte string manipulation ==========================================================

# ===== Byte string manipulation ==========================================================

def reverse_byte_bits(b)
  b.chr.unpack('b*').pack("B*")[0]
end
def reverse_byte_nibbles(v)
  if v.kind_of?(String)
    # ... reverse each byte
    w = ""
    v.each_byte do |b|
      w << ((b >> 4)|((b&0xF)<<4))
    end
    v = w
  else
    # assume one byte
    # from_hex(to_hex(v).reverse)
    v = (v >> 4)|((v&0xF)<<4)
  end
  v
end
# reverse bytes in 16-bit words
def reverse_byte_pairs(b)
    w = ""
    (0...b.size).step(2) do |i|
      w << b[i+1]
      w << b[i]
    end
    w  
end
    
# supported endianness modes for byte strings are:
# :little_endian (Intel order): least significant bytes come first.
# :big_endian (Network order): most significant bytes come first.
# :little_big_endian or :middle_endian (PDP-11 order): each pair of bytes
# (16-bit word) has the bytes in little endian order, but the words
# are stored in big endian order (we assume the number of bytes is even).
# :big_little_endian order which would logically complete the set is
# not currently supported as it has no known uses.
def convert_endianness(byte_str, from_endianness, to_endianness)
  if from_endianness!=to_endianness
    if ([:little_endian,:big_endian]+[from_endianness, to_endianness]).uniq.size==2
      # no middle_endian order
      byte_str = byte_str.reverse
    else
      # from or to is middle_endian
      if [:middle_endian, :little_big_endian].include?(to_endianness)
        # from little_big_endian
        byte_str = convert_endianness(byte_str, from_endianness, :big_endian)
        byte_str = reverse_byte_pairs(byte_str)
        # now swap the byte pairs            
      else
        # from little_big_endian
        byte_str = reverse_byte_pairs(byte_str)
        byte_str = convert_endianness(byte_str, :big_endian, to_endianness)      
      end        
    end
  end
  byte_str
end

# Binary data is handled here in three representations:
#  as an Integer
#  as a byte sequence (String) (with specific endianness)
#  an an hex-string (nibble values) (with specific endianness)

def bytes_to_int(bytes, byte_endianness=:little_endian, bits_little_endian=false)
  i = 0
  bytes = convert_endianness(bytes, byte_endianness, :big_endian)
  bytes.each_byte do |b|
    # reverse b is bits_little_endian
    if bits_little_endian
      b = reverse_byte_bits(b)
    end    
    i <<= 8
    i |= b
  end
  i
end

def int_to_bytes(i, len=0, byte_endianness=:little_endian, bits_little_endian=false)
  return nil if i<0
  bytes = ""
  while i>0
    b = (i&0xFF)
    if bits_little_endian
      b = reverse_byte_bits(b)
    end    
    #puts "i=#{i} b<<#{b}"
    bytes << b
    i >>= 8
  end
  bytes << 0 while bytes.size<len
  bytes = convert_endianness(bytes, :little_endian, byte_endianness)  
  bytes
end

# conversion between byte string and separate fixed-widht fields as integers

def get_bitfields(bytes,lens,byte_endianness=:little_endian, bits_little_endian=false)
  fields = []
  i = bytes_to_int(bytes,byte_endianness,bits_little_endian)
  for len in lens
    mask = (1<<len)-1    
    fields << (i&mask)
    i >>= len
  end
  fields
end

def set_bitfields(lens,fields,byte_endianness=:little_endian, bits_little_endian=false)
  i = 0
  lens = lens.reverse
  fields = fields.reverse
  
  bits = 0
        
  (0...lens.size).each do |j|
    i <<= lens[j]
    i |= fields[j]    
    bits += lens[j]
  end  
  int_to_bytes i,(bits+7)/8,byte_endianness, bits_little_endian
end

# DPD (Densely Packed Decimal) encoding

# The bcd2dpd and dpd2bcd methods are adapted from Mike Cowlishaw's Rexx program:
# (mfc 2000.10.03; Rexx version with new equations 2007.02.01)
# available at http://www2.hursley.ibm.com/decimal/DPDecimal.html

def bitnot(b)
  (~b)&1
end

# bcd2dpd -- Compress BCD to Densely Packed Decimal
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

# dpd2bcd -- Expand Densely Packed Decimal to BCD
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