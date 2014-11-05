require 'net/https'

module EWS # :nodoc:

  # A Transporter is responsible for communicating with the E-xact Web Service in
  # whichever dialect is chosen by the user. The available options are:
  #   :json     REST with JSON payload
  #   :rest     REST with XML payload (default)
  #   :soap     SOAP
  #
  # The Transporter will connect to the service, using SSL if required, and will
  # encode Reqests to send to the service, and decode Responses received from the
  # service.
  #
  # Once configured to connect to a particular service, it can be used repeatedly
  # to send as many transactions as required.
  class Transporter

    # Initialize a Transporter.
    #
    # You can specify the URL you would like the Transporter to connect to, although it defaults
    # to https://api.e-xact.com, the location of our transaction processing web service.
    #
    # You can also specify a hash of options as follows:
    #   :transport_type   the transport_type for this transporter (defaults to :rest)
    #
    # The default certificates are those required to connect to https://api.e-xact.com and the
    # default <tt>transport_type</tt> is <tt>:rest</tt>. The default <tt>transport_type</tt> can be overridden on a per-transaction
    # basis, if you choose to do so, by specifying it as a parameter to the <tt>submit</tt> method.
    def initialize(url = "https://api.e-xact.com", options = {})
      @url = URI.parse(url.gsub(/\/$/,''))
      @transport_type = options[:transport_type] || :rest

      @@issuer_cert ||= File.dirname(__FILE__)+"/../../certs/equifax_ca.cer"
      @@server_cert ||= File.new(File.dirname(__FILE__)+"/../../certs/exact.cer").read
    end

    # Submit a transaction request to the server
    #
    # <tt>transaction</tt>::  the Request object to encode for transmission to the server
    # <tt>transport_type</tt>::  (optional) the transport type to use for this transaction only. If it is not specified, the Transporter's transport type will be used
    def submit(transaction, transport_type = nil)
      raise "Request not supplied" if transaction.nil?
      return false unless transaction.valid?

      transport_type ||= @transport_type

      raise "Transport type #{transport_type} is not supported" unless @@transport_types.include? transport_type

      transport_details = @@transport_types[transport_type]
      
      request = build_http_request(transaction, transport_type, transport_details[:suffix])
      request.basic_auth(transaction.gateway_id, transaction.password)
      request.add_field "Accept", transport_details[:content_type]
      request.add_field "User-Agent", "exact4r v0.9"
      request.add_field "Content-type", "#{transport_details[:content_type]}; charset=UTF-8"

      response = get_connection.request(request)

      case response
      when Net::HTTPSuccess then EWS::Transaction::Mapping.send "#{transport_type}_to_response", response.body
      else
        r = ::EWS::Transaction::Response.new
        if(transport_type == :soap)
          # we may have a SOAP Fault
          r = EWS::Transaction::Mapping.send "#{transport_type}_to_response", response.body
        end

        # SOAP Fault may already have populated the error_number etc.
        unless r.error_number
          # populate the error number and description
          r.error_number = response.code.to_i
          r.error_description = response.message
        end
        
        r
      end

    end

private

    def build_http_request(transaction, transport_type, request_suffix)
      req = nil
      if !transaction.is_find_transaction? or transport_type == :soap
        req = Net::HTTP::Post.new(@url.path + "/transaction.#{request_suffix}")
        if transport_type == :soap
          # add the SOAPAction header
          soapaction = (transaction.is_find_transaction?) ? "TransactionInfo" : "SendAndCommit"
          req.add_field "soapaction", "http://secure2.e-xact.com/vplug-in/transaction/rpc-enc/#{soapaction}"
        end
        req.body = EWS::Transaction::Mapping.send "request_to_#{transport_type.to_s}", transaction
      else
        req = Net::HTTP::Get.new(@url.path + "/transaction/#{transaction.transaction_tag}.#{request_suffix}")
      end
      req
    end
    
    def get_connection
      # re-use the connection if it's available
      return @connection unless @connection.nil?
      
      @connection = Net::HTTP.new(@url.host, @url.port)
      @connection.set_debug_output $stdout if $DEBUG
      if @url.scheme == 'https'
        @connection.use_ssl = true
        @connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
        @connection.verify_callback = method(:validate_certificate)
        @connection.ca_file = @@issuer_cert
      end
      @connection
    end

    def validate_certificate(is_ok, ctx)
      cert = ctx.current_cert

      # Only check the server certificate, not the issuer.
      unless (cert.subject.to_s == cert.issuer.to_s)
        is_ok &&= (@@server_cert == cert.to_pem)
      end

      is_ok
    end

    # what transport types we support, and their corresponding suffixes
    @@transport_types = {
      :rest => {:suffix => "xml", :content_type => "application/xml"},
      :json => {:suffix => "json", :content_type => "application/json"},
      :soap => {:suffix => "xmlsoap", :content_type => "application/xml"}
    }

  end
end
