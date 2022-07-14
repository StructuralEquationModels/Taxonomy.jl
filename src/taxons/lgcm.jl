struct LGCM <: Taxon
    timecoding::Judgement 
    ntimepoints::Judgement
    npredictors::Judgement
    nonlinearfunction::Judgement
end

function LGCM(; timecoding, 
    ntimepoints = length(timecoding),
    npredictors = 0,
    nonlinearfunction = 0)
    LGCM(timecoding, 
        ntimepoints, 
        npredictors, 
        nonlinearfunction
        )
end