import Base: +, -, *, /

macro defonce(expr)
  @assert expr.head == :(=) "defonce expects an assignment expression"
  :(isdefined($__module__, $(QuoteNode(expr.args[1]))) || $(esc(expr)))
end


Vec2f(v::ImVec2) = Vec2f(v.x, v.y)

+(a::ImVec2, b::ImVec2) = ImVec2(a.x + b.x, a.y + b.y)
-(a::ImVec2, b::ImVec2) = ImVec2(a.x - b.x, a.y - b.y)
-(a::ImVec2) = ImVec2(-a.x, -a.y)
*(a::Float32, b::ImVec2) = ImVec2(a * b.x, a * b.y)
/(a::ImVec2, b::Float32) = ImVec2(a.x/b, a.y/b)
