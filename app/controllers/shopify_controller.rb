require 'exact4r' # Obtain this ruby gem with "gem install exact4r"

module EWS
 class Transporter
   def my_connection
     @connection = Net::HTTP.new(@url.host, @url.port)
     if @url.scheme == 'https'
       @connection.use_ssl = true
       @connection.verify_mode = OpenSSL::SSL::VERIFY_NONE
     end
   end
 end
end

class ShopifyController < ApplicationController
  def index
    ShopifyAPI::Base.site = "https://c24cbce62005d55b1697ebc4c9a828e1:f960f9ea4338c79e8681528c2ef3a936@lemon-stand.myshopify.com/admin"
    @products = ShopifyAPI::Product.find(:all)
  end

  def create
    product_id = params[:product_id]
    @product = ShopifyAPI::Product.find(product_id)
    request = EWS::Transaction::Request.new({:transaction_type => :purchase, :amount => @product.variants.first.price, :cardholder_name => "ShopifyAPI Webservice Test", :cc_number => "4111111111111111", :cc_expiry => "1016", :gateway_id => "AD9819-01", :password => "_njgQhMA"})
    transporter = EWS::Transporter.new("https://api-demo.e-xact.com/")
    transporter.my_connection
    response = transporter.submit(request, :json)
    redirect_to shopify_path(product_id, {response: response.bank_message})
  end

  def show
    @response = params[:response]
  end

end
