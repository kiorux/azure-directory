# Azure Active Directory Graph API

## Description

Simple Azure Active Directory Graph API wrapper for Ruby on Rails. 

The API authentication protocol is a service to service call using OAuth2 client credentials. For more information go to
[Azure Documentation](https://msdn.microsoft.com/en-us/library/azure/dn645543.aspx).

* This library is in alpha. Future incompatible changes may be necessary. *

## Install

Add the gem to the Gemfile

```ruby
gem 'azure-directory'
```

## Configuration

First configure your API client in `config/initializers/azure_directory.rb`

``` ruby
Azure::Directory.configure do
	
	# OPTIONAL. Use a YAML file to store the requested access tokens. When the token is refreshed, this file will be updated.
	use_yaml Rails.root.join('config', 'google_directory.yaml')

	# Required attributes
	client_id       ''
	client_secret   ''
	tenant_id       ''
	resource_id     ''

end
```

### Multiple API clients using scopes

Specify a single or multiple scopes in the configuration file. 

``` ruby
Azure::Directory.configure do
	
	scope :domain_one do
		client_id       ''
		client_secret   ''
		# [...]
	end

	scope :domain_two do
		client_id       ''
		client_secret   ''
		# [...]
	end

end
```

## Usage

``` ruby
azure = Azure::Directory::Client.new

azure.find_users

azure.create_user("email", "given_name", "family_name", "password")

azure.update_user("email", update_data)

azure.update_user_password("email", "new_password")

```

### Multiple Scopes

``` ruby
domain_one = Azure::Directory::Client.new(:domain_one)
domain_one.find_users

domain_two = Azure::Directory::Client.new(:domain_two)
domain_two.find_users
```

## TO DO

* `use_active_model` for database token store
* Build the configuration generator
* Implement the Azure's REST API calls
* Abstract the API's Entities into ruby models [Entity Reference](https://msdn.microsoft.com/en-us/library/azure/dn151470.aspx)
* Better error handling
* Testing