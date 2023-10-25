
macro defonce(expr)
  @assert expr.head == :(=) "defonce expects an assignment expression"
  :(isdefined($__module__, $(QuoteNode(expr.args[1]))) || $(esc(expr)))
end

