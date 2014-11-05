module EWS # :nodoc:
  module Transaction # :nodoc:

    # This class encapsulates all the data returned from the E-xact Web Service.
    class Response

      attr_accessor :logon_message, :error_number, :error_description, :transaction_error, :transaction_approved
      attr_accessor :exact_resp_code, :exact_message, :bank_resp_code, :bank_message, :bank_resp_code_2
      attr_accessor :sequence_no, :avs, :cvv2, :retrieval_ref_no, :cavv_response
      attr_accessor :merchant_name, :merchant_address, :merchant_city, :merchant_province, :merchant_country, :merchant_postal, :merchant_url, :ctr

      attr_accessor :gateway_id, :password, :transaction_type, :amount, :surcharge_amount, :cc_number, :transaction_tag, :track1, :track2, :pan, :authorization_num, :cc_expiry, :cardholder_name
      attr_accessor :cc_verification_str1, :cc_verification_str2, :cvd_presence_ind, :tax1_amount, :tax1_number, :tax2_amount, :tax2_number, :secure_auth_required, :secure_auth_result
      attr_accessor :ecommerce_flag, :xid, :cavv, :cavv_algorithm, :reference_no, :customer_ref, :reference_3, :language, :client_ip, :client_email, :user_name, :zip_code 

      # Indicates whether or not the transaction was approved
      def approved?
        self.transaction_approved == 1
      end
    end
  end
end