$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "blacklight_cornell_requests/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "blacklight_cornell_requests"
  s.version     = BlacklightCornellRequests::VERSION
  s.authors     = ["Shinwoo Kim", "Matt Connolly"]
  s.email       = ["cul-da-developers-l@list.cornell.edu"]
  s.homepage    = "http://search.library.cornell.edu"
  s.summary     = "Given a bibid, provide user with the best delivery option and all other available options."
  s.description = "Given a bibid, provide user with the best delivery option and all other available options."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", "~> 7.0"
  s.add_dependency 'protected_attributes_continued'
  s.add_dependency 'haml', ['>= 3.0.0']
  s.add_dependency 'haml-rails'
  s.add_dependency 'httpclient'
  s.add_dependency 'net-ldap'
  s.add_dependency 'blacklight'
  s.add_dependency 'i18n'
  s.add_dependency 'dotenv'
  s.add_dependency 'dotenv-rails'
  s.add_dependency 'dotenv-deployment'
  s.add_dependency 'exception_notification'
  # TODO: I don't think we need an Oracle adapter anymore
  # s.add_dependency 'activerecord-oracle_enhanced-adapter'
  s.add_dependency 'repost'
  s.add_dependency 'rest-client'
  # s.add_dependency 'cul-folio-edge', '~> 2.0'

  s.add_development_dependency "sqlite3", "~> 1.4"
  s.add_development_dependency "rspec-rails", "~> 6.0"
  s.add_development_dependency "capybara"
  s.add_development_dependency "guard-rspec"
  s.add_development_dependency "rails-controller-testing"
  s.add_development_dependency "rsolr"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "webmock"
  s.add_development_dependency "vcr"

end
