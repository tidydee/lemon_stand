module EWS # :nodoc:
  module Transaction # :nodoc:
    
    # As its name suggests, this class allows you to generate fake responses,
    # allowing you to stub out the web service in your testing.
    #
    # The most likely responses have been catered for here, but if you require a fake response
    # which is not provided for here, the best approach would be to generate a fake valid response
    # and then adjust its attributes (in consultation with E-xact's Web Service Programming Reference
    # Guide) to match the particular response you want.
    #
    # Example:
    #
    #   describe "Fake requests" do
    #     it "should stub sending" do
    #       request = {:nonsense => "this is nonsense"}
    #       fake_response = EWS::Transaction::FakeResponse.valid(request) # a fake valid response
    #       transporter = EWS::Transporter.new
    #       transporter.stubs(:submit).returns(fake_response)
    # 
    #       response = transporter.submit(request)
    #       response.should == fake_response
    #       response.should be_approved
    #       response.bank_message.should == "APPROVED"
    #     end
    #   end
    class FakeResponse
      
      # fake a valid response
      def self.valid(request)
        build_response(request)
      end
      # fake a declined response
      def self.declined(request)
        response = build_response(request, {:bank_resp_code => '200'})
      end

      # fake a response indicating an invalid credit card number
      def self.invalid_cc_number(request)
        build_response(request, {:exact_resp_code => '22'})
      end
      # fake a response indicating an invalid credit card expiry date
      def self.invalid_cc_expiry(request)
        build_response(request, {:exact_resp_code => '25'})
      end
      # fake a response indicating an invalid amount
      def self.invalid_amount(request)
        build_response(request, {:exact_resp_code => '26'})
      end
      # fake a response indicating an invalid credit card holder name
      def self.invalid_cardholder_name(request)
        build_response(request, {:exact_resp_code => '27'})
      end
      # fake a response indicating an invalid authorisation number
      def self.invalid_auth_num(request)
        build_response(request, {:exact_resp_code => '28'})
      end
      # fake a response indicating an invalid credit card verification string
      def self.invalid_cc_verification_str(request)
        build_response(request, {:exact_resp_code => '31'})
      end
      # fake a response indicating an invalid transaction code
      def self.invalid_transaction_code(request)
        build_response(request, {:exact_resp_code => '32'})
      end
      # fake a response indicating an invalid reference number
      def self.invalid_reference_no(request)
        build_response(request, {:exact_resp_code => '57'})
      end
      # fake a response indicating an invalid address verification string
      def self.invalid_avs(request)
        build_response(request, {:exact_resp_code => '58'})
      end
      
      private
      
      def self.build_response(request, options = {})
        # copy all the information from the request
        exact_resp_code = options[:exact_resp_code] || '00'
        bank_resp_code = options[:bank_resp_code] || '000'
  
        response = EWS::Transaction::Mapping.json_to_response(EWS::Transaction::Mapping.request_to_json(request))
        response.transaction_tag = rand(9000)
        
        response.exact_resp_code = exact_resp_code
        response.exact_message = @@exact_messages[exact_resp_code]
        if (exact_resp_code == '00')
          response.bank_resp_code = bank_resp_code
          response.bank_resp_code_2 = '00'
          response.bank_message = (bank_resp_code == '000') ? "APPROVED" : "Declined"
        end

        response.error_number = 0 # no http errors occurred
        response.transaction_error = (exact_resp_code == '00') ? 0 : 1
        response.transaction_approved = (exact_resp_code == '00' and bank_resp_code == '000') ? 1 : 0
        
        response.authorization_num = "ET#{response.transaction_tag}" if response.approved?

        response.sequence_no = "#{rand(100000)}"
        response.avs = 'X'  # exact match, 9-digit zip
        response.cvv2 = 'M' # match
        
        # great snowboarding ;-)
        response.merchant_name = "Fernie Alpine Resort"
        response.merchant_address = "5339 Fernie Ski Hill Rd."
        response.merchant_city = "Fernie"
        response.merchant_province = "BC"
        response.merchant_country = "Canada"
        response.merchant_postal = "V0B 1M6"
        response.merchant_url = "http://skifernie.com/"
        
        response.ctr = "Let's pretend this is a receipt"
        
        response
      end
      
      @@exact_messages = {
        '00' => 'Transaction Normal',
        '08' => 'CVV2/CID/CVC2 Data not verified',
        '22' => 'Invalid Credit Card Number',
        '25' => 'Invalid Expiry Date',
        '26' => 'Invalid Amount',
        '27' => 'Invalid Card Holder',
        '28' => 'Invalid Authorization Number',
        '31' => 'Invalid Verification String',
        '32' => 'Invalid Transaction Code',
        '57' => 'Invalid Reference Number',
        '58' => 'Invalid AVS String'
      }
      
      @@bank_messages = {
        '000' => "APPROVED",
        '200' => "Declined"
      }
    end
  end
end