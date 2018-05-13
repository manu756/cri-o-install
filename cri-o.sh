#!/bin/bash

#Is necesary VM with 2 Gb of memory to run this script.

#1.runc instalation

cd && wget https://github.com/opencontainers/runc/releases/download/v1.0.0-rc4/runc.amd64 &>/dev/null
chmod +x runc.amd64
sudo mv runc.amd64 /usr/bin/runc
runc -version

#2.Cri-o instalation

wget https://storage.googleapis.com/golang/go1.8.5.linux-amd64.tar.gz &>/dev/null
tar -xf go1.8.5.linux-amd64.tar.gz -C /usr/local/
mkdir -p $HOME/go/src
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/local/go/bin:/root/go/bin" > /etc/environment
GOPATH="/root/go" >> /etc/environment
apt-get update apt-get install -y libglib2.0-dev \
                                          libseccomp-dev \
                                          libgpgme11-dev \
                                          libdevmapper-dev \
                                          make \
                                          git &>/dev/null
                                          
go get github.com/kubernetes-incubator/cri-tools/cmd/crictl &>/dev/null
cd $GOPATH/src/github.com/kubernetes-incubator/cri-tools &>/dev/null
make &>/dev/null
make install &>/dev/null

go get -d github.com/kubernetes-incubator/cri-o &>/dev/null
cd $GOPATH/src/github.com/kubernetes-incubator/cri-o &>/dev/null
make install.tools &>/dev/null
make &>/dev/null
make install &>/dev/null
make install.config &>/dev/null

sudo sh -c 'echo "[Unit]
Description=OCI-based implementation of Kubernetes Container Runtime Interface
Documentation=https://github.com/kubernetes-incubator/cri-o

[Service]
ExecStart=/usr/local/bin/crio --log-level debug
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/crio.service'

echo "registries = [ 'docker.io' ]" >> /etc/crio/crio.conf

systemctl daemon-reload
systemctl enable crio
systemctl start crio

#2.1 CNI plugins

go get -d github.com/containernetworking/plugins &>/dev/null
cd $GOPATH/src/github.com/containernetworking/plugins
./build.sh &>/dev/null
mkdir -p /opt/cni/bin
cp bin/* /opt/cni/bin/
mkdir -p /etc/cni/net.d

sudo sh -c 'cat >/etc/cni/net.d/10-mynet.conf <<-EOF
{
    "cniVersion": "0.2.0",
    "name": "mynet",
    "type": "bridge",
    "bridge": "cni0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "subnet": "10.88.0.0/16",
        "routes": [
            { "dst": "0.0.0.0/0"  }
        ]
    }
}
EOF'

sudo sh -c 'cat >/etc/cni/net.d/99-loopback.conf <<-EOF
{
    "cniVersion": "0.2.0",
    "type": "loopback"
}
EOF'

add-apt-repository ppa:projectatomic/ppa &>/dev/null
apt-get update &>/dev/null
apt-get install skopeo-containers -y &>/dev/null
systemctl restart crio

crictl --runtime-endpoint /var/run/crio/crio.sock info
CRI_RUNTIME_ENDPOINT=/var/run/crio/crio.sock
CRI_RUNTIME_ENDPOINT="/var/run/crio/crio.sock" >> /etc/environment

echo "Done!"
