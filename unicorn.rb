worker_processes 4
listen "/tmp/.sock", :backlog => 64
listen 80, :tcp_nopush => true
timeout 30
pid "/tmp/unicorn.pid"
