require 'asciidoctor'
require 'json'

if Gem::Version.new(Asciidoctor::VERSION) <= Gem::Version.new('1.5.1')
  fail 'asciidoctor: FAILED: HTML5/Slim backend needs Asciidoctor >=1.5.2!'
end

unless defined? Slim::Include
  fail 'asciidoctor: FAILED: HTML5/Slim backend needs Slim >= 2.1.0!'
end

# Add custom functions to this module that you want to use in your Slim
# templates. Within the template you can invoke them as top-level functions
# just like in Haml.
module Slim::Helpers

  # URIs of external assets.
  FONT_AWESOME_URI     = '//cdnjs.cloudflare.com/ajax/libs/font-awesome/4.5.0/css/font-awesome.min.css'
  HIGHLIGHTJS_BASE_URI = '//cdnjs.cloudflare.com/ajax/libs/highlight.js/7.4'
  PRETTIFY_BASE_URI    = '//cdnjs.cloudflare.com/ajax/libs/prettify/r298'

  # Defaults
  DEFAULT_HIGHLIGHTJS_THEME = 'github'
  DEFAULT_PRETTIFY_THEME = 'prettify'
  DEFAULT_SECTNUMLEVELS = 3
  DEFAULT_TOCLEVELS = 2

  VOID_ELEMENTS = %w(area base br col command embed hr img input keygen link meta param source track wbr)

  ##
  # Creates an HTML tag with the given name and optionally attributes. Can take
  # a block that will run between the opening and closing tags.
  #
  # @param name [#to_s] the name of the tag.
  # @param attributes [Hash]
  # @param content [#to_s] the content; +nil+ to call the block.
  # @yield The block of Slim/HTML code within the tag (optional).
  # @return [String] a rendered HTML element.
  #
  def html_tag(name, attributes = {}, content = nil)
    attrs = attributes.reject { |_, v|
      v.nil? || (v.respond_to?(:empty?) && v.empty?)
    }.map do |k, v|
      v = v.compact.join(' ') if v.is_a? Array
      v = nil if v == true
      v = %("#{v}") if v
      [k, v] * '='
    end
    attrs_str = attrs.empty? ? '' : attrs.join(' ').prepend(' ')

    if VOID_ELEMENTS.include? name.to_s
      %(<#{name}#{attrs_str}>)
    else
      content ||= yield if block_given?
      %(<#{name}#{attrs_str}>#{content}</#{name}>)
    end
  end

  def urlize(*segments)
    path = segments * '/'
    if path.start_with? '//'
      @_uri_scheme ||= document.attr 'asset-uri-scheme', 'https'
      path = %(#{@_uri_scheme}:#{path}) unless @_uri_scheme.empty?
    end
    normalize_web_path path
  end

  ##
  # @param index [Integer] the footnote's index.
  # @return [String] footnote id to be used in a link.
  def footnote_id(index = (attr :index))
    %(_footnote_#{index})
  end

  ##
  # @param index (see #footnote_id)
  # @return [String] footnoteref id to be used in a link.
  def footnoteref_id(index = (attr :index))
    %(_footnoteref_#{index})
  end

  ##
  # Returns HTML meta tag if the given +content+ is not +nil+.
  #
  # @param name [#to_s] the name for the metadata.
  # @param content [#to_s, nil] the value of the metadata, or +nil+.
  # @return [String, nil] the meta tag, or +nil+ if the +content+ is +nil+.
  #
  def html_meta_if(name, content)
    %(<meta name="#{name}" content="#{content}">) if content
  end

  # Returns formatted style/link and script tags for header.
  def styles_and_scripts
    scripts = []
    styles = []
    tags = []

    stylesheet = attr :stylesheet
    stylesdir = attr :stylesdir, ''
    default_style = ::Asciidoctor::DEFAULT_STYLESHEET_KEYS.include? stylesheet
    linkcss = (attr? :linkcss) || safe >= ::Asciidoctor::SafeMode::SECURE
    stylehref = attr :stylehref
    ss = ::Asciidoctor::Stylesheets.instance

    if stylehref
      styles << { href: [stylehref] }
    elsif linkcss
      path = default_style ? ::Asciidoctor::DEFAULT_STYLESHEET_NAME : stylesheet
      styles << { href: [stylesdir, path] }
    elsif default_style
      styles << { text: ss.primary_stylesheet_data }
    else
      styles << { text: read_asset(normalize_system_path(stylesheet, stylesdir), true) }
    end

    if attr? :icons, 'font'
      if attr? 'iconfont-remote'
        styles << { href: (attr 'iconfont-cdn', FONT_AWESOME_URI) }
      else
        styles << { href: [stylesdir, %(#{attr 'iconfont-name', 'font-awesome'}.css)] }
      end
    end

    case attr 'source-highlighter'
    when 'coderay'
      if (attr 'coderay-css', 'class') == 'class'
        if linkcss
          styles << { href: [stylesdir, ss.coderay_stylesheet_name] }
        else
          styles << { text: ss.coderay_stylesheet_data }
        end
      end

    when 'pygments'
      if (attr 'pygments-css', 'class') == 'class'
        if linkcss
          styles << { href: [stylesdir, ss.pygments_stylesheet_name(attr 'pygments-style')] }
        else
          styles << { text: ss.pygments_stylesheet_data(attr 'pygments-style') }
        end
      end

    when 'highlightjs'
      hjs_base = attr :highlightjsdir, HIGHLIGHTJS_BASE_URI
      hjs_theme = attr 'highlightjs-theme', DEFAULT_HIGHLIGHTJS_THEME

      scripts << { src: [hjs_base, 'highlight.min.js'] }
      scripts << { src: [hjs_base, 'lang/common.min.js'] }
      scripts << { text: 'hljs.initHighlightingOnLoad()' }
      styles  << { href: [hjs_base, %(styles/#{hjs_theme}.min.css)] }

    when 'prettify'
      prettify_base = attr :prettifydir, PRETTIFY_BASE_URI
      prettify_theme = attr 'prettify-theme', DEFAULT_PRETTIFY_THEME

      scripts << { src: [prettify_base, 'prettify.min.js'] }
      scripts << { text: 'document.addEventListener("DOMContentLoaded", prettyPrint)' }
      styles  << { href: [prettify_base, %(#{prettify_theme}.min.css)] }
    end

    styles.each do |item|
      if item.key?(:text)
        tags << html_tag(:style, {}, item[:text])
      else
        tags << html_tag(:link, rel: 'stylesheet', href: urlize(*item[:href]))
      end
    end

    scripts.each do |item|
      if item.key? :text
        tags << html_tag(:script, {type: item[:type]}, item[:text])
      else
        tags << html_tag(:script, type: item[:type], src: urlize(*item[:src]))
      end
    end

    tags.join "\n"
  end

  def articles
      files = Dir["articles/*.adoc"]
      files.map { |file|
          [file, Asciidoctor.load_file(file, safe: :safe)]
      }.sort_by {|(_, d)| d.attr "published-date"}
  end

  def prev_article
      idx = articles.index{|(_,d)| d.doctitle == doctitle}
      unless not idx or idx == 0
          link = articles[idx-1]
          {link: '/'+link[0].gsub(/\.adoc/, ''),
           text: link[1].doctitle}
      end
  end

  def next_article
      idx = articles.index{|(_,d)| d.doctitle == doctitle}
      unless not idx or idx == articles.length-1
          link = articles[idx+1]
          {link: '/'+link[0].gsub(/\.adoc/, ''),
           text: link[1].doctitle}
      end
  end

end
