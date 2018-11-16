#!/bin/bash

#What to install?
packages=true
saltstack=true
elastic=true
kibana=true
nginx=true
logstash=true
generatecert=true
configlogstash=true
kibanadashboard=true
loadfilebeat=true
setupfilebeat=true
docker=false
kubernetes=false
minions=false
testif=true

#Fixing asking for password
echo "nik ALL = NOPASSWD: /bin/chown, /bin/cp" >> /etc/sudoers


#----------------Installing packages-------------------------
if [ $packages == true ]
then
	echo "Curl"
	sudo apt-get install curl

	echo "Java"
	yes | sudo apt-get install default-jre
	yes | sudo apt-get install default-jdk
		
	echo "Kibana"
	yes | sudo apt-get install unzip

fi

#----------------Installing Saltstack------------------------
if [ $saltstack == true ]
then
	curl -L https://bootstrap.saltstack.com -o install_salt.sh
	sudo sh install_salt.sh -M

	#Accept all keys
	yes | sudo salt-key --accept-all
fi


#----------------Installing ElasticSearch------------------------
if [ $elastic == true ]
then
	#get key elastic
	wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add 
		
	echo "deb http://packages.elastic.co/elasticsearch/2.x/debian stable main" | sudo tee -a /etc/apt/sources.list.d/elasticsearch-2.x.list
		
	#update
	sudo apt-get update

	#install elastic
	yes | sudo apt-get -y install elasticsearch

	#config to localhost
	sed -i -e "s/# network.host: 192.168.0.1/network.host: localhost/g" /etc/elasticsearch/elasticsearch.yml

	#restart and enable elastic
	sudo systemctl restart elasticsearch
	sudo systemctl daemon-reload
    	sudo systemctl enable elasticsearch
fi

#----------------Installing Kibana------------------------
if [ $kibana == true ]
then
	#Get kibana
	echo "deb http://packages.elastic.co/kibana/4.5/debian stable main" | sudo tee -a /etc/apt/sources.list
	
	#update
	sudo apt-get update
	
	#install kibana
	sudo apt-get -y install kibana

	#kibana config to localhost
	sed -i -e "s/# server.host: \"0.0.0.0\"/server.host: localhost/g" /opt/kibana/config/kibana.yml

	#Restart kibana
	sudo systemctl daemon-reload
    	sudo systemctl enable kibana
    	sudo systemctl start kibana
fi

#----------------Installing NGINX------------------------
if [ $nginx == true ]
then
	#install nginx
	yes | sudo apt-get -y install nginx
	sudo -v
	
	#the variable ip = 'userinput'
	read -p "Enter ip address of Master: " ip
	username='root'
	#Edit config with password
	echo "Enter password for user: $username \n"
	echo "$username:`openssl passwd -apr1`" | sudo tee -a /etc/nginx/htpasswd.users
echo "    server {
        listen 80;

        server_name $ip;

        auth_basic \"Restricted Access\";
        auth_basic_user_file /etc/nginx/htpasswd.users;

        location / {
            proxy_pass http://localhost:5601;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;        
        }
    }
" > /etc/nginx/sites-available/default

		#Restart NGINX
		sudo systemctl restart nginx

		#Allow UWF
		sudo ufw allow 'Nginx Full'
fi

#----------------Installing Logstash------------------------
if [ $logstash == true ]
then

	#get logstash
	echo "deb http://packages.elastic.co/logstash/2.3/debian stable main" | sudo tee -a /etc/apt/sources.list

	#update
	sudo apt-get update

	#install
	sudo apt-get install logstash
fi


#----------------Generate certificate------------------------
if [ $generatecert == true ]
then
	#Creating dirs for certs
	sudo mkdir -p /etc/pki/tls/certs
    	sudo mkdir /etc/pki/tls/private
	
	#the variable ip = 'userinput'
	read -p "Enter ip address of Master: " ip

	#Adding master ip address ${ip}
	input="subjectAltName = IP: ${ip}"

	sed -i -e "s/# issuerAltName=issuer:copy/$input/g" /etc/ssl/openssl.cnf

	#Insert certificate
	cd /etc/pki/tls
	sudo openssl req -config /etc/ssl/openssl.cnf -x509 -days 3650 -batch -nodes -newkey rsa:2048 -keyout private/logstash-forwarder.key -out certs/logstash-forwarder.crt
	cd /home/nik/Desktop/

fi

#----------------Config Logstash------------------------
if [ $configlogstash == true ]
then
	#Fill logstash config file
		touch /etc/logstash/conf.d/02-beats-input.conf
		echo "input {
      beats {
        port => 5044
        ssl => true
        ssl_certificate => \"/etc/pki/tls/certs/logstash-forwarder.crt\"
        ssl_key => \"/etc/pki/tls/private/logstash-forwarder.key\"
      }
    }
" >/etc/logstash/conf.d/02-beats-input.conf

		#allow trafic over 5044
		sudo ufw allow 5044

		#Fill filter config of logstash
		echo "filter {
      if [type] == \"syslog\" {
        grok {
          match => { \"message\" => \"%{SYSLOGTIMESTAMP:syslog_timestamp} %{SYSLOGHOST:syslog_hostname} %{DATA:syslog_program}(?:\[%{POSINT:syslog_pid}\])?: %{GREEDYDATA:syslog_message}\" }
          add_field => [ \"received_at\", \"%{@timestamp}\" ]
          add_field => [ \"received_from\", \"%{host}\" ]
        }
        syslog_pri { }
        date {
          match => [ \"syslog_timestamp\", \"MMM  d HH:mm:ss\", \"MMM dd HH:mm:ss\" ]
        }
      }
    }
" >/etc/logstash/conf.d/10-syslog-filter.conf

		#Fill output conf logstash
		echo "output {
      elasticsearch {
        hosts => [\"localhost:9200\"]
        sniffing => true
        manage_template => false
        index => \"%{[@metadata][beat]}-%{+YYYY.MM.dd}\"
        document_type => \"%{[@metadata][type]}\"
      }
    }
" >/etc/logstash/conf.d/30-elasticsearch-output.conf
	
	#Restart and enable Logstash
	sudo systemctl restart logstash
	sudo systemctl enable logstash


fi


#----------------Setup kibana dashboard------------------------
if [ $kibanadashboard == true ]
then
	#Download dashboard
	cd ~
    	curl -L -O https://download.elastic.co/beats/dashboards/beats-dashboards-1.2.2.zip

	#Unzip Dashboards
	unzip beats-dashboards-*.zip

	#Load Dashboards
	cd beats-dashboards-*
    	./load.sh
	cd /home/nik/Desktop/
fi


#----------------Load filebeat in elastic------------------------
if [ $loadfilebeat == true ]
then
	#Download filebeat template
	cd ~
    	curl -O https://gist.githubusercontent.com/thisismitch/3429023e8438cc25b86c/raw/d8c479e2a1adcea8b1fe86570e42abab0f10f364/filebeat-index-template.json

	#Load template
	curl -XPUT 'http://localhost:9200/_template/filebeat?pretty' -d@filebeat-index-template.json
fi

#----------------Setup filebeat------------------------
if [ $setupfilebeat == true ]
then
	#accept all keys for the saltstack minions.
	yes | sudo salt-key --accept-all

	#Install openssh on Minion
	sudo salt '*' cmd.run 'cd /home/nik/Desktop/; yes | sudo apt-get install openssh-server; sudo service ssh restart'

	#Copy certificat from master to minion
	
	echo "Fill in password for certificate on minion!"
	#10.0.2.15
	minionip='10.0.2.18'
	scp /etc/pki/tls/certs/logstash-forwarder.crt nik@$minionip:/tmp

	#Place certificate in correct directory
	sudo salt '*' cmd.run '	sudo mkdir -p /etc/pki/tls/certs; 
				sudo cp /tmp/logstash-forwarder.crt /etc/pki/tls/certs/'

	#Download fileBeat + key on Minion
	sudo salt '*' cmd.run '	echo "deb https://packages.elastic.co/beats/apt stable main" |  sudo tee -a /etc/apt/sources.list.d/beats.list;
				wget -qO - https://packages.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -'

	#Installeren fileBeat op Minion"
	sudo salt '*' cmd.run '	sudo apt-get update;
				yes | sudo apt-get install filebeat'		

	#Edit configuration
	sudo salt '*' cmd.script "salt://changeConfigFileBeat.sh"

fi


#----------------Installing Docker------------------------
if [ $docker == true ]
then
	echo "Installing Docker"
	sudo apt-get install \
    	apt-transport-https \
    	ca-certificates \
    	curl \
    	software-properties-common

	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

	#Verify the key with the last 8 digits...
	sudo apt-key fingerprint 0EBFCD88

	sudo add-apt-repository \
  	"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   	$(lsb_release -cs) \
   	stable"

	sudo apt-get update

	sudo apt-get install -y docker-ce=18.06.1~ce~3-0~ubuntu
fi


#----------------Installing Kubernetes------------------------
if [ $kubernetes == true ]
then

	apt-get update && apt-get install -y apt-transport-https curl
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

	#Disabling swap:
	sudo swapoff -a
	#Also after reboot:
	sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
	
	#the variable ip = 'userinput'
	read -p "Enter ip address of Master: " ip
	#Initialize...
	kubeadm init --apiserver-advertise-address $ip
	
	#Create directory
	su nik -c 'mkdir -p $HOME/.kube'
	#Copy conf file
	su nik -c 'sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config'
	su nik -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config'
	

	export KUBECONFIG=/etc/kubernetes/admin.conf

	#network pod Weave Net
	kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

	openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | \
   	openssl dgst -sha256 -hex | sed 's/^.* //'
fi

#--------------------Preparing minions-----------------------
if [ $minions == true ]
then
	#salt-cp '*' /home/nik/Desktop/install_docker.sh /home/nik/Desktop/install_docker.sh
	#salt '*' cmd.script "/home/nik/Desktop/install_docker.sh"

	salt-cp '*' /home/nik/Desktop/install_kubernetes.sh /home/nik/Desktop/install_kubernetes.sh
	salt '*' cmd.script "/home/nik/Desktop/install_kubernetes.sh"

	
fi
#accept all keys for the saltstack minions.
yes | sudo salt-key --accept-all

if [ $testif == true ]
then
	echo 'hoi'
	
	
fi






















