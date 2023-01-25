#!/bin/bash 
# install-demo script

echo "***** Reading variables from site.ini ******"
source ~/Wire-Server/site.ini

echo "****** Configuring DNS on host ******"
# service DNS requests locally via dnsmasq
sudo systemctl disable systemd-resolved
sudo apt install -y dnsmasq
sudo systemctl stop systemd-resolved
sudo bash -c 'echo "listen-address=127.0.0.53" > /etc/dnsmasq.d/00-lo-systemd-resolvconf'
sudo bash -c 'echo "no-resolv" >> /etc/dnsmasq.d/00-lo-systemd-resolvconf'
sudo bash -c 'echo "server=8.8.8.8" >> /etc/dnsmasq.d/00-lo-systemd-resolvconf'
sudo service dnsmasq restart

echo "***** Installing packages ******"
sudo apt install -y ufw qemu-kvm qemu-utils sgabios bridge-utils screen docker.io

echo "****** Configuring networking on host ******"
# configure firewall
sudo ufw allow 22/tcp
sudo ufw allow from 172.16.0.0/24 proto udp to any port 53
sudo ufw allow from 127.0.0.0/24 proto udp to any port 53
sudo ufw allow in on br0 from any proto udp to any port 67
sudo ufw allow from 172.16.0.0/24 proto tcp to 172.16.0.1 port 8008
sudo ufw enable

# create bridge interface
sudo brctl addbr br0
sudo ifconfig br0 172.16.0.1 netmask 255.255.255.0 up

# setup dhcp for the kvms
sudo bash -c 'echo "listen-address=172.16.0.1" > /etc/dnsmasq.d/10-br0-dhcp'
sudo bash -c 'echo "dhcp-range=172.16.0.2,172.16.0.127,10m" >> /etc/dnsmasq.d/10-br0-dhcp'
sudo service dnsmasq restart

# ip forwarding
sudo sed -i "s/.*net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf 
sudo sysctl -p

# masquerading
OUTBOUNDINTERFACE=`ip ro | grep ^default | egrep -o 'en[0-9a-fops]+'`
sudo sed -i 's/.*DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo sed -i "1i *nat\n:POSTROUTING ACCEPT [0:0]\n-A POSTROUTING -s 172.16.0.0/24 -o $OUTBOUNDINTERFACE -j MASQUERADE\nCOMMIT" /etc/ufw/before.rules
sudo service ufw restart

echo "****** Fetching Wire-Server artifact ******"
wget "${ARTIFACT_URL}"

echo "****** Extracting Wire-Server artifact ******"
tar -xzf wire-server-deploy-static-*.tgz
tar -xf debs.tar
#sudo dpkg -i debs/public/pool/main/d/docker-ce/docker-ce-cli_*.deb
#sudo dpkg -i debs/public/pool/main/c/containerd.io/containerd.io_*.deb 
#sudo dpkg -i debs/public/pool/main/d/docker-ce/docker-ce_*.deb
#sudo dpkg --configure -a

echo "****** Copy deployment scripts ******"
cp -a wire-server-deploy/kvmhelpers/ ./
cp -a wire-server-deploy/bin/newvm.sh ./bin
cp -a wire-server-deploy/bin/autoinstall ./bin
cp -a wire-server-deploy/ansible/setup-offline-sources.yml ./ansible # see https://github.com/wireapp/wire-server-deploy/blob/kvm_support/offline/docs.md#workaround-old-debian-key 
cp wire-server-deploy/offline/kvm-demo-hosts.ini hosts.ini
#cp wire-server-deploy/offline/kvm-demo-host.json .
chmod 550 ./bin/newvm.sh ./bin/autoinstall ./kvmhelpers/*.sh

echo "****** Download Ubuntu Server CD ******"
curl https://releases.ubuntu.com/18.04.6/ubuntu-18.04.6-live-server-amd64.iso -o ubuntu.iso
# WARNING: check that the instructions still work for this image, or find the mini.iso.
sudo mkdir -p /mnt/iso
sudo mount -r ubuntu.iso /mnt/iso

echo "****** Setup autoinstall web server ******"
mkdir -p ~/Wire-Server/autoinstall/d-i/bionic
cp wire-server-deploy/preseed_files/preseed_template.cfg autoinstall/
cd ~/Wire-Server/autoinstall
screen -S autoinstall_web -d -m python3 -m http.server 8008

echo "****** Create pre-seed files for each host ******"
cd ~/Wire-Server/autoinstall/d-i/bionic/
sed -e "s/NODENAME/assethost.${WIRE_DOMAIN}/" ../../preseed_template.cfg >assethost.cfg
sed -e "s/NODENAME/kubenode1.${WIRE_DOMAIN}/" ../../preseed_template.cfg >kubenode1.cfg
sed -e "s/NODENAME/kubenode2.${WIRE_DOMAIN}/" ../../preseed_template.cfg >kubenode2.cfg
sed -e "s/NODENAME/kubenode3.${WIRE_DOMAIN}/" ../../preseed_template.cfg >kubenode3.cfg
sed -e "s/NODENAME/ansnode1.${WIRE_DOMAIN}/" ../../preseed_template.cfg >ansnode1.cfg
sed -e "s/NODENAME/ansnode2.${WIRE_DOMAIN}/" ../../preseed_template.cfg >ansnode2.cfg
sed -e "s/NODENAME/ansnode3.${WIRE_DOMAIN}/" ../../preseed_template.cfg >ansnode3.cfg
cd ~/Wire-Server

echo "****** Configure KVM ******"
# add demo to kvm group
sudo usermod -a -G kvm demo

# assign each host a static DHCP address
sudo bash -c 'echo "dhcp-host=assethost,172.16.0.128,10h" > /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=kubenode1,172.16.0.129,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=kubenode2,172.16.0.130,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=kubenode3,172.16.0.131,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=ansnode1,172.16.0.132,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=ansnode2,172.16.0.133,10h" >> /etc/dnsmasq.d/20-hosts'
sudo bash -c 'echo "dhcp-host=ansnode3,172.16.0.134,10h" >> /etc/dnsmasq.d/20-hosts'
sudo service dnsmasq restart

# TODO: walk through kvm-demo-host.json instead
# sudo python3 setup-dhcp kvm-demo-host.json
#    read/parse the json file
#    for each host, print(f"dhcp-host={nodename},172.16.0.{ip},10h") into /etc/dnsmasq.d/20-hosts

echo "****** Create KVMs and Install ubuntu"

# Create kvm directories manually
./bin/newvm.sh -d 40 -m 1024 -c 1 -t tap_asset -M 0 assethost
./bin/newvm.sh -d 80 -m 8192 -c 6 -t tap_kube1 -M 1 kubenode1
./bin/newvm.sh -d 80 -m 8192 -c 6 -t tap_kube2 -M 2 kubenode2
./bin/newvm.sh -d 80 -m 8192 -c 6 -t tap_kube3 -M 3 kubenode3
./bin/newvm.sh -d 80 -m 8192 -c 6 -t tap_ans1 -M 4 ansnode1
./bin/newvm.sh -d 80 -m 8192 -c 6 -t tap_ans2 -M 5 ansnode2
./bin/newvm.sh -d 80 -m 8192 -c 6 -t tap_ans3 -M 6 ansnode3

# Run the autoinstall script for each node
cd assethost
../bin/autoinstall -d 40 -m 1024 -c 1 -t tap_asset -M 0
cd ../kubenode1
../bin/autoinstall -d 80 -m 8192 -c 6 -t tap_kube1 -M 1
cd ../kubenode2
../bin/autoinstall -d 80 -m 8192 -c 6 -t tap_kube2 -M 2
cd ../kubenode3
../bin/autoinstall -d 80 -m 8192 -c 6 -t tap_kube3 -M 3
cd ../ansnode1
../bin/autoinstall -d 80 -m 8192 -c 6 -t tap_ans1 -M 4
cd ../ansnode2
../bin/autoinstall -d 80 -m 8192 -c 6 -t tap_ans2 -M 5
cd ../ansnode3
../bin/autoinstall -d 80 -m 8192 -c 6 -t tap_ans3 -M 6
cd ..

# Backup freshly installed kvms
cp -a assethost assethost-new
cp -a ansnode1 ansnode1-new
cp -a ansnode2 ansnode2-new
cp -a ansnode3 ansnode3-new
cp -a kubenode1 kubenode1-new
cp -a kubenode2 kubenode2-new
cp -a kubenode3 kubenode3-new

# TODO
#for each one
#for host in hostparams:
#  (nodename, short, cpus, mem, disk, ip, mac_seq, nets) = host
#  tap_prefix = 'tap_' + short
#  setup_dhcp(nodename, "172.16.0." + ip)
#  create_kvm(nodename, disk, cpus, mem, mac_seq, tap_prefix)
#  install_ubuntu(nodename, cpus, mem, mac_seq, tap_prefix)
#  backup_ubuntu(nodename)
#  start_in_detached_screen(nodename)

# create kvms 
# f"bin/newvm -d {disk} -m {mem} -c {cpus} -t {tap_prefix} -M {mac_seq} {nodename}"
# autoinstall kvms
# f"(cd {nodename} && ../bin/autoinstall -m {mem} -c {cpus} -t {tap_prefix} -M {mac_seq})"
# backup freshly installed kvm
# cp -a {nodename} {nodename}-new
# start each kvm in it's own detached screen
# f"cd {nodename} && screen -S {nodename} -d -m ./start_kvm.sh"

echo "****** Stop autoinstall web server ******"
# gotta be a better way
kill -KILL `screen -list | grep '.autoinstall_web' | cut -d . -f 1 | egrep -o '[0-9]+'`
screen -wipe

echo "****** Start each KVM in it's own detached screen ******"
cd assethost    && screen -S assethost -d -m ./start_kvm.sh
cd ../kubehost1 && screen -S kubehost1 -d -m ./start_kvm.sh
cd ../kubehost2 && screen -S kubehost2 -d -m ./start_kvm.sh
cd ../kubehost3 && screen -S kubehost3 -d -m ./start_kvm.sh
cd ../anshost1  && screen -S anshost1  -d -m ./start_kvm.sh
cd ../anshost2  && screen -S anshost2  -d -m ./start_kvm.sh
cd ../anshost3  && screen -S anshost3  -d -m ./start_kvm.sh
cd ..

echo "****** More networking ******"


# TODO ??
EXTERNALIPADDRESS=`ip ro | grep ^default | egrep -o 'via [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | egrep -o '[0-9.]+'`
# get PUBLICIPADDRESS from site.ini and compare
PUBLICIPADDRESS=$EXTERNALIPADDRESS
IP_IS_PUBLIC=1


KUBENODE1IP=172.16.0.129
RESTUND01IP=172.16.0.132
#  TODO: fetch the KUBENODE1IP from nodes.params
#KUBENODE1IP=``
#RESTUND01IP=``

if [ $IP_IS_PUBLIC = 1 ]; then
  sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 80 -j DNAT --to-destination $KUBENODE1IP:31772
  sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 443 -j DNAT --to-destination $KUBENODE1IP:31773
else
  sudo iptables -t nat -A PREROUTING -i $OUTBOUNDINTERFACE -p tcp --dport 80 -j DNAT --to-destination $KUBENODE1IP:31772
  sudo iptables -t nat -A PREROUTING -i $OUTBOUNDINTERFACE -p tcp --dport 443 -j DNAT --to-destination $KUBENODE1IP:31773
fi
sudo ufw allow in on $OUTBOUNDINTERFACE proto tcp to any port 443
sudo ufw allow in on $OUTBOUNDINTERFACE proto tcp to any port 80
# Julia: do I need these?
sudo ufw allow in on $OUTBOUNDINTERFACE proto udp to any port 3478
sudo ufw allow in on $OUTBOUNDINTERFACE proto tcp to any port 3478
sudo ufw allow in on $OUTBOUNDINTERFACE proto tcp to any port 5349

# TODO: make sure to add the above iptables rules to /etc/ufw/before.rules, so they persist after a reboot
sudo iptables -t nat -A PREROUTING -i br0 -d $PUBLICIPADDRESS -p tcp --dport 80 -j DNAT --to-destination $KUBENODE1IP:31772
sudo iptables -t nat -A PREROUTING -i br0 -d $PUBLICIPADDRESS -p tcp --dport 443 -j DNAT --to-destination $KUBENODE1IP:31773

sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p udp --dport 3478 -j DNAT --to-destination $RESTUND01IP:3478
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 3478 -j DNAT --to-destination $RESTUND01IP:3478
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p tcp --dport 5349 -j DNAT --to-destination $RESTUND01IP:5349
sudo iptables -t nat -A PREROUTING -d $PUBLICIPADDRESS -i $OUTBOUNDINTERFACE -p udp -m udp --dport 32768:60999 -j DNAT --to-destination $RESTUND01IP

#ERROR: after you install restund, the restund firewall will fail to start.
#
#delete the outbound rule to 172.16.0.0/12
#
#sudo ufw status numbered
#sudo ufw delete <right number>

echo "****** Install certmanager ******"
wget https://charts.jetstack.io/charts/cert-manager-v1.9.1.tgz
mkdir tmp
(cd tmp && tar -xzf ../cert-manager-*.tgz)
mv tmp/cert-manager/ charts/
rm -rf tmp
sed -i "s/  useCertManager: false/  useCertManager: true/" values/nginx-ingress-services/values.yaml
sed -i "s/(  certmasterEmail:)/\1 ${INSTALL_EMAIL}/" values/nginx-ingress-services/values.yaml
sed -i "s/example.com/${WIRE_DOMAIN}/" values/nginx-ingress-services/values.yaml


echo "****** Create the host.ini file ******"
cp wire-server-deploy/offline/kvm-demo-hosts.ini ansible/inventory/offline/hosts.ini
sed -i "s/EXTERNAL_IP/${PUBLICIPADDRESS}/g" ansible/inventory/offline/hosts.ini
sed -i "s/DOMAIN/${WIRE_DOMAIN}/g" ansible/inventory/offline/hosts.ini
mv ansible/inventory/offline/99-static ansible/inventory/offline/orig.99-static

echo "****** Fix restund configuration ******"
# TODO:


echo "****** First phase of the install is complete ******"
echo
echo "Please run the following commands:"
echo "source ./bin/offline-env.sh"
echo "./bin/offline-secrets.sh"
echo
echo "then follow instructions from:"
echo "  https://github.com/wireapp/wire-server-deploy/blob/master/offline/docs.md#deploying-with-ansible"

