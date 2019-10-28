#!/bin/bash
sudo systemctl start firewalld
sudo systemctl enable firewalld
firewall-cmd --add-port=2379/tcp --permanent --zone=public
firewall-cmd --add-port=2380/tcp --permanent --zone=public

current_file_path=$(cd "$(dirname "$0")"; pwd)
cd ${current_file_path}

#ETCD_INITIAL_CLUSTER="etcd1=http://10.6.4.31:2380,etcd2=http://10.6.4.32:2380,etcd3=http://10.6.4.333:2380"
ETCD_INITIAL_SECURE_CLUSTER="etcd1=https://10.6.4.31:2380,etcd2=https://10.6.4.32:2380,etcd3=https://10.6.4.333:2380"

ETCD_INITIAL_CLUSTER_STATE=new

#export currentHostIp=`ip -4 address show eth0 | grep 'inet' |  grep -v grep | awk '{print $2}' | cut -d '/' -f1`

firewall-cmd --reload
firewall-cmd --list-all

#注意防火墙出现奇怪问题,集群可能还无法访问,只能本机访问,需要重现启动可以解决问题. to do

docker stop etcd2
docker rm   etcd2

docker run \
  -d \
  --restart=always \
  --hostname=etcd2 \
  -p 2379:2379 \
  -p 2380:2380 \
  -v /etc/localtime:/etc/localtime \
  -v `pwd`/data:/data \
  -v `pwd`/ssl:/etc/etcd/ssl \
  --name etcd2 \
  nexus.linkaixin.com:2443/k8s.gcr.io/etcd:3.3.10 \
   etcd \
  -name etcd2 \
  --cert-file=/etc/etcd/ssl/etcd2-server.crt \
  --key-file=/etc/etcd/ssl/etcd2-server.key \
  --peer-cert-file=/etc/etcd/ssl/etcd2-server.crt \
  --peer-key-file=/etc/etcd/ssl/etcd2-server.key \
  --trusted-ca-file=/etc/etcd/ssl/ca.pem \
  --peer-trusted-ca-file=/etc/etcd/ssl/ca.pem \
  --initial-advertise-peer-urls https://10.6.4.32:2380 \
  --listen-peer-urls https://0.0.0.0:2380 \
  --listen-client-urls https://0.0.0.0:2379 \
  --advertise-client-urls https://10.6.4.32:2379 \
  --initial-cluster-token etcd-cluster-of-ceph \
  --initial-cluster etcd1=https://10.6.4.31:2380,etcd2=https://10.6.4.32:2380,etcd3=https://10.6.4.33:2380 \
  --initial-cluster-state existing \
  --data-dir=/data

docker logs -f etcd2
