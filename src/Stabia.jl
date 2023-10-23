# This module is to make the tooling happy and eventually build the application,
# or distribute as a library. For now I mostly start a repl with ./dev.sh and
# then `include("src/stabia.jl")` which loads everything into the Main package,
# which is easier for development, hotloading code by reincluding. Eventually
# I might give Revise.jl a look which might solve this, but this workflow is
# very convenient and portable.

module Stabia

include("stabia.jl")

end
