#r "Newtonsoft.Json"

using System;
using System.Net;
using Newtonsoft.Json;
using SendGrid;
using SendGrid.Helpers.Mail; 

public static async Task<object> Run(HttpRequestMessage req, TraceWriter log)
{

    string jsonContent = await req.Content.ReadAsStringAsync();
    log.Info($"Received data: {jsonContent}");
    dynamic data = JsonConvert.DeserializeObject(jsonContent);


    if (string.IsNullOrEmpty((string)data.email) ||
        string.IsNullOrEmpty((string)data.etheradmin) ||
        string.IsNullOrEmpty((string)data.rpc))
    {
        return req.CreateResponse(HttpStatusCode.BadRequest, new
        {
            status = "failure",
            msg = "Missing required params"
        });
    }

    bool isStandalone = string.IsNullOrEmpty((string)data.gatewayId);
    bool deployedOMS = !string.IsNullOrEmpty((string)data.oms);
    string emailTemplate = File.ReadAllText(@"D:\home\site\wwwroot\EmailProxyWebhook\email-template.html");
    string emailBody = emailTemplate.Replace("##ETHERADMIN_URL##", (string)data.etheradmin)
                                    .Replace("##RPC_ENDPOINT##", (string)data.rpc)
                                    .Replace("##OMS_DASHBOARD##", (string)data.oms)
                                    .Replace("##HIDE_IF_NO_OMS##", deployedOMS ? "" : "hide")
                                    .Replace("##HIDE_IF_STANDALONE##", isStandalone ? "hide" : "")
                                    .Replace("##CONSORTIUM_DATA_URL##", (string)data.consortiumUrl)
                                    .Replace("##GATEWAY_ID##", (string)data.gatewayId);
    
    // Welcome Email
    SendMail((string)data.email, "Blockchain Deployment Completed", emailBody).Wait();

    return req.CreateResponse(HttpStatusCode.OK, new
    {
        status = "success",
        msg = "Welcome! You'll receive an email shortly."
    });
}

public static async Task SendMail(string email, string subject, string content)
{          
    string apiKey = "<SENDGRID_APIKEY>";
    
    dynamic sg = new SendGridAPIClient(apiKey);

    Email from = new Email("donotreply@outlook.com");            
    Email to = new Email(email);
    Content innerContent = new Content("text/html", content);
    Mail mail = new Mail(from, subject, to, innerContent);

    dynamic response = await sg.client.mail.send.post(requestBody: mail.Get());
}
