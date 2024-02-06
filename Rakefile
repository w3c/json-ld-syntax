require 'bundler/setup'
task default: :test

desc "Test examples in spec files"
task :test do
  sh %(bundle exec common/extract-examples.rb index.html)
end

desc "Extract Examples"
task :examples  do
  sh %(rm -rf examples yaml)
  sh %(bundle exec common/extract-examples.rb --example-dir examples --yaml-dir yaml index.html)
end

desc "Check HTML"
task :check_html do
  require 'nokogiri'
  doc = ::Nokogiri::HTML5(File.open("index.html"), max_parse_errors: 1000)
  unless doc.errors.empty?
    STDERR.puts "Errors found parsing index.html:"
    doc.errors.each {|e| STDERR.puts "  #{e}"}
    exit(1)
  end
end
