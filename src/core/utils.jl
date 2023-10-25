
@inline zpad(i::Int, ndigits::Int)::String =
  lpad(i, ndigits, "0")
