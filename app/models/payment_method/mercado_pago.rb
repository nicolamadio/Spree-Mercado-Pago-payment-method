# -*- encoding : utf-8 -*-
class PaymentMethod::MercadoPago < Spree::PaymentMethod

  preference :client_id, :string
  preference :client_secret, :string
  preference :mode, :string, default: 'modal'
  preference :success_url, :string, default: ''
  preference :failure_url, :string, default: ''
  preference :pending_url, :string, default: ''
  preference :sandbox, :boolean, default: true

  def payment_profiles_supported?
    false
  end

  def actions
    %w{capture void}
  end

  # Indicates whether its possible to void the payment.
  def can_void?(payment)
    payment.state != 'void'
  end

  def auto_capture?
    false
  end

  def authorize(amount, source, gateway_options)
    ActiveMerchant::Billing::Response.new(true, "", {}, {})
  end

  def capture(*args)
    ActiveMerchant::Billing::Response.new(true, "", {}, {})
  end

  def void(*args)
    ActiveMerchant::Billing::Response.new(true, "", {}, {})
  end
end
