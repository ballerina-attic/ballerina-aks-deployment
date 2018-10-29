import ballerina/http;
import ballerinax/kubernetes;
import ballerinax/docker;
import ballerina/system;

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
