
"""
A representation of the most important metadata.

```jldoctest
min = Meta("Peikert, Aaron", 2022, "Journal of Statistical Software")
typeof(min)

# output

MinimalMeta
```
"""
struct MinimalMeta <: AbstractMeta
    author::String
    year::Int64
    journal::String
end

"""
A representation of Metadata when we can not even capture the most important metadata.

```jldoctest
incomplete = Meta(missing, 2022, "Journal of Statistical Software")
typeof(incomplete)

# output

IncompleteMeta
```
"""
struct IncompleteMeta <: AbstractMeta
    author::Union{String, Missing}
    year::Union{Int64, Missing}
    journal::Union{String, Missing}
end

"""
The metadata we can gather from [doi.org](https://www.doi.org).

```jldoctest
doi = Meta(DOI("10.1126/SCIENCE.169.3946.635"))
typeof(doi)

# output

ExtensiveMeta
```
"""
struct ExtensiveMeta <: AbstractMeta
    meta::Union{IncompleteMeta, MinimalMeta}
    citation::Union{String, Missing}
    json::Dict
end

for fun in [:year, :author, :journal]
    @eval $fun(x::MinimalMeta) = x.$fun
    @eval $fun(x::IncompleteMeta) = x.$fun
    @eval $fun(x::ExtensiveMeta) = $fun(x.meta)
    @eval $fun(x::NoDOI) = x.$fun
end

"""
Extract the year.

```jldoctest
julia> doi = Meta(DOI("10.1126/SCIENCE.169.3946.635"));
julia> year(doi)
1970
```

"""
function year(x::Dict{Tkey, Tval}) where {Tkey, Tval}
    if haskey(x, Tkey(:issued))
        issued = x[Tkey(:issued)]
        if haskey(issued, Tkey("date-parts"))
           return issued[Tkey("date-parts")][end][1]
        else
            return missing
        end
    else
        return missing
    end
end

function flatten_name(x::Dict{Tkey, Tval}) where {Tkey, Tval}
    if haskey(x, Tkey(:literal))
        x = x[Tkey(:literal)]
    elseif haskey(x, Tkey(:given)) && haskey(x, Tkey(:family))
        x = x[Tkey(:family)] * ", " * x[Tkey(:given)]
    elseif haskey(x, Tkey(:family))
        x = x[Tkey(:family)]
    else
        return missing
    end    
end

function flatten_name(x::Vector)
    x = filter(x -> !ismissing(x), x)
    if length(x) > 0
        join(flatten_name.(x), " & ")
    else
        missing
    end
end

"""
Extract the author.

```jldoctest
julia> doi = Meta(DOI("10.1126/SCIENCE.169.3946.635"));
julia> author(doi)
"Frank, Henry S."
```

"""
function author(x::Dict{Tkey, Tval}) where {Tkey, Tval}
    x = get(x, Tkey(:author), missing)
    if !ismissing(x)
        flatten_name(x)
    else
        x
    end
end

"""
Extract the journal.

```jldoctest
julia> doi = Meta(DOI("10.1126/SCIENCE.169.3946.635"));
julia> journal(doi)
"Frank, Henry S."
```
"""
function journal(x::Dict{Tkey, Tval}) where {Tkey, Tval}
    if haskey(x, Tkey("container-title"))
        x[Tkey("container-title")]
    else
        missing
    end
end

function request_meta(x, format)
    # see https://citation.crosscite.org/docs.html
    HTTP.get(
        x,
        ["Accept" => format];
        status_exception = false
    )
end

function request_meta(location::AbstractLocation, format)
    request_meta(url(location), format)
end

function request_json(location)
    request_meta(location, "application/vnd.citationstyles.csl+json")
end

function request_citation(location, format)
    request_meta(location, "text/x-bibliography; style=" * format)
end

function request_apa(location)
    request_citation(location, "apa")
end

function interpret_status(status::Integer)
    if status == 200
        return nothing
    elseif status == 404
        error("The DOI requested doesn't exist.")
    elseif status == 204
        error("No metadata available.")
    elseif status == 406
        error("Can not generate JSON.")
    else
        error("Can not reach DOI service. Maybe internet connection down?")
    end
end

interpret_status(status::HTTP.Messages.Response) = interpret_status(status.status)
"""
Get an APA citation.

```jldoctest
julia> apa(DOI("10.5281/zenodo.6719627"))
"Ernst, M. S., &amp; Peikert, A. (2022). <i>StructuralEquationModels.jl</i> (Version v0.1.0) [Computer software]. Zenodo. https://doi.org/10.5281/ZENODO.6719627"
```
"""
apa(request::HTTP.Messages.Response) = String(request.body)
function apa(location)
    request = request_apa(location)
    interpret_status(request)
    apa(request)
end

"""
Get a Citeproc JSON.

[CSL JSON Documentation](https://citeproc-js.readthedocs.io/en/latest/csl-json/markup.html)

CSL JSON can be read by Zotero and automatically generated by [doi.org](http://www.doi.org) from DOI.
All availible information are included and saved in a [`Dict`](https://docs.julialang.org/en/v1/base/collections/#Dictionaries).

```jldoctest
julia> json(DOI("10.5281/zenodo.6719627"))
Dict{String, Any} with 11 entries:
  "publisher" => "Zenodo"
  "issued"    => Dict{String, Any}("date-parts"=>Any[Any[2022, 6, 24]])
  "author"    => Any[Dict{String, Any}("family"=>"Ernst", "given"=>"Maximilian S…
  "id"        => "https://doi.org/10.5281/zenodo.6719627"
  "copyright" => "MIT License"
  "version"   => "v0.1.0"
  "DOI"       => "10.5281/ZENODO.6719627"
  "URL"       => "https://zenodo.org/record/6719627"
  "title"     => "StructuralEquationModels.jl"
  "abstract"  => "StructuralEquationModels v0.1.0 This is a package for Structur…
  "type"      => "book"
```
"""
json(request::HTTP.Messages.Response) = JSON.parse(String(request.body))
function json(location)
    request = request_json(location)
    interpret_status(request)
    json(request)
end
"""
Save metadata.

Can be from complete minimal metadata, incomplete metadata or preferably from [`DOI`](@ref).

```jldoctest
julia> min = Meta("Peikert, Aaron", 2022, "Journal of Statistical Software");
julia> incomplete = Meta("Peikert, Aaron", 2022, missing);
julia> extensive = Meta(DOI("10.5281/zenodo.6719627"));
```
"""
function Meta(author, year, journal)
    if any(ismissing.([author, year, journal]))
        IncompleteMeta(author, year, journal)
    else
        MinimalMeta(author, year, journal)
    end
end

function Meta(location::AbstractDOI)
    json = Taxonomy.json(location)
    apa_request = request_apa(location)
    apa = apa_request.status == 200 ? Taxonomy.apa(apa_request) : missing
    meta = Meta(author(json), year(json), journal(json))
    ExtensiveMeta(meta, apa, json)
end
