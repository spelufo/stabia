

write_tom(f::IOStream, V::Array{Float32, 4}) = begin
  write(f, UInt16(size(V, 2)))
  write(f, UInt16(size(V, 3)))
  write(f, UInt16(size(V, 4)))
  # virtual-unfolding additions (see virtual-unfolding/docs/tom.md)
  seek(f, 320)
  write(f, "float32")
  seek(f, 330)
  write(f, "NumEl")
  write(f, UInt8(size(V, 1)))
  # seek(f, 336)
  # write(f, "Null")
  # write(f, 0x00)

  # data
  seek(f, 512)
  write(f, V)
end

write_tom(f::IOStream, V::Array{Float32, 3}) = begin
  write(f, UInt16(size(V, 1)))
  write(f, UInt16(size(V, 2)))
  write(f, UInt16(size(V, 3)))
  # virtual-unfolding additions (see virtual-unfolding/docs/tom.md)
  seek(f, 320)
  write(f, "float32")
  # seek(f, 330)
  # write(f, "NumEl")
  # write(f, 0x01)
  # seek(f, 336)
  # write(f, "Null")
  # write(f, 0x00)

  # data
  seek(f, 512)
  write(f, V)
end

write_tom(f::IOStream, V::Array{UInt8, 3}) = begin
  # header
  write(f, UInt16(size(V, 1)))
  write(f, UInt16(size(V, 2)))
  write(f, UInt16(size(V, 3)))
  # write(f, UInt16(lmarg))
  # write(f, UInt16(rmarg))
  # write(f, UInt16(tmarg))
  # write(f, UInt16(bmarg))
  # write(f, UInt16(tzmarg))
  # write(f, UInt16(bzmarg))
  # write(f, UInt16(num_samples))
  # write(f, UInt16(num_proj))
  # write(f, UInt16(num_blocks))
  # write(f, UInt16(num_slices))
  # write(f, UInt16(bin))
  # write(f, UInt16(gain))
  # write(f, UInt16(speed))
  # write(f, UInt16(pepper))
  # write(f, UInt16(calibrationissue))
  # write(f, UInt16(num_frames))
  # write(f, UInt16(machine))
  # for _ = 1:12  write(f, UInt16(0x00))
  # write(f, Float32(scale)
  # write(f, Float32(offset)
  # write(f, Float32(voltage)
  # write(f, Float32(current)
  # write(f, Float32(thickness)
  # write(f, Float32(pixel_size)
  # write(f, Float32(distance)
  # write(f, Float32(exposure)
  # write(f, Float32(mag_factor)
  # write(f, Float32(filterb)
  # write(f, Float32(correction_factor)
  # write(f, Float32(0x00)
  # write(f, Float32(0x00)
  # write(f, UInt32(z_shift))
  # write(f, UInt32(z))
  # write(f, UInt32(theta))
  # char time[26]
  # char duration[12]
  # char owner[21]
  # char user[5]
  # char specimen[32]
  # char scan[32]
  # char comment[64]
  # char spare_char[192]

  # virtual-unfolding additions (see virtual-unfolding/docs/tom.md)
  seek(f, 320)
  write(f, "uint8")
  # seek(f, 330)
  # write(f, "NumEl")
  # write(f, 0x01)
  # seek(f, 336)
  # write(f, "Null")
  # write(f, 0x00)

  # data
  seek(f, 512)
  write(f, V)
end


for T in (UInt8, UInt32, Int32, Float32)
  for n in (3, 4)
    @eval begin
      read_tom_data!(f::IOStream, V::Array{$T, $n}) = begin
        for i = 1:length(V)  V[i] = read(f, $T)  end
        nothing
      end
    end
  end
end

read_tom(f::IOStream) = begin
  # header
  xsize = read(f, UInt16)
  ysize = read(f, UInt16)
  zsize = read(f, UInt16)

  # virtual-unfolding additions (see virtual-unfolding/docs/tom.md)
  seek(f, 320)
  tystr = String(read(f, 8))
  T = UInt8
  if startswith(tystr, "int32")   T = Int32   end
  if startswith(tystr, "uint32")  T = UInt32  end
  if startswith(tystr, "float32") T = Float32 end
  seek(f, 330 + length("NumEl"))
  numel = read(f, UInt8)
  seek(f, 336 + length("Null"))
  nulls = read(f, UInt8) > 0

  # data
  seek(f, 512)
  if numel > 1
    V = zeros(T, numel, xsize, ysize, zsize)
  else
    V = zeros(T, xsize, ysize, zsize)
  end
  read_tom_data!(f, V)
  V
end


