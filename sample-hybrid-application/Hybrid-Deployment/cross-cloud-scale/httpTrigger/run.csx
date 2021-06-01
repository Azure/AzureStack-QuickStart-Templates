#r "Newtonsoft.Json"

using System.Net;
using System.Linq;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Primitives;
using Newtonsoft.Json;
using Microsoft.Azure.Management.AppService.Fluent;
using Microsoft.Azure.Management.AppService.Fluent.Models;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core.ResourceActions;
using Microsoft.Azure.Management.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent;
using Microsoft.Azure.Management.ResourceManager.Fluent.Core;
using Microsoft.Azure.Management.TrafficManager.Fluent;

public static IActionResult Run(HttpRequest req, TraceWriter log)
{
    string action;
    log.Info("Scale function triggered.");
    try
    {
        action = req.Query["action"];
    }
    catch (Exception e)
    {
        return new BadRequestObjectResult("Please pass a valid location.");
    }

    try
    {
        var azureCredentials = SdkContext.AzureCredentialsFactory.FromServicePrincipal("SERVICE_PRINCIPAL_ID", "SERVICE_PRINCIPAL_KEY", "DIRECTORY_ID", AzureEnvironment.AzureGlobalCloud);

        var azure = Azure.Configure().Authenticate(azureCredentials).WithDefaultSubscription();
        var trafficManager = azure.TrafficManagerProfiles.GetByResourceGroup("AZURE_RESOURCE_GROUP", "TRAFFIC_MANAGER_NAME");
        var webapp = azure.WebApps.GetByResourceGroup("AZURE_RESOURCE_GROUP", "AZURE_WEB_APP_NAME");

        if (action == "azs")
        {
            log.Info("Scaling IN to Azure Stack.");
            try
            {
                //Disable azure endpoint.
                trafficManager.Update().UpdateAzureTargetEndpoint("AZURE_TRAFFIC_MANAGER_ENDPOINT_NAME").WithTrafficDisabled().Parent().Apply();
                //Stop Webapp
                webapp.Stop();
            }
            catch (Exception e)
            {
                log.Info(e.ToString());
                return new BadRequestObjectResult("Scale in failed.");
            }
        }
        else if (action == "azure")
        {
            log.Info("Scaling OUT to Azure.");
            try
            {
                //Disable azure endpoint.
                trafficManager.Update().UpdateAzureTargetEndpoint("AZURE_TRAFFIC_MANAGER_ENDPOINT_NAME").WithTrafficEnabled().Parent().Apply();
                //Stop Webapp
                webapp.Start();
            }
            catch (Exception e)
            {
                log.Info(e.ToString());
                return new BadRequestObjectResult("Scale to Azure failed.");
            }
        }
        else
        {
            return new BadRequestObjectResult("Please pass a valid location.");
        }

        return action == null
            ? (ActionResult)new BadRequestObjectResult("Please pass a location.")
            : new OkObjectResult("Scale successful");
    }
    catch (Exception e)
    {
        log.Info(e.Message);
        return null;
    }

}
