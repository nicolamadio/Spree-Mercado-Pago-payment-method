MercadoPago = {
    hidePaymentSaveAndContinueButton: function(paymentMethod) {
        if (MercadoPago.paymentMethodID && paymentMethod.val() == MercadoPago.paymentMethodID) {
            $('.continue').hide();
        } else {
            $('.continue').show();
        }
    }
};

$(document).ready(function() {
    function openCheckout(data, textStatus, jqXHR){
        $MPC.openCheckout( {
            url: data['url'],
            mode: data['mode'],
            onreturn: function(data) {
                console.log('hello world!');
            }
        })
    }

    checkedPaymentMethod = $('div[data-hook="checkout_payment_step"] input[type="radio"]:checked');
    MercadoPago.hidePaymentSaveAndContinueButton(checkedPaymentMethod);
    paymentMethods = $('div[data-hook="checkout_payment_step"] input[type="radio"]').click(function (e) {
        MercadoPago.hidePaymentSaveAndContinueButton($(e.target));
    });

    $('#mercado_pago_button').click(function(event){
        event.preventDefault();
        event.stopPropagation();
        $(event.target).prop("disabled",true);
        $.ajax({
            type: "POST",
            url: $(this).data('url'),
            data: {payment_method_id: $(this).data('payment-method-id')},
            success: openCheckout,
            dataType: 'json'
        });
    });
});