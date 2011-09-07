class Previewer
  attr_reader :error
  attr_reader :error_area

  def initialize(params, app)
    @app = app

    @html       = params[:html]
    @css        = params[:css]
    @javascript = params[:javascript]

    @htmlFormat       = params[:html_format]
    @cssFormat        = params[:css_format]
    @javascriptFormat = params[:javascript_format]

    @error      = nil
    @error_area = nil
  end

  def javascript
    "<script type='text/javascript'>%s</script>" % [ built_javascript ]
  end

  def css
    "<style type='text/css'>%s</style>" % [ built_css ]
  end

  def error_area_proper
    case error_area
    when :javascript then "JavaScript"
    when :css then "CSS"
    when :html then "HTML"
    else nil
    end
  end

  def error_line
    return nil  unless error?

    return error.line  if @error.respond_to?(:line)
  end

  def html
    @output_html ||= begin
      # If the user submitted a valid HTML document, use it as is.
      if built_html =~ /^<!DOCTYPE/ || built_html =~ /<html>/
        [built_html, javascript, css].compact.join("\n")

      # Else, use our HTML5 layout.
      else
        @app.haml :_boilerplate, { :layout => false },
          head: [javascript, css].compact.join("\n"),
          body: built_html
      end
    end
  end

  def error?
    return @error  unless @error.nil?

    # These will populate @error and @error_area if it finds something.
    catch_error(:javascript) { built_javascript }
    catch_error(:css)        { built_css }
    catch_error(:html)       { built_html }

    !! @error
  end
  
  def catch_error(area, &blk)
    begin
      yield
    rescue => e
      @error      = e
      @error_area = area
    end
  end

  def built_javascript
    @built_javascript ||=
      case @javascriptFormat
      when 'coffee' then @app.coffee @javascript
      else @javascript
      end
  end

  def built_css
    @built_css ||=
      case @cssFormat
      when 'scss' then @app.scss "@import 'compass/css3';\n#{@css}"
      when 'sass' then @app.sass "@import 'compass/css3'\n#{@css}"
      when 'less' then @app.less @css
      else @css
      end
  end

  def built_html
    @built_html ||=
      case @htmlFormat
      when 'haml' then @app.haml @html, { layout: false, suppress_eval: true }
      else @html
      end
  end
end

class Main
  get '/' do
    haml :home
  end

  helpers do
    def get_context(string, line, spread)
      lines = string.split("\n")
      alpha = [line-spread, 0].max
      omega = [line+spread, lines.size-1].min

      lines = (alpha..omega).map { |i|
        [ i+1, lines[i] ]
      }
    end
  end

  post '/preview' do
    sleep 0.5  if settings.development?

    preview = Previewer.new(params, self)

    if preview.error?
      @error   = preview.error
      @area    = preview.error_area_proper
      @source  = params[preview.error_area]
      @line    = preview.error_line
      @context = get_context(@source, @line, 3)  if @line

      haml :error, layout: false
    else
      preview.html
    end
  end
end

