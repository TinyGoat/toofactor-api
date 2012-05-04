xml.instruct! :xml, :version => '1.1'
xml.auth do
  xml.token @cmatch
  xml.timestamp @timestamp
  xml.expires @token_expires
  xml.token_url @token_url
  xml.client_url @client_url
end
