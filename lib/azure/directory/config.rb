require 'yaml'

module Azure

	module Directory
	
		class MissingConfiguration < StandardError
			def initialize
				super('No configuration found for Azure Directory')
			end
		end

		def self.configure(&block)
			@config = Config::Builder.new(&block).build
		end

		def self.configuration
			@config || (fail MissingConfiguration.new)
		end



		class Config

			attr_reader :scope_name, :client_id, :client_secret, :tenant_id, :resource_id

			def initialize(scope_name = :main)
				@scope_name = scope_name
			end

			def using(scope)
				@scopes[scope]
			end


			def save_token(token_hash)
				token_hash = token_hash.slice('access_token', 'token_type', 'expires_at')
				@token_store and @token_store.save(@scope_name, token_hash)
			end

			def load_token
				@token_store and @token_store.load(@scope_name)
			end


			class Builder
				
				def initialize(&block)
					@config = @current_config = Config.new
					@config.instance_variable_set('@scopes', { })
					instance_eval(&block)
				end

				def build
					@config
				end

				##
				# Use a YAML file to store the requested access tokens. When the token is refreshed, this file will be updated.
				# You must declare this configuration attribute before any scope.
				#
				# @param [String] The YAML file path (keep this file secure).
				#
				def use_yaml( yaml_file )
					
					File.exist?(yaml_file) || FileUtils.touch(yaml_file)
					@token_store = YamlTokenStore.new( yaml_file )
					@current_config.instance_variable_set('@token_store', @token_store)

				end

				##
				# OAuth: Application Client ID
				#
				def client_id( client_id )
					@current_config.instance_variable_set('@client_id', client_id)
				end

				##
				# OAuth: Application Client Secret
				#
				def client_secret( client_secret )
					@current_config.instance_variable_set('@client_secret', client_secret)
				end

				##
				# OAuth: Azure's Tenant ID.
				#
				# @param [String] tenant_id Tenant identifier (ID) of the Azure AD tenant that issued the token.
				#
				def tenant_id( tenant_id )
					@current_config.instance_variable_set('@tenant_id', tenant_id)
				end

				##
				# Required Resource Access
				#
				# @param [String] Get the resourceAppId from the manifest of your application added to the Active Directory.
				#
				def resource_id( resource_id )
					@current_config.instance_variable_set('@resource_id', resource_id)
				end

				##
				# Set a new configuration for a specific scope, in order to support multiple connections to different applications.
				# Provide a block with the configuration parameters.
				#
				# @param [Symbol] scope_name Scope name
				#
				def scope( scope_name, &block )
					scopes = @config.instance_variable_get('@scopes')
					scopes[scope_name] = @current_config = Config.new(scope_name)

					@current_config.instance_variable_set('@token_store', @token_store)

					instance_eval(&block)
					@current_config = @config
				end

			end

		end


		class YamlTokenStore

			def initialize(yaml_file)
				@yaml_file = yaml_file
				@yaml_data = YAML::load( yaml_file.open )
				@yaml_data = {} unless @yaml_data.is_a?(Hash)
			end

			def save( scope_name, token_hash )
				data = (@yaml_data[Rails.env.to_s] ||= {})
				data[scope_name.to_s] = token_hash
				File.open(@yaml_file, 'w') { |file| file.write( YAML::dump(@yaml_data) ) }
			end

			def load( scope_name )
				data = @yaml_data[Rails.env.to_s] and data = data[scope_name.to_s] and data.slice('access_token', 'token_type', 'expires_at')
			end

		end

	end


end