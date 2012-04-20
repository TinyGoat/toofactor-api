brew install redis
redis-server
redis-cli 
set customer:1234 foo

shotgun -p 8080 config.ru

curl 127.0.0.1:8080/api/1234/xml/
curl 127.0.0.1:8080/api/1234/json/
curl 127.0.0.1:8080/api/1234/sms/7575551212 (only my number is currently sandboxed)
