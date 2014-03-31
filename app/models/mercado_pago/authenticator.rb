module MercadoPago
  module Authenticator

    #Authenticate the mercado_pago client_secret and client_id
    #Returns a hash with the access_token
    def authenticate
      response = send_authentication_request
      @auth_response = ActiveSupport::JSON.decode(response)
    rescue RestClient::Exception => e
      @errors << I18n.t(:mp_authentication_error)
      raise MercadoPagoException.new e.message
    end

    #If is already authenticated, return the access_token. if not, authenticate first.
    def access_token
      unless @auth_response
        authenticate
      end
      @auth_response['access_token']
    end

    private

    def send_authentication_request
      RestClient.post(
          'https://api.mercadolibre.com/oauth/token',
          {:grant_type => 'client_credentials', :client_id => client_id, :client_secret => client_secret},
          :content_type => 'application/x-www-form-urlencoded', :accept => 'application/json'
      )
    end


  end
end