require 'builder'

module EWS # :nodoc:
  module Transaction # :nodoc:

    # This class handles encoding of transaction requests to the various transport formats,
    # and the decoding of responses to transaction response objects.
    #
    # The supported formats are:
    #   * REST/JSON
    #   * REST/XML
    #   * SOAP/XML
    class Mapping # :nodoc:

      XML_REQUEST_TAGS_TO_ATTRS = {
        :ExactID => :gateway_id,
        :Password => :password,
        :Transaction_Type => :transaction_type,
        :DollarAmount => :amount,
        :SurchargeAmount => :surcharge_amount,
        :Card_Number => :cc_number,
        :Transaction_Tag => :transaction_tag,
        :Track1 => :track1,
        :Track2 => :track2,
        :PAN => :pan,
        :Authorization_Num => :authorization_num,
        :Expiry_Date => :cc_expiry,
        :CardHoldersName => :cardholder_name,
        :VerificationStr1 => :cc_verification_str1,
        :VerificationStr2 => :cc_verification_str2,
        :CVD_Presence_Ind => :cvd_presence_ind,
        :ZipCode => :zip_code,
        :Tax1Amount => :tax1_amount,
        :Tax1Number => :tax1_number,
        :Tax2Amount => :tax2_amount,
        :Tax2Number => :tax2_number,
        :Secure_AuthRequired => :secure_auth_required,
        :Secure_AuthResult => :secure_auth_result,
        :Ecommerce_Flag => :ecommerce_flag,
        :XID => :xid,
        :CAVV => :cavv,
        :CAVV_Algorithm => :cavv_algorithm,
        :Reference_No => :reference_no,
        :Customer_Ref => :customer_ref,
        :Reference_3 => :reference_3,
        :Language => :language,
        :Client_IP => :client_ip,
        :Client_Email => :client_email
      } unless defined?(XML_REQUEST_TAGS_TO_ATTRS)

      XML_RESPONSE_TAGS_TO_ATTRS = {
        :LogonMessage => :logon_message,
        :Error_Number =>  :error_number,
        :Error_Description => :error_description,
        :Transaction_Error => :transaction_error,
        :Transaction_Approved => :transaction_approved,
        :EXact_Resp_Code => :exact_resp_code,
        :EXact_Message => :exact_message,
        :Bank_Resp_Code => :bank_resp_code,
        :Bank_Message => :bank_message,
        :Bank_Resp_Code_2 => :bank_resp_code_2,
        :SequenceNo => :sequence_no,
        :AVS => :avs,
        :CVV2 => :cvv2,
        :Retrieval_Ref_No => :retrieval_ref_no,
        :CAVV_Response => :cavv_response,
        :MerchantName => :merchant_name,
        :MerchantAddress => :merchant_address,
        :MerchantCity => :merchant_city,
        :MerchantProvince => :merchant_province,
        :MerchantCountry => :merchant_country,
        :MerchantPostal => :merchant_postal,
        :MerchantURL => :merchant_url,
        :CTR => :ctr
      }.merge(XML_REQUEST_TAGS_TO_ATTRS) unless defined?(XML_RESPONSE_TAGS_TO_ATTRS)

      def self.request_to_json(request)
        request.to_json
      end
      def self.request_to_rest(request)
        xml = Builder::XmlMarkup.new

        xml.instruct!
        xml.tag! 'Transaction' do
          add_request_hash(xml, request)
        end
        xml.target!
      end
      def self.request_to_soap(request)
        xml = Builder::XmlMarkup.new(:indent => 2)

        xml.instruct!
        xml.tag! 'soap:Envelope', REQUEST_ENVELOPE_NAMESPACES do
          xml.tag! 'soap:Body' do
            xml.tag! 'n1:SendAndCommit', REQUEST_SAC_ATTRIBUTES do
              xml.tag! 'SendAndCommitSource', REQUEST_SAC_SOURCE_ATTRIBUTES do
                add_request_hash(xml, request)
              end
            end
          end
        end
        xml.target!
      end
    
      def self.json_to_response(content)
        response = EWS::Transaction::Response.new
        ActiveSupport::JSON.decode(content).each { |k,v| response.send "#{k}=", v if response.respond_to?("#{k}=") }
        response
      end
      def self.rest_to_response(content)
        response = EWS::Transaction::Response.new
        xml = REXML::Document.new(content)
        root = REXML::XPath.first(xml, "//TransactionResult")
        response_xml_string_to_hash(response, root) if root
        response
      end
      def self.soap_to_response(content)
        response = EWS::Transaction::Response.new
        xml = REXML::Document.new(content)
        root = REXML::XPath.first(xml, "//types:TransactionResult")
        if root
          # we have a normal response
          response_xml_string_to_hash(response, root)
        else
          # check if we have an error response
          faultErrorRoot = REXML::XPath.first(xml, "//soap:Fault")
          unless faultErrorRoot.nil?
            # if we do, then see if we have a details section
            detailRoot = REXML::XPath.first(faultErrorRoot, "detail")
            if detailRoot.nil? or !detailRoot.has_elements?
              # no details section, so we have an XML parsing error and should raise an exception
              faultString = REXML::XPath.first(faultErrorRoot, "faultstring")
              raise faultString.text
            else
              errorElem = REXML::XPath.first(detailRoot, "error")
              # do have details, so figure out the error_number and error_description
              errorNumElem = errorElem.attribute("number")
              response.error_number = errorNumElem.value.to_i unless errorNumElem.nil?
              errorDescElem = errorElem.attribute("description")
              response.error_description = errorDescElem.value unless errorDescElem.nil?
            end
          end
        end
        response
      end
    
      private

      # Adds the request's attributes to the XmlMarkup.
      def self.add_request_hash(xml, request)
        XML_REQUEST_TAGS_TO_ATTRS.each do |k, v|
          xml.tag! k.to_s, request.send(v.to_s)
        end
      end
      
      # parses xml response elements into the response attributes
      def self.response_xml_string_to_hash(response, root)
        root.elements.to_a.each do |node|
          gwlib_prop_name = XML_RESPONSE_TAGS_TO_ATTRS[node.name.to_sym]
          unless gwlib_prop_name.nil?
            value = case gwlib_prop_name
            when :transaction_approved, :transaction_error
              (node.text == "true") ? 1 : 0
            when :transaction_tag
              node.text.to_i
            else
              node.text
            end

            response.send "#{gwlib_prop_name}=", value
          end
        end
      end
    
      REQUEST_ENVELOPE_NAMESPACES = {
        "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
        "xmlns:soap" => "http://schemas.xmlsoap.org/soap/envelope/",
        "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
      }
      REQUEST_SAC_ATTRIBUTES = {
        "xmlns:n1" => "http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/Request",
        "soap:encodingStyle" => "http://schemas.xmlsoap.org/soap/encoding/"
      }
      REQUEST_SAC_SOURCE_ATTRIBUTES = {
        "xmlns:n2" => "http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/encodedTypes",
        "xsi:type" => "n2:Transaction"
      }
    end
  end
end