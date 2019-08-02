# samba-ad-dc container
A samba active directory domain controller container to run on a Kubernetes cluster.

## Getting Started

### Prerequisites
Samba doesn't really fit with the modern app in container model. But with a few
tricks we can make it all work. The guide is based around a baremetal onsite Kubernetes
cluster with some slight differences to a regular Kubernetes network setup.

If you want to run this in your cloud environment you're on your own for now. You'll
need good knowledge of Samba and how Windows AD domains work. Please feel free to contribute
back to the project if you manage to get this working.

#### Static IP address
This is important. If Samba's IP address changes every time the container/pod is recreated it causes a few problems.

Samba adds/updates DNS entries each time it starts. If the IP address changes it adds a new entry for itself every time.
Some of the other DNS entries use the domain controller as their CNAME, which then references every DNS entry for the domain controller.
Your Windows machines will have all manner of problems trying to talk to the domain controller.

It's not good enough to simply expose Samba using a Kubernetes load balancer Service with a statically configured IP address.
The IP address Samba gets on the network on which it will be acting as the domain controller needs to be static. I cannot stress this enough.

The best way to do this seems to be using [multus-cni](https://github.com/intel/multus-cni) and a network bridge on your Kubernetes hosts to the network on which your Windows machines will live.

Once multus is setup in addition to your existing CNI it's then easy to give your pods a static address on that network

```yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: samba-ad-dc-static-ip-conf
spec:
  config: '{
    "cniVersion": "0.3.1",
	"name": "lan",
	"type": "bridge",
	"bridge": "br-lan",
	"ipam": {
		"type": "static",
		"addresses": [
			{
				"address": "10.1.0.1/16"
			}
		]
    }
}'
```

### Kubernetes
Once you have a networking setup that will work with Samba it's time to add the samba pod to your Kubernetes cluster

Take [](The example Kubernetes yaml file and edit it to your needs.)

The obvious things to think about are:

#### Static IP external to the cluster on the network where your Windows machines will live
The dc StatefulSet resource needs to be told to add the additional network interface to the pods it creates based on the multus config.
```yaml
spec:
  template:
    metadata:
      annotations:
        k8s.v1.cni.cncf.io/networks: samba-ad-dc-static-ip-conf
```
This must match the name of the NetworkAttachmentDefinition that was created in the multus configuration.

#### Static IP internal to the Kubernetes cluster for the DNS part of the container
In the samba-ad-dc-dns Service resource you need to specify clusterIP. This must be within your serviceSubnet. This exposes bind running in the container to the Kubernetes cluster on a static I address. Eventually you can configure the domain handled by Samba in CoreDNS to hand off to bind within our Samba container so that everything in the Kubernetes cluster can resolve things on the Samba domain
```yaml
spec:
  type: ClusterIP
  clusterIP: 10.96.53.53
```

#### Environment variables
The following environment variables must be configured in the container template section of the dc StatefulSet resource
* SAMBA_DOMAIN - the name of your samba domain, eg. SAMDOM
* SAMBA_REALM - the full domain name for the samba domain, eg. SAMDOM.EXAMPLE.COM
* SAMBA_DOMAIN_PASSWORD - the initial password for the Administrator user. Only used on initial domain controller initialisation. Can be removed afterwards.
* NET_DEV - the name of the network device that Samba will bind to and use to work out its IP address. If using multus as described above this will likely need to be set to 'net1'

```yaml
spec:
   template:
     spec:
       containers:
       - image: opensourcery/samba-ad-dc:4
         name: samba-ad-dc
         env:
         - name: SAMBA_DOMAIN
           value: SAMDOM
         - name: SAMBA_REALM
           value: SAMDOM.EXAMPLE.COM
         - name: SAMBA_DOMAIN_PASSWORD
           value: TEMPORARY_ADMIN_PASSWORD
```

#### Persistent Volumes
Assuming that you want to persist your data, you should define persistent volumes for the following paths within you pods
* /var/lib/samba
* /etc/samba
* /var/log/samba

How you do that is entirely down to your environment. The example template in the Stateful set already references the volumes and their mount points like so:
```yaml
         volumeMounts:
         - name: samba-ad-dc-var-lib
           mountPath: /var/lib/samba
         - name: samba-ad-dc-etc
           mountPath: /etc/samba
         - name: samba-ad-dc-var-log
           mountPath: /var/log/samba
```

So you need to define volumes matching those names or have some auto persistent volume provisioning configured.

## Building the image and pushing it to a docker registry
Assuming you have a dockerhub account (or other docker compatible registry) you can simply run the build script

```bash
# ./build.sh <registry/image_name> [tag]
```
For example
```bash
# ./build.sh opensourcery/samba-ad-dc 4
```
