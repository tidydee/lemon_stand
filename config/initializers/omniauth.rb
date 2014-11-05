Rails.application.config.middleware.use OmniAuth::Builder do
  provider :shopify, 'c24cbce62005d55b1697ebc4c9a828e1', '46ecba4f224a10400ed1aa54039e9b5e'
end
