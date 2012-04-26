xml.instruct! :xml, :version => '1.1'
xml.auth do
  xml.token @cmatch
  xml.timestamp @timestamp
  xml.expires @token_expires
  xml.tokenURL @token_url
  xml.clientURL @client_url
end
