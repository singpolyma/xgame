Gem::Specification.new do |s|
  s.name     = "xgame"
  s.version  = "0.0.1"
  s.date     = "2008-10-18"
  s.summary  = "High-level game framework based on rubygame"
  s.email    = "singpolyma@singpolyma.net"
  s.homepage = "http://github.com/singpolyma/xgame"
  s.description = "High-level game framework based on rubygame"
  s.has_rdoc = true
  s.authors  = ['Stephen Paul Weber']
  s.files    = ["README", 
		"TODO", 
		"COPYING", 
		"xgame.gemspec", 
		"lib/xgame.rb"] 
  s.extra_rdoc_files = ["README", "COPYING", "TODO"]
  s.add_dependency("rubygame", ["> 0.0.0"])
end

