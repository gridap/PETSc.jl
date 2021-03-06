# Application Ordering (AO
# exposes 1-based indexing interface, although there is a zero based interface
# underneath
# this is WIP pending Clang getting AOs right
export AO, map_petsc_to_app!, map_app_to_petsc!
mutable struct AO{T}
  p::C.AO{T}

  function AO(p::C.AO{T}) where {T}
    o = new{T}(p)
    if (!deactivate_finalizers)
      finalizer(PetscDestroy,o)
    end
    return o
  end
end

# zero based, using arrays
function AO_(::Type{T}, app_idx::AbstractArray{PetscInt, 1},
            petsc_idx::AbstractArray{PetscInt, 1}; comm=MPI.COMM_WORLD, basic=true ) where {T}
  ao_ref = Ref{C.AO{T}}()
  if basic  # mapping is one-to-one and onto
    #chk(C.AOCreateBasic(comm, PetscInt(length(app_idx)), app_idx, petsc_idx, ao_ref))
    chk(C.AOCreateMemoryScalable(comm, PetscInt(length(app_idx)), app_idx, petsc_idx, ao_ref))
  else  # worse performance
    chk(C.AOCreateMapping(comm, PetscInt(length(app_idx)), app_idx, petsc_idx, ao_ref))
  end

  return AO(ao_ref[])
end


# zero based, using index sets
# because index sets are already zero based, this function can be exposed
# directly
function AO( app_idx::IS{T}, petsc_idx::IS{T}; basic=true ) where {T}

  ao_ref = Ref{C.AO{T}}()
  if basic  # mapping is one-to-one and onto
    chk(C.AOCreateBasicIS( app_idx.p, petsc_idx.p, ao_ref))
  else  # worse performance
    chk(C.AOCreateMappingIS(app_idx.p, petsc_idx.p, ao_ref))
  end

  return AO(ao_ref[])
end

# one based interface
function AO(::Type{T}, app_idx::AbstractArray{I1, 1},
            petsc_idx::AbstractArray{I2, 1}; comm=MPI.COMM_WORLD, basic=true ) where {T, I1 <: Integer, I2 <: Integer}

  app_idx0 = PetscInt[app_idx[i] - 1 for i=1:length(app_idx)]
  petsc_idx0 = PetscInt[petsc_idx[i] - 1 for i=1:length(petsc_idx)]
  AO_(T, app_idx0, petsc_idx0; comm=comm, basic=basic)
end


function PetscDestroy(ao::AO{T}) where {T}

  if !PetscFinalized(T)
    chk(C.AODestroy(Ref(ao.p)))
    ao.p = C.AO{T}(C_NULL)
  end
end

function isfinalized(ao::AO)
  return isfinalized(ao.p)
end

function isfinalized(ao::C.AO)
  return ao.pobj == C_NULL
end

function petscview(ao::AO{T}) where {T}
  viewer = C.PetscViewer{T}(C_NULL)
  chk(C.VecView(ao.p, viewer))
end


###############################################################################
# functions to apply index changes

function map_petsc_to_app!(ao::AO, idx::AbstractArray)

  # because idx is expected to be modified, here we can decrement in-place
  for i=1:length(idx)
    idx[i] -= 1
  end

  chk(C.AOPetscToApplication(ao.p, PetscInt(length(idx)), idx))

  # increment back to 1-based indices
   for i=1:length(idx)
    idx[i] += 1
   end
end

function map_petsc_to_app!(ao::AO, is::IS)
  chk(C.AOPetscToApplicationIS(ao.p, is.p))
end

function map_app_to_petsc!(ao::AO, idx::AbstractArray)

  # because idx is expected to be modified, here we can decrement in-place
  for i=1:length(idx)
    idx[i] -= 1
  end

  chk(C.AOApplicationToPetsc(ao.p, PetscInt(length(idx)), idx))

  # increment back to 1-based indices
   for i=1:length(idx)
    idx[i] += 1
   end
end

function map_app_to_petsc!(ao::AO, is::IS)
  chk(C.AOApplicationToPetscIS(ao.p, is.p))
end
