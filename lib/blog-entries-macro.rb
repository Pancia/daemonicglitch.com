require 'asciidoctor/extensions'

include Asciidoctor

class BlogEntriesMacro < Extensions::BlockMacroProcessor
    use_dsl
    named :blog_entries

    def process(parent, target, attrs)
        files = Dir["#{target}/*.adoc"]
        entries = files.map { |file|
            [file, Asciidoctor.load_file(file, safe: :safe)]
        }.sort_by {|(_, d)| d.attr "published-date"}.reverse.reduce("") { |acc, (file, document)|
            abstract = document.find_by(id: "abstract").first.content rescue nil
            rellink = file.gsub(/\.adoc/, '')
            doclink = Asciidoctor.convert("link:#{rellink}[#{document.doctitle}]")
            readmore = Asciidoctor.convert("link:#{rellink}[read more]")
            acc + %(<article class='abstract'>
            <h2>#{doclink}</h2>
            <span>#{document.attr "published-date"}</span>
            <p>#{abstract}<br>#{readmore}</p>
            </article>)
        }
        html = "<div class='entries'>#{entries}</div>"

        create_pass_block parent, html, attrs, subs: nil
    end
end

Extensions.register do
    block_macro BlogEntriesMacro
end
