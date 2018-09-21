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
