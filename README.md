
参考 https://blog.csdn.net/happyfreeangel/article/details/102779844

https://pcocc.readthedocs.io/en/latest/deps/etcd-production.html

部署安全的etcd集群。
本指南说明了如何设置高可用性etcd服务器集群以及如何确保与TLS的通信安全。 本指南改编自官方的etcd文档，您可以在其中找到更多详细信息。
证书生成要启用TLS，您需要生成自签名证书颁发机构和服务器证书。 在此示例中，我们将考虑使用以下节点作为etcd服务器。
Hostname FQDN IP
node1 node1.mydomain.com 10.6.4.31
node2 node2.mydomain.com 10.6.4.32
node3 node3.mydomain.com 10.6.4.33
注意：为了获得高可用性，最好使用奇数个服务器。 添加更多服务器可提高高可用性，并可以提高读取性能，但会降低写入性能。 建议使用3、5或7个服务器。为了生成CA和服务器证书，我们按照官方文档中的建议使用Cloudflare的cfssl。 它可以很容易地安装，如下所示：

mkdir ~/bin
curl -s -L -o ~/bin/cfssl https://pkg.cfssl.org/R1.2/cfssl_linux-amd64
curl -s -L -o ~/bin/cfssljson https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64
chmod +x ~/bin/{cfssl,cfssljson}
export PATH=$PATH:~/bin

#创建一个目录来保存您的证书和私钥。 如果需要生成更多证书，将来可能会需要它们，因此请确保将它们保存在具有受限访权限的安全位置：
mkdir ~/etcd-ca
cd ~/etcd-ca

#生成CA证书
echo '{"CN":"CA","key":{"algo":"rsa","size":2048}}' | cfssl gencert -initca - | cfssljson -bare ca -
echo '{"signing":{"default":{"expiry":"43800h","usages":["signing","key encipherment","server auth","client auth"]}}}' > ca-config.json


#对于每个etcd服务器，生成如下证书：
export NAME=etcd1
export DOMAIN="linkaixin.com"
export ADDRESS=10.6.4.31,$NAME.$DOMAIN,$NAME
echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -config=ca-config.json -ca=ca.pem -ca-key=ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare $


export NAME=etcd2
export DOMAIN="linkaixin.com"
export ADDRESS=10.6.4.32,$NAME.$DOMAIN,$NAME
echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -config=ca-config.json -ca=ca.pem -ca-key=ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare $NAME


export NAME=etcd3
export DOMAIN="linkaixin.com"
export ADDRESS=10.6.4.33,$NAME.$DOMAIN,$NAME
echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -config=ca-config.json -ca=ca.pem -ca-key=ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare $NAME


注意：
如果将通过其他IP或DNS别名访问服务器，请确保在ADDRESS变量中引用它们。

现在，您必须在每个服务器节点的/ etc / etcd /目录中部署生成的密钥和证书。 例如，node1：
scp ca.pem root@node1:/etc/etcd/etcd-ca.crt
scp node1.pem root@node1:/etc/etcd/server.crt
scp node1-key.pem root@node1:/etc/etcd/server.key
ssh root@node1 chmod 600 /etc/etcd/server.key
\

#在etcd-ca目录下

 mkdir -p deploy/etcd1
 mkdir -p deploy/etcd2
 mkdir -p deploy/etcd3


cd etcd-ca/deploy/etcd1

cp ../../ca.pem etcd-ca.crt
cp ../../etcd1.pem server.crt
cp ../../etcd1-key.pem server.key


cd etcd-ca/deploy/etcd2
cp ../../ca.pem etcd-ca.crt
cp ../../etcd2.pem server.crt
cp ../../etcd2-key.pem server.key


cd etcd-ca/deploy/etcd3
cp ../../ca.pem etcd-ca.crt
cp ../../etcd3.pem server.crt
cp ../../etcd3-key.pem server.key


确保通信安全：
要为etcd配置安全的对等通信，请指定标志 --peer-key-file=peer.key 和 --peer-cert-file=peer.cert,并使用https作为URL架构。
同样，要为etcd配置安全的客户端通信，请指定标志 --key-file=k8sclient.key 和 --cert-file=k8sclient.cert, 并使用https作为URL架构。


注意：
稍后将必须在承载pcocc的所有节点（前端和计算节点）上部署CA证书ca.pem。 确保与整个etcd-ca目录一起保留备份。
etcd配置：
需要在/etc/etcd/etcd.conf配置文件中的每个服务器节点上配置etcd。 这是node1的示例：

ETCD_NAME=node1
ETCD_LISTEN_PEER_URLS="https://10.19.213.101:2380"
ETCD_LISTEN_CLIENT_URLS="https://10.19.213.101:2379"
ETCD_INITIAL_CLUSTER_TOKEN="pcocc-etcd-cluster"
ETCD_INITIAL_CLUSTER="node1=https://node1.mydomain.com:2380,node2=https://node2.mydomain.com:2380,node3=https://node3.mydomain.com:2380"
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://node1.mydomain.com:2380"
ETCD_ADVERTISE_CLIENT_URLS="https://node1.mydomain.com:2379"
ETCD_TRUSTED_CA_FILE=/etc/etcd/etcd-ca.crt
ETCD_CERT_FILE="/etc/etcd/server.crt"
ETCD_KEY_FILE="/etc/etcd/server.key"
ETCD_PEER_CLIENT_CERT_AUTH=true
ETCD_PEER_TRUSTED_CA_FILE=/etc/etcd/etcd-ca.crt
ETCD_PEER_KEY_FILE=/etc/etcd/server.key
ETCD_PEER_CERT_FILE=/etc/etcd/server.crt


注意
ETCD_NAME，ETCD_ADVERTISE_CLIENT_URLS，ETCD_INITIAL_ADVERTISE_PEER_URLS，ETCD_LISTEN_PEER_URLS和ETCD_LISTEN_CLIENT_URLS必须适合每个服务器节点。
最后，您可以在所有etcd节点上启用并启动服务：
systemctl enable etcd
systemctl start etcd



检查ETCD状态
要检查您的etcd服务器是否正常运行，可以执行以下操作：
$ etcdctl --endpoints=https://node1.mydomain.com:2379 --ca-file=~/etcd-ca/ca.pem member list
6c86f26914e6ace, started, Node2, https://node3.mydomain.com:2380, https://node3.mydomain.com:2379
1ca80865c0583c45, started, Node1, https://node2.mydomain.com:2380, https://node2.mydomain.com:2379
99c7caa3f8dfeb70, started, Node0, https://node1.mydomain.com:2380, https://node1.mydomain.com:2379

[ceph@ceph1 ~]$ docker exec etcd1 etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem member list
2e26c284a608e734: name=etcd1 peerURLs=https://10.6.4.31:2380 clientURLs=https://10.6.4.31:2379 isLeader=true
86110446cab57f89: name=etcd2 peerURLs=https://10.6.4.32:2380 clientURLs=https://10.6.4.32:2379 isLeader=false
ebbc05ecb174c1c3: name=etcd3 peerURLs=https://10.6.4.33:2380 clientURLs=https://10.6.4.33:2379 isLeader=false



为pcocc配置etcd

启用身份验证之前，请在etcd中配置root用户：
etcdctl --endpoints="https://node1.mydomain.com:2379" --ca-file=~/etcd-ca/ca.pem  user add root

docker exec etcd1
/ #  etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem  user add root
New password:
User root created
/ #  etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem  user add etcd
New password:
User etcd created

docker exec etcd1 etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem  user add root


警告
选择一个安全密码。 您必须在pcocc配置文件中引用它。
启用身份验证：
etcdctl --endpoints="https://node1.mydomain.com:2379" --ca-file=~/etcd-ca/ca.pem auth enable
etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem auth enable



Remove the guest role:
$ etcdctl --endpoints="https://node1.mydomain.com:2379" --ca-file=~/etcd-ca/ca.pem -u root:<password> role remove guest
Role guest removed

etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem -u root:kaixin.com role remove guest


未经身份验证，您将不再能够访问密钥库：
$ etcdctl --endpoints "https://node1.mydomain.com:2379" --ca-file=~/etcd-ca/ca.pem  get /
Error:  110: The request requires user authentication (Insufficient credentials) [0]


#在ceph1 上操作 添加一个key=test value=test123
etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem -u root:kaixin.com set test test123
test123
/ # etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem -u root:kaixin.com get test

Run a command in a running container
[ceph@ceph2 secure-etcd]$ docker exec -ti etcd2 sh
/ # etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem -u root:kaixin.com get test
test123
/ # etcdctl --endpoints=https://10.6.4.31:2379 --ca-file=/etc/etcd/ssl/ca.pem  get test
Error:  110: The request requires user authentication (Insufficient credentials) [0]