#-----------------------Installing packages-----------------------
echo "Installing Curl"
sudo apt-get install curl


#-----------------------Installing Saltstack-----------------------

curl -L https://bootstrap.saltstack.com -o install_salt.sh

#the variable ip = 'userinput'
read -p "Enter ip address of Master: " ip

sudo sh install_salt.sh -A $ip
