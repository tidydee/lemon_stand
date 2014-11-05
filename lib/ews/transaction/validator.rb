module EWS  # :nodoc:
  module Transaction  # :nodoc:
    module Validator
      
      @@valid_lengths = {
        :authorization_num => 8,
        :cardholder_name => 30,
        :cc_number => 19,
        :cc_expiry => 4,
        :cavv => 40,
        :client_email => 30,
        :client_ip => 15,
        :customer_ref => 20,
        :gateway_id => 10,
        :pan => 39,
        :password => 30,
        :reference_3 => 30,
        :reference_no => 20,
        :tax1_number => 20,
        :tax2_number => 20,
        :track1 => 79,
        :track2 => 40,
        :transaction_type => 2,
        :cc_verification_str1 => 40,
        :cc_verification_str2 => 4,
        :xid => 40,
        :zip_code => 10
      }.freeze unless defined?(@@valid_lengths)
      
      def valid?
        @errors = {}

        validate_lengths
        
        validate_mandatory_fields
        
        append_error(:transaction_type, "transaction_type must be supplied") if self.transaction_type.blank?
      
        # need to authenticate
        append_error(:gateway_id, "gateway_id must be supplied") if self.gateway_id.blank?
        append_error(:password, "password must be supplied") if self.password.blank?

        # ensure we've been given valid amounts
        append_error(:amount, "invalid amount supplied") unless valid_amount?(self.amount)
        append_error(:surcharge_amount, "invalid surcharge_amount supplied") unless valid_amount?(self.surcharge_amount)
        append_error(:tax1_amount, "invalid tax1_amount supplied") unless valid_amount?(self.tax1_amount)
        append_error(:tax2_amount, "invalid tax2_amount supplied") unless valid_amount?(self.tax2_amount)

        # ensure our amounts are within range
        append_error(:amount, "amount must be between 0.00 and 99999.99") unless amount_in_range?(self.amount)
        append_error(:surcharge_amount, "amount must be between 0.00 and 99999.99") unless amount_in_range?(self.surcharge_amount)
        append_error(:tax1_amount, "amount must be between 0.00 and 99999.99") unless amount_in_range?(self.tax1_amount)
        append_error(:tax2_amount, "amount must be between 0.00 and 99999.99") unless amount_in_range?(self.tax2_amount)
        
        # ensure our credit card information is valid
        append_error(:cc_number, "invalid cc_number supplied") unless valid_card_number?
        append_error(:cc_expiry, "invalid cc_expiry supplied") unless valid_expiry_date?
        
        @errors.empty?
      end
      
    private
      def validate_lengths
        @@valid_lengths.each do |k,len|
          value = self.send k
          append_error(k, "#{k.to_s} is too long. Maximum allowed length is #{len} characters") unless value.nil? or (value.length <= len)
        end
      end
      
      # which fields are mandatory and which optional depends on the transaction_type and
      # also how the credit card information is supplied.
      #
      # it can be supplied either
      # a) via the cc_number field
      # b) via a tagged transaction
      # c) encoded in a track1 value, or
      # d) encoded in a track2 value
      def validate_mandatory_fields
        validate_for_card unless self.cc_number.blank?
        validate_for_transaction_tag unless self.transaction_tag.blank?
        validate_for_track1 unless self.track1.blank?
        validate_for_track2 unless self.track2.blank?
      end
      
      def valid_amount?(amount)
        return true if amount.blank?

        ((amount.class == Float) or (amount.class == Fixnum) or !amount.match(/[^0-9.]/))        
      end
      def amount_in_range?(amount)
        return true if amount.blank?

        return ((amount.to_f <= 99999.99) and (amount.to_f >= 0.0))
      end

      def valid_card_number?
        return true if self.cc_number.blank?

        # do a mod10 check
        weight = 1
        card_number = self.cc_number.scan(/./).map(&:to_i)
        result = card_number.reverse[1..-1].inject(0) do |sum, num|
          weight = 1 + weight%2
          digit = num * weight
          sum += (digit / 10) + (digit % 10)
        end
        card_number.last == (10 - result % 10 ) % 10
      end

      # date should be...
      # - not blank
      # - 4 digits
      # - MMYY format
      # - not in the past
      def valid_expiry_date?
        return true if self.cc_expiry.blank?
      
        # check format
        return false unless self.cc_expiry.match(/^\d{4}$/)
      
        # check date is not in past
        year, month = self.cc_expiry[2..3].to_i, self.cc_expiry[0..1].to_i
        year += (year > 79) ? 1900 : 2000

    		# CC is still considered valid during the month of expiry,
    		# so just compare year and month, ignoring the rest.
    		now = DateTime.now
        return ((1..12) === month) && DateTime.new(year, month) >= DateTime.new(now.year, now.month)
      end
      
      def append_error(key, message)
        if @errors[key].nil?
          @errors[key] = message 
        else
          # otherwise convert into an array of errors
          current_val = @errors[key]
          if current_val.is_a?(String)
            @errors[key] = [current_val, message]
          else
            @errors[key] << message
          end
        end
      end

      # validate presence of mandatory fields when cc_number present
      def validate_for_card
        tt = self.transaction_type.to_i
        
        # mandatory: transaction_type must != (30, 31, 32, 34, 35)
        append_error(:cc_number, "cc_number must not be set for tagged transactions") if [30,31,32,34,35].include?(tt)
        
        # amount, cardholder_name always mandaory
        mandatory = [:amount, :cardholder_name]
        
        # card_number & expiry_date mandatory for all except 50, 54
        # pan mandatory for only 50, 54
        mandatory << ([50,54].include?(tt) ? :pan : [:cc_number, :cc_expiry])
        mandatory.flatten!

        # reference_no mandatory for 60
        mandatory << :reference_no if tt == 60
        
        # auth_number mandatory for (02, 03, 11, 12, 13)
        mandatory << :authorization_num if [02, 03, 11, 12, 13].include?(tt)
        
        check_mandatory(mandatory)
      end

      def validate_for_transaction_tag
        tt = self.transaction_type

        # mandatory: transaction_type must == (30, 31, 32, 34, 35)
        append_error(:transaction_tag, "transaction_tag must only be set for tagged transactions") unless ['30','31','32','34','35','CR'].include?(tt)
        
        # transaction_tag, auth_num & amount mandatory
        mandatory = [:transaction_tag]
        mandatory << [:authorization_num, :amount] unless tt == 'CR'
        
        check_mandatory(mandatory.flatten)
      end
      
      def validate_for_track1
        tt = self.transaction_type.to_i
        
        # mandatory: transaction_type must != (30, 31, 32, 34, 35)
        append_error(:track1, "track1 must not be set for tagged transactions") if [30,31,32,34,35].include?(tt)

        # amount mandatory for all
        mandatory = [:amount]
        
        # track1 mandatory, except 50,54
        # pan mandatory 50,54 only
        mandatory << ([50,54].include?(tt) ? :pan : :track1)

        # reference_no mandatory for 60
        mandatory << :reference_no if tt == 60
        # auth_number mandatory for (02, 03, 11, 12, 13)
        mandatory << :authorization_num if [02, 03, 11, 12, 13].include?(tt)
        
        check_mandatory(mandatory)
      end
      
      def validate_for_track2
        tt = self.transaction_type.to_i

        # mandatory: transaction_type must != (30, 31, 32, 34, 35, 50, 54)
        append_error(:track2, "track2 must not be set for tagged transactions") if [30,31,32,34,35,50,54].include?(tt)

        # track2, expiry_date, cardholder_name, amount mandatory
        mandatory = [:track2, :cc_expiry, :cardholder_name, :amount]
        
        # auth_number mandatory for (02, 03, 11, 12, 13)
        mandatory << :authorization_num if [02, 03, 11, 12, 13].include?(tt)
        
        check_mandatory(mandatory)
      end
      
      def check_mandatory(mandatory)
        mandatory.each do |key|
          append_error(key, "#{key} is required") if self.send(key).blank?
        end
      end
    end
  end
end
  