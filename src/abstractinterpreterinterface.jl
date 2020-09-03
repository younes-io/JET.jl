# `AbstractInterpreter` API
# -------------------------

struct TPInterpreter <: AbstractInterpreter
    native::NativeInterpreter
    optimize::Bool
    compress::Bool
    discard_trees::Bool

    # TypeProfiler.jl specific
    # for escaping reporting duplicated cached reports
    id::Symbol
    # for constructing virtual stack frame from cached reports
    current_frame::Ref{InferenceState}
    # keeping reports from frame that always `throw`
    exceptionreports::Vector{Pair{Int,ExceptionReport}}

    istoplevel::Bool
    virtualglobalvartable::Dict{Module,Dict{Symbol,Any}} # maybe we don't need this nested dicts
    filter_native_remarks::Bool
    reports::Vector{InferenceErrorReport}

    function TPInterpreter(world::UInt = get_world_counter();
                           inf_params::InferenceParams = InferenceParams(),
                           opt_params::OptimizationParams = OptimizationParams(;
                               inlining = false,
                           ),
                           optimize::Bool = true,
                           compress::Bool = false,
                           discard_trees::Bool = false,
                           istoplevel::Bool = false,
                           virtualglobalvartable::AbstractDict = Dict(),
                           filter_native_remarks::Bool = true,
                           )
        @assert !opt_params.inlining "inlining should be disabled"

        native = NativeInterpreter(world; inf_params, opt_params)
        id     = gensym(:TPInterpreterID)
        return new(native,
                   optimize,
                   compress,
                   discard_trees,
                   id,
                   Ref{InferenceState}(),
                   [],
                   istoplevel,
                   virtualglobalvartable,
                   filter_native_remarks,
                   [],
                   )
    end
end

InferenceParams(interp::TPInterpreter) = InferenceParams(interp.native)
OptimizationParams(interp::TPInterpreter) = OptimizationParams(interp.native)
get_world_counter(interp::TPInterpreter) = get_world_counter(interp.native)
get_inference_cache(interp::TPInterpreter) = get_inference_cache(interp.native)

# TP only works for runtime inference
lock_mi_inference(::TPInterpreter, ::MethodInstance) = nothing
unlock_mi_inference(::TPInterpreter, ::MethodInstance) = nothing

function add_remark!(interp::TPInterpreter, ::InferenceState, report::InferenceErrorReport)
    push!(interp.reports, report)
    return
end
function add_remark!(interp::TPInterpreter, sv::InferenceState, s::String)
    interp.filter_native_remarks && return
    add_remark!(interp, sv, NativeRemark(interp, sv, s))
    return
end

may_optimize(interp::TPInterpreter) = interp.optimize
may_compress(interp::TPInterpreter) = interp.compress
may_discard_trees(interp::TPInterpreter) = interp.discard_trees
