Gem::Specification.new do |s|
  s.name        = 'haml_to_star'
  s.version     = '0.3.2'
  s.date        = '2012-12-25'
  s.summary     = "haml_to_star is a ruby library that purpose is to allow you to transform haml to any language."
  s.add_runtime_dependency('json')
  s.description =<<eos
haml_to_star is a ruby library that purpose is to allow you to transform haml to any language.

The compiler class handle common processing tasks as generating the code tree and html tags, but functions that are specific to languages such as how the code in the source code must be implemented on extensions.

Please take a look at known extensions and at the documentation if you want to create your own extension.
eos
  s.authors     = ["Sébastien Drouyer"]
  s.email       = 'sdrdis@hotmail.com'
  s.files       = `git ls-files`.split("\n")
  s.homepage    = 'https://github.com/sdrdis/haml_to_star'
end
