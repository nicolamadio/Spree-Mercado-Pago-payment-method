# -*- encoding : utf-8 -*-
require 'rest_client'

module Spree
  class MercadoPagoController < Spree::StoreController
    before_filter :current_order,  :check_order_state, :check_payment_state, :current_payment, only: [:success, :pending]
    before_filter :get_payment_method, only: [:payment]
    before_filter :create_payment, only: [:payment]

    def success
      @current_order.next!
      @current_payment.purchase!
    end

    def pending
      @current_order.next!
    end

    def failure
      current_order
      flash[:error] = I18n.t(:mp_invalid_order)
    end

    def payment
      return unless current_order.payment?

      mercado_pago_client = create_client

      if mercado_pago_client.authenticate && mercado_pago_client.send_data
        redirect_to mercado_pago_client.redirect_url
      else
        render :action => 'spree/checkout/mercado_pago_error'
      end

    end

    # The current payment find through order.payments.find(id)
    def current_payment
      @current_payment = current_order.payments.find(params[:external_reference]) unless @current_payment
      @current_payment
    end

    private

    def payer_data
      email = get_email
      {email:email}
    end

    def create_client
      back_urls = get_back_urls
      options = {
          sandbox: @payment_method.preferred_sandbox,
          payment: @mp_payment
      }
      options[:payer] = payer_data
      SpreeMercadoPagoClient.new(@current_order, @mp_payment, back_urls[:success], back_urls[:pending], back_urls[:failure], options)
    end

    def get_email
      user = spree_current_user

      if user
        user.email
      else
        current_order.email
      end
    end

    def get_back_urls
      success_url = @payment_method.preferred_success_url
      pending_url = @payment_method.preferred_pending_url
      failure_url = @payment_method.preferred_failure_url

      success_url = spree.mercado_pago_success_url(order_number: @current_order.number) if success_url.empty?
      pending_url = spree.mercado_pago_pending_url(order_number: @current_order.number) if pending_url.empty?
      failure_url = spree.mercado_pago_failure_url(order_number: @current_order.number) if failure_url.empty?

      {
          success: success_url,
          pending: pending_url,
          failure: failure_url,
      }
    end

    def get_payment_method
      selected_method_id = params[:payment_method_id]
      @payment_method = Spree::PaymentMethod.find(selected_method_id)
    end

    def check_order_state
      check_state { current_order.payment? }
    end

    def check_payment_state
      check_state { @current_order.payments.where(id: params[:external_reference]).exists? }
    end

    def check_state
      unless yield
        flash[:error] = I18n.t(:mp_invalid_order)
        redirect_to root_path
      end
    end

    def create_payment
      @mp_payment = current_order.payments.create!({:source => @payment_method, :amount => @current_order.total, :payment_method => @payment_method})
    end
  end
end
