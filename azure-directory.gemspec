$:.push File.expand_path("../lib", __FILE__)

require 'azure/directory/version'

Gem::Specification.new do |spec|
  spec.name          = "azure-directory"
  spec.version       = Azure::Directory::VERSION
  spec.authors       = ["Omar Osorio"]
  spec.email         = ["omar@kioru.com"]
  spec.homepage      = "https://github.com/kioru/azure-directory"

  spec.summary       = "Azure Active Directory Graph API client for Ruby on Rails"
  spec.description   = "Setup your Rails application with one or multiple clients for Azure AD Graph API using OAuth2 service-to-service calls."
  
  spec.rdoc_options = ["--main", "README.md"]

  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'oauth2', '~> 1.0'

  spec.add_development_dependency 'rails', '~> 4.2'
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency 'yard', '~> 0.8'
end
