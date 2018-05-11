#!/bin/bash

#Is necesary VM with 2 Gb of memory to run this script.

#1.runc instalation

wget https://github.com/opencontainers/runc/releases/download/v1.0.0-rc4/runc.amd64
chmod +x runc.amd64
sudo mv runc.amd64 /usr/bin/runc
runc -version

#2.Cri-o instalation

wget https://storage.googleapis.com/golang/go1.8.5.linux-amd64.tar.gz
sudo tar -xvf go1.8.5.linux-amd64.tar.gz -C /usr/local/
mkdir -p $HOME/go/src
export GOPATH=$HOME/go
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/usr/local/go/bin:/root/bin" > /etc/environment
GOPATH="/root/go" >> /etc/environment
sudo apt-get update && apt-get install -y libglib2.0-dev \
                                          libseccomp-dev \
                                          libgpgme11-dev \
                                          libdevmapper-dev \
                                          make \
                                          git
go get -d github.com/kubernetes-incubator/cri-o
cd $GOPATH/src/github.com/kubernetes-incubator/cri-o
make install.tools
make
make install
make install.config

sudo sh -c 'echo "[Unit]
Description=OCI-based implementation of Kubernetes Container Runtime Interface
Documentation=https://github.com/kubernetes-incubator/cri-o

[Service]
ExecStart=/usr/local/bin/crio --log-level debug
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/crio.service'

sudo systemctl daemon-reload
sudo systemctl enable crio
sudo systemctl start crio

#2.1 CNI plugins

go get -d github.com/containernetworking/plugins
cd $GOPATH/src/github.com/containernetworking/plugins
./build.sh
sudo mkdir -p /opt/cni/bin
sudo cp bin/* /opt/cni/bin/
sudo mkdir -p /etc/cni/net.d
sudo add-apt-repository ppa:projectatomic/ppa
sudo apt-get update
sudo apt-get install skopeo-containers -y
systemctl restart crio

#3.Get crictl
go get github.com/kubernetes-incubator/cri-tools/cmd/crictl
cd go/src/github.com/kubernetes-incubator/cri-tools/cmd/crictl
make
make install

sudo crictl --runtime-endpoint /var/run/crio/crio.sock info
$CRI_RUNTIME_ENDPOINT=/var/run/crio/crio.sock
CRI_RUNTIME_ENDPOINT="/var/run/crio/crio.sock" >> /etc/environment
