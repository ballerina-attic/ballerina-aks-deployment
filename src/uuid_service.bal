import ballerina/http;
import ballerinax/kubernetes;
import ballerina/system;

@kubernetes:Service {
    name:"uuid-gen", 
    serviceType:"LoadBalancer",
    port:80
}
listener http:Listener uuid_ep = new(8080);

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
service uuid_service on uuid_ep {

    @http:ResourceConfig {
        path:"/"
    }
    resource function gen_uuid(http:Caller caller, http:Request request) {
        _ = caller->respond(system:uuid());
    }

}
