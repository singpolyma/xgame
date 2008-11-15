Gem::Specification.new do |s|
  s.name     = "xgame"
  s.version  = "0.1.0" # NOTE: Don't forget to update the configure script and lib/xgame.rb
  s.date     = "2008-11-15"
  s.summary  = "High-level game framework based on rubygame and chipmunk"
  s.email    = "singpolyma@singpolyma.net"
  s.homepage = "http://github.com/singpolyma/xgame"
  s.description = "High-level game framework based on rubygame and chipmunk"
  s.has_rdoc = true
  s.authors  = ['Stephen Paul Weber']
  s.files    = ["README", 
		"TODO", 
		"COPYING", 
		"xgame.gemspec", 
		"lib/xgame.rb"] 
  s.extra_rdoc_files = ["README", "COPYING", "TODO"]
  s.add_dependency("rubygame", ["> 2.3.0"])
end

