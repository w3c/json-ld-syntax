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
require 'nokogiri'
require 'linkeddata'
require 'fileutils'
require 'colorize'
require 'yaml'

PREFIXES = {
  dc:     "http://purl.org/dc/terms/",
  cred:   "https://w3id.org/credentials#",
  ex:     "http://example.org/",
  foaf:   "http://xmlns.com/foaf/0.1/",
  prov:   "http://www.w3.org/ns/prov#",
  rdf:    "http://www.w3.org/1999/02/22-rdf-syntax-ns#",
  schema: "http://schema.org/",
  xsd:    "http://www.w3.org/2001/XMLSchema#"
}
example_dir = yaml_dir = trig_dir = verbose = number = nil

opts = GetoptLong.new(
  ["--example-dir",   GetoptLong::REQUIRED_ARGUMENT],
  ["--yaml-dir",      GetoptLong::REQUIRED_ARGUMENT],
  ["--trig-dir",      GetoptLong::REQUIRED_ARGUMENT],
  ["--verbose", '-v', GetoptLong::NO_ARGUMENT],
  ["--number", '-n',  GetoptLong::REQUIRED_ARGUMENT],
)
opts.each do |opt, arg|
  case opt
  when '--example-dir'  then example_dir = arg && FileUtils::mkdir_p(arg)
  when '--yaml-dir'     then yaml_dir = arg && FileUtils::mkdir_p(arg)
  when '--trig-dir'     then trig_dir = arg && FileUtils::mkdir_p(arg)
  when '--verbose'      then verbose = true
  when '--number'       then number = arg.to_i
  end
end

num_errors = 0

# Justify and remove leading and trailing blank lines from str
# Remove highlighting and commented out sections
def justify(str)
  str = str.
    sub(/^\s*<!--\s*$/, '').
    sub(/^\s*-->\s*$/, '').
    gsub('****', '').
    gsub(/####([^#]*)####/, '')

  # remove blank lines
  lines = str.split("\n").reject {|s| s =~ /\A\s*\z/}

  # count minimum leading space
  leading = lines.map {|s| s.length - s.lstrip.length}.min

  # remove leading blank space
  lines.map {|s| s[leading..-1]}.join("\n")
end

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
        next
      end

      if examples[title]
        warn = "Example #{example_number} at line #{element.line} uses duplicate title: #{title}"
      end

      content = justify(element.inner_html)

      ext = case element.attr('data-content-type')
      when nil, '', 'application/ld+json' then "jsonld"
      when 'application/json' then 'json'
      when 'application/ld-frame+json' then 'jsonldf'
      when 'application/n-quads', 'nq' then 'nq'
      when 'text/html', 'html' then 'html'
      when 'text/turtle', 'ttl' then 'ttl'
      when 'application/trig', 'trig' then 'trig'
      else 'txt'
      end

      fn = "example-#{"%03d" % example_number}-#{title.gsub(/[^\w]+/, '-')}.#{ext}"
      examples[title] = {
        title: title,
        filename: fn,
        content: content,
        content_type: element.attr('data-content-type'),
        number: example_number,
        ext: ext,
        context_for: element.attr('data-context-for'),
        context: element.attr('data-context'),
        ignore: element.attr('data-ignore'),
        flatten: element.attr('data-flatten'),
        compact: element.attr('data-compact'),
        fromRdf: element.attr('data-from-rdf'),
        toRdf: element.attr('data-to-rdf'),
        frame_for: element.attr('data-frame-for'),
        frame: element.attr('data-frame'),
        result_for: element.attr('data-result-for'),
        options: element.attr('data-options'),
        element: element.name,
        line: element.line,
        warn: warn,
        error: error,
      }
      #puts "example #{example_number}: #{content}"
    end
  end

  # Process API functions for
  examples.values.sort_by {|ex| ex[:number]}.each do |ex|
    next if number && number != ex[:number]

    args = []
    content = ex[:content]

    $stderr.puts "example #{ex[:number]}: #{ex.select{|k,v| k != :content}.to_json(JSON::LD::JSON_STATE)}" if verbose
    $stderr.puts "content: #{ex[:content]}" if verbose

    if ex[:ignore] || ex[:element] == 'table'
      $stdout.write "i".colorize(:yellow)
      next
    end

    if ex[:error]
      errors << ex[:error]
      $stdout.write "F".colorize(:red)
      next
    end

    if !%w(pre script aside).include?(ex[:element])
      errors << "Example #{ex[:number]} at line #{ex[:line]} has unknown element type #{ex[:element]}"
      $stdout.write "F".colorize(:red)
      next
    end

    # Perform example syntactic validation based on extension
    case ex[:ext]
    when 'json', 'jsonld', 'jsonldf'
      begin
        ::JSON.parse(content)
      rescue JSON::ParserError => exception
        errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{exception.message}"
        $stdout.write "F".colorize(:red)
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
      rescue Nokogiri::XML::SyntaxError => exception
        errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{exception.message}"
        $stdout.write "F".colorize(:red)
        next
      end
    when 'ttl', 'trig'
      begin
        reader_errors = []
        RDF::TriG::Reader.new(content, logger: reader_errors) {|r| r.validate!}
      rescue
        reader_errors.each do |er|
          errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{er}"
        end
        $stdout.write "F".colorize(:red)
        next
      end
    when 'nq'
      begin
        reader_errors = []
        RDF::NQuads::Reader.new(content, logger: reader_errors) {|r| r.validate!}
      rescue
        reader_errors.each do |er|
          errors << "Example #{ex[:number]} at line #{ex[:line]} parse error: #{er}"
        end
        $stdout.write "F".colorize(:red)
        next
      end
    end

    options = ex[:options].to_s.split(',').inject({}) do |memo, pair|
      k, v = pair.split('=')
      v = case v
      when 'true' then true
      when 'false' then false
      else v
      end
      memo.merge(k.to_sym => v)
    end

    # Set API to use
    method = case
    when ex[:compact] then :compact
    when ex[:flatten] then :flatten
    when ex[:fromRdf] then :fromRdf
    when ex[:toRdf]   then :toRdf
    when ex[:ext] == 'json' then nil
    else                   :expand
    end

    if ex[:frame_for]
      unless examples[ex[:frame_for]]
        errors << "Example Frame #{ex[:number]} at line #{ex[:line]} references unknown example ex[:frame_for].inspect"
        $stdout.write "F".colorize(:red)
        next
      end

      method = :frame
      args = [StringIO.new(examples[ex[:frame_for]][:content]), StringIO.new(content), options]
    elsif ex[:context_for]
      unless examples[ex[:context_for]]
        errors << "Example Context #{ex[:number]} at line #{ex[:line]} references unknown example ex[:context_for].inspect"
        $stdout.write "F".colorize(:red)
        next
      end

      # Either exapand with this external context, or compact using it
      case method
      when :expand
        options[:externalContext] = StringIO.new(content)
        args = [StringIO.new(examples[ex[:context_for]][:content]), options]
      when :compact, :flatten, nil
        args = [StringIO.new(examples[ex[:context_for]][:content]), StringIO.new(content), options]
      end
    elsif ex[:ext] == 'jsonld'
      # Either exapand with this external context, or compact using it
      case method
      when :expand, :toRdf, :fromRdf
        options[:externalContext] = StringIO.new(ex[:context]) if ex[:context]
        args = [StringIO.new(content), options]
      when :compact, :flatten
        # Fixme how to find context?
        args = [StringIO.new(content), (StringIO.new(ex[:context]) if ex[:context]), options]
      end
    end

    if ex[:result_for]
      # Source is referenced
      args[0] = StringIO.new(examples[ex[:result_for]][:content])
      if ex[:frame] && !examples[ex[:frame]]
        errors << "Example #{ex[:number]} at line #{ex[:line]} references unknown frame ex[:frame].inspect"
        $stdout.write "F".colorize(:red)
        next
      elsif ex[:frame]
        method = :frame
        args = [args[0], StringIO.new(examples[ex[:frame]][:content]), options]
      end

      if ex[:context] && !examples[ex[:context]]
        errors << "Example #{ex[:number]} at line #{ex[:line]} references unknown context ex[:context].inspect"
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
      File.open(File.join(example_dir, ex[:filename]), 'w') {|f| f.write(content)}
    end

    # Save example as YAML
    if yaml_dir && ex[:filename].match?(/\.json.*$/)
      fn = ex[:filename].sub(/\.json.*$/, '.yml')
      File.open(File.join(yaml_dir, fn), 'w') do |f|
        f.puts "Example #{"%03d" % ex[:number]}: #{ex[:title]}"
        f.write(::JSON.parse(ex[:content]).to_yaml)
      end
    end

    # Generate result
    begin
      result = case method
      when nil then nil
      when :fromRdf
        ext = ex[:result_for] ? examples[ex[:result_for]][:ext] : ex[:ext]
        args[0] = RDF::Reader.for(file_extension: ext).new(args[0])
        JSON::LD::API.fromRdf(*args)
      when :toRdf
        RDF::Dataset.new statements: JSON::LD::API.toRdf(*args)
      else
        JSON::LD::API.method(method).call(*args)
      end
    rescue
      errors << "Example #{ex[:number]} at line #{ex[:line]} parse error generating result: #{$!}"
      $stdout.write "F".colorize(:red)
      next
    end

    if verbose
      if result.is_a?(RDF::Dataset)
        $stderr.puts "result: " + result.to_trig
      else
        $stderr.puts "result: " + result.to_json(JSON::LD::JSON_STATE)
      end
    end

    begin
      if ex[:result_for]
        # Compare to expected result
        case ex[:ext]
        when 'ttl', 'trig', 'nq', 'html'
          reader = RDF::Reader.for(file_extension: ex[:ext]).new(StringIO.new(content))
          expected = RDF::Dataset.new(statements: reader)
          $stderr.puts "expected: " + expected.to_trig if verbose
          expected_norm = RDF::Normalize.new(expected).map(&:to_nquads)
          result_norm = RDF::Normalize.new(result).map(&:to_nquads)
          unless expected_norm == expected_norm
            errors << "Example #{ex[:number]} at line #{ex[:line]} not isomorphic with #{examples[ex[:result_for]][:number]}"
            $stdout.write "F".colorize(:red)
            next
          end
        else
          expected = ::JSON.parse(content)
          $stderr.puts "expected: " + expected.to_json(JSON::LD::JSON_STATE) if verbose
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
      next
    end

    # Save example as TriG
    if trig_dir && (ex[:filename].match?(/\.json.*$/) || result.is_a?(RDF::Enumerable))
      # Make examples directory
      FileUtils::mkdir_p(trig_dir)
      fn = ex[:filename].sub(/\.json.*$/, '.trig')
      unless result.is_a?(RDF::Enumerable)
        result = RDF::Dataset.new(statements: JSON::LD::API.toRdf(result))
      end

      File.open(File.join(trig_dir, fn), 'w') do |f|
        RDF::TriG::Writer.dump(result,  f, prefixes: PREFIXES)
      end
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