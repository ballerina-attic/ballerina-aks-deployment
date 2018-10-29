[![Build Status](https://travis-ci.org/ballerina-guides/ballerina-aks-deployment.svg?branch=master)](https://travis-ci.org/ballerina-guides/ballerina-aks-deployment)

# Deployment Ballerina with Azure Kubernetes Service
[AKS](https://azure.microsoft.com/en-us/services/kubernetes-service/) provides an easy to use hosted Kubernetes cluster service, which drastically reduces your time to setup your own infrastructure 

> In this guide you will learn about building a Ballerina service and deploying it on Azure Kubernetes Service (AKS).

The following are the sections available in this guide.

- [What you'll build](#what-youll-build)
- [Prerequisites](#prerequisites)
- [Implementation](#implementation)
- [Deployment](#deployment)
- [Testing](#testing)

## What you’ll build 
In this guide, you will build a simple Ballerina service that generates an UUID each time, and you will deploy that service on AKS. 

## Compatibility
| Ballerina Language Version 
| -------------------------- 
| 0.982.0

## Prerequisites
 
- [Ballerina Distribution](https://ballerina.io/learn/getting-started/)
- A Text Editor or an IDE 
- [Docker](https://docs.docker.com/engine/installation/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Docker Hub Account](https://hub.docker.com/)
- [Microsoft Azure Account](https://azure.microsoft.com/en-us/free/)

### Optional requirements
- Ballerina IDE plugins ([IntelliJ IDEA](https://plugins.jetbrains.com/plugin/9520-ballerina), [VSCode](https://marketplace.visualstudio.com/items?itemName=WSO2.Ballerina))

## Implementation

As the first step, you can build a Ballerina service that gives an UUID as the output. You can simply create a file `uuid_service.bal` and add the following content to the service code.

```ballerina
import ballerina/http;
import ballerina/system;

endpoint http:Listener uuid_ep {
    port:8080
};

@http:ServiceConfig {
    basePath:"/"
}
service<http:Service> uuid_service bind uuid_ep {

    @http:ResourceConfig {
        path:"/"
    }
    gen_uuid(endpoint outboundEP, http:Request request) {
        _ = outboundEP->respond(system:uuid());
    }

}
```

Now you can add the Kubernetes annotations that are required to generate the Kubernetes deployment artifacts. 

```ballerina
import ballerina/http;
import ballerina/system;
import ballerinax/kubernetes;
import ballerinax/docker;

@kubernetes:Service {
    name:"uuid-gen", 
    serviceType:"LoadBalancer",
    port:80
}
endpoint http:Listener uuid_ep {
    port:8080
};

@kubernetes:Deployment {
    enableLiveness:true,
    image:"<username>/uuid-gen:latest",
    push:true,
    username:"<username>",
    password:"<password>"
}
@http:ServiceConfig {
    basePath:"/"
}
service<http:Service> uuid_service bind uuid_ep {

    @http:ResourceConfig {
        path:"/"
    }
    gen_uuid(endpoint outboundEP, http:Request request) {
        _ = outboundEP->respond(system:uuid());
    }

}
```
We will be building a Docker image here, and publishing it to Docker Hub. This is required, since we cannot simply have the Docker image in the local registry, and run the Kubernetes applicates in AKS, where it needs to have access to the docker image in a globally accessible location. For this, an image name should be given in the format <username>/image_name in the "image" property, and "username" and "password" properties needs to contain the Docker Hub account username and password respectively. The property "push" is set to "true" to signal the build process to push the build docker image to Docker Hub.

You can build the Ballerina service using `$ ballerina build uuid_service.bal`. You should be able to see the following output. 

```bash
$ ballerina build uuid_service.bal
Compiling source
    uuid_service.bal

Generating executable
    uuid_service.balx
	@kubernetes:Service 			 - complete 1/1
	@kubernetes:Deployment 			 - complete 1/1
	@kubernetes:Docker 			 - complete 3/3 
	@kubernetes:Helm 			 - complete 1/1

	Run the following command to deploy the Kubernetes artifacts: 
	kubectl apply -f /home/laf/dev/uuid-service/kubernetes/

	Run the following command to install the application using Helm: 
	helm install --name uuid-service-deployment /home/laf/dev/uuid-service/kubernetes/uuid-service-deployment
```

After the build is done, the docker image would have been created, and pushed to Docker Hub, and also the Kubernetes deployment artifacts would be generated as well.
    
## Deployment
- Before deploying the service on AKS, you will need to setup the AKS environment to create the Kubernetes cluster and deploy an application

Let's start by installing the Azure command line utilities (CLI) in our local machine. Please refer to [Azure CLI Installation](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) in finding the steps for the installation.

Next step is creating an Azure Service Principal:

```bash 
$ az ad sp create-for-rbac --skip-assignment
```

The output would be similar to the following:

```bash 
{
  "appId": "e7596ae3-6864-4cb8-94fc-20164b1588a9",
  "displayName": "azure-cli-2018-10-29-21-37-08",
  "name": "http://azure-cli-2018-10-29-21-37-08",
  "password": "52c95f25-bd1e-4314-bd31-d8112b293521",
  "tenant": "72f988bf-86f1-41af-91ab-2d7cd011db48"
}
```

- Create the Kubernetes cluster

```bash 
$ az aks create \
    --resource-group myResourceGroup \
    --name myAKSCluster \
    --node-count 1 \
    --service-principal <appId> \
    --client-secret <password> \
    --generate-ssh-keys
```

- Configure kubectl to connect to AKS Kubernetes cluster

The following command will get the credentials for a given Kubernetes cluster in AKS.

```bash
$ az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

To verify the connection to your cluster, run "kubectl get nodes" command:

```bash
$ kubectl get nodes
NAME                       STATUS    ROLES     AGE       VERSION
aks-nodepool1-29389471-0   Ready     agent     10d       v1.9.11

```

- Deploying the Ballerina service to AKS

Since the Kubernetes artifacts has been automatically built in the earlier Ballerina application build, we simply have to run the following command to deploy the Ballerina service in AKS:

```bash
$ kubectl apply -f /home/laf/dev/uuid-service/kubernetes/
deployment.extensions/uuid-service-deployment created
service/uuid-gen created
```

Listing the pods in Kubernetes will show the current application being deployed successfully:

```bash
$ kubectl get pods
NAME
uuid-service-deployment-74d84d9487-7zz6n   1/1       Running   0          33s
```

After verifying that the pod is alive, we can list the services to see the status of the Kubernetes service created to represent our Ballerina service:

```bash
$ kubectl get svc
NAME               TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)          AGE
kubernetes         ClusterIP      10.0.0.1       <none>          443/TCP          10d
uuid-gen           LoadBalancer   10.0.157.35    <pending>       8080:31744/TCP   43s
```

Here, the "uuid-gen" service's "EXTERNAL-IP" is stated as pending, where this is due to the load balancer service type we defined, and it is still configuring a public IP address which we can use to access the service from outside. After a few seconds, you can check again, and you will get a valid IP address, like the following:-

```bash
$ kubectl get svc
NAME               TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)          AGE
kubernetes         ClusterIP      10.0.0.1       <none>          443/TCP          10d
uuid-gen           LoadBalancer   10.0.157.35    40.117.59.238   8080:31744/TCP   1m
```

## Testing

You've just deployed your first Ballerina service in AKS!. You can test out the service using a web browser with the URL ([http://<EXTERNAL-IP>:8080/](http://<EXTERNAL-IP>:8080/), or by running the following cURL command:

```bash
$ curl http://<EXTERNAL-IP>:8080/
9aee44b8-c11e-4876-9d87-c7a74da0dd35
```


