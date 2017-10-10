abstract type RobertsRosenthalMCTune{F<:VariateForm} <: MCTunerState end

mutable struct UnvRobertsRosenthalMCTune <: RobertsRosenthalMCTune{Univariate}
  σ::Real # Standard deviation of underlying normal
  δ::Real # Increase or decrease of σ at each batch
  accepted::Integer # Number of accepted MCMC samples during current tuning period
  proposed::Integer # Number of proposed MCMC samples during current tuning period
  totproposed::Integer # Total number of proposed MCMC samples during burnin
  rate::Real # Observed acceptance rate over current tuning period

  function UnvRobertsRosenthalMCTune(
    σ::Real,
    δ::Real,
    accepted::Integer,
    proposed::Integer,
    totproposed::Integer,
    rate::Real
  )
    @assert σ > 0 "Stepsize of MCMC iteration should be positive"
    @assert accepted >= 0 "Number of accepted MCMC samples should be non-negative"
    @assert proposed >= 0 "Number of proposed MCMC samples should be non-negative"
    @assert totproposed >= 0 "Total number of proposed MCMC samples should be non-negative"
    if !isnan(rate)
      @assert 0 <= rate <= 1 "Observed acceptance rate should be in [0, 1]"
    end
    new(σ, δ, accepted, proposed, totproposed, rate)
  end
end

UnvRobertsRosenthalMCTune(σ::Real=1., accepted::Integer=0, proposed::Integer=0, totproposed::Integer=0) =
  UnvRobertsRosenthalMCTune(σ, NaN, accepted, proposed, totproposed, NaN)

mutable struct MuvRobertsRosenthalMCTune <: RobertsRosenthalMCTune{Multivariate}
  σ::RealVector # Standard deviation of underlying normal
  δ::Real # Increase or decrease of σ at each batch
  accepted::IntegerVector # Number of accepted MCMC samples during current tuning period
  proposed::Integer # Number of proposed MCMC samples during current tuning period
  totproposed::Integer # Total number of proposed MCMC samples during burnin
  rate::RealVector # Observed acceptance rate over current tuning period

  function MuvRobertsRosenthalMCTune(
    σ::RealVector,
    δ::Real,
    accepted::IntegerVector,
    proposed::Integer,
    totproposed::Integer,
    rate::RealVector
  )
    @assert all(i -> i > 0, σ) "Stepsize of MCMC iteration should be positive"
    @assert all(i -> i >= 0, accepted) "Number of accepted MCMC samples should be non-negative"
    @assert proposed >= 0 "Number of proposed MCMC samples should be non-negative"
    @assert totproposed >= 0 "Total number of proposed MCMC samples should be non-negative"
    if all(i -> !isnan(i), rate)
      @assert all(i -> 0 <= i <= 1, rate) "Observed acceptance rates should be in [0, 1]"
    end
    new(σ, δ, accepted, proposed, totproposed, rate)
  end
end

function MuvRobertsRosenthalMCTune(σ::RealVector, proposed::Integer=0, totproposed::Integer=0)
  l = length(σ)
  MuvRobertsRosenthalMCTune(σ, NaN, fill(0, l), proposed, totproposed, fill(NaN, l))
end

MuvRobertsRosenthalMCTune(size::Integer, proposed::Integer=0, totproposed::Integer=0) =
  MuvRobertsRosenthalMCTune(fill(1., size), NaN, fill(0, size), proposed, totproposed, fill(NaN, size))

### RobertsRosenthalMCTuner

struct RobertsRosenthalMCTuner <: MCTuner
  targetrate::Real # Target acceptance rate
  nadapt::Integer # Number of steps in which the proposal variance is scaled
  period::Integer # Tuning period over which acceptance rate is computed
  verbose::Bool # If verbose=false then the tuner is silent, else it is verbose

  function RobertsRosenthalMCTuner(targetrate::Real, nadapt::Integer, period::Integer, verbose::Bool)
    @assert 0 < targetrate < 1 "Target acceptance rate should be between 0 and 1"
    @assert nadapt > 0 "Number of adaptation steps should be positive"
    @assert period > 0 "Tuning period should be positive"
    new(targetrate, nadapt, period, verbose)
  end
end

RobertsRosenthalMCTuner(
  targetrate::Real,
  nadapt::Integer;
  period::Integer=100,
  verbose::Bool=false
) =
  RobertsRosenthalMCTuner(targetrate, nadapt, period, verbose)

set_delta!(tune::RobertsRosenthalMCTune, tuner::RobertsRosenthalMCTuner) =
  tune.δ = min(0.01, sqrt(tuner.period/tune.totproposed))

tune!(tune::UnvRobertsRosenthalMCTune, tuner::RobertsRosenthalMCTuner) =
  tune.σ *= exp(tune.rate < tuner.targetrate ? -tune.δ : tune.δ)

tune!(tune::MuvRobertsRosenthalMCTune, tuner::RobertsRosenthalMCTuner, i::Integer) =
  tune.σ[i] *= exp(tune.rate[i] < tuner.targetrate ? -tune.δ : tune.δ)

show(io::IO, tuner::RobertsRosenthalMCTuner) =
  print(
    io,
    string(
      "RobertsRosenthalMCTuner: target rate = ",
      tuner.targetrate,
      ", nadapt = ",
      tuner.nadapt,
      ", period = ",
      tuner.period,
      ", verbose = ",
      tuner.verbose
    )
  )
