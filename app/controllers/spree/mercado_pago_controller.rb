# -*- encoding : utf-8 -*-
require 'rest_client'

module Spree
  class MercadoPagoController < Spree::StoreController
    before_filter :check_state, only: [:success, :pending]

    def success
      current_order.next
    end

    def pending
      current_order.next
    end

    def failure
    end

    def payment
      return unless current_order.payment?
      selected_method_id = params[:payment_method_id]
      @payment_method = Spree::PaymentMethod.find(selected_method_id)

      success_url = @payment_method.preferred_success_url
      pending_url = @payment_method.preferred_pending_url
      failure_url = @payment_method.preferred_failure_url

      success_url = spree.mercado_pago_success_url(order_number: @current_order.number) if success_url.empty?
      pending_url = spree.mercado_pago_pending_url(order_number: @current_order.number) if pending_url.empty?
      failure_url = spree.mercado_pago_failure_url(order_number: @current_order.number) if failure_url.empty?

      back_urls = {
          success: success_url,
          pending: pending_url,
          failure: failure_url,
      }

      mercado_pago_client = SpreeMercadoPagoClient.new(@current_order, back_urls)

      if mercado_pago_client.authenticate && mercado_pago_client.send_data
        redirect_to mercado_pago_client.redirect_url
      else
        render :action => 'spree/checkout/mercado_pago_error'
      end

    end

    private

    def check_state
      flash[:error] = "Check checkout success"
      redirect_to failure
    end
  end
end
