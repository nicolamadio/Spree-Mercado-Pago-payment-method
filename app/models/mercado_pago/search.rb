class MercadoPago
  module Search

    #Get the external reference based on mercado_pago id, given on IPN notification
    def get_external_reference(mercado_pago_id)
      response = send_notification_request mercado_pago_id
      if response
        response['collection']['external_reference']
      end
    end

    #Get the status of a mercado_pago payment
    def get_payment_status(external_reference)
      response = send_search_request({:external_reference => external_reference, :access_token => access_token})
      response['results'][0]['collection']['status']
    end

    private

    def send_notification_request(mercado_pago_id)
      url = create_url(notifications_url(mercado_pago_id), access_token: @auth_response['access_token'])
      options = {:content_type => 'application/x-www-form-urlencoded', :accept => 'application/json'}
      get(url, options, quiet: true)
    end

    def send_search_request(params, options={})
      url = create_url(search_url, params)
      options = {:content_type => 'application/x-www-form-urlencoded', :accept => 'application/json'}
      get(url, options)
    end

    def notifications_url(mercado_pago_id)
      sandbox_part = sandbox ? 'sandbox/' : ''
      "https://api.mercadolibre.com/#{sandbox_part}collections/notifications/#{mercado_pago_id}"
    end

    def search_url
      sandbox_part = sandbox ? 'sandbox/' : ''
      "https://api.mercadolibre.com/#{sandbox_part}collections/search"
    end
  end
end