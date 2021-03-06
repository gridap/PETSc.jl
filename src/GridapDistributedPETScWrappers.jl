module GridapDistributedPETScWrappers

const deactivate_finalizers=true

import MPI
export PetscInt
include(joinpath("generated", "C.jl"))
using .C
include("petsc_com.jl")
include("options.jl")
include("is.jl")

using LinearAlgebra
include("vec.jl")
using SparseArrays
include("mat.jl")

include("vec_scatter.jl")
include("pc.jl")
include("ksp.jl")
include("mapping.jl")
include("ts.jl")
end
