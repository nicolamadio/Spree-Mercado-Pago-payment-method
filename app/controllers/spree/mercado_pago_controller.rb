# -*- encoding : utf-8 -*-
module Spree

  class MercadoPagoController < Spree::StoreController

    before_filter :verify_external_reference, :current_payment, only: [:success, :pending]
    before_filter :payment_method_by_external_reference, :only => [:success, :pending, :failure]
    before_filter :verify_payment_state, :only => [:payment]
    skip_before_filter :verify_authenticity_token, :only => [:notification]

    # If the order is in 'payment' state, redirects to Mercado Pago Checkout page
    def payment
      mp_payment = current_order.payments.create!({:source => payment_method,
                                                   :amount => current_order.total,
                                                   :payment_method => @payment_method})

      back_urls = get_back_urls

      if provider.create_preference(current_order, mp_payment,
                                    back_urls[:success], back_urls[:pending], back_urls[:failure])
        redirect_to provider.redirect_url
      else
        render 'spree/checkout/mercado_pago_error'
      end
    end

    def pending
      render_result :pending
    end

    def success
      render_result :success
    end

    def failure
      render_result :failure
    end

    # "Mercado Pago" IPN
    def notification
      # TODO: FIXME. This is not the best way. What happens with multiples MercadoPago payments?
      # TODO: Log all IPN messages
      @payment_method = ::PaymentMethod::MercadoPago.first

      external_reference = provider.get_external_reference params[:id]

      if external_reference
        puts "Processing payment for #{external_reference}"
	payment = current_payment external_reference
        if payment
          process_payment payment
        else
          puts "Ignoring payment #{external_reference}. Payment not found!"
        end
      end

      render status: :ok, nothing: true
    end

    private

    def render_result(current_state)
      process_payment current_payment
      if success_order? and current_state != :success
        redirect_to_state :success
      end
      if failed_payment? and current_state != :failure
        redirect_to_state :failure
      end
      if pending_payment? and current_state != :pending
        redirect_to_state :pending
      end

    end

    def payment_method
      @payment_method ||= ::PaymentMethod::MercadoPago.find (params[:payment_method_id])
    end

    def provider
      @provider ||= payment_method.provider({:payer => payer_data})
    end

    def current_payment(external_reference=params[:external_reference])
      @current_payment ||= Spree::Payment.find_by identifier: external_reference
    end

    def success_order?
      current_payment.completed? and current_payment.order.completed?
    end

    def pending_payment?
      (current_payment.pending? || current_payment.processing?) and current_payment.order.completed?
    end

    def failed_payment?
      current_payment.failed? || current_payment.invalid?
    end

    def redirect_to_state(status)
      redirect_to controller: 'spree/mercado_pago', action: status, external_reference: external_reference
    end

    def process_payment(payment)
      order = payment.order
      order.next
      payment.reload
      payment_method.try_capture payment
    end

    # Get payer info for sending within Mercado Pago request
    def payer_data
      email = get_email
      {email: email}
    end

    def external_reference
      params[:external_reference]
    end

    # Get email for using in Mercado Pago request
    def get_email
      user = spree_current_user

      user.email if user
      current_order.email if current_order
    end

    # Get urls callbacks.
    # If the current 'payment method' haven't any callback, the default will be used
    def get_back_urls
      success_url = payment_method.preferred_success_url
      pending_url = payment_method.preferred_pending_url
      failure_url = payment_method.preferred_failure_url

      success_url = spree.mercado_pago_success_url(order_number: current_order.number) if success_url.empty?
      pending_url = spree.mercado_pago_pending_url(order_number: current_order.number) if pending_url.empty?
      failure_url = spree.mercado_pago_failure_url(order_number: current_order.number) if failure_url.empty?

      {
          success: success_url,
          pending: pending_url,
          failure: failure_url,
      }
    end

    def verify_external_reference
      external_reference = params[:external_reference]
      unless external_reference
        flash[:error] = I18n.t(:mp_invalid_order)
        redirect_to root_path
      end
    end

    def verify_payment_state
      redirect_to root_path unless current_order.payment?
    end

    def payment_method_by_external_reference
      @payment_method = current_payment.payment_method
    end
  end

end
