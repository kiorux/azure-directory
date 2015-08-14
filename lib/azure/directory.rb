require 'azure/directory/version'
require 'azure/directory/config'
require 'oauth2'

module Azure
	module Directory
		
		GRAPH_API_VERSION = '1.5'

		class Client

			attr_reader :oauth, :oauth_token, :config

			##
			# @param [Symbol] scope (:main) The scope to use with this client.
			#
			def initialize(scope = :main, &block)
				@config = Azure::Directory.configuration
				@config = @config.using(scope) if @config.scope_name != scope

				@oauth = OAuth2::Client.new( @config.client_id, @config.client_secret, 
					                         :site => 'https://login.windows.net/', 
					                         :authorize_url =>  "/#{@config.tenant_id}/oauth2/authorize", 
					                         :token_url => "/#{@config.tenant_id}/oauth2/token" ) do |faraday|
					faraday.request :url_encoded
					faraday.adapter Faraday.default_adapter
					yield(faraday) if block_given?
				end
				
				if token_hash = @config.load_token
					@oauth_token = OAuth2::AccessToken.from_hash(@oauth, token_hash)

				else
					fetch_access_token!
				end
				
			end


			##
			# Do the service-to-service access token request and 
			# save it to the Token Store defined in the configuration.
			#
			# @return [OAuth2::AccessToken] a access token for the current session.
			#
			def fetch_access_token!
				@oauth_token = oauth.get_token( :client_id => config.client_id, 
					                            :client_secret => config.client_secret, 
					                            :grant_type => 'client_credentials', 
					                            :response_type => 'client_credentials', 
					                            :resource => config.resource_id )

				token_hash = { 'access_token' => oauth_token.token, 'token_type' => oauth_token.params['token_type'], 'expires_at' => oauth_token.expires_at }
				config.save_token(token_hash)
				oauth_token
			end


			##
			# Get all users from the active directory
			#
			# @return [Array]
			#
			# @see https://msdn.microsoft.com/en-us/library/azure/hh974483.aspx User
			def find_users(params = nil)
				users = get('/users', params)
				users['value'] if users.is_a?(Hash)
			end



			##
			# Get user by email
			#
			# @return [Hash] The user's information or nil if not found
			#
			# @see https://msdn.microsoft.com/en-us/library/azure/hh974483.aspx User
			def find_user_by_email(email, params = nil)
				get("/users/#{email}", params)
			end



			## 
			# Creates a unique user on the Active Directory
			#
			# @param [String] email User unique email inside the AD Domain.
			# @param [String] given_name 
			# @param [String] family_name
			# @param [String] password The password will set up with `forceChangePasswordNextLogin = true`by default.
			# @param [Hash] params If you wish to add or override specific parameters from the Graph API.
			# 
			# @option params [Boolean] 'accountEnabled' (true)
			# @option params [String] 'displayName' Will concatenate given_name and family_name
			# @option params [String] 'mailNickname' Username extracted from the email.
			# @option params [String] 'passwordProfile' { "password" => password, "forceChangePasswordNextLogin" => true }
			# @option params [String] 'userPrincipalName' email
			# @option params [String] 'givenName' given_name
			# @option params [String] 'surname' family_name
			# @option params [String] 'usageLocation' 'US'
			#
			# @return [Hash] The user's information or nil if unsuccessful 
			#
			# @see https://msdn.microsoft.com/en-us/library/azure/hh974483.aspx User
			#
			def create_user(email, given_name, family_name, password, params = {})
				params = { 'accountEnabled'    => true,
				           'displayName'       => "#{given_name} #{family_name}",
				           'mailNickname'      => email.split('@').first,
				           'passwordProfile'   => { "password" => password, "forceChangePasswordNextLogin" => true },
				           'userPrincipalName' => email,
				           'givenName'         => given_name,
				           'surname'           => family_name,
				           'usageLocation'     => 'US'
				}.merge(params)

				post('users', params)
			end



			##
			# Updates the current user with specified parameters
			#
			# @param [String] params See the create_user method's params
			#
			# @return [Boolean] True if update was successful
			#
			def update_user(email, params = nil)
				patch("users/#{email}", params) == :no_content
			end



			##
			# Updates the user's password
			#
			# @param [String] email
			# @param [String] password A valid password
			# @param [String] force_change_password_next_login True by default
			#
			# @return [Hash] The user's information or nil if unsuccessful
			#
			def update_user_password(email, password, force_change_password_next_login = true)
				params = { 'passwordProfile' => { 
					           'password' => password, 
					           'forceChangePasswordNextLogin' => force_change_password_next_login } }

				patch("users/#{email}", params) == :no_content
			end


			##
			# Obtain the SubscribedSkus.
			#
			def get_subscribed_skus
				get('subscribedSkus')
			end


			##
			# Assignment of subscriptions for provisioned user account.
			#
			# @param [String] sku_part_number Using this name we get the skuId to do the proper assignment. 
			#
			# @example
			#   assign_license('username@domain.com', 'STANDARDWOFFPACK_STUDENT')
			#
			def assign_license(email, sku_part_number)
				skus = get('subscribedSkus')['value']
				return nil unless sku = skus.detect{ |_sku| _sku['skuPartNumber'] == sku_part_number }
				
				post("users/#{email}/assignLicense", { "addLicenses" => [ {"disabledPlans" => [], "skuId" => sku['skuId'] }], "removeLicenses" => [] })
			end


			##
			# Deletes an existing user by email
			#
			# @param [String] email User email
			#
			# @return [Boolean] True if the user was deleted
			#
			def delete_user(email)
				delete("users/#{email}") == :no_content
			end



			private 

				def get(path, params = nil)
					request(:get, path, params)
				end

				def post(path, params)
					request(:post, path, nil, params)
				end

				def patch(path, params)
					request(:patch, path, nil, params)
				end

				def delete(path)
					request(:delete, path)
				end

				def request(method, path, params = nil, body = nil)
					fetch_access_token! if oauth_token.expired?

					response = oauth_token.request(method, graph_url(path), build_params(params, body).merge(:raise_errors => false) )
					if response.error
						unless (error = response.parsed).is_a?(Hash) and error['odata.error']['code'] == 'Request_ResourceNotFound'
							Rails.logger.error("OAuth2 Error (#{response.status}): #{response.parsed}" )
						end
						return nil 
					end
					
					case response.status
					when 200, 201 then return response.parsed
					when 204 then return :no_content
					end

					response

				end


				def graph_url(path)
					"https://graph.windows.net/#{config.tenant_id}/#{path}"
				end

				def build_params(params = nil, body = nil)
					params ||= {}
					body = body.to_json if body and body.class.method_defined?(:to_json)

					{ :params => params.merge!( 'api-version' => GRAPH_API_VERSION ),
					  :body => body,
					  :headers => {'Content-Type' => 'application/json'} }
				end
		end


	end
end
