#!/usr/bin/env ruby
# Extracts examples from a ReSpec document, verifies that example titles are unique. Numbering attempts to replicate that used by ReSpec. Examples in script elements, which are not visibile, may be used for describing the results of related examples
#
# Transformations from JSON-LD
# - @data-frame identifies the title of the frame used to process the example
# - @data-frame-for identifies the source to apply this frame to, verifies that the no errors are encountered
# - @data-context identifies the title of the context used to process the example
# - @data-context-for identifies the source to apply this context to, verifies that the no errors are encountered
# - @data-result-for identifies the title of the source which should result in the content. May be used along with @data-frame or @data-context
# - @data-options indicates the comma-separated option/value pairs to pass to the processor
require 'getoptlong'
require 'json'
require 'json/ld/preloaded'
require 'rdf/isomorphic'
require 'rdf/vocab'
require 'nokogiri'
require 'linkeddata'
require 'fileutils'
require 'colorize'
require 'yaml'
require 'cgi'

# Define I18N vocabulary
class RDF::Vocab::I18N < RDF::Vocabulary("https://www.w3.org/ns/i18n#"); end unless RDF::Vocab.const_defined?(:I18N)

# FIXME: This is here until the rdf:JSON is added in RDF.rb
unless RDF::RDFV.properties.include?( RDF.to_uri + 'JSON')
  RDF::RDFV.property :JSON, label: "JSON", comment: "JSON datatype"
end

PREFIXES = {
  dc:     "http://purl.org/dc/terms/",
  dct:    "http://purl.org/dc/terms/",
  dcterms:"http://purl.org/dc/terms/",
  dc11:   "http://purl.org/dc/elements/1.1/",
  dce:    "http://purl.org/dc/elements/1.1/",
  cred:   "https://w3id.org/credentials#",
  ex:     "http://example.org/",
  foaf:   "http://xmlns.com/foaf/0.1/",
  prov:   "http://www.w3.org/ns/prov#",
  rdf:    "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  schema: "http://schema.org/",
  xsd:    "http://www.w3.org/2001/XMLSchema#"
}
example_dir = yaml_dir = verbose = number = line = nil

opts = GetoptLong.new(
  ["--example-dir",   GetoptLong::REQUIRED_ARGUMENT],
  ["--yaml-dir",      GetoptLong::REQUIRED_ARGUMENT],
  ["--verbose", '-v', GetoptLong::NO_ARGUMENT],
  ["--number", '-n',  GetoptLong::REQUIRED_ARGUMENT],
  ["--line", '-l',  GetoptLong::REQUIRED_ARGUMENT],
)
opts.each do |opt, arg|
  case opt
  when '--example-dir'  then example_dir = arg && FileUtils::mkdir_p(arg)
  when '--yaml-dir'     then yaml_dir = arg && FileUtils::mkdir_p(arg)
  when '--verbose'      then verbose = true
  when '--number'       then number = arg.to_i
  when '--line'         then line = arg.to_i
  end
end

num_errors = 0

# Justify and remove leading and trailing blank lines from str
# Remove highlighting and commented out sections
def justify(str)
  str = str.
    gsub(/^\s*<!--\s*$/, '').
    gsub(/^\s*-->\s*$/, '').
    gsub('****', '').
    gsub(/####([^#]*)####/, '')

  # remove blank lines
  lines = str.split("\n").reject {|s| s =~ /\A\s*\z/}

  # count minimum leading space
  leading = lines.map {|s| s.length - s.lstrip.length}.min

  # remove leading blank space
  lines.map {|s| s[leading..-1]}.join("\n")
end

def table_to_dataset(table)
  repo = RDF::Repository.new
  titles = table.xpath('thead/tr/th/text()').map(&:to_s)

  table.xpath('tbody/tr').each do |row|
    gname, subject, predicate, object = nil
    row.xpath('td/text()').map(&:to_s).each_with_index do |cell, ndx|
      case titles[ndx]
      when 'Graph'
        gname = case cell
        when nil, '', " " then nil
        when /^_:/ then RDF::Node.intern(cell[2..-1])
        else RDF::Vocabulary.expand_pname(cell)
        end
      when 'Subject'
        subject = case cell
        when /^_:/ then RDF::Node.intern(cell[2..-1])
        else RDF::Vocabulary.expand_pname(cell)
        end
      when 'Property'
        predicate = RDF::Vocabulary.expand_pname(cell.sub("dcterms:", "dc:"))
      when 'Value'
        object = case cell
        when /^_:/ then RDF::Node.intern(cell[2..-1])
        when /^\w+:/ then RDF::Vocabulary.expand_pname(cell.sub("dcterms:", "dc:"))
        else RDF::Literal(cell)
        end
      when 'Value Type'
        case cell
        when /IRI/, '-', /^\s*$/, " "
        else
          # We might think something was an IRI, but determine that it's not
          dt = RDF::Vocabulary.expand_pname(cell.sub("dcterms:", "dc:"))
          object = RDF::Literal(object.to_s, datatype: dt)
        end
      when 'Language' 
        case cell
        when '-', /^\s*$/
        else
          # We might think something was an IRI, but determine that it's not
          object = RDF::Literal(object.to_s, language: cell.to_sym)
        end
      when 'Direction' 
        case cell
        when '-', /^\s*$/
        else
          object = RDF::Literal(object.to_s, datatype: RDF::URI("https://www.w3.org/ns/i18n##{object.language}_#{cell}"))
          # We might think something was an IRI, but determine that it's not
        end
      end
    end
    repo << RDF::Statement.new(subject, predicate, object, graph_name: gname)
  end

  repo
end

def dataset_to_table(repo)
  has_graph = !repo.graph_names.empty?
  litereals = repo.objects.select(&:literal?)
  has_datatype = litereals.any?(&:datatype?)
  has_language = litereals.any?(&:language?)
  positions = {}

  head = []
  head << "Graph" if has_graph
  head += %w(Subject Property Value)

  if has_datatype && has_language
    head += ["Value Type", "Language"]
    positions = {datatype: (has_graph ? 4 : 3), language: (has_graph ? 5 : 4)}
  elsif has_datatype
    positions = {datatype: (has_graph ? 4 : 3)}
    head << "Value Type"
  elsif has_language
    positions = {language: (has_graph ? 4 : 3)}
    head << "Language"
  end

  rows = []
  repo.each_statement do |statement|
    row = []
    row << (statement.graph_name || "&nbsp;").to_s if has_graph
    row += statement.to_triple.map do |term|
      if term.uri? && RDF::Vocabulary.find_term(term)
        RDF::Vocabulary.find_term(term).pname.sub("dc:", "dcterms:")
      else
        term.to_s
      end
    end

    if has_datatype
      if statement.object.literal? && statement.object.datatype?
        row[positions[:datatype]] = RDF::Vocabulary.find_term(statement.object.datatype).pname
      else
        row[positions[:datatype]] = "&nbsp;"
      end
    end

    if has_language
      if statement.object.literal? && statement.object.language?
        row[positions[:language]] = statement.object.language.to_s
      else
        row[positions[:language]] = "&nbsp;"
      end
    end

    rows << row
  end

  "<table>\n  <thead><tr>" +
  head.map {|cell| "<th>#{cell}</th>"}.join("") +
  "</tr></thead>\n  <tbody>\n    " +
  rows.map do |row|
    "<tr>" + row.map  {|cell| "<td>#{cell}</td>"}.join("") + "</tr>"
  end.join("\n    ") + "\n  </tbody>\n</table>"
end

# Allow linting examples
RDF::Reasoner.apply(:rdfs, :schema)

ARGV.each do |input|
  $stderr.puts "\ninput: #{input}"
  example_number = 1 # Account for imported Example 1 in typographical conventions
  examples = {}
  errors = []
  warnings = []

  File.open(input, "r") do |f|
    doc = Nokogiri::HTML.parse(f.read)
    doc.css(".example, .illegal-example").each do |element|
      error = nil
      warn = nil
      example_number += 1 if %w(pre aside).include?(element.name)

      if (title = element.attr('title').to_s).empty?
        error = "Example #{example_number} at line #{element.line} has no title"
      end

      if examples[title]
        warn = "Example #{example_number} at line #{element.line} uses duplicate title: #{title}"
      end

      def save_example(examples:, element:, title:, example_number:, error:, warn:)
        content = justify(element.inner_html)

        ext = case element.attr('data-content-type')
        when nil, '', 'application/ld+json' then "jsonld"
        when 'application/json' then 'json'
        when 'application/n-quads', 'nq' then 'nq'
        when 'text/html', 'html' then 'html'
        when 'text/turtle', 'ttl' then 'ttl'
        when 'application/trig', 'trig' then 'trig'
        else 'txt'
        end

        # Capture HTML table
        if element.name == 'table'
          ext, content = 'table', element
        end

        fn = "#{title.gsub(/[^\w]+/, '-')}.#{ext}"
        examples[title] = {
          title: title,
          filename: fn,
          content: content.to_s.gsub(/^\s*< !\s*-\s*-/, '<!--').gsub(/-\s*- >/, '-->').gsub(/-\s*-\s*&gt;/, '--&gt;'),
          content_type: element.attr('data-content-type'),
          number: example_number,
          ext: ext,
          context_for: element.attr('data-context-for'),
          context: element.attr('data-context'),
          base: element.attr('data-base'),
          ignore: element.attr('data-ignore') || element.attr('class').include?('illegal-example'),
          flatten: element.attr('data-flatten'),
          compact: element.attr('data-compact'),
          fromRdf: element.attr('data-from-rdf'),
          toRdf: element.attr('data-to-rdf'),
          frame_for: element.attr('data-frame-for'),
          no_lint: element.attr('data-no-lint'),
          frame: element.attr('data-frame'),
          result_for: element.attr('data-result-for'),
          options: element.attr('data-options'),
          target: element.attr('data-target'),
          element: element.name,
          line: element.line,
          warn: warn,
          error: error,
        }
        #puts "example #{example_number}: #{content}"
      end

      if element.name == 'aside'
        # If element is aside, look for sub elements with titles
        element.css('.original, .compacted, .expanded, .flattened, .turtle, .trig, .statements, .graph, .context, .frame, .framed').each do |sub|
          cls = (%w(original compacted expanded flattened turtle trig statements graph context frame) & sub.classes).first
          save_example(examples: examples,
                       element: sub,
                       title: "#{title}-#{cls}",
                       example_number: example_number,
                       error: error,
                       warn: warn)
        end
      else
        # otherwise, this is the example
        save_example(examples: examples,
                     element: element,
                     title: title,
                     example_number: example_number,
                     error: error,
                     warn: warn)
      end
    end
  end

  # Process API functions for
  examples.values.sort_by {|ex| ex[:number]}.each do |ex|
    next if number && number != ex[:number]
    next if line && line != ex[:line]

    xpath = '//script[@type="application/ld+json"]'
    xpath += %([@id="#{ex[:target][1..-1]}"]) if ex[:target]
    args = []
    content = ex[:content]

    options = ex[:options].to_s.split(',').inject({}) do |memo, pair|
      k, v = pair.split('=')
      v = case v
      when 'true' then true
      when 'false' then false
      else v
      end
      memo.merge(k.to_sym => v)
    end
    options[:validate] = true unless options.key?(:validate)

    $stderr.puts "example #{ex[:number]}: #{ex.select{|k,v| k != :content}.to_json(JSON::LD::JSON_STATE)}" if verbose
    $stderr.puts "content: #{ex[:content]}" if verbose

    if ex[:ignore]
      $stdout.write "i".colorize(:yellow)
      next
    end

    if ex[:error]
      errors << ex[:error]
      $stdout.write "F".colorize(:red)
      next
    end

    if !%w(pre script table).include?(ex[:element])
      errors << "Example #{ex[:number]} at line #{ex[:line]} has unknown element type #{ex[:element]}"
      $stdout.write "F".colorize(:red)
      next
    end

    # Perform example syntactic validation based on extension
    case ex[:ext]
    when 'json', 'jsonld'
      begin
        ::JSON.parse(content)
      rescue JSON::ParserError => exception
        errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{exception.message}"
        $stdout.write "F".colorize(:red)
        $stderr.puts exception.backtrace.join("\n") if verbose
        next
      end
    when 'html'
      begin
        doc = Nokogiri::HTML.parse(content) {|c| c.strict}
        doc.errors.each do |er|
          errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{er}"
        end
        unless doc.errors.empty?
          $stdout.write "F".colorize(:red)
          next
        end

        # Get base from document, if present
        html_base = doc.at_xpath('/html/head/base/@href')
        ex[:base] = html_base.to_s if html_base

        #script_content = doc.at_xpath(xpath)
        #content = script_content.inner_html if script_content
        content
      rescue Nokogiri::XML::SyntaxError => exception
        errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{exception.message}"
        $stdout.write "F".colorize(:red)
        $stderr.puts exception.backtrace.join("\n") if verbose
        next
      end
    when 'table'
      content = Nokogiri::HTML.parse(content)
    when 'ttl', 'trig'
      begin
        reader_errors = []
        RDF::Repository.new << RDF::TriG::Reader.new(content, logger: reader_errors, **options)
      rescue
        reader_errors.each do |er|
          errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{er}"
        end
        $stdout.write "F".colorize(:red)
        $stderr.puts $!.backtrace.join("\n") if verbose
        next
      end
    when 'nq'
      begin
        reader_errors = []
        RDF::Repository.new << RDF::NQuads::Reader.new(content, logger: reader_errors, **options)
      rescue
        reader_errors.each do |er|
          errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{er}"
        end
        $stdout.write "F".colorize(:red)
        $stderr.puts $!.backtrace.join("\n") if verbose
        next
      end
    end

    if content.is_a?(String)
      content = StringIO.new(content)
      # Set content_type so it can be parsed properly
      content.define_singleton_method(:content_type) {ex[:content_type]} if ex[:content_type]
    end

    # Set API to use
    method = case
    when ex[:compact]        then :compact
    when ex[:flatten]        then :flatten
    when ex[:fromRdf]        then :fromRdf
    when ex[:toRdf]          then :toRdf
    when ex[:ext] == 'table' then :toRdf
    when %w(json ttl trig).include?(ex[:ext] )
      nil
    else
      :expand
    end

    # Set args to parse example content
    if ex[:frame_for]
      unless examples[ex[:frame_for]]
        errors << "Example Frame #{ex[:number]} at line #{ex[:line]} references unknown example #{ex[:frame_for].inspect}"
        $stdout.write "F".colorize(:red)
        next
      end

      method = :frame
      args = [StringIO.new(examples[ex[:frame_for]][:content]), content, options]
    elsif ex[:context_for]
      unless examples[ex[:context_for]]
        errors << "Example Context #{ex[:number]} at line #{ex[:line]} references unknown example #{ex[:context_for].inspect}"
        $stdout.write "F".colorize(:red)
        next
      end

      # Either exapand with this external context, or compact using it
      case method
      when :expand
        options[:externalContext] = content
        options[:base] = ex[:base] if ex[:base]
        args = [StringIO.new(examples[ex[:context_for]][:content]), options]
      when :compact, :flatten, nil
        options[:base] = ex[:base] if ex[:base]
        args = [StringIO.new(examples[ex[:context_for]][:content]), content, options]
      end
    elsif %w(jsonld html).include?(ex[:ext])
      # Either exapand with this external context, or compact using it
      case method
      when :expand, :toRdf, :fromRdf
        options[:externalContext] = StringIO.new(ex[:context]) if ex[:context]
        options[:base] = ex[:base] if ex[:base]
        args = [content, options]
      when :compact, :flatten
        # Fixme how to find context?
        options[:base] = ex[:base] if ex[:base]
        args = [content, (StringIO.new(ex[:context]) if ex[:context]), options]
      end
    else
      args = [content, options]
    end

    if ex[:result_for]
      # Source is referenced
      # Instead of parsing this example content, parse that which is referenced
      unless examples[ex[:result_for]]
        errors << "Example #{ex[:number]} at line #{ex[:line]} references unknown example #{ex[:result_for].inspect}"
        $stdout.write "F".colorize(:red)
        next
      end

      # Set argument to referenced content to be parsed
      args[0] = if examples[ex[:result_for]][:ext] == 'html' && method == :expand
        # If we are expanding, and the reference is HTML, find the first script element.
        doc = Nokogiri::HTML.parse(examples[ex[:result_for]][:content])

        # Get base from document, if present
        html_base = doc.at_xpath('/html/head/base/@href')
        options[:base] = html_base.to_s if html_base

        script_content = doc.at_xpath(xpath)
        unless script_content
          errors << "Example #{ex[:number]} at line #{ex[:line]} references example #{ex[:result_for].inspect} with no JSON-LD script element"
          $stdout.write "F".colorize(:red)
          next
        end
        StringIO.new(examples[ex[:result_for]][:content])
      elsif examples[ex[:result_for]][:ext] == 'html' && ex[:target]
        # Only use the targeted script
        doc = Nokogiri::HTML.parse(examples[ex[:result_for]][:content])
        script_content = doc.at_xpath(xpath)
        unless script_content
          errors << "Example #{ex[:number]} at line #{ex[:line]} references example #{ex[:result_for].inspect} with no JSON-LD script element"
          $stdout.write "F".colorize(:red)
          next
        end
        StringIO.new(script_content.to_html)
      else
        StringIO.new(examples[ex[:result_for]][:content])
      end

      if examples[ex[:result_for]][:content_type]
        args[0].define_singleton_method(:content_type) {examples[ex[:result_for]][:content_type]}
      end

      # :frame option indicates the frame to use on the referenced content
      if ex[:frame] && !examples[ex[:frame]]
        errors << "Example #{ex[:number]} at line #{ex[:line]} references unknown frame #{ex[:frame].inspect}"
        $stdout.write "F".colorize(:red)
        next
      elsif ex[:frame]
        method = :frame
        args = [args[0], StringIO.new(examples[ex[:frame]][:content]), options]
      end

      # :context option indicates the context to use on the referenced content
      if ex[:context] && !examples[ex[:context]]
        errors << "Example #{ex[:number]} at line #{ex[:line]} references unknown context #{ex[:context].inspect}"
        $stdout.write "F".colorize(:red)
        next
      else
        case method
        when :expand, :toRdf, :fromRdf
          options[:externalContext] = StringIO.new(examples[ex[:context]][:content]) if ex[:context]
          args = [args[0], options]
        when :compact, :flatten
          args = [args[0], ex[:context] ? StringIO.new(examples[ex[:context]][:content]) : nil, options]
        end
      end
    end

    # Save example
    if example_dir
      file_content = content.respond_to?(:rewind) ? (content.rewind; content.read) : content
      File.open(File.join(example_dir, ex[:filename]), 'w') {|f| f.write(file_content)}
      content.rewind if content.respond_to?(:rewind)
    end

    # Save example as YAML
    if yaml_dir && ex[:filename].match?(/\.json.*$/)
      fn = ex[:filename].sub(/\.json.*$/, '.yaml')
      File.open(File.join(yaml_dir, fn), 'w') do |f|
        f.puts "Example #{"%03d" % ex[:number]}: #{ex[:title]}"
        f.write(::JSON.parse(ex[:content]).to_yaml)
      end
    end

    # Generate result
    # * If result_for is set, this is for the referenced example
    # * otherwise, this is for this example
    begin
      ext = ex[:result_for] ? examples[ex[:result_for]][:ext] : ex[:ext]
      result = case method
      when nil then nil
      when :fromRdf
        args[0] = RDF::Reader.for(file_extension: ext).new(args[0], **options)
        opts = args.last.is_a?(Hash) ? args.pop : {}
        JSON::LD::API.fromRdf(*args, **opts)
      when :toRdf
        opts = args.last.is_a?(Hash) ? args.pop : {}
        RDF::Repository.new << JSON::LD::API.toRdf(*args, **opts)
      else
        opts = args.last.is_a?(Hash) ? args.pop : {}
        JSON::LD::API.method(method).call(*args, **opts)
      end
    rescue
      errors << "Example #{ex[:number]} at line #{ex[:line]} parse error generating result: #{$!}"
      $stdout.write "F".colorize(:red)
      $stderr.puts $!.backtrace.join("\n") if verbose
      next
    end

    if verbose
      if result.is_a?(RDF::Enumerable)
        $stderr.puts "result:\n" + result.to_nquads
      else
        $stderr.puts "result:\n" + result.to_json(JSON::LD::JSON_STATE)
      end
    end

    begin
      if ex[:result_for]
        # Compare to expected to result
        case ex[:ext]
        when 'ttl', 'trig', 'nq', 'html'
          reader = RDF::Reader.for(file_extension: ex[:ext]).new(content, **options)
          expected = RDF::Repository.new << reader
          $stderr.puts "expected:\n" + expected.to_nquads if verbose
        when 'table'
          expected = begin
            table_to_dataset(content.xpath('/html/body/table'))
          rescue
            errors << "Example #{ex[:number]} at line #{ex[:line]} raised error reading table: #{$!}"
            $stderr.puts $!.backtrace.join("\n") if verbose
            RDF::Repository.new
          end
            
          if verbose
            $stderr.puts "expected:\n" + expected.to_nquads
            $stderr.puts "result table:\n" + begin
              dataset_to_table(result)
            rescue
              errors << "Example #{ex[:number]} at line #{ex[:line]} raised error turning into table: #{$!}"
              ""
              $stderr.puts $!.backtrace.join("\n") if verbose
            end
          end
        else
          expected = ::JSON.parse(content.read)
          $stderr.puts "expected: " + expected.to_json(JSON::LD::JSON_STATE) if verbose
        end

        # Perform appropriate comparsion
        if expected.is_a?(RDF::Enumerable)
          if !expected.isomorphic_with?(result)
            errors << "Example #{ex[:number]} at line #{ex[:line]} not isomorphic with #{examples[ex[:result_for]][:number]}"
            $stdout.write "F".colorize(:red)
            next
          elsif !ex[:no_lint] && !(messages = expected.lint).empty?
            # Lint problems in resulting graph.
            if verbose
              messages.each do |kind, term_messages|
                term_messages.each do |term, messages|
                  $stderr.puts "lint #{kind}  #{term}"
                  messages.each {|m| $stderr.puts "  #{m}"}
                end
              end
            end
            errors << "Example #{ex[:number]} at line #{ex[:line]} has lint errors"
            $stdout.write "F".colorize(:red)
            next
          end
        else
          unless result == expected
            errors << "Example #{ex[:number]} at line #{ex[:line]} not equivalent to #{examples[ex[:result_for]][:number]}"
            $stdout.write "F".colorize(:red)
            next
          end
        end
      end
    rescue
      errors << "Example #{ex[:number]} at line #{ex[:line]} parse error comparing result: #{$!}"
      $stdout.write "F".colorize(:red)
      $stderr.puts $!.backtrace.join("\n") if verbose
      next
    end

    if ex[:warn]
      warnings << ex[:warn]
      $stdout.write "w".colorize(:yellow)
    else
      $stdout.write ".".colorize(:green)
    end
  end

  $stdout.puts "\nWarnings:" unless warnings.empty?
  warnings.each {|e| $stdout.puts "  #{e}".colorize(:yellow)}
  $stdout.puts "\nErrors:" unless errors.empty?
  errors.each {|e| $stdout.puts "  #{e}".colorize(:red)}
  num_errors += errors.length
end

if num_errors == 0
  $stdout.puts "\nok".colorize(:green)
else
  exit(1)
end

exit(0)
