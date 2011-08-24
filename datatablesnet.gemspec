# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "datatablesnet/version"

Gem::Specification.new do |s|
  s.name        = "datatablesnet"
  s.version     = Datatablesnet::VERSION
  s.platform    = Gem::Platform::RUBY  
  s.summary     = "Datatables.net component for rails"
  s.email       = "mfields106@gmail.com"
  s.homepage    = "https://github.com/IslandPort/datatablesnet"
  s.description = "Component abstraction for datatables.net"
  s.authors     = ['Matt Fields']


  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

end