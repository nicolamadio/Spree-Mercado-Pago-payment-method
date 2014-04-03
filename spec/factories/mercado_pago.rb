FactoryGirl.define do
  
  factory :mercado_pago_payment_method, class: PaymentMethod::MercadoPago do
    name "MercadoPago Payment Method"
  end
end
