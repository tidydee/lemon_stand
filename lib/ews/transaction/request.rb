require 'ews/transaction/validator'
module EWS # :nodoc:
  module Transaction # :nodoc:
    
    # The Request class allows you to build transaction requests for
    # submission to the E-xact Web Service.
    #
    # All requests will result in a financial transaction occurring, with the exception
    # of the <tt>:transaction_details</tt> request, which looks up the details of a pre-existing
    # transaction.
    #
    # The following fields are *mandatory* on all requests:
    #   :gateway_id         the gateway to which this request should be sent
    #   :password           your password for that gateway
    #   :transaction_type   the type of transaction you want to perform
    #
    # Different transaction types will have their own additional requirements when it comes to 
    # mandatory and optional fields, and it is recommended that the E-xact Web Service Programming
    # Reference Guide, v8.5 be consulted. This document is contained in the Webservice Plugin ZIP file:
    # http://www.e-xact.com/wp-content/uploads/2007/06/E-xact_Payment_Webservice_Plug-In.zip
    #
    # Please note that, if your chosen transaction requires it, credit card expiry dates *must* be entered in MMYY format.
    #
    # =Allowable transaction types
    #  :purchase
    #  :pre_auth
    #  :pre_auth_completion
    #  :forced_post
    #  :refund
    #  :pre_auth_only
    #  :purchase_correction
    #  :refund_correction
    #  :void
    #  :tagged_purchase
    #  :tagged_pre_auth
    #  :tagged_pre_auth_completion
    #  :tagged_void
    #  :tagged_refund
    #  :tagged_online_debit_refund
    #  :recurring_seed_pre_auth
    #  :recurring_seed_purchase
    #  :idebit_purchase
    #  :idebit_refund
    #  :secure_storage
    #  :secure_storage_eft
    #  :transaction_details
    class Request
      include Validator

      # yeah, it's ugly, but otherwise RDoc won't pick them up
      attr_accessor :errors
      attr_accessor :gateway_id, :password, :transaction_type, :amount, :surcharge_amount, :cc_number, :transaction_tag, :track1, :track2, :pan, :authorization_num, :cc_expiry, :cardholder_name
      attr_accessor :cc_verification_str2, :cvd_presence_ind, :tax1_amount, :tax1_number, :tax2_amount, :tax2_number, :secure_auth_required, :secure_auth_result

      # AVS - Address Verification, 
      attr_accessor :cc_verification_str1
      [:avs_test_flag, :avs_street_address,  :avs_unit_no, :avs_po_box, :avs_postal_code].each { |m|
        class_eval <<-METHOD_EOS
          def #{m.to_s}
            @#{m.to_s}
          end
          def #{m.to_s}=(v)
            @#{m.to_s} = v
            calculate_verification_str1
          end
    METHOD_EOS
      }
      
      attr_accessor :ecommerce_flag, :xid, :cavv, :cavv_algorithm, :reference_no, :customer_ref, :reference_3, :language, :client_ip, :client_email, :zip_code 
    
      # Initialize a Request with a hash of values 
      def initialize(hash = {})
        hash.each {|k,v| self.send "#{k.to_s}=", v}
        @errors = {}
      end

      # Set the <tt>transasction_type<tt> using either a symbol or the relevant code, e.g: for a purchase
      # you can use either <tt>:purchase</tt> or <tt>'00'</tt>
      def transaction_type=(type_sym)
        # assume we're given a symbol, so look up the code
        value = @@transaction_codes[type_sym]
        # if nothing found, then maybe we were given an actual code?
        if(value.nil?)
          raise "invalid transaction_type supplied #{type_sym}" unless @@transaction_codes.values.include?(type_sym)
          value = type_sym
        end

        @transaction_type = value
      end

      # Indicates whether or not this transaction is a <tt>:transaction_details</tt> transaction
      def is_find_transaction?
        self.transaction_type == "CR"
      end
    
    private
    
      @@transaction_codes = {
        :purchase => '00',
        :pre_auth => '01',
        :pre_auth_completion => '02',
        :forced_post => '03',
        :refund => '04',
        :pre_auth_only => '05',
        :purchase_correction => '11',
        :refund_correction => '12',
        :void => '13',
        :tagged_purchase => '30',
        :tagged_pre_auth => '31',
        :tagged_pre_auth_completion => '32',
        :tagged_void => '33',
        :tagged_refund => '34',
        :tagged_online_debit_refund => '35',
        :recurring_seed_pre_auth => '40',
        :recurring_seed_purchase => '41',
        :idebit_purchase => '50',
        :idebit_refund => '54',
        :secure_storage => '60',
        :secure_storage_eft => '61',
        :transaction_details => 'CR'
      }.freeze unless defined?(@@transaction_codes)
      
      # Calculate verification str1, callback method invoked after the avs_*= methods
      def calculate_verification_str1
        self.cc_verification_str1 = ''
        self.cc_verification_str1 << (self.avs_test_flag || '')
        unless self.avs_street_address.nil? 
          self.cc_verification_str1 << (self.avs_street_address || '')
          self.cc_verification_str1 << (self.avs_unit_no || '')
        else
          self.cc_verification_str1 << (self.avs_po_box || '')
        end
        unless self.avs_postal_code.nil?
          self.cc_verification_str1 << '|' << self.avs_postal_code
        end
      end
    end
  end
end
