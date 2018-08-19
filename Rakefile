task default: :test

desc "Test examples in spec files"
task :test do
  sh %(bundle exec common/extract-examples.rb index.html)
end

desc "Extract Examples"
task :examples  do
  sh %(rm -rf examples yaml trig)
  sh %(bundle exec common/extract-examples.rb --example-dir examples --yaml-dir yaml --trig-dir trig index.html)
end
