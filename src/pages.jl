module Pages

using HypertextTemplates
using HypertextTemplates.Elements

"""@layout {theme, title} ...

Standard page layout for chartserver.jl pages.
"""
@component function layout(; theme="dark", title="Title")
    @html { lang="en" } begin
        @head begin
            @title $title
        end
        @body { "data-theme"=theme } begin
            @__slot__
        end
    end
end
@deftag macro layout end

"""home 

Return HTML for the home page.  Go!
"""
function home()
    @render @layout { title="chartserver.jl" } begin
        @h1 @a { href="/demo" }  "Demo"
        @h1 @a { href="/demo2" } "Demo 2"
        @h1 @a { href="/docs" }  "Docs"
        @h1 @a { href="/docs/metrics" } "Metrics"
    end
end

end
